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

            Task {
                await LocalNotificationScheduler().rearmAlarmsIfNeeded()
            }
        }
    }
}
