import Foundation

struct CommuteAlarmSettings: Codable, Equatable {
    static let allWeekdays = Set(1...7)

    enum CommuteMode: String, CaseIterable, Codable, Identifiable, Equatable {
        case car
        case scooter
        case walking
        case publicTransit

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .car:
                String(localized: "commute_mode_car")
            case .scooter:
                String(localized: "commute_mode_scooter")
            case .walking:
                String(localized: "commute_mode_walking")
            case .publicTransit:
                String(localized: "commute_mode_public_transit")
            }
        }
    }

    enum AlarmSound: String, CaseIterable, Codable, Identifiable, Equatable, Sendable {
        case rainyClock
        case morningBell
        case softPiano
        case brightChime
        case gentleWaves
        case digitalBeep
        case forestBirds
        case energeticPulse
        case deepResonance
        case minimalTap
        case systemDefault

        static var allCases: [AlarmSound] {
            [
                .rainyClock,
                .morningBell,
                .softPiano,
                .brightChime,
                .gentleWaves,
                .digitalBeep,
                .forestBirds,
                .energeticPulse,
                .deepResonance,
                .minimalTap
            ]
        }

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .rainyClock:
                String(localized: "alarm_sound_rainy_clock")
            case .morningBell:
                String(localized: "alarm_sound_morning_bell")
            case .softPiano:
                String(localized: "alarm_sound_soft_piano")
            case .brightChime:
                String(localized: "alarm_sound_bright_chime")
            case .gentleWaves:
                String(localized: "alarm_sound_gentle_waves")
            case .digitalBeep:
                String(localized: "alarm_sound_digital_beep")
            case .forestBirds:
                String(localized: "alarm_sound_forest_birds")
            case .energeticPulse:
                String(localized: "alarm_sound_energetic_pulse")
            case .deepResonance:
                String(localized: "alarm_sound_deep_resonance")
            case .minimalTap:
                String(localized: "alarm_sound_minimal_tap")
            case .systemDefault:
                String(localized: "alarm_sound_system_default")
            }
        }

        var fileName: String {
            switch self {
            case .rainyClock:
                "RainyClock.wav"
            case .morningBell:
                "MorningBell.wav"
            case .softPiano:
                "SoftPiano.wav"
            case .brightChime:
                "BrightChime.wav"
            case .gentleWaves:
                "GentleWaves.wav"
            case .digitalBeep:
                "DigitalBeep.wav"
            case .forestBirds:
                "ForestBirds.wav"
            case .energeticPulse:
                "EnergeticPulse.wav"
            case .deepResonance:
                "DeepResonance.wav"
            case .minimalTap:
                "MinimalTap.wav"
            case .systemDefault:
                "AlarmTone.wav"
            }
        }
    }

    var homeAddress: String = ""
    var workAddress: String = ""
    var homeResolvedLocation: ResolvedMapLocation?
    var workResolvedLocation: ResolvedMapLocation?
    var confirmedHomeAddressInput: String?
    var confirmedWorkAddressInput: String?
    var commuteMode: CommuteMode = .car
    var alarmTime: Date = Calendar.current.date(bySettingHour: 7, minute: 30, second: 0, of: Date()) ?? Date()
    var rainLeadTimeMinutes: Int = 30
    var rainProbabilityThreshold: Double = 0.5
    var selectedWeekdays: Set<Int> = Self.allWeekdays
    var alarmSound: AlarmSound = .rainyClock

    init() {}

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        homeAddress = try values.decodeIfPresent(String.self, forKey: .homeAddress) ?? ""
        workAddress = try values.decodeIfPresent(String.self, forKey: .workAddress) ?? ""
        homeResolvedLocation = try values.decodeIfPresent(ResolvedMapLocation.self, forKey: .homeResolvedLocation)
        workResolvedLocation = try values.decodeIfPresent(ResolvedMapLocation.self, forKey: .workResolvedLocation)
        confirmedHomeAddressInput = try values.decodeIfPresent(String.self, forKey: .confirmedHomeAddressInput)
        confirmedWorkAddressInput = try values.decodeIfPresent(String.self, forKey: .confirmedWorkAddressInput)
        commuteMode = try values.decodeIfPresent(CommuteMode.self, forKey: .commuteMode) ?? .car
        alarmTime = try values.decodeIfPresent(Date.self, forKey: .alarmTime)
            ?? Calendar.current.date(bySettingHour: 7, minute: 30, second: 0, of: Date())
            ?? Date()
        rainLeadTimeMinutes = try values.decodeIfPresent(Int.self, forKey: .rainLeadTimeMinutes) ?? 30
        rainProbabilityThreshold = try values.decodeIfPresent(Double.self, forKey: .rainProbabilityThreshold) ?? 0.5
        selectedWeekdays = try values.decodeIfPresent(Set<Int>.self, forKey: .selectedWeekdays) ?? Self.allWeekdays
        let decodedAlarmSound = try values.decodeIfPresent(AlarmSound.self, forKey: .alarmSound) ?? .rainyClock
        alarmSound = decodedAlarmSound == .systemDefault ? .rainyClock : decodedAlarmSound
    }
}

struct RouteWeatherSnapshot: Equatable {
    var checkedAt: Date
    var forecastAt: Date
    var segments: [RouteWeatherSegment]

    func exceedsRainThreshold(_ threshold: Double) -> Bool {
        segments.contains { $0.precipitationProbability >= threshold }
    }

    var maximumPrecipitationProbability: Double {
        segments.map(\.precipitationProbability).max() ?? 0
    }
}

struct RouteWeatherSegment: Identifiable, Equatable {
    enum Condition: String, Equatable, Sendable {
        case clear
        case cloudy
        case rain
    }

    var id = UUID()
    var name: String
    var condition: Condition
    var precipitationProbability: Double
}

/// Snapshot of every setting the scheduling flow reads. Comparing the stored
/// snapshot against the live settings tells whether the scheduled alarm still
/// matches what the user currently has configured.
struct AlarmScheduleFingerprint: Codable, Equatable {
    var homeAddress: String
    var workAddress: String
    var commuteMode: CommuteAlarmSettings.CommuteMode
    var alarmHour: Int
    var alarmMinute: Int
    var selectedWeekdays: Set<Int>
    var rainLeadTimeMinutes: Int
    var rainProbabilityThreshold: Double
    var alarmSoundRawValue: String
}

extension CommuteAlarmSettings {
    func scheduleFingerprint(calendar: Calendar = .current) -> AlarmScheduleFingerprint {
        let time = calendar.dateComponents([.hour, .minute], from: alarmTime)
        return AlarmScheduleFingerprint(
            homeAddress: homeAddress.trimmingCharacters(in: .whitespacesAndNewlines),
            workAddress: workAddress.trimmingCharacters(in: .whitespacesAndNewlines),
            commuteMode: commuteMode,
            alarmHour: time.hour ?? 7,
            alarmMinute: time.minute ?? 30,
            selectedWeekdays: selectedWeekdays,
            rainLeadTimeMinutes: rainLeadTimeMinutes,
            rainProbabilityThreshold: rainProbabilityThreshold,
            alarmSoundRawValue: alarmSound.rawValue
        )
    }
}

struct ScheduledAlarmSummary: Codable, Equatable {
    var normalAlarmDate: Date
    var scheduledAlarmDate: Date
    var weatherRefreshDate: Date
    var exceedsRainThreshold: Bool
    var leadTimeMinutes: Int
    var rainProbabilityThreshold: Double
    var maximumPrecipitationProbability: Double
}

extension ScheduledAlarmSummary {
    /// Returns the summary with past dates advanced to their next weekly occurrence,
    /// so a summary reloaded after relaunch still describes the upcoming ring.
    func rollingForward(
        selectedWeekdays: Set<Int>,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> ScheduledAlarmSummary {
        let weekdays = selectedWeekdays.isEmpty ? CommuteAlarmSettings.allWeekdays : selectedWeekdays
        var summary = self
        summary.scheduledAlarmDate = Self.nextOccurrence(
            of: scheduledAlarmDate,
            weekdays: Self.shiftedWeekdays(weekdays, from: normalAlarmDate, to: scheduledAlarmDate, calendar: calendar),
            after: now,
            calendar: calendar
        )
        summary.weatherRefreshDate = Self.nextOccurrence(
            of: weatherRefreshDate,
            weekdays: Self.shiftedWeekdays(weekdays, from: normalAlarmDate, to: weatherRefreshDate, calendar: calendar),
            after: now,
            calendar: calendar
        )
        summary.normalAlarmDate = Self.nextOccurrence(
            of: normalAlarmDate,
            weekdays: weekdays,
            after: now,
            calendar: calendar
        )
        return summary
    }

    /// A ring that sits on an earlier day than the normal alarm (rain lead time
    /// crossing midnight) rings on every selected weekday shifted by that delta.
    private static func shiftedWeekdays(
        _ weekdays: Set<Int>,
        from reference: Date,
        to date: Date,
        calendar: Calendar
    ) -> Set<Int> {
        let dayShift = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: reference),
            to: calendar.startOfDay(for: date)
        ).day ?? 0
        guard dayShift != 0 else {
            return weekdays
        }

        return Set(weekdays.map { (($0 - 1 + dayShift) % 7 + 7) % 7 + 1 })
    }

    private static func nextOccurrence(
        of date: Date,
        weekdays: Set<Int>,
        after now: Date,
        calendar: Calendar
    ) -> Date {
        guard date < now else {
            return date
        }

        let time = calendar.dateComponents([.hour, .minute, .second], from: date)
        for dayOffset in 0...7 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: calendar.startOfDay(for: now)),
                  let candidate = calendar.date(
                      bySettingHour: time.hour ?? 0,
                      minute: time.minute ?? 0,
                      second: time.second ?? 0,
                      of: day
                  ),
                  candidate > now,
                  weekdays.contains(calendar.component(.weekday, from: candidate)) else {
                continue
            }

            return candidate
        }

        return date
    }
}
