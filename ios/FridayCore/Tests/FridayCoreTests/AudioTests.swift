import Foundation
import XCTest
@testable import FridayCore

private let rate = AudioFormat.sampleRate

/// Deterministic test audio: quiet hiss with loud "speech" (a 220 Hz tone) at given seconds.
private func audio(seconds: Double, speech: [ClosedRange<Double>], noise: Float = 0.002) -> [Float] {
    var seed: UInt32 = 12345
    return (0..<Int(seconds * Double(rate))).map { i in
        seed = seed &* 1_664_525 &+ 1_013_904_223
        let hiss = (Float(seed % 2000) / 1000 - 1) * noise
        let t = Double(i) / Double(rate)
        let talking = speech.contains { $0.contains(t) }
        return hiss + (talking ? Float(0.3 * sin(2 * .pi * 220 * t)) : 0)
    }
}

final class RingBufferTests: XCTestCase {
    func testKeepsNewestInOrder() {
        var ring = RingBuffer(capacity: 4)
        ring.append(contentsOf: [1, 2, 3])
        XCTAssertEqual(ring.snapshot(), [1, 2, 3])
        ring.append(contentsOf: [4, 5, 6])
        XCTAssertEqual(ring.snapshot(), [3, 4, 5, 6])
        ring.append(contentsOf: [7, 8, 9, 10, 11])
        XCTAssertEqual(ring.snapshot(), [8, 9, 10, 11])
        ring.removeAll()
        XCTAssertEqual(ring.snapshot(), [])
    }
}

final class SpeechFramesTests: XCTestCase {
    func testFindsSpeechAndSilence() {
        let samples = audio(seconds: 3, speech: [1.0...2.0])
        let flags = SpeechFrames.detect(samples)
        XCTAssertEqual(flags.count, 150)
        XCTAssertFalse(flags[10])
        XCTAssertTrue(flags[75])
        XCTAssertFalse(flags[140])
        XCTAssertTrue(Recording(samples: samples).hasSpeech)
    }

    func testSilenceAndHissAreNotSpeech() {
        XCTAssertFalse(Recording(samples: audio(seconds: 2, speech: [])).hasSpeech)
        XCTAssertFalse(Recording(samples: Array(repeating: 0, count: rate)).hasSpeech)
        XCTAssertFalse(Recording(samples: []).hasSpeech)
    }

    func testShortGapsInsideSpeechStaySpeech() {
        let flags = SpeechFrames.detect(audio(seconds: 3, speech: [0.5...1.0, 1.1...1.5]))
        // 100 ms gap at 1.0–1.1 s (frames 50–55) is bridged.
        XCTAssertTrue(flags[52])
    }
}

final class RecordingTests: XCTestCase {
    func testTrimKeepsMargins() {
        let trimmed = Recording(samples: audio(seconds: 4, speech: [1.0...2.0])).trimmed()
        // ~1 s of speech + 0.2 s each side.
        XCTAssertEqual(trimmed.duration, 1.4, accuracy: 0.06)
        XCTAssertTrue(trimmed.hasSpeech)
    }

    func testTrimSilenceIsEmpty() {
        XCTAssertEqual(Recording(samples: audio(seconds: 2, speech: [])).trimmed().samples.count, 0)
    }
}

final class ChunkPlannerTests: XCTestCase {
    func testShortDictationGoesWhole() {
        let r = Recording(samples: audio(seconds: 10, speech: [1...4, 5...9]))
        XCTAssertEqual(ChunkPlanner.chunks(r), [0..<r.samples.count])
    }

    func testLongDictationCutsOnlyInPauses() {
        // Speech with 1 s pauses at 8–9 s and 17–18 s, and a short 0.3 s gap at 12 s.
        let speech: [ClosedRange<Double>] = [0.5...8, 9...12, 12.3...17, 18...25]
        let r = Recording(samples: audio(seconds: 26, speech: speech))
        let chunks = ChunkPlanner.chunks(r)
        XCTAssertEqual(chunks.count, 3)
        let cuts = chunks.dropFirst().map { Double($0.lowerBound) / Double(rate) }
        XCTAssertEqual(cuts[0], 8.5, accuracy: 0.1)
        XCTAssertEqual(cuts[1], 17.5, accuracy: 0.1)
        XCTAssertEqual(chunks.last?.upperBound, r.samples.count)
    }

    func testEmptyChunksAreDropped() {
        XCTAssertEqual(ChunkPlanner.chunks(Recording(samples: audio(seconds: 5, speech: []))), [])
        XCTAssertEqual(ChunkPlanner.chunks(Recording(samples: [])), [])
    }
}

final class LiveChunkerTests: XCTestCase {
    /// Feeds the audio as it would arrive, in 1.5 s steps, like the app's timer.
    private func runLive(_ samples: [Float]) -> (LiveChunker, [Range<Int>]) {
        var chunker = LiveChunker()
        var uploaded: [Range<Int>] = []
        var n = 0
        while n < samples.count {
            n = min(samples.count, n + Int(1.5 * Double(rate)))
            let sofar = Array(samples[0..<n])
            while let range = chunker.update(samples: sofar) { uploaded.append(range) }
        }
        return (chunker, uploaded)
    }

    func testCoversEverySampleWithNoGaps() {
        // 40 s with pauses at 9–10, 18–19, 27–28 s and loud and quiet stretches.
        let samples = audio(seconds: 40, speech: [0.5...9, 10...18, 19...27, 28...39.5])
        let (chunker, uploaded) = runLive(samples)
        let ranges = chunker.finalRanges(total: samples.count)
        XCTAssertGreaterThanOrEqual(ranges.count, 2)
        XCTAssertEqual(ranges.first?.lowerBound, 0)
        XCTAssertEqual(ranges.last?.upperBound, samples.count)
        for (a, b) in zip(ranges, ranges.dropFirst()) { XCTAssertEqual(a.upperBound, b.lowerBound) }
        // Everything uploaded live is exactly one of the final ranges (reused as-is).
        for range in uploaded { XCTAssertTrue(ranges.contains(range)) }
    }

    func testCutsOnlyInPausesAndNeverMove() {
        let samples = audio(seconds: 40, speech: [0.5...9, 10...18, 19...27, 28...39.5])
        let (chunker, _) = runLive(samples)
        for cut in chunker.cuts {
            let t = Double(cut) / Double(rate)
            XCTAssertTrue([9.0...10.0, 18.0...19.0, 27.0...28.0].contains { $0.contains(t) }, "cut at \(t)")
        }
        var again = chunker
        XCTAssertNil(again.update(samples: samples))
        XCTAssertEqual(again.cuts, chunker.cuts)
    }

    func testShortRecordingsStayWhole() {
        let samples = audio(seconds: 12, speech: [0.5...5, 6...11])
        let (chunker, uploaded) = runLive(samples)
        XCTAssertEqual(uploaded, [])
        XCTAssertEqual(chunker.finalRanges(total: samples.count), [0..<samples.count])
        XCTAssertEqual(LiveChunker().finalRanges(total: 0), [])
    }
}

final class WAVTests: XCTestCase {
    func testHeaderAndSamples() {
        let data = WAV.encode([0, 1, -1, 2])
        XCTAssertEqual(data.count, 44 + 8)
        XCTAssertEqual(String(data: data[0..<4], encoding: .ascii), "RIFF")
        XCTAssertEqual(String(data: data[8..<12], encoding: .ascii), "WAVE")
        XCTAssertEqual(String(data: data[36..<40], encoding: .ascii), "data")
        let rateBytes = data[24..<28].withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }
        XCTAssertEqual(UInt32(littleEndian: rateBytes), 16_000)
        let samples = data[44...].withUnsafeBytes { Array($0.bindMemory(to: Int16.self)) }.map { Int16(littleEndian: $0) }
        XCTAssertEqual(samples, [0, Int16.max, -Int16.max, Int16.max])
    }
}
