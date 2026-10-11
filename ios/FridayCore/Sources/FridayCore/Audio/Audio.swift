import Foundation

/// Audio format used everywhere after capture: 16 kHz mono float (what Whisper wants).
public enum AudioFormat {
    public static let sampleRate = 16_000
    /// 20 ms analysis frames.
    public static let frameSize = 320
    public static let frameSeconds = Double(frameSize) / Double(sampleRate)
}

/// Fixed-size ring of the most recent samples: the 1 s pre-roll prepended to every dictation,
/// so the first word is never lost (RISKS B2).
public struct RingBuffer: Sendable {
    public let capacity: Int
    private var storage: [Float]
    private var head = 0
    public private(set) var count = 0

    public init(capacity: Int) {
        precondition(capacity > 0)
        self.capacity = capacity
        storage = Array(repeating: 0, count: capacity)
    }

    public mutating func append(contentsOf samples: [Float]) {
        let incoming = samples.count > capacity ? Array(samples.suffix(capacity)) : samples
        for sample in incoming {
            storage[head] = sample
            head = (head + 1) % capacity
        }
        count = min(capacity, count + incoming.count)
    }

    /// Oldest first.
    public func snapshot() -> [Float] {
        guard count > 0 else { return [] }
        let start = (head - count + capacity) % capacity
        if start + count <= capacity { return Array(storage[start..<(start + count)]) }
        return Array(storage[start...] + storage[..<head])
    }

    public mutating func removeAll() {
        head = 0
        count = 0
    }
}

/// Finds speech in audio by loudness against the room's own noise level.
/// Used to trim silence, skip empty chunks (Whisper invents text on silence, RISKS B1)
/// and find pauses to cut long dictations at.
public enum SpeechFrames {
    /// Below this RMS nothing counts as speech, however quiet the room.
    static let minimumLevel: Float = 0.008
    /// Speech must be this many times louder than the noise floor.
    static let factor: Float = 3

    public static func rms(_ samples: ArraySlice<Float>) -> Float {
        guard !samples.isEmpty else { return 0 }
        var sum: Float = 0
        for s in samples { sum += s * s }
        return (sum / Float(samples.count)).squareRoot()
    }

    public static func levels(_ samples: [Float]) -> [Float] {
        stride(from: 0, to: samples.count, by: AudioFormat.frameSize).map { start in
            rms(samples[start..<min(samples.count, start + AudioFormat.frameSize)])
        }
    }

    /// One flag per 20 ms frame. Short gaps inside speech (under `hangover` frames) count as speech.
    public static func detect(_ samples: [Float], hangover: Int = 8) -> [Bool] {
        let levels = levels(samples)
        guard !levels.isEmpty else { return [] }
        // The quietest frames tell us the room's noise floor; the loud ones how loud the voice is.
        // Capping by the voice level keeps it working when there is barely any pause at all.
        let sorted = levels.sorted()
        let floor = sorted[sorted.count / 10]
        let peak = sorted[min(sorted.count - 1, sorted.count * 95 / 100)]
        let threshold = max(minimumLevel, min(floor * factor, peak * 0.3))
        var flags = levels.map { $0 > threshold }
        var lastSpeech: Int?
        for i in flags.indices {
            if flags[i] {
                if let last = lastSpeech, i - last > 1, i - last <= hangover {
                    for j in (last + 1)..<i { flags[j] = true }
                }
                lastSpeech = i
            }
        }
        return flags
    }
}

/// One dictation's audio: the pre-roll plus everything captured until ✓.
public struct Recording: Sendable, Equatable {
    public var samples: [Float]

    public init(samples: [Float]) {
        self.samples = samples
    }

    public var duration: Double { Double(samples.count) / Double(AudioFormat.sampleRate) }

    /// At least 100 ms of speech somewhere.
    public var hasSpeech: Bool {
        SpeechFrames.detect(samples).filter { $0 }.count >= 5
    }

    /// Cuts leading and trailing silence, keeping a small margin so words aren't clipped.
    /// Returns an empty recording if there is no speech at all.
    public func trimmed(marginSeconds: Double = 0.2) -> Recording {
        let flags = SpeechFrames.detect(samples)
        guard let first = flags.firstIndex(of: true), let last = flags.lastIndex(of: true) else {
            return Recording(samples: [])
        }
        let margin = Int(marginSeconds * Double(AudioFormat.sampleRate))
        let start = max(0, first * AudioFormat.frameSize - margin)
        let end = min(samples.count, (last + 1) * AudioFormat.frameSize + margin)
        return Recording(samples: Array(samples[start..<end]))
    }
}

/// Splits a long dictation at real pauses so the finished parts can be uploaded while
/// you're still talking (PLAN §5.3, RISKS B3).
public enum ChunkPlanner {
    /// Dictations shorter than this go whole.
    public static let wholeUpTo: Double = 20
    /// A pause must last this long to cut at it.
    public static let minPause: Double = 0.6
    /// Don't make chunks shorter than this.
    public static let minChunk: Double = 6

    /// Sample ranges to send, in order. Ranges with no speech are left out.
    public static func chunks(_ recording: Recording) -> [Range<Int>] {
        let samples = recording.samples
        guard !samples.isEmpty else { return [] }
        let flags = SpeechFrames.detect(samples)
        let all = [0..<samples.count]
        let ranges = recording.duration <= wholeUpTo ? all : cut(flags: flags, total: samples.count)
        return ranges.filter { range in
            let firstFrame = range.lowerBound / AudioFormat.frameSize
            let lastFrame = min(flags.count, (range.upperBound + AudioFormat.frameSize - 1) / AudioFormat.frameSize)
            return flags[firstFrame..<lastFrame].filter { $0 }.count >= 5
        }
    }

    private static func cut(flags: [Bool], total: Int) -> [Range<Int>] {
        let pauseFrames = Int(minPause / AudioFormat.frameSeconds)
        let chunkFrames = Int(minChunk / AudioFormat.frameSeconds)
        var cuts: [Int] = []
        var chunkStart = 0
        var i = 0
        while i < flags.count {
            guard !flags[i] else { i += 1; continue }
            var j = i
            while j < flags.count, !flags[j] { j += 1 }
            // A long enough pause, far enough from the last cut, and not the trailing silence.
            if j - i >= pauseFrames, (i + j) / 2 - chunkStart >= chunkFrames, j < flags.count {
                let middle = (i + j) / 2
                cuts.append(middle)
                chunkStart = middle
            }
            i = j
        }
        var ranges: [Range<Int>] = []
        var start = 0
        for frame in cuts {
            let sample = frame * AudioFormat.frameSize
            ranges.append(start..<sample)
            start = sample
        }
        ranges.append(start..<total)
        return ranges
    }
}

/// Cuts a long dictation at pauses *while you're talking*, so finished parts upload early.
/// A cut never moves once made, and the final ranges cover every sample exactly once:
/// no audio can fall between two chunks (RISKS B3).
public struct LiveChunker: Sendable {
    /// Recordings shorter than this are never cut.
    public static let startAfter: Double = 15
    public static let minPause: Double = 0.6
    public static let minChunk: Double = 6
    /// Leave the newest audio alone: the pause there may still be growing into speech.
    public static let keepClearOfEnd: Double = 1

    public private(set) var cuts: [Int] = []

    public init() {}

    /// Looks only at the audio after the last cut. If it holds a qualifying pause, commits a cut
    /// in its middle and returns the finished chunk to upload. Call repeatedly until nil.
    public mutating func update(samples: [Float]) -> Range<Int>? {
        let rate = Double(AudioFormat.sampleRate)
        guard Double(samples.count) / rate > LiveChunker.startAfter else { return nil }
        let start = cuts.last ?? 0
        let end = samples.count - Int(LiveChunker.keepClearOfEnd * rate)
        guard end - start > Int(LiveChunker.minChunk * rate) else { return nil }

        let flags = SpeechFrames.detect(Array(samples[start..<end]))
        let pauseFrames = Int(LiveChunker.minPause / AudioFormat.frameSeconds)
        let minFrames = Int(LiveChunker.minChunk / AudioFormat.frameSeconds)
        var i = 0
        while i < flags.count {
            guard !flags[i] else { i += 1; continue }
            var j = i
            while j < flags.count, !flags[j] { j += 1 }
            let middle = (i + j) / 2
            // Long enough, far enough from the last cut, and speech came back after it.
            if j - i >= pauseFrames, middle >= minFrames, j < flags.count {
                let cut = start + middle * AudioFormat.frameSize
                cuts.append(cut)
                return start..<cut
            }
            i = j
        }
        return nil
    }

    /// Every chunk in order, back to back from the first sample to the last.
    public func finalRanges(total: Int) -> [Range<Int>] {
        var ranges: [Range<Int>] = []
        var start = 0
        for cut in cuts where cut > start && cut < total {
            ranges.append(start..<cut)
            start = cut
        }
        if start < total { ranges.append(start..<total) }
        return ranges
    }
}

/// 16-bit PCM WAV, the upload format for Groq Whisper.
public enum WAV {
    public static func encode(_ samples: ArraySlice<Float>, sampleRate: Int = AudioFormat.sampleRate) -> Data {
        var data = Data(capacity: 44 + samples.count * 2)
        func u32(_ v: UInt32) { withUnsafeBytes(of: v.littleEndian) { data.append(contentsOf: $0) } }
        func u16(_ v: UInt16) { withUnsafeBytes(of: v.littleEndian) { data.append(contentsOf: $0) } }
        let byteCount = UInt32(samples.count * 2)
        data.append(contentsOf: Array("RIFF".utf8)); u32(36 + byteCount)
        data.append(contentsOf: Array("WAVE".utf8))
        data.append(contentsOf: Array("fmt ".utf8)); u32(16); u16(1); u16(1)
        u32(UInt32(sampleRate)); u32(UInt32(sampleRate * 2)); u16(2); u16(16)
        data.append(contentsOf: Array("data".utf8)); u32(byteCount)
        for s in samples {
            let clipped = max(-1, min(1, s))
            u16(UInt16(bitPattern: Int16(clipped * Float(Int16.max))))
        }
        return data
    }

    public static func encode(_ samples: [Float], sampleRate: Int = AudioFormat.sampleRate) -> Data {
        encode(samples[...], sampleRate: sampleRate)
    }
}
