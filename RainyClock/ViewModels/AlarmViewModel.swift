import Foundation

enum CommuteAddressField: Hashable {
    case home
    case work
}

struct SuggestedAddressMatch: Equatable {
    var originalInput: String
    var suggestedAddress: String
    var isConfirmed: Bool
}

@MainActor
final class AlarmViewModel: ObservableObject {
    @Published var settings: CommuteAlarmSettings {
        didSet {
            if oldValue.homeAddress != settings.homeAddress {
                invalidAddressFields.remove(.home)
                clearSuggestedAddressIfInputChanged(.home, input: settings.homeAddress)
                if suggestionSelectedInputs[.home] != settings.homeAddress.trimmingCharacters(in: .whitespacesAndNewlines) {
                    settings.homeResolvedLocation = nil
                }
            }
            if oldValue.workAddress != settings.workAddress {
                invalidAddressFields.remove(.work)
                clearSuggestedAddressIfInputChanged(.work, input: settings.workAddress)
                if suggestionSelectedInputs[.work] != settings.workAddress.trimmingCharacters(in: .whitespacesAndNewlines) {
                    settings.workResolvedLocation = nil
                }
            }
            saveSettings()
            updateScheduleStaleness()
        }
    }
    @Published private(set) var routeWeatherSnapshot: RouteWeatherSnapshot?
    @Published private(set) var routePreview: RoutePreview?
    @Published private(set) var scheduledAlarmSummary: ScheduledAlarmSummary? {
        didSet {
            saveScheduledAlarmSummary()
        }
    }
    @Published private(set) var statusMessage = String(localized: "status_enter_settings")
    @Published private(set) var routePreviewStatusMessage = String(localized: "route_preview_empty")
    @Published private(set) var routeWeatherStatusMessage = String(localized: "route_weather_empty")
    @Published private(set) var isScheduling = false
    @Published private(set) var isPreviewingRoute = false
    @Published private(set) var isRefreshingRouteWeather = false
    @Published private(set) var invalidAddressFields: Set<CommuteAddressField> = []
    @Published private(set) var suggestedAddressMatches: [CommuteAddressField: SuggestedAddressMatch] = [:]
    /// True when schedule-relevant settings changed after the last successful
    /// scheduling, so the registered alarm no longer matches the visible settings.
    @Published private(set) var isScheduleStale = false

    private let routeWeatherService: RouteWeatherService
    private let routePreviewService: RoutePreviewService
    private let notificationScheduler: NotificationScheduling
    private let settingsStorage: UserDefaults
    private var suggestionSelectedInputs: [CommuteAddressField: String] = [:]
    private var previewGeneration = 0
    private var weatherGeneration = 0
    private var scheduledFingerprint: AlarmScheduleFingerprint? {
        didSet {
            saveScheduledFingerprint()
        }
    }
    private static let addressValidationTimeout: Duration = .seconds(4)
    private static let settingsStorageKey = "commuteAlarmSettings"
    private static let scheduledSummaryStorageKey = "scheduledAlarmSummaryDisplay"
    private static let scheduledFingerprintStorageKey = "scheduledAlarmFingerprint"

    init(
        routeWeatherService: RouteWeatherService = MockRouteWeatherService(),
        routePreviewService: RoutePreviewService = MapKitRoutePreviewService(),
        notificationScheduler: NotificationScheduling = LocalNotificationScheduler(),
        settingsStorage: UserDefaults = .standard
    ) {
        self.settings = Self.loadSettings(from: settingsStorage) ?? CommuteAlarmSettings()
        self.routeWeatherService = routeWeatherService
        self.routePreviewService = routePreviewService
        self.notificationScheduler = notificationScheduler
        self.settingsStorage = settingsStorage

        // Restore state that survives relaunches, so a scheduled alarm and confirmed
        // addresses do not look reset every time the app reopens.
        if let confirmedHome = settings.confirmedHomeAddressInput {
            suggestionSelectedInputs[.home] = confirmedHome
        }
        if let confirmedWork = settings.confirmedWorkAddressInput {
            suggestionSelectedInputs[.work] = confirmedWork
        }
        if let storedSummary = Self.loadScheduledAlarmSummary(from: settingsStorage) {
            scheduledAlarmSummary = storedSummary.rollingForward(selectedWeekdays: settings.selectedWeekdays)
            statusMessage = String(localized: "status_alarm_scheduled")
        }
        scheduledFingerprint = Self.loadScheduledFingerprint(from: settingsStorage)
        updateScheduleStaleness()
    }

    private func updateScheduleStaleness() {
        guard scheduledAlarmSummary != nil, let scheduledFingerprint else {
            isScheduleStale = false
            return
        }

        let isStale = settings.scheduleFingerprint() != scheduledFingerprint
        if isStale != isScheduleStale {
            isScheduleStale = isStale
        }
    }

    var canSchedule: Bool {
        !settings.homeAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !settings.workAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !settings.selectedWeekdays.isEmpty
            && settings.rainLeadTimeMinutes > 0
            && !hasUnconfirmedSuggestedAddresses
    }

    var canPreviewRoute: Bool {
        !settings.homeAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !settings.workAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var requiresSuggestedAddressConfirmation: Bool {
        hasUnconfirmedSuggestedAddresses
    }

    func previewRoute() async {
        guard canPreviewRoute else {
            clearRoutePreview(message: String(localized: "route_preview_required"))
            return
        }

        previewGeneration += 1
        let generation = previewGeneration
        isPreviewingRoute = true
        routePreviewStatusMessage = String(localized: "previewing_route")
        defer {
            if generation == previewGeneration {
                isPreviewingRoute = false
            }
        }

        do {
            let preview = try await routePreviewService.previewRoute(
                from: settings.homeAddress,
                homeLocation: settings.homeResolvedLocation,
                to: settings.workAddress,
                workLocation: settings.workResolvedLocation,
                mode: settings.commuteMode
            )
            // A newer preview request (or a clear) supersedes this in-flight result.
            guard generation == previewGeneration else {
                return
            }
            routePreview = preview
            invalidAddressFields.removeAll()
            updateSuggestedAddressMatches(homeLocation: preview.homeLocation, workLocation: preview.workLocation)
            if let expectedTravelTimeMinutes = preview.expectedTravelTimeMinutes,
               let distanceKilometers = preview.distanceKilometers {
                routePreviewStatusMessage = String.localizedStringWithFormat(
                    String(localized: "route_preview_ready"),
                    preview.routeName,
                    expectedTravelTimeMinutes,
                    distanceKilometers
                )
            } else {
                routePreviewStatusMessage = String(localized: "route_preview_locations_only_message")
            }
        } catch {
            guard generation == previewGeneration else {
                return
            }
            routePreview = nil
            updateAddressValidation(for: error)
            routePreviewStatusMessage = String.localizedStringWithFormat(
                String(localized: "route_preview_failed"),
                error.localizedDescription
            )
        }
    }

    func clearRoutePreview(message: String = String(localized: "route_preview_empty")) {
        previewGeneration += 1
        isPreviewingRoute = false
        routePreview = nil
        routePreviewStatusMessage = message
    }

    func confirmSuggestedAddress(_ field: CommuteAddressField) {
        guard let match = suggestedAddressMatches[field] else {
            return
        }

        let actualAddress = match.suggestedAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !actualAddress.isEmpty else {
            return
        }

        setSuggestionSelectedInput(actualAddress, for: field)
        switch field {
        case .home:
            settings.homeAddress = actualAddress
            settings.homeResolvedLocation = nil
        case .work:
            settings.workAddress = actualAddress
            settings.workResolvedLocation = nil
        }
        suggestedAddressMatches.removeValue(forKey: field)
        invalidAddressFields.remove(field)
    }

    func clearAddressState(_ field: CommuteAddressField) {
        invalidAddressFields.remove(field)
        suggestedAddressMatches.removeValue(forKey: field)
        setSuggestionSelectedInput(nil, for: field)
        switch field {
        case .home:
            settings.homeResolvedLocation = nil
        case .work:
            settings.workResolvedLocation = nil
        }
    }

    func setAddressFromSuggestion(_ address: String, location: ResolvedMapLocation?, field: CommuteAddressField) {
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        setSuggestionSelectedInput(trimmedAddress, for: field)

        switch field {
        case .home:
            settings.homeAddress = address
            settings.homeResolvedLocation = location
        case .work:
            settings.workAddress = address
            settings.workResolvedLocation = location
        }
    }

    func refreshRouteWeather() async {
        guard canPreviewRoute else {
            clearRouteWeather(message: String(localized: "route_weather_empty"))
            return
        }

        weatherGeneration += 1
        let generation = weatherGeneration
        isRefreshingRouteWeather = true
        routeWeatherStatusMessage = String(localized: "route_weather_refreshing")
        defer {
            if generation == weatherGeneration {
                isRefreshingRouteWeather = false
            }
        }

        do {
            let now = Date()
            let snapshot = try await routeWeatherService.fetchRouteWeather(
                from: settings.homeAddress,
                homeLocation: settings.homeResolvedLocation,
                to: settings.workAddress,
                workLocation: settings.workResolvedLocation,
                mode: settings.commuteMode,
                around: nextWeatherCheckDate(now: now)
            )
            // A newer refresh (or a clear) supersedes this in-flight result.
            guard generation == weatherGeneration else {
                return
            }
            routeWeatherSnapshot = snapshot
            invalidAddressFields.removeAll()
            let forecastAt = snapshot.forecastAt.formatted(date: .abbreviated, time: .shortened)
            routeWeatherStatusMessage = String.localizedStringWithFormat(
                String(localized: "route_weather_updated"),
                forecastAt,
                snapshot.checkedAt.formatted(date: .omitted, time: .shortened)
            )
        } catch {
            guard generation == weatherGeneration else {
                return
            }
            routeWeatherSnapshot = nil
            updateAddressValidation(for: error)
            routeWeatherStatusMessage = String.localizedStringWithFormat(
                String(localized: "route_weather_failed"),
                Self.userFacingMessage(for: error)
            )
        }
    }

    func clearRouteWeather(message: String = String(localized: "route_weather_empty")) {
        weatherGeneration += 1
        isRefreshingRouteWeather = false
        routeWeatherSnapshot = nil
        routeWeatherStatusMessage = message
    }

    /// Invalidates an in-flight preview request so its late result cannot land while a
    /// replacement request is still in its debounce delay.
    func supersedeRoutePreview() {
        previewGeneration += 1
    }

    /// Invalidates an in-flight weather refresh so its late result cannot land while a
    /// replacement request is still in its debounce delay.
    func supersedeRouteWeather() {
        weatherGeneration += 1
    }

    func evaluateRouteAndScheduleAlarm() async {
        guard canSchedule else {
            statusMessage = hasUnconfirmedSuggestedAddresses
                ? String(localized: "status_confirm_suggested_address")
                : String(localized: "status_required")
            return
        }

        isScheduling = true
        defer { isScheduling = false }

        do {
            let authorized = try await notificationScheduler.requestAuthorization()
            guard authorized else {
                statusMessage = String(localized: "status_permission_denied")
                return
            }

            // Scheduling supersedes any in-flight background weather refresh, and must
            // also clear the refresh spinner that refresh will no longer reset.
            weatherGeneration += 1
            let weatherFetchGeneration = weatherGeneration
            isRefreshingRouteWeather = false
            let now = Date()
            let weatherCheckDate = nextWeatherCheckDate(now: now)
            let snapshot = try await routeWeatherService.fetchRouteWeather(
                from: settings.homeAddress,
                homeLocation: settings.homeResolvedLocation,
                to: settings.workAddress,
                workLocation: settings.workResolvedLocation,
                mode: settings.commuteMode,
                around: weatherCheckDate
            )
            if weatherFetchGeneration == weatherGeneration {
                routeWeatherSnapshot = snapshot
                invalidAddressFields.removeAll()
                routeWeatherStatusMessage = String.localizedStringWithFormat(
                    String(localized: "route_weather_updated"),
                    snapshot.forecastAt.formatted(date: .abbreviated, time: .shortened),
                    snapshot.checkedAt.formatted(date: .omitted, time: .shortened)
                )
            }

            let exceedsThreshold = snapshot.exceedsRainThreshold(settings.rainProbabilityThreshold)
            let summary = AlarmTimeCalculator.nextAlarmDateForWeatherCheck(
                alarmTime: settings.alarmTime,
                leadTimeMinutes: settings.rainLeadTimeMinutes,
                shouldApplyLeadTime: exceedsThreshold,
                rainProbabilityThreshold: settings.rainProbabilityThreshold,
                maximumPrecipitationProbability: snapshot.maximumPrecipitationProbability,
                selectedWeekdays: settings.selectedWeekdays,
                now: now
            )
            scheduledAlarmSummary = summary

            let body = exceedsThreshold
                ? String(localized: "notification_body_adjusted")
                : String(localized: "notification_body_normal")

            try await notificationScheduler.scheduleAlarm(
                at: summary.scheduledAlarmDate,
                normalAlarmDate: summary.normalAlarmDate,
                weekdays: settings.selectedWeekdays,
                sound: settings.alarmSound,
                title: String(localized: "notification_title"),
                body: body
            )
            scheduledFingerprint = settings.scheduleFingerprint()
            isScheduleStale = false

            let checkedAt = snapshot.checkedAt.formatted(date: .omitted, time: .shortened)
            let forecastAt = snapshot.forecastAt.formatted(date: .abbreviated, time: .shortened)
            let statusKey = exceedsThreshold ? "status_adjusted_checked" : "status_normal_checked"
            statusMessage = String.localizedStringWithFormat(String(localized: String.LocalizationValue(statusKey)), forecastAt, checkedAt)
        } catch {
            updateAddressValidation(for: error)
            statusMessage = String.localizedStringWithFormat(
                String(localized: "status_schedule_failed"),
                Self.userFacingMessage(for: error)
            )
        }
    }

    private static func userFacingMessage(for error: Error) -> String {
        let description = error.localizedDescription
        let lowercasedDescription = description.lowercased()
        if lowercasedDescription.contains("weatherdaemon")
            || lowercasedDescription.contains("jwtauthenticator") {
            return String(localized: "error_weather_unavailable")
        }

        return description
    }

    private var hasUnconfirmedSuggestedAddresses: Bool {
        suggestedAddressMatches.values.contains { !$0.isConfirmed }
    }

    private func updateSuggestedAddressMatches(
        homeLocation: ResolvedMapLocation,
        workLocation: ResolvedMapLocation
    ) {
        updateSuggestedAddressMatch(.home, input: settings.homeAddress, location: homeLocation)
        updateSuggestedAddressMatch(.work, input: settings.workAddress, location: workLocation)
    }

    private func updateSuggestedAddressMatch(
        _ field: CommuteAddressField,
        input: String,
        location: ResolvedMapLocation
    ) {
        let trimmedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
        // An input the user already picked from suggestions or explicitly confirmed
        // (persisted across relaunches) needs no re-confirmation banner.
        let wasSelectedFromSuggestions = suggestionSelectedInputs[field] == trimmedInput
        guard !wasSelectedFromSuggestions else {
            suggestedAddressMatches.removeValue(forKey: field)
            return
        }

        let suggestedAddress = location.displayAddress?.trimmingCharacters(in: .whitespacesAndNewlines)
        suggestedAddressMatches[field] = SuggestedAddressMatch(
            originalInput: trimmedInput,
            suggestedAddress: suggestedAddress?.isEmpty == false ? suggestedAddress! : trimmedInput,
            isConfirmed: suggestedAddressMatches[field]?.originalInput == trimmedInput
                ? suggestedAddressMatches[field]?.isConfirmed ?? false
                : false
        )
    }

    private func clearSuggestedAddressIfInputChanged(_ field: CommuteAddressField, input: String) {
        let trimmedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard suggestedAddressMatches[field]?.originalInput != trimmedInput else {
            return
        }

        suggestedAddressMatches.removeValue(forKey: field)
        if suggestionSelectedInputs[field] != trimmedInput {
            setSuggestionSelectedInput(nil, for: field)
        }
    }

    private func setSuggestionSelectedInput(_ value: String?, for field: CommuteAddressField) {
        if let value {
            suggestionSelectedInputs[field] = value
        } else {
            suggestionSelectedInputs.removeValue(forKey: field)
        }

        switch field {
        case .home:
            settings.confirmedHomeAddressInput = value
        case .work:
            settings.confirmedWorkAddressInput = value
        }
    }

    private func updateAddressValidation(for error: Error) {
        guard let routeError = error as? MapKitRouteWeatherServiceError else {
            let description = error.localizedDescription.lowercased()
            if description.contains("route")
                || description.contains("directions")
                || description.contains("路線")
                || description.contains("路徑") {
                validateAddressesIndividuallyInBackground()
            }
            return
        }

        switch routeError {
        case .addressNotFound(let address):
            markAddressNotFound(address)
        case .routeNotFound:
            validateAddressesIndividuallyInBackground()
        }
    }

    private func validateAddressesIndividuallyInBackground() {
        Task { @MainActor in
            await validateAddressesIndividually()
        }
    }

    private func markAddressNotFound(_ address: String) {
        let normalizedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalizedAddress == settings.homeAddress.trimmingCharacters(in: .whitespacesAndNewlines) {
            invalidAddressFields.insert(.home)
        }
        if normalizedAddress == settings.workAddress.trimmingCharacters(in: .whitespacesAndNewlines) {
            invalidAddressFields.insert(.work)
        }
    }

    private func validateAddressesIndividually() async {
        async let homeResolved = canResolveAddress(settings.homeAddress)
        async let workResolved = canResolveAddress(settings.workAddress)

        var fields: Set<CommuteAddressField> = []
        if !(await homeResolved) {
            fields.insert(.home)
        }
        if !(await workResolved) {
            fields.insert(.work)
        }

        invalidAddressFields = fields
    }

    private func canResolveAddress(_ address: String) async -> Bool {
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAddress.isEmpty else {
            return false
        }

        return await withTaskGroup(of: Bool.self) { group in
            group.addTask {
                await MapItemResolver().canResolvePrecisely(trimmedAddress)
            }

            group.addTask {
                try? await Task.sleep(for: Self.addressValidationTimeout)
                return false
            }

            let result = await group.next() ?? false
            group.cancelAll()
            return result
        }
    }

    private func nextWeatherCheckDate(now: Date = Date()) -> Date {
        AlarmTimeCalculator.nextAlarmDateForWeatherCheck(
            alarmTime: settings.alarmTime,
            leadTimeMinutes: settings.rainLeadTimeMinutes,
            shouldApplyLeadTime: false,
            rainProbabilityThreshold: settings.rainProbabilityThreshold,
            maximumPrecipitationProbability: 0,
            selectedWeekdays: settings.selectedWeekdays,
            now: now
        ).weatherRefreshDate
    }

    private func saveSettings() {
        guard let data = try? JSONEncoder().encode(settings) else {
            return
        }

        settingsStorage.set(data, forKey: Self.settingsStorageKey)
    }

    private func saveScheduledAlarmSummary() {
        guard let summary = scheduledAlarmSummary else {
            settingsStorage.removeObject(forKey: Self.scheduledSummaryStorageKey)
            return
        }

        guard let data = try? JSONEncoder().encode(summary) else {
            return
        }

        settingsStorage.set(data, forKey: Self.scheduledSummaryStorageKey)
    }

    private static func loadScheduledAlarmSummary(from storage: UserDefaults) -> ScheduledAlarmSummary? {
        guard let data = storage.data(forKey: scheduledSummaryStorageKey) else {
            return nil
        }

        return try? JSONDecoder().decode(ScheduledAlarmSummary.self, from: data)
    }

    private func saveScheduledFingerprint() {
        guard let fingerprint = scheduledFingerprint else {
            settingsStorage.removeObject(forKey: Self.scheduledFingerprintStorageKey)
            return
        }

        guard let data = try? JSONEncoder().encode(fingerprint) else {
            return
        }

        settingsStorage.set(data, forKey: Self.scheduledFingerprintStorageKey)
    }

    private static func loadScheduledFingerprint(from storage: UserDefaults) -> AlarmScheduleFingerprint? {
        guard let data = storage.data(forKey: scheduledFingerprintStorageKey) else {
            return nil
        }

        return try? JSONDecoder().decode(AlarmScheduleFingerprint.self, from: data)
    }

    private static func loadSettings(from storage: UserDefaults) -> CommuteAlarmSettings? {
        guard let data = storage.data(forKey: settingsStorageKey) else {
            return nil
        }

        return try? JSONDecoder().decode(CommuteAlarmSettings.self, from: data)
    }
}
