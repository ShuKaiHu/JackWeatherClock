import AVFoundation
import XCTest
@testable import RainyClock

/// The assembler exists because AlarmKit will not say whether it repeats a custom
/// sound — iOS 26.0 played one once, 26.1 repeats it, and there is no API to ask.
/// These pin the property that makes that stop mattering: the file is a complete
/// alarm either way.
final class GeneratedVoiceAssemblerTests: XCTestCase {
    private let rate = GeneratedVoiceAssembler.outputSampleRate
    private let bed = CommuteAlarmSettings.AlarmSound.rainyClock.fileName

    /// Silence, in the format the proxy returns: 24 kHz mono 16-bit.
    private func speech(seconds: Double) -> Data {
        Data(count: Int(seconds * GeneratedVoiceAssembler.speechSampleRate) * 2)
    }

    private func frames(of wav: Data) -> [Int16] {
        // 44-byte canonical RIFF header, which is what `wav(frames:sampleRate:)` writes.
        wav.dropFirst(44).withUnsafeBytes { Array($0.bindMemory(to: Int16.self)) }
    }

    func testAssembledClipIsAlwaysTheSameLength() throws {
        // Whatever comes back, the alarm rings for the same span. A ten-second
        // line that plays once would otherwise leave eighteen seconds of silence.
        for seconds in [0.5, 3.0, 9.9, 25.0] {
            let data = try GeneratedVoiceAssembler.assemble(speech: speech(seconds: seconds), bedFileName: bed)
            XCTAssertEqual(
                frames(of: data).count,
                Int(GeneratedVoiceStore.assembledDuration * rate),
                "speech of \(seconds)s produced the wrong total length"
            )
        }
    }

    func testTheRemainderIsAudibleToneRatherThanSilence() throws {
        let data = try GeneratedVoiceAssembler.assemble(speech: speech(seconds: 2), bedFileName: bed)
        let all = frames(of: data)
        let budget = Int(GeneratedVoiceStore.maximumSpeechDuration * rate)

        // Silent speech was supplied, so anything non-zero after the budget is the
        // tone bed — the half that makes this still work as an alarm.
        XCTAssertTrue(all[budget...].contains { $0 != 0 })
    }

    func testTheBedStartsAtTheBudgetNotWhereTheSpeechStopped() throws {
        // A short line gets a beat of silence before the tone rather than the two
        // running together.
        let data = try GeneratedVoiceAssembler.assemble(speech: speech(seconds: 1), bedFileName: bed)
        let all = frames(of: data)
        let budget = Int(GeneratedVoiceStore.maximumSpeechDuration * rate)
        XCTAssertTrue(all[(budget - 1_000)..<budget].allSatisfy { $0 == 0 })
    }

    func testAMissingToneIsAnErrorRatherThanASilentFile() {
        XCTAssertThrowsError(
            try GeneratedVoiceAssembler.assemble(speech: speech(seconds: 2), bedFileName: "NotShipped.wav")
        )
    }

    func testTheHeaderIsSomethingAVFoundationWillOpen() throws {
        // Both alarm paths hand the file to the system, not to our own player, so
        // "it parses" is the only check that means anything.
        let data = try GeneratedVoiceAssembler.assemble(speech: speech(seconds: 2), bedFileName: bed)
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
