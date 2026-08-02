import SwiftUI
import UserNotifications

@main
struct RainyClockApp: App {
    @Environment(\.scenePhase) private var scenePhase

    init() {
        UNUserNotificationCenter.current().delegate = NotificationPresentationDelegate.shared
        LocalNotificationScheduler.registerNotificationCategories()
    }

    var body: some Scene {
        WindowGroup {
            ContentView(
                viewModel: AlarmViewModel(routeWeatherService: AppEnvironment.routeWeatherService),
                showsWeatherAttribution: AppEnvironment.showsWeatherAttribution
            )
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else {
                return
            }

            // Runs on every system, not just pre-26: an install that upgraded to
            // iOS 26 before rescheduling still carries notification alarms, and
            // skipping this would strand any that are sitting on a fallback
            // trigger. Once AlarmKit takes over there is no stored plan left and
            // this is a no-op.
            Task {
                await LocalNotificationScheduler().rearmAlarmsIfNeeded()
            }

            // The tracking prompt is skipped when the consent flow finishes while
            // the app is not yet active; this is where that launch catches up.
            Task {
                await ConsentManager.shared.requestTrackingAuthorizationIfDeferred()
            }
        }
    }
}
