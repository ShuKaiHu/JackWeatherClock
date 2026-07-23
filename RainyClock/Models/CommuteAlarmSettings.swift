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

struct ScheduledAlarmSummary: Equatable {
    var normalAlarmDate: Date
    var scheduledAlarmDate: Date
    var weatherRefreshDate: Date
    var exceedsRainThreshold: Bool
    var leadTimeMinutes: Int
    var rainProbabilityThreshold: Double
    var maximumPrecipitationProbability: Double
}
