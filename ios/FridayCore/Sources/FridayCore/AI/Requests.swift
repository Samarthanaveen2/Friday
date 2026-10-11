import Foundation

/// Request bodies and reply parsing for the OpenAI-compatible endpoints (Groq, Gemini).
public enum CloudRequests {
    /// Multipart body for /audio/transcriptions (PLAN §4: language en, temperature 0, dictionary as prompt).
    public static func whisperBody(wav: Data, prompt: String, boundary: String, model: String = Models.whisper) -> Data {
        var body = Data()
        func field(_ name: String, _ value: String) {
            body.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n".utf8))
        }
        field("model", model)
        field("language", "en")
        field("temperature", "0")
        field("response_format", "json")
        if !prompt.isEmpty { field("prompt", prompt) }
        body.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"audio.wav\"\r\nContent-Type: audio/wav\r\n\r\n".utf8))
        body.append(wav)
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))
        return body
    }

    /// JSON body for /chat/completions.
    public static func chatBody(model: String, system: String, user: String, maxTokens: Int,
                                reasoningEffort: String?, json: Bool = false) -> Data {
        var object: [String: Any] = [
            "model": model,
            "messages": [["role": "system", "content": system], ["role": "user", "content": user]],
            "temperature": 0,
            "max_tokens": maxTokens,
        ]
        if let reasoningEffort { object["reasoning_effort"] = reasoningEffort }
        if json { object["response_format"] = ["type": "json_object"] }
        return try! JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    /// Output budget: ~1.5× the input plus room for a short reasoning pass (gpt-oss counts it).
    public static func cleanupMaxTokens(for text: String) -> Int {
        let words = text.split(whereSeparator: \.isWhitespace).count
        return min(2_000, Int(Double(words) * 1.5 * 1.4) + 256)
    }

    public static func whisperText(_ data: Data) -> String? {
        guard let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return nil }
        return (object["text"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func chatText(_ data: Data) -> String? {
        guard let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let choices = object["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String
        else { return nil }
        return content
    }
}
