import AVFoundation
import Foundation

/// Turns the speech the proxy returns into a file an alarm can actually ring.
///
/// A spoken line is the whole alarm — no tone under it, no tone after it. What
/// it is not is long enough on its own: AlarmKit exposes no way to ask for a
/// sound to repeat, and the observed behaviour changed between iOS 26.0, which
/// played a custom sound once, and 26.1, which repeats it. Nine seconds that
/// play once leave nineteen seconds of silence where an alarm should be, and on
/// iOS 17-25 the notification path plays the file exactly once per ring.
///
/// So the line is repeated to a fixed length with a pause between passes, which
/// is how a person actually wakes someone: say it, wait, say it again. Whichever
/// way the system behaves the result works, and it costs nothing extra — the
/// repeats are copies of audio already paid for.
enum GeneratedVoiceAssembler {
    /// What the proxy sends back: headerless mono 16-bit PCM.
    static let speechSampleRate: Double = 24_000

    /// What the shipped tones are, and therefore what the assembled file is. The
    /// speech is converted up to meet the tone rather than the tone converted
    /// down, so the bundled audio is never re-encoded and the ten tones stay
    /// byte-identical to what already ships.
    static let outputSampleRate: Double = 44_100

    /// Silence between one pass of the line and the next. Long enough to read as
    /// a pause rather than a stutter, short enough that the alarm never sounds
    /// like it has stopped.
    static let gapBetweenRepeats: TimeInterval = 1.5

    enum AssemblyError: Error {
        case emptySpeech
        case conversionFailed
    }

    /// - Parameter speech: raw little-endian 16-bit mono PCM at `speechSampleRate`.
    /// - Returns: a complete WAV, `GeneratedVoiceStore.assembledDuration` long.
    static func assemble(speech: Data) throws -> Data {
        let resampled = try resampleToOutputRate(speech)
        guard !resampled.isEmpty else {
            throw AssemblyError.emptySpeech
        }

        let total = Int(GeneratedVoiceStore.assembledDuration * outputSampleRate)
        let limit = Int(GeneratedVoiceStore.maximumSpeechDuration * outputSampleRate)
        let gap = Int(gapBetweenRepeats * outputSampleRate)

        // Trust nothing about the length: the model has no duration parameter, so
        // a clip longer than the budget is a normal outcome rather than a fault.
        let line = Array(resampled.prefix(min(limit, total)))
        var frames = [Int16](repeating: 0, count: total)

        var cursor = 0
        while cursor < total {
            for i in 0..<line.count where cursor + i < total {
                frames[cursor + i] = line[i]
            }
            cursor += line.count + gap
        }

        return wav(frames: frames, sampleRate: outputSampleRate)
    }

    /// Converts the proxy's 24 kHz speech up to the tones' 44.1 kHz.
    ///
    /// The two rates have to meet somewhere, and meeting at the tones' rate means
    /// the bundled audio is copied rather than resampled — a tone that already
    /// ships and already works should not be re-encoded on device to accommodate
    /// a new feature.
    private static func resampleToOutputRate(_ pcm: Data) throws -> [Int16] {
        guard let input = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: speechSampleRate,
            channels: 1,
            interleaved: true
        ), let output = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: outputSampleRate,
            channels: 1,
            interleaved: true
        ), let converter = AVAudioConverter(from: input, to: output) else {
            throw AssemblyError.conversionFailed
        }

        let inputFrames = AVAudioFrameCount(pcm.count / 2)
        guard inputFrames > 0,
              let inputBuffer = AVAudioPCMBuffer(pcmFormat: input, frameCapacity: inputFrames),
              let channel = inputBuffer.int16ChannelData else {
            throw AssemblyError.conversionFailed
        }
        inputBuffer.frameLength = inputFrames
        pcm.withUnsafeBytes { raw in
            channel[0].update(
                from: raw.bindMemory(to: Int16.self).baseAddress!,
                count: Int(inputFrames)
            )
        }

        let ratio = outputSampleRate / speechSampleRate
        let capacity = AVAudioFrameCount(Double(inputFrames) * ratio) + 1_024
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: output, frameCapacity: capacity) else {
            throw AssemblyError.conversionFailed
        }

        var supplied = false
        var conversionError: NSError?
        converter.convert(to: outputBuffer, error: &conversionError) { _, status in
            if supplied {
                status.pointee = .endOfStream
                return nil
            }
            supplied = true
            status.pointee = .haveData
            return inputBuffer
        }
        if conversionError != nil {
            throw AssemblyError.conversionFailed
        }

        return samples(from: outputBuffer)
    }

    private static func samples(from buffer: AVAudioPCMBuffer) -> [Int16] {
        guard let channel = buffer.int16ChannelData else {
            return []
        }
        return Array(UnsafeBufferPointer(start: channel[0], count: Int(buffer.frameLength)))
    }

    /// Wraps samples in a RIFF header. Both alarm paths resolve a sound by file
    /// name and neither will play headerless PCM.
    static func wav(frames: [Int16], sampleRate: Double) -> Data {
        let byteCount = frames.count * 2
        var data = Data(capacity: 44 + byteCount)

        func ascii(_ string: String) { data.append(contentsOf: Array(string.utf8)) }
        func u32(_ value: UInt32) { withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }
        func u16(_ value: UInt16) { withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }

        let rate = UInt32(sampleRate)
        ascii("RIFF"); u32(UInt32(36 + byteCount)); ascii("WAVE")
        ascii("fmt "); u32(16); u16(1); u16(1)
        u32(rate); u32(rate * 2); u16(2); u16(16)
        ascii("data"); u32(UInt32(byteCount))
        frames.withUnsafeBufferPointer { data.append(UnsafeRawBufferPointer($0).bindMemory(to: UInt8.self)) }
        return data
    }
}
