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
        let wanted = await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: "en-IN"))
        let fallback = await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: "en-US"))
        guard let locale = wanted ?? fallback else { fatalError("SpeechTranscriber has no English model here") }
        FileHandle.standardError.write(Data("locale \(locale.identifier)\n".utf8))
        let probe = SpeechTranscriber(locale: locale, transcriptionOptions: [], reportingOptions: [], attributeOptions: [])
        if let request = try await AssetInventory.assetInstallationRequest(supporting: [probe]) {
            try await request.downloadAndInstall()
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
