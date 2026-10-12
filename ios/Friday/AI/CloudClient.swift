import Foundation
import FridayCore

struct CloudError: Error, Sendable {
    enum Kind: Sendable { case noKey, useBackup(TimeInterval), badKey, failed(Int), network, empty }
    let kind: Kind
}

/// One warm HTTP/2 connection for Groq and Gemini (PLAN §5.6).
final class CloudClient: Sendable {
    static let shared = CloudClient()

    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.httpMaximumConnectionsPerHost = 4
        config.waitsForConnectivity = false
        session = URLSession(configuration: config)
    }

    /// Opens the connection early so the first dictation doesn't pay for TLS.
    func warm(key: String) {
        var request = URLRequest(url: Models.groqBase.appendingPathComponent("models"))
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        let session = session
        Task.detached { _ = try? await session.data(for: request) }
    }

    /// `m4a`: the audio is compressed AAC instead of WAV.
    /// `seconds`: the audio's length, for the usage meter.
    func transcribe(wav: Data, prompt: String, key: String, m4a: Bool = false, seconds: Double? = nil) async throws -> String {
        let boundary = "friday-\(UUID().uuidString)"
        var request = URLRequest(url: Models.groqBase.appendingPathComponent("audio/transcriptions"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = m4a
            ? CloudRequests.whisperBody(wav: wav, prompt: prompt, boundary: boundary, filename: "audio.m4a", contentType: "audio/mp4")
            : CloudRequests.whisperBody(wav: wav, prompt: prompt, boundary: boundary)
        let data = try await send(request, model: Models.whisper, audioSeconds: seconds)
        guard let text = CloudRequests.whisperText(data) else { throw CloudError(kind: .empty) }
        return text
    }

    func chat(base: URL, key: String, body: Data) async throws -> String {
        var request = URLRequest(url: base.appendingPathComponent("chat/completions"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        let data = try await send(request, model: Usage.model(inRequest: body))
        guard let text = CloudRequests.chatText(data) else { throw CloudError(kind: .empty) }
        return text
    }

    private func send(_ request: URLRequest, model: String?, audioSeconds: Double? = nil) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw CloudError(kind: .network)
        }
        let http = response as? HTTPURLResponse
        let status = http?.statusCode ?? 0
        if let model {
            var headers: [String: String] = [:]
            for (name, value) in http?.allHeaderFields ?? [:] {
                if let name = name as? String, let value = value as? String { headers[name.lowercased()] = value }
            }
            let ok = status == 200
            await MainActor.run {
                UsageBook.shared.record(model: model, headers: headers, body: ok || status == 429 ? data : nil, audioSeconds: audioSeconds, ok: ok)
            }
        }
        switch CallOutcome.from(status: status, body: String(decoding: data.prefix(1000), as: UTF8.self)) {
        case .ok: return data
        case .useBackup(let seconds): throw CloudError(kind: .useBackup(seconds))
        case .badKey: throw CloudError(kind: .badKey)
        case .failed: throw CloudError(kind: .failed(status))
        }
    }
}

/// The quota tracker, saved between launches.
@MainActor
final class QuotaBook {
    static let shared = QuotaBook()
    private var quota: Quota
    private let defaults = UserDefaults.standard

    private init() {
        quota = (defaults.data(forKey: "ai.quota")).flatMap { try? JSONDecoder().decode(Quota.self, from: $0) } ?? Quota()
    }

    func available(_ key: String) -> Bool { quota.available(key, now: .now) }

    func restingUntil(_ key: String) -> Date? { quota.restingUntil(key, now: .now) }

    func record(_ key: String) {
        quota.record(key, now: .now)
        save()
    }

    /// Applies what a failed call means for this provider.
    func failed(_ key: String, _ error: Error) {
        if let error = error as? CloudError, case .useBackup(let seconds) = error.kind {
            quota.coolDown(key, for: seconds, now: .now)
            save()
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(quota) { defaults.set(data, forKey: "ai.quota") }
    }
}

/// Runs `operation`, giving up with nil after `seconds`.
/// Returns on time even if the work ignores cancellation (like awaiting another task's value);
/// a task group would quietly wait for it to finish.
func withTimeout<T: Sendable>(_ seconds: Double, _ operation: @escaping @Sendable () async -> T?) async -> T? {
    let once = Once<T?>()
    return await withCheckedContinuation { continuation in
        let work = Task {
            let value = await operation()
            once.resume(continuation, with: value)
        }
        Task {
            try? await Task.sleep(for: .seconds(seconds))
            work.cancel()
            once.resume(continuation, with: nil)
        }
    }
}

/// Resumes a continuation exactly once, whichever side gets there first.
private final class Once<T: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var done = false

    func resume(_ continuation: CheckedContinuation<T, Never>, with value: T) {
        lock.lock()
        let first = !done
        done = true
        lock.unlock()
        if first { continuation.resume(returning: value) }
    }
}
