import ActivityKit
import AlarmKit
import SwiftUI
import WidgetKit

/// The non-alerting face of the commute alarm: the snooze countdown on the Lock
/// Screen, in the Dynamic Island and in StandBy.
///
/// AlarmKit requires a widget extension for any alarm that can enter the countdown
/// state — the snooze button puts it there — and drops alarms that lack one.
struct CommuteAlarmLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmAttributes<CommuteAlarmMetadata>.self) { context in
            HStack(spacing: 12) {
                icon(for: context.attributes)
                    .font(.title2)
                    .foregroundStyle(context.attributes.tintColor)

                VStack(alignment: .leading, spacing: 2) {
                    title(for: context.attributes)
                        .font(.headline)
                    subtitle(for: context.attributes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                countdown(for: context.state)
                    .font(.title2.monospacedDigit())
                    .foregroundStyle(context.attributes.tintColor)
            }
            .padding()
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    icon(for: context.attributes)
                        .font(.title3)
                        .foregroundStyle(context.attributes.tintColor)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    countdown(for: context.state)
                        .font(.title3.monospacedDigit())
                        .foregroundStyle(context.attributes.tintColor)
                }
                DynamicIslandExpandedRegion(.center) {
                    title(for: context.attributes)
                        .font(.headline)
                }
            } compactLeading: {
                icon(for: context.attributes)
                    .foregroundStyle(context.attributes.tintColor)
            } compactTrailing: {
                countdown(for: context.state)
                    .monospacedDigit()
                    .foregroundStyle(context.attributes.tintColor)
            } minimal: {
                icon(for: context.attributes)
                    .foregroundStyle(context.attributes.tintColor)
            }
        }
    }

    private func icon(for attributes: AlarmAttributes<CommuteAlarmMetadata>) -> Image {
        Image(systemName: attributes.metadata?.adjustedForRain == true ? "cloud.rain.fill" : "alarm.fill")
    }

    /// The app supplies both titles when it schedules the alarm, so the wording and
    /// its localization stay in one place.
    private func title(for attributes: AlarmAttributes<CommuteAlarmMetadata>) -> Text {
        Text(attributes.presentation.countdown?.title ?? attributes.presentation.alert.title)
    }

    /// The alarm time the user actually configured, shown only when rain moved the
    /// ring off it. A glyph rather than a word keeps the extension free of its own
    /// string catalog.
    private func subtitle(for attributes: AlarmAttributes<CommuteAlarmMetadata>) -> Text {
        guard let metadata = attributes.metadata,
              metadata.adjustedForRain,
              let normalAlarmDate = Calendar.current.date(
                  bySettingHour: metadata.normalAlarmHour,
                  minute: metadata.normalAlarmMinute,
                  second: 0,
                  of: Date.now
              ) else {
            return Text(verbatim: "")
        }

        return Text(Image(systemName: "alarm"))
            + Text(verbatim: " ")
            + Text(normalAlarmDate, format: .dateTime.hour().minute())
    }

    @ViewBuilder
    private func countdown(for state: AlarmPresentationState) -> some View {
        switch state.mode {
        case .countdown(let countdown):
            // WidgetKit re-renders cached snapshots, so this can run at or after the
            // fire date. A reversed range traps, which would take the extension —
            // and with it the alarm AlarmKit expects it to present — down with it.
            let now = Date.now
            Text(timerInterval: now...max(countdown.fireDate, now), countsDown: true)
                .multilineTextAlignment(.trailing)

        case .paused(let paused):
            let remaining = max(0, paused.totalCountdownDuration - paused.previouslyElapsedDuration)
            Text(Duration.seconds(remaining), format: .time(pattern: .minuteSecond))

        case .alert:
            EmptyView()

        @unknown default:
            EmptyView()
        }
    }
}
