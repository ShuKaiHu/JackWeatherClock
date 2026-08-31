import AVFoundation
import XCTest
@testable import RainyClock

/// The assembler exists because AlarmKit will not say whether it repeats a custom
/// sound — iOS 26.0 played one once, 26.1 repeats it, and there is no API to ask.
/// These pin the property that makes that stop mattering: the file is a complete
/// alarm either way.
final class GeneratedVoiceAssemblerTests: XCTestCase {
    private let rate = GeneratedVoiceAssembler.outputSampleRate

    /// A tone in the format the proxy returns — 24 kHz mono 16-bit — so the
    /// repeats are findable in the output. Silence would prove nothing.
    private func speech(seconds: Double) -> Data {
        let rate = GeneratedVoiceAssembler.speechSampleRate
        let frames = (0..<Int(seconds * rate)).map { i -> Int16 in
            Int16(12_000 * sin(2 * .pi * 440 * Double(i) / rate))
        }
        return frames.withUnsafeBufferPointer { Data(buffer: $0) }
    }

    private func frames(of wav: Data) -> [Int16] {
        // 44-byte canonical RIFF header, which is what `wav(frames:sampleRate:)` writes.
        wav.dropFirst(44).withUnsafeBytes { Array($0.bindMemory(to: Int16.self)) }
    }

    func testAssembledClipIsAlwaysTheSameLength() throws {
        // Whatever comes back, the alarm rings for the same span. A nine-second
        // line that plays once would otherwise leave nineteen seconds of silence.
        for seconds in [0.5, 3.0, 9.9, 25.0] {
            let data = try GeneratedVoiceAssembler.assemble(speech: speech(seconds: seconds))
            XCTAssertEqual(
                frames(of: data).count,
                Int(GeneratedVoiceStore.assembledDuration * rate),
                "speech of \(seconds)s produced the wrong total length"
            )
        }
    }

    func testNoSilenceLastsLongerThanThePause() throws {
        // The property that matters is not "audio at the very end" — the clip can
        // legitimately finish mid-pause — but that it never goes quiet for long
        // enough to read as the alarm having stopped.
        for seconds in [1.0, 2.0, 5.5, 9.9] {
            let all = frames(of: try GeneratedVoiceAssembler.assemble(speech: speech(seconds: seconds)))
            var longest = 0
            var run = 0
            for sample in all {
                run = sample == 0 ? run + 1 : 0
                longest = max(longest, run)
            }
            let allowed = Int((GeneratedVoiceAssembler.gapBetweenRepeats + 0.2) * rate)
            XCTAssertLessThanOrEqual(
                longest, allowed,
                "a \(seconds)s line left \(Double(longest) / rate)s of silence"
            )
        }
    }

    func testThereIsAPauseBetweenPasses() throws {
        // Say it, wait, say it again — not a stutter.
        let data = try GeneratedVoiceAssembler.assemble(speech: speech(seconds: 2))
        let all = frames(of: data)
        let lineEnd = Int(2 * rate)
        let gap = Int(GeneratedVoiceAssembler.gapBetweenRepeats * rate)
        XCTAssertTrue(all[lineEnd..<(lineEnd + gap)].allSatisfy { $0 == 0 })
        XCTAssertNotEqual(all[lineEnd + gap + 100], 0, "the second pass should start after the gap")
    }

    func testSpeechLongerThanItsBudgetIsTruncatedRatherThanRefused() throws {
        // The model has no duration parameter, so an over-long clip is a normal
        // outcome, not a fault.
        let data = try GeneratedVoiceAssembler.assemble(speech: speech(seconds: 25))
        XCTAssertEqual(frames(of: data).count, Int(GeneratedVoiceStore.assembledDuration * rate))
    }

    func testEmptySpeechIsAnErrorRatherThanASilentAlarm() {
        XCTAssertThrowsError(try GeneratedVoiceAssembler.assemble(speech: Data()))
    }

    func testTheHeaderIsSomethingAVFoundationWillOpen() throws {
        // Both alarm paths hand the file to the system, not to our own player, so
        // "it parses" is the only check that means anything.
        let data = try GeneratedVoiceAssembler.assemble(speech: speech(seconds: 2))
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("assembler-\(UUID().uuidString).wav")
        try data.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let file = try AVAudioFile(forReading: url)
        XCTAssertEqual(file.fileFormat.sampleRate, rate)
        XCTAssertEqual(file.fileFormat.channelCount, 1)
        XCTAssertEqual(Double(file.length) / rate, GeneratedVoiceStore.assembledDuration, accuracy: 0.01)
    }

    func testTheAssembledLengthStaysUnderTheNotificationLimit() {
        // iOS 17-25 route the same file through UNNotificationSound, whose limit is
        // *less than* 30 seconds; a file on the boundary is silently swapped for
        // the default tone.
        XCTAssertLessThan(GeneratedVoiceStore.assembledDuration, 30)
        XCTAssertLessThan(GeneratedVoiceStore.maximumSpeechDuration, GeneratedVoiceStore.assembledDuration)
    }
}
