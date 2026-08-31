import AVFoundation
import SwiftUI

/// Where a user writes what the alarm should say and hears who will say it.
///
/// Two decisions and a sentence, in that order, and only the last one costs
/// anything: every voice can be auditioned from clips shipped in the bundle, so
/// nobody spends a generation — or waits on the network — to find out what a
/// persona sounds like.
struct AIVoiceSheet: View {
    /// Roughly nine seconds of speech either way. The two numbers differ because
    /// the languages do: measured at about 4.4 Chinese characters a second
    /// against about 18 Latin characters, so one shared limit would be generous
    /// in one language and punishing in the other.
    static let chineseBudget = 40.0
    static let latinBudget = 150.0

    @ObservedObject var viewModel: AlarmViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var text = ""
    @State private var persona: VoicePersona = .default
    @State private var isGenerating = false
    @State private var message: String?
    @State private var previewPlayer: AVAudioPlayer?
    @State private var playingPersona: VoicePersona?
    @State private var previewTask: Task<Void, Never>?

    private let client: AIVoiceGenerating = AIVoiceClient()

    /// One counter for both languages: a Chinese character costs a whole unit, a
    /// Latin one the fraction that makes 150 of them weigh the same as 40.
    private var used: Double {
        text.reduce(0) { total, character in
            let isCJK = character.unicodeScalars.contains { (0x4E00...0x9FFF).contains($0.value) }
            return total + (isCJK ? 1 : Self.chineseBudget / Self.latinBudget)
        }
    }

    private var isOverBudget: Bool { used > Self.chineseBudget }
    private var canGenerate: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isOverBudget && !isGenerating
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextEditor(text: $text)
                        .frame(minHeight: 90)
                        .overlay(alignment: .topLeading) {
                            if text.isEmpty {
                                Text("ai_voice_placeholder")
                                    .foregroundStyle(.tertiary)
                                    .padding(.top, 8)
                                    .allowsHitTesting(false)
                            }
                        }
                    HStack {
                        Spacer()
                        Text("\(Int(used.rounded())) / \(Int(Self.chineseBudget))")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(isOverBudget ? Color.red : .secondary)
                    }
                } header: {
                    Text("ai_voice_what_to_say")
                } footer: {
                    Text("ai_voice_what_to_say_hint")
                }

                Section {
                    ForEach(VoicePersona.allCases) { candidate in
                        // Not a Button wrapping a Button: SwiftUI gives the outer
                        // one every tap, and the play control inside it silently
                        // never fires. The row selects through a tap gesture so the
                        // preview can stay a real button.
                        HStack(spacing: 12) {
                            Image(systemName: persona == candidate ? "largecircle.fill.circle" : "circle")
                                .foregroundStyle(Color.accentColor)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(candidate.displayName)
                                    .foregroundStyle(.primary)
                                Text(candidate.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        // The whole row selects, including the empty space beside
                        // the labels, but stops short of the preview button.
                        .contentShape(Rectangle())
                        .onTapGesture { persona = candidate }
                        .overlay(alignment: .trailing) {
                            Button {
                                playPreview(of: candidate)
                            } label: {
                                Image(systemName: playingPersona == candidate
                                      ? "stop.circle.fill" : "play.circle.fill")
                                    .font(.title3)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(Color.accentColor)
                            .accessibilityLabel(Text("preview_alarm_sound"))
                        }
                    }
                } header: {
                    Text("ai_voice_who_says_it")
                } footer: {
                    Text("ai_voice_who_says_it_hint")
                }

                if let message {
                    Section {
                        Text(message).font(.footnote)
                    }
                }
            }
            .navigationTitle("alarm_sound_ai_voice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isGenerating {
                        ProgressView()
                    } else {
                        Button("ai_voice_generate") { generate() }
                            .disabled(!canGenerate)
                    }
                }
            }
            .onAppear {
                // Reopen on what was last chosen rather than a blank page: the clip
                // is audio and cannot be read back into a text field, so the words
                // have to come from settings or they are gone.
                text = viewModel.settings.aiVoiceText
                persona = viewModel.settings.aiVoicePersona
            }
            .onDisappear { stopPreview() }
        }
    }

    private func playPreview(of candidate: VoicePersona) {
        let wasPlaying = playingPersona == candidate
        // Unconditionally, before anything else. Replacing the player alone does
        // not silence the old one — it plays on until it happens to be
        // deallocated — so tapping a second voice used to leave two talking over
        // each other.
        stopPreview()
        if wasPlaying {
            return
        }

        guard let url = Bundle.main.url(forResource: candidate.previewResourceName, withExtension: "m4a"),
              let player = try? AVAudioPlayer(contentsOf: url) else {
            return
        }
        // Without this the session inherits `.soloAmbient`, which plays nothing
        // while the ring switch is silenced — the same trap the tone preview hit.
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)

        previewPlayer = player
        playingPersona = candidate
        player.prepareToPlay()
        player.play()

        // Reaching the end has to put the button back, or every voice the user
        // auditions is left showing a stop control for audio that finished.
        let duration = player.duration
        previewTask = Task {
            try? await Task.sleep(for: .milliseconds(Int(duration * 1_000)))
            guard !Task.isCancelled, playingPersona == candidate else {
                return
            }
            stopPreview()
        }
    }

    private func stopPreview() {
        previewTask?.cancel()
        previewTask = nil
        previewPlayer?.stop()
        previewPlayer = nil
        playingPersona = nil
    }

    /// Generation happens here and nowhere else. It is deliberately not part of
    /// scheduling: that path also runs from a debounced settings change and from
    /// the background refresh task, and neither should be able to spend money or
    /// wait on a network call.
    private func generate() {
        stopPreview()
        isGenerating = true
        message = nil

        Task {
            let outcome = await client.speak(text, as: persona)
            isGenerating = false

            switch outcome {
            case .speech(let pcm):
                guard let assembled = try? GeneratedVoiceAssembler.assemble(speech: pcm),
                      let fileName = GeneratedVoiceStore.write(
                        assembled,
                        fileName: "ai-\(UUID().uuidString.prefix(8)).wav"
                      ) else {
                    message = String(localized: "ai_voice_error_unavailable")
                    return
                }

                let previous = viewModel.settings.aiVoiceFileName
                viewModel.settings.aiVoiceFileName = fileName
                viewModel.settings.aiVoicePersona = persona
                viewModel.settings.aiVoiceText = text
                viewModel.settings.alarmSound = .aiVoice
                // Keep the clip the alarm is about to use; drop whatever it
                // replaced. Superseded generations would otherwise accumulate for
                // the life of the install.
                GeneratedVoiceStore.removeAll(except: [fileName])
                _ = previous
                dismiss()

            case .rejected:
                message = String(localized: "ai_voice_error_rejected")
            case .busy:
                message = String(localized: "ai_voice_error_busy")
            case .unavailable:
                message = String(localized: "ai_voice_error_unavailable")
            }
        }
    }
}
