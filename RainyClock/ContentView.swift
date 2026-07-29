import AVFoundation
import MapKit
import SwiftUI

struct ContentView: View {
    private enum AppTab {
        case route
        case alarm
    }

    @StateObject var viewModel: AlarmViewModel
    @ObservedObject private var consentManager = ConsentManager.shared
    @State private var selectedTab: AppTab = .route
    var showsWeatherAttribution = false

    var body: some View {
        TabView(selection: $selectedTab) {
            RouteTabView(
                viewModel: viewModel,
                showsWeatherAttribution: showsWeatherAttribution
            )
                .tag(AppTab.route)

            AlarmTabView(viewModel: viewModel)
            .tag(AppTab.alarm)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomControls
        }
        .background(Color.appBackground.ignoresSafeArea())
        .preferredColorScheme(.dark)
        // Runs once the view hierarchy exists: the consent form needs a view
        // controller to present from, which is not available during app `init()`.
        .task {
            consentManager.requestConsentThenStartAds()
        }
    }

    private var bottomControls: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                tabButton(
                    title: String(localized: "tab_route"),
                    systemImage: "map",
                    tab: .route
                )
                tabButton(
                    title: String(localized: "tab_alarm"),
                    systemImage: "alarm",
                    tab: .alarm
                )
            }
            .padding(6)
            .background(.ultraThinMaterial, in: Capsule())
            .background(Color.white.opacity(0.04), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.35), radius: 14, x: 0, y: 8)
            .padding(.horizontal, 34)
            .padding(.top, 12)
            .padding(.bottom, 22)

            // Kept out of the hierarchy until UMP reports consent, so no ad request
            // can precede it.
            if !AppEnvironment.isRunningTests, consentManager.canRequestAds {
                AdMobBannerView(adUnitID: AppEnvironment.adMobBannerAdUnitID)
                    .frame(maxWidth: .infinity)
                    .background(Color.appBackground)
            }
        }
        .background(Color.appBackground)
    }

    private func tabButton(title: String, systemImage: String, tab: AppTab) -> some View {
        Button {
            withAnimation(.easeInOut) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: selectedTab == tab ? .semibold : .regular))
                Text(title)
                    .font(.caption)
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(
                Group {
                    if selectedTab == tab {
                        Capsule()
                            .fill(Color.white.opacity(0.14))
                    }
                }
            )
            .foregroundStyle(selectedTab == tab ? Color.accentColor : Color.secondary)
        }
        .buttonStyle(.plain)
    }
}

private struct RouteTabView: View {
    private static let routeModes: [CommuteAlarmSettings.CommuteMode] = [
        .car,
        .scooter,
        .publicTransit,
        .walking
    ]

    private enum AddressField: Hashable {
        case home
        case work
    }

    @ObservedObject var viewModel: AlarmViewModel
    let showsWeatherAttribution: Bool
    @StateObject private var addressCompleter = AddressSearchCompleter()
    @FocusState private var focusedAddressField: AddressField?
    @State private var expandedAddressSuggestionField: AddressField?
    @State private var addressSelectionGeneration = 0
    @State private var previewTask: Task<Void, Never>?
    @State private var weatherTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(spacing: 12) {
                            AddressFieldRow(
                                label: String(localized: "home_label"),
                                placeholder: String(localized: "home_address"),
                                text: $viewModel.settings.homeAddress,
                                isInvalid: viewModel.invalidAddressFields.contains(.home),
                                suggestedMatch: viewModel.suggestedAddressMatches[CommuteAddressField.home],
                                focusedField: $focusedAddressField,
                                field: .home,
                                onSubmit: submitAddressSearch,
                                onClear: { clearAddress(.home) },
                                onConfirmSuggestion: { viewModel.confirmSuggestedAddress(.home) },
                                onChooseAnotherSuggestion: { focusAddressForSuggestion(.home) }
                            )
                            AddressFieldRow(
                                label: String(localized: "work_label"),
                                placeholder: String(localized: "work_address"),
                                text: $viewModel.settings.workAddress,
                                isInvalid: viewModel.invalidAddressFields.contains(.work),
                                suggestedMatch: viewModel.suggestedAddressMatches[CommuteAddressField.work],
                                focusedField: $focusedAddressField,
                                field: .work,
                                onSubmit: submitAddressSearch,
                                onClear: { clearAddress(.work) },
                                onConfirmSuggestion: { viewModel.confirmSuggestedAddress(.work) },
                                onChooseAnotherSuggestion: { focusAddressForSuggestion(.work) }
                            )

                            if shouldShowAddressCompletionPanel {
                                AddressCompletionList(
                                    completions: addressCompleter.completions,
                                    isSearching: addressCompleter.isSearching
                                ) { completion in
                                    Task { @MainActor in
                                        await selectAddressCompletion(completion)
                                    }
                                }
                            }
                        }

                        HStack(spacing: 12) {
                            Text("mode")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                                .frame(minWidth: 44, alignment: .leading)
                            RouteModePicker(
                                selection: $viewModel.settings.commuteMode,
                                modes: Self.routeModes
                            )
                        }
                        .padding(14)
                        .background(Color.appCardBackground, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                    }

                    if let preview = viewModel.routePreview {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("route_preview")
                                .font(.headline)
                                .foregroundStyle(.secondary)

                            RoutePreviewMapView(preview: preview)

                            if let expectedTravelTimeMinutes = preview.expectedTravelTimeMinutes,
                               let distanceKilometers = preview.distanceKilometers {
                                HStack(spacing: 12) {
                                    MetricCard(
                                        title: String(localized: "route_preview_travel_time"),
                                        value: String.localizedStringWithFormat(
                                            String(localized: "route_preview_minutes_value"),
                                            expectedTravelTimeMinutes
                                        )
                                    )
                                    MetricCard(
                                        title: String(localized: "route_preview_distance"),
                                        value: String.localizedStringWithFormat(
                                            String(localized: "route_preview_distance_value"),
                                            distanceKilometers
                                        )
                                    )
                                }
                            }

                            Text(viewModel.routePreviewStatusMessage)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    } else if viewModel.isPreviewingRoute || viewModel.routePreviewStatusMessage != String(localized: "route_preview_empty") {
                        Text(viewModel.routePreviewStatusMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("route_weather")
                                .font(.title.weight(.bold))
                            Spacer()
                            if viewModel.isRefreshingRouteWeather {
                                ProgressView()
                            }
                        }

                        if let snapshot = viewModel.routeWeatherSnapshot {
                            HStack(spacing: 10) {
                                ForEach(snapshot.segments) { segment in
                                    RouteWeatherCard(segment: segment)
                                }
                            }
                        } else {
                            RouteWeatherPlaceholderCards()
                        }

                        Text(viewModel.routeWeatherStatusMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        // WeatherKit attribution must always be visible where weather
                        // data is presented, not only once a forecast has loaded.
                        if showsWeatherAttribution {
                            WeatherAttributionView()
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 0)
                .padding(.bottom, 20)
            }
            .navigationTitle(String(localized: "tab_route"))
            .toolbar(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("done") {
                        focusedAddressField = nil
                    }
                }
            }
            .background(Color.appBackground)
        }
        .onAppear {
            normalizeRouteMode()
            scheduleRoutePreview()
            scheduleRouteWeather()
        }
        .onDisappear {
            previewTask?.cancel()
            weatherTask?.cancel()
        }
        .onChange(of: focusedAddressField) { _, _ in
            updateAddressCompletions()
        }
        .onChange(of: viewModel.settings.homeAddress) { _, _ in
            updateAddressCompletions()
        }
        .onChange(of: viewModel.settings.workAddress) { _, _ in
            updateAddressCompletions()
        }
        .onChange(of: viewModel.settings.commuteMode) { _, _ in
            normalizeRouteMode()
            scheduleRoutePreview()
            scheduleRouteWeather()
        }
        .onChange(of: viewModel.settings.alarmTime) { _, _ in
            scheduleRouteWeather()
        }
        .onChange(of: viewModel.settings.selectedWeekdays) { _, _ in
            scheduleRouteWeather()
        }
    }

    private func normalizeRouteMode() {
        guard !Self.routeModes.contains(viewModel.settings.commuteMode) else {
            return
        }

        viewModel.settings.commuteMode = .car
    }

    private func submitAddressSearch() {
        focusedAddressField = nil
        expandedAddressSuggestionField = nil
        addressCompleter.clear()
        scheduleRoutePreview(delay: .zero)
        scheduleRouteWeather(delay: .zero)
    }

    private func clearAddress(_ field: AddressField) {
        switch field {
        case .home:
            viewModel.settings.homeAddress = ""
            viewModel.clearAddressState(.home)
        case .work:
            viewModel.settings.workAddress = ""
            viewModel.clearAddressState(.work)
        }

        focusedAddressField = field
        expandedAddressSuggestionField = nil
        addressCompleter.clear()
        previewTask?.cancel()
        weatherTask?.cancel()
        viewModel.clearRoutePreview()
        viewModel.clearRouteWeather()
    }

    private func focusAddressForSuggestion(_ field: AddressField) {
        focusedAddressField = field
        expandedAddressSuggestionField = field
        updateAddressCompletions(forceRefresh: true)
    }

    @MainActor
    private func selectAddressCompletion(_ completion: MKLocalSearchCompletion) async {
        // Capture the target field before any await: focus can move (or clear) while
        // the completion resolves over the network, and the result must not follow it.
        // The generation makes the LATEST tap win when taps overlap in flight.
        guard let targetField = focusedAddressField else {
            return
        }

        addressSelectionGeneration += 1
        let generation = addressSelectionGeneration

        let fallbackAddress = [completion.title, completion.subtitle]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: ", ")
        let resolvedLocation = await MapItemResolver.resolvedLocation(for: completion)
        guard generation == addressSelectionGeneration else {
            return
        }

        let resolvedAddress = resolvedLocation?.displayAddress?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let address = resolvedAddress?.isEmpty == false ? resolvedAddress! : fallbackAddress

        switch targetField {
        case .home:
            viewModel.setAddressFromSuggestion(address, location: resolvedLocation, field: .home)
        case .work:
            viewModel.setAddressFromSuggestion(address, location: resolvedLocation, field: .work)
        }

        submitAddressSearch()
    }

    private var shouldShowAddressCompletionPanel: Bool {
        guard let focusedAddressField else {
            return false
        }

        return !addressCompleter.completions.isEmpty || expandedAddressSuggestionField == focusedAddressField
    }

    private func updateAddressCompletions(forceRefresh: Bool = false) {
        switch focusedAddressField {
        case .home:
            addressCompleter.update(query: viewModel.settings.homeAddress, forceRefresh: forceRefresh)
        case .work:
            addressCompleter.update(query: viewModel.settings.workAddress, forceRefresh: forceRefresh)
        case nil:
            expandedAddressSuggestionField = nil
            addressCompleter.clear()
        }
    }

    private func scheduleRoutePreview(delay: Duration = .milliseconds(700)) {
        previewTask?.cancel()
        // Cancellation cannot abort an already-running fetch, so also invalidate it —
        // otherwise its stale result could land during the debounce delay below.
        viewModel.supersedeRoutePreview()
        previewTask = Task {
            guard viewModel.canPreviewRoute else {
                await MainActor.run {
                    viewModel.clearRoutePreview()
                }
                return
            }

            if delay > .zero {
                try? await Task.sleep(for: delay)
                guard !Task.isCancelled else {
                    return
                }
            }

            await viewModel.previewRoute()
        }
    }

    private func scheduleRouteWeather(delay: Duration = .milliseconds(700)) {
        weatherTask?.cancel()
        viewModel.supersedeRouteWeather()
        weatherTask = Task {
            guard viewModel.canPreviewRoute else {
                await MainActor.run {
                    viewModel.clearRouteWeather()
                }
                return
            }

            if delay > .zero {
                try? await Task.sleep(for: delay)
                guard !Task.isCancelled else {
                    return
                }
            }

            await viewModel.refreshRouteWeather()
        }
    }
}

private struct AlarmTabView: View {
    private let weekdayOrder = [1, 2, 3, 4, 5, 6, 7]

    @ObservedObject var viewModel: AlarmViewModel
    @ObservedObject private var consentManager = ConsentManager.shared
    @State private var showsTimePicker = false
    @State private var audioPlayer: AVAudioPlayer?
    @State private var previewingSound: CommuteAlarmSettings.AlarmSound?
    @State private var soundPreviewTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 20) {
                        HStack(spacing: 12) {
                            ForEach(weekdayOrder, id: \.self) { weekday in
                                let isSelected = viewModel.settings.selectedWeekdays.contains(weekday)
                                Button {
                                    toggleWeekday(weekday)
                                } label: {
                                    Text(label(for: weekday))
                                        .font(.callout.weight(.semibold))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.72)
                                        .foregroundStyle(isSelected ? .white : Color.white.opacity(0.45))
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 44)
                                        .background(
                                            Circle()
                                                .fill(isSelected ? Color.accentColor : Color.appCardBackground)
                                        )
                                }
                                .buttonStyle(.plain)
                                .animation(.easeOut(duration: 0.15), value: isSelected)
                            }
                        }

                        Button {
                            showsTimePicker = true
                        } label: {
                            Text(timeText(for: viewModel.settings.alarmTime))
                                .font(.system(size: 60, weight: .regular, design: .rounded))
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
                    }
                    .padding(22)
                    .background(Color.appCardBackground, in: RoundedRectangle(cornerRadius: 30, style: .continuous))

                    VStack(spacing: 18) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("rain_lead_time")
                                Spacer()
                                Text(String.localizedStringWithFormat(String(localized: "rain_lead_time_value"), viewModel.settings.rainLeadTimeMinutes))
                                    .foregroundStyle(.secondary)
                            }

                            Slider(value: rainLeadTimeSliderValue, in: 1...60, step: 1)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("rain_threshold")
                                Spacer()
                                Text("\(Int(viewModel.settings.rainProbabilityThreshold * 100))%")
                                    .foregroundStyle(.secondary)
                            }
                            Slider(value: $viewModel.settings.rainProbabilityThreshold, in: 0.1...0.9, step: 0.05)
                        }

                        HStack {
                            Text("alarm_sound")
                            Spacer()
                            Menu {
                                Picker("alarm_sound", selection: $viewModel.settings.alarmSound) {
                                    ForEach(CommuteAlarmSettings.AlarmSound.selectableCases) { sound in
                                        Text(sound.displayName).tag(sound)
                                    }
                                }
                            } label: {
                                Text(viewModel.settings.alarmSound.displayName)
                                    .foregroundStyle(.secondary)
                            }
                            // The system alarm tone lives in iOS, not in the app
                            // bundle, so there is nothing to play here.
                            if !viewModel.settings.alarmSound.usesSystemAlarmTone {
                                Button {
                                    toggleSelectedSoundPreview()
                                } label: {
                                    Image(systemName: isPreviewingSelectedSound ? "stop.circle.fill" : "play.circle.fill")
                                        .font(.title3)
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(Color.accentColor)
                                .accessibilityLabel(Text("preview_alarm_sound"))
                            }
                        }

                        Toggle(isOn: $viewModel.settings.isSnoozeEnabled) {
                            Text("snooze")
                        }
                        .tint(Color.accentColor)

                        if viewModel.settings.isSnoozeEnabled {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("snooze_duration")
                                    Spacer()
                                    Text(String.localizedStringWithFormat(String(localized: "snooze_duration_value"), viewModel.settings.snoozeDurationMinutes))
                                        .foregroundStyle(.secondary)
                                }

                                Slider(
                                    value: snoozeDurationSliderValue,
                                    in: Double(CommuteAlarmSettings.snoozeDurationRange.lowerBound)...Double(CommuteAlarmSettings.snoozeDurationRange.upperBound),
                                    step: 1
                                )
                            }
                        }

                        // Only regulated regions require this entry point, so UMP
                        // decides whether it appears at all.
                        if consentManager.showsPrivacyOptions {
                            HStack {
                                Text("ad_privacy_options")
                                Spacer()
                                Button("ad_privacy_options_manage") {
                                    consentManager.presentPrivacyOptions()
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                    .padding(18)
                    .background(Color.appCardBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))

                    Button {
                        Task { await viewModel.evaluateRouteAndScheduleAlarm() }
                    } label: {
                        Label(
                            viewModel.isScheduling ? String(localized: "checking_route") : String(localized: "schedule_smart_alarm"),
                            systemImage: "alarm"
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.accentColor)
                    .disabled(!viewModel.canSchedule || viewModel.isScheduling)

                    // Colour answers "is an alarm actually armed right now?" at a
                    // glance: green = armed and matching the settings above,
                    // orange = armed but syncing/stale, grey = nothing armed.
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Image(systemName: scheduleStatusIcon)
                        Text(viewModel.statusMessage)
                    }
                    .font(.subheadline.weight(viewModel.hasScheduledAlarm ? .semibold : .regular))
                    .foregroundStyle(scheduleStatusColor)

                    if let summary = viewModel.scheduledAlarmSummary {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("scheduled_result")
                                .font(.headline)
                            if viewModel.isScheduleStale {
                                Label(String(localized: "schedule_stale_notice"), systemImage: "exclamationmark.triangle.fill")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.orange)
                            }
                            if viewModel.requiresAlarmKitReschedule {
                                Label(String(localized: "alarmkit_reschedule_notice"), systemImage: "bell.badge.fill")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.orange)
                            }
                            MetricRow(title: String(localized: "normal_alarm"), value: summary.normalAlarmDate.formatted(date: .omitted, time: .shortened))
                            MetricRow(title: String(localized: "scheduled_alarm"), value: summary.scheduledAlarmDate.formatted(date: .abbreviated, time: .shortened))
                            MetricRow(title: String(localized: "weather_refresh"), value: summary.weatherRefreshDate.formatted(date: .abbreviated, time: .shortened))
                            MetricRow(title: String(localized: "rain_threshold"), value: "\(Int(summary.rainProbabilityThreshold * 100))%")
                            MetricRow(title: String(localized: "route_max"), value: "\(Int(summary.maximumPrecipitationProbability * 100))%")
                            MetricRow(title: String(localized: "rain_adjustment"), value: rainAdjustmentText(for: summary))
                        }
                        .padding(18)
                        .background(Color.appCardBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 0)
                .padding(.bottom, 20)
            }
            .navigationTitle(String(localized: "tab_alarm"))
            .toolbar(.hidden, for: .navigationBar)
            .background(Color.appBackground)
        }
        .sheet(isPresented: $showsTimePicker) {
            NavigationStack {
                DatePicker(
                    "normal_alarm",
                    selection: $viewModel.settings.alarmTime,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .padding()
                .presentationDetents([.height(320)])
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("done") {
                            showsTimePicker = false
                        }
                    }
                }
            }
        }
        .onAppear {
            clampRainLeadTime()
        }
        .onDisappear {
            stopSoundPreview()
        }
    }

    private func toggleWeekday(_ weekday: Int) {
        if viewModel.settings.selectedWeekdays.contains(weekday) {
            viewModel.settings.selectedWeekdays.remove(weekday)
        } else {
            viewModel.settings.selectedWeekdays.insert(weekday)
        }
    }

    private var rainLeadTimeSliderValue: Binding<Double> {
        Binding {
            Double(min(max(viewModel.settings.rainLeadTimeMinutes, 1), 60))
        } set: { newValue in
            viewModel.settings.rainLeadTimeMinutes = min(max(Int(newValue.rounded()), 1), 60)
        }
    }

    private var scheduleStatusIcon: String {
        guard viewModel.hasScheduledAlarm else {
            return "minus.circle"
        }

        return viewModel.isScheduleStale ? "exclamationmark.triangle.fill" : "checkmark.circle.fill"
    }

    private var scheduleStatusColor: Color {
        guard viewModel.hasScheduledAlarm else {
            return .secondary
        }

        return viewModel.isScheduleStale ? .orange : .green
    }

    private var snoozeDurationSliderValue: Binding<Double> {
        let range = CommuteAlarmSettings.snoozeDurationRange
        return Binding {
            Double(min(max(viewModel.settings.snoozeDurationMinutes, range.lowerBound), range.upperBound))
        } set: { newValue in
            viewModel.settings.snoozeDurationMinutes = min(max(Int(newValue.rounded()), range.lowerBound), range.upperBound)
        }
    }

    private func clampRainLeadTime() {
        viewModel.settings.rainLeadTimeMinutes = min(max(viewModel.settings.rainLeadTimeMinutes, 1), 60)
    }

    private func label(for weekday: Int) -> String {
        switch weekday {
        case 1:
            String(localized: "weekday_sunday_short")
        case 2:
            String(localized: "weekday_monday_short")
        case 3:
            String(localized: "weekday_tuesday_short")
        case 4:
            String(localized: "weekday_wednesday_short")
        case 5:
            String(localized: "weekday_thursday_short")
        case 6:
            String(localized: "weekday_friday_short")
        default:
            String(localized: "weekday_saturday_short")
        }
    }

    private func rainAdjustmentText(for summary: ScheduledAlarmSummary) -> String {
        guard summary.exceedsRainThreshold else {
            return String(localized: "not_applied")
        }

        return String.localizedStringWithFormat(String(localized: "minutes_earlier"), summary.leadTimeMinutes)
    }

    private func timeText(for date: Date) -> String {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        let period = hour < 12 ? String(localized: "alarm_am") : String(localized: "alarm_pm")
        let displayHour = hour % 12 == 0 ? 12 : hour % 12
        let time = "\(displayHour):\(String(format: "%02d", minute))"

        if Locale.current.language.languageCode?.identifier.hasPrefix("zh") == true {
            return "\(period)\(time)"
        }

        return "\(time) \(period)"
    }

    private var isPreviewingSelectedSound: Bool {
        previewingSound == viewModel.settings.alarmSound
    }

    private func toggleSelectedSoundPreview() {
        if isPreviewingSelectedSound {
            stopSoundPreview()
        } else {
            previewSound(viewModel.settings.alarmSound)
        }
    }

    private func previewSound(_ sound: CommuteAlarmSettings.AlarmSound) {
        stopSoundPreview()
        let soundFile = sound.fileName.split(separator: ".", maxSplits: 1).map(String.init)
        guard let resource = soundFile.first,
              let fileExtension = soundFile.dropFirst().first,
              let url = Bundle.main.url(forResource: resource, withExtension: fileExtension),
              let player = try? AVAudioPlayer(contentsOf: url) else {
            return
        }

        audioPlayer = player
        previewingSound = sound
        player.prepareToPlay()
        player.play()

        let duration = player.duration
        soundPreviewTask = Task {
            try? await Task.sleep(for: .milliseconds(Int(duration * 1_000)))
            guard !Task.isCancelled else {
                return
            }

            await MainActor.run {
                if previewingSound == sound {
                    audioPlayer?.stop()
                    audioPlayer = nil
                    previewingSound = nil
                    soundPreviewTask = nil
                }
            }
        }
    }

    private func stopSoundPreview() {
        soundPreviewTask?.cancel()
        soundPreviewTask = nil
        audioPlayer?.stop()
        audioPlayer = nil
        previewingSound = nil
    }
}

private struct RouteModePicker: View {
    @Binding var selection: CommuteAlarmSettings.CommuteMode
    let modes: [CommuteAlarmSettings.CommuteMode]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(modes) { mode in
                Button {
                    selection = mode
                } label: {
                    Text(mode.displayName)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .background(selection == mode ? Color.accentColor : Color.appFieldBackground)
                .clipShape(Capsule())
            }
        }
    }
}

private struct AddressCompletionList: View {
    let completions: [MKLocalSearchCompletion]
    let isSearching: Bool
    let onSelect: (MKLocalSearchCompletion) -> Void

    var body: some View {
        VStack(spacing: 0) {
            if completions.isEmpty {
                HStack(spacing: 12) {
                    if isSearching {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "magnifyingglass")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    Text(String(localized: isSearching ? "address_suggestions_loading" : "address_suggestions_empty"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
            } else {
                ForEach(completions.indices, id: \.self) { index in
                    let completion = completions[index]
                    Button {
                        onSelect(completion)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 22)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(completion.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                if !completion.subtitle.isEmpty {
                                    Text(completion.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }

                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if index < completions.indices.last ?? 0 {
                        Divider()
                            .overlay(Color.white.opacity(0.08))
                            .padding(.leading, 48)
                    }
                }
            }
        }
        .background(Color.appCardBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private final class AddressSearchCompleter: NSObject, ObservableObject, MKLocalSearchCompleterDelegate, @unchecked Sendable {
    @Published private(set) var completions: [MKLocalSearchCompletion] = []
    @Published private(set) var isSearching = false

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    func update(query: String, forceRefresh: Bool = false) {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedQuery.count >= 2 else {
            clear()
            return
        }

        let candidates = MapItemResolver.candidateQueries(for: trimmedQuery)
        let autocompleteQuery = candidates.first { candidate in
            !candidate.contains(",")
                && !candidate.contains("，")
                && !candidate.localizedStandardContains("股份有限公司")
                && !candidate.localizedStandardContains("Corporation")
        } ?? candidates.first ?? trimmedQuery

        if forceRefresh && completer.queryFragment == autocompleteQuery {
            isSearching = true
            completions = []
            completer.queryFragment = ""
            DispatchQueue.main.async { [weak self] in
                self?.completer.queryFragment = autocompleteQuery
            }
        } else if completer.queryFragment != autocompleteQuery {
            isSearching = true
            completer.queryFragment = autocompleteQuery
        }
        // Same query as the current search: assigning an unchanged queryFragment never
        // triggers a delegate callback, so leave isSearching untouched to avoid a stuck spinner.
    }

    func clear() {
        completer.queryFragment = ""
        completions = []
        isSearching = false
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        completions = Array(completer.results.prefix(5))
        isSearching = false
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        completions = []
        isSearching = false
    }
}

private struct AddressFieldRow<Field: Hashable>: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    let isInvalid: Bool
    let suggestedMatch: SuggestedAddressMatch?
    var focusedField: FocusState<Field?>.Binding
    let field: Field
    let onSubmit: () -> Void
    let onClear: () -> Void
    let onConfirmSuggestion: () -> Void
    let onChooseAnotherSuggestion: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Text(label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isInvalid ? Color.red : .secondary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .frame(minWidth: 44, alignment: .leading)

                TextField(placeholder, text: $text)
                    .textContentType(.fullStreetAddress)
                    .submitLabel(.search)
                    .focused(focusedField, equals: field)
                    .onSubmit(onSubmit)
                    .textFieldStyle(.plain)
                    .lineLimit(1)
                    .tint(isInvalid ? .red : .accentColor)

                if !text.isEmpty {
                    Button {
                        onClear()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 28, height: 28)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(localized: "clear_address"))
                }
            }
            .padding(14)
            .background(
                (isInvalid ? Color.red.opacity(0.20) : Color.appFieldBackground),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isInvalid ? Color.red : Color.clear, lineWidth: 2.5)
            )

            if isInvalid {
                Text(String(localized: "address_not_found_inline"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 14)
            } else if let suggestedMatch {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: suggestedMatch.isConfirmed ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(suggestedMatch.isConfirmed ? .green : .yellow)
                        Text(
                            String.localizedStringWithFormat(
                                String(localized: "suggested_address_prefix"),
                                suggestedMatch.suggestedAddress
                            )
                        )
                        .font(.caption)
                        .foregroundStyle(suggestedMatch.isConfirmed ? Color.secondary : Color.yellow)
                        .fixedSize(horizontal: false, vertical: true)
                    }

                    if suggestedMatch.isConfirmed {
                        Text(String(localized: "confirmed_suggested_address"))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.green)
                    } else {
                        HStack(spacing: 8) {
                            Button(String(localized: "confirm_suggested_address")) {
                                onConfirmSuggestion()
                            }
                            .font(.caption.weight(.semibold))
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                            .tint(.yellow)

                            Button(String(localized: "choose_another_address")) {
                                onChooseAnotherSuggestion()
                            }
                            .font(.caption.weight(.semibold))
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                            .tint(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 14)
            }
        }
    }
}

private struct MetricCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.appCardBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct MetricRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
        }
    }
}

private struct RouteWeatherCard: View {
    let segment: RouteWeatherSegment

    var body: some View {
        VStack(spacing: 12) {
            Text(segment.name)
                .font(.headline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Image(systemName: segment.condition.iconName)
                .symbolRenderingMode(.multicolor)
                .font(.system(size: 42))
                .foregroundStyle(segment.condition.color)

            Text(conditionText)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, minHeight: 150)
        .padding(.vertical, 18)
        .padding(.horizontal, 8)
        .background(
            LinearGradient(
                colors: [Color(red: 0.02, green: 0.12, blue: 0.15), Color(red: 0.02, green: 0.28, blue: 0.42)],
                startPoint: .top,
                endPoint: .bottom
            ),
            in: RoundedRectangle(cornerRadius: 30, style: .continuous)
        )
    }

    private var conditionText: String {
        if segment.condition == .rain {
            return String.localizedStringWithFormat(
                String(localized: "precipitation_value"),
                Int(segment.precipitationProbability * 100)
            )
        }

        switch segment.condition {
        case .clear:
            return String(localized: "weather_clear")
        case .cloudy:
            return String(localized: "weather_cloudy")
        case .rain:
            return String.localizedStringWithFormat(
                String(localized: "precipitation_value"),
                Int(segment.precipitationProbability * 100)
            )
        }
    }
}

private struct RouteWeatherPlaceholderCards: View {
    private let titles = [
        String(localized: "segment_home_area"),
        String(localized: "segment_office_area")
    ]

    var body: some View {
        HStack(spacing: 10) {
            ForEach(titles, id: \.self) { title in
                VStack(spacing: 12) {
                    Text(title)
                        .font(.headline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Image(systemName: "cloud.sun.fill")
                        .symbolRenderingMode(.multicolor)
                        .font(.system(size: 42))

                    Text("weather_waiting")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 150)
                .padding(.vertical, 18)
                .padding(.horizontal, 8)
                .background(Color.appCardBackground, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
            }
        }
    }
}

private extension RouteWeatherSegment.Condition {
    var iconName: String {
        switch self {
        case .clear:
            "sun.max.fill"
        case .cloudy:
            "cloud.sun.fill"
        case .rain:
            "cloud.rain.fill"
        }
    }

    var color: Color {
        switch self {
        case .clear:
            .yellow
        case .cloudy:
            .cyan
        case .rain:
            .blue
        }
    }
}

private extension Color {
    static let appBackground = Color.black
    static let appCardBackground = Color(red: 0.12, green: 0.12, blue: 0.13)
    static let appFieldBackground = Color(red: 0.18, green: 0.18, blue: 0.20)
}

#Preview {
    ContentView(viewModel: AlarmViewModel())
}
