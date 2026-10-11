// Speech bench helper (macOS 26): transcribes each <id>.wav in a folder with Apple's on-device
// SpeechTranscriber — the same recogniser the app runs as its second ear — and prints JSON {id: text}.
// Usage: swift AppleSpeech.swift <folder with wavs>
import AVFoundation
import Foundation
import Speech

@main
struct AppleSpeech {
    static func main() async throws {
        let folder = URL(fileURLWithPath: CommandLine.arguments[1])
        let installed = await SpeechTranscriber.installedLocales
        FileHandle.standardError.write(Data("installed \(installed.map(\.identifier))\n".utf8))
        let wanted = await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: "en-IN"))
        let fallback = await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: "en-US"))
        let ready = installed.first { $0.language.languageCode?.identifier == "en" }
        guard let locale = ready ?? wanted ?? fallback else { fatalError("SpeechTranscriber has no English model here") }
        FileHandle.standardError.write(Data("locale \(locale.identifier)\n".utf8))
        // Models are per-app "reservations"; reserve English before checking the download.
        if let reserved = try? await AssetInventory.reserve(locale: locale) {
            FileHandle.standardError.write(Data("reserved \(reserved)\n".utf8))
        }
        let probe = SpeechTranscriber(locale: locale, transcriptionOptions: [], reportingOptions: [], attributeOptions: [])
        do {
            if let request = try await AssetInventory.assetInstallationRequest(supporting: [probe]) {
                try await request.downloadAndInstall()
            }
        } catch {
            FileHandle.standardError.write(Data("model download: \(error.localizedDescription) (trying anyway)\n".utf8))
        }

        let files = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "wav" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        var results: [String: String] = [:]
        for file in files {
            let id = file.deletingPathExtension().lastPathComponent
            let transcriber = SpeechTranscriber(locale: locale, transcriptionOptions: [], reportingOptions: [], attributeOptions: [])
            let analyzer = SpeechAnalyzer(modules: [transcriber])
            let collector = Task { () -> String in
                var text = ""
                for try await result in transcriber.results where result.isFinal {
                    text += String(result.text.characters)
                }
                return text
            }
            let audio = try AVAudioFile(forReading: file)
            if let last = try await analyzer.analyzeSequence(from: audio) {
                try await analyzer.finalizeAndFinish(through: last)
            } else {
                await analyzer.cancelAndFinishNow()
            }
            let text = try await collector.value.trimmingCharacters(in: .whitespacesAndNewlines)
            results[id] = text
            FileHandle.standardError.write(Data("\(id): \(text.prefix(80))…\n".utf8))
        }
        let data = try JSONSerialization.data(withJSONObject: results, options: [.sortedKeys, .prettyPrinted])
        print(String(decoding: data, as: UTF8.self))
    }
}
