import AVFoundation
import Foundation

/// Turns the speech the proxy returns into a file an alarm can actually ring.
///
/// The speech alone is not an alarm. It is ten seconds at most, and AlarmKit
/// exposes no way to ask for it to repeat — the observed behaviour changed
/// between iOS 26.0, which played a custom sound once, and 26.1, which repeats
/// it. A ten-second clip that plays once leaves eighteen seconds of silence
/// where an alarm should be.
///
/// So every clip is assembled to a fixed length: the speech first, then the tone
/// the user already chose, looped to fill the rest. Whichever way the system
/// behaves, the result works — played once it is a complete alarm, repeated it
/// alternates speech and tone, which is easier to wake up to than speech on a
/// loop.
enum GeneratedVoiceAssembler {
    /// What the proxy sends back: headerless mono 16-bit PCM.
    static let speechSampleRate: Double = 24_000

    /// What the shipped tones are, and therefore what the assembled file is. The
    /// speech is converted up to meet the tone rather than the tone converted
    /// down, so the bundled audio is never re-encoded and the ten tones stay
    /// byte-identical to what already ships.
    static let outputSampleRate: Double = 44_100

    enum AssemblyError: Error {
        case bedMissing(String)
        case conversionFailed
    }

    /// - Parameters:
    ///   - speech: raw little-endian 16-bit mono PCM at `speechSampleRate`.
    ///   - bedFileName: a tone from the app bundle to fill the remainder.
    /// - Returns: a complete WAV, `GeneratedVoiceStore.assembledDuration` long.
    static func assemble(speech: Data, bedFileName: String) throws -> Data {
        let speechFrames = try resampleToOutputRate(speech)
        let bed = try loadBed(named: bedFileName)

        let total = Int(GeneratedVoiceStore.assembledDuration * outputSampleRate)
        let speechLimit = Int(GeneratedVoiceStore.maximumSpeechDuration * outputSampleRate)
        var frames = [Int16](repeating: 0, count: total)

        // Trust nothing about the length: the model has no duration parameter, so
        // a clip longer than the budget is a normal outcome rather than a fault.
        let spoken = min(speechFrames.count, speechLimit, total)
        for i in 0..<spoken {
            frames[i] = speechFrames[i]
        }

        // The bed starts where the speech budget ends, not where the speech
        // happens to stop, so a short line leaves a beat of silence before the
        // tone instead of running straight into it.
        if !bed.isEmpty {
            for i in speechLimit..<total {
                frames[i] = bed[(i - speechLimit) % bed.count]
            }
        }

        return wav(frames: frames, sampleRate: outputSampleRate)
    }

    /// Reads a bundled tone down to bare samples. Any format AVFoundation can
    /// open works, so this keeps holding once the shipped tones change.
    private static func loadBed(named fileName: String) throws -> [Int16] {
        let name = (fileName as NSString).deletingPathExtension
        let ext = (fileName as NSString).pathExtension
        guard let url = Bundle.main.url(forResource: name, withExtension: ext.isEmpty ? "wav" : ext) else {
            throw AssemblyError.bedMissing(fileName)
        }

        let file = try AVAudioFile(forReading: url)
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: outputSampleRate,
            channels: 1,
            interleaved: true
        ), let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: AVAudioFrameCount(file.length)
        ) else {
            throw AssemblyError.conversionFailed
        }

        try file.read(into: buffer)
        return samples(from: buffer)
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
