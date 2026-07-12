import GoogleMobileAds
import SwiftUI
import UserNotifications

@main
struct RainyClockApp: App {
    init() {
        UNUserNotificationCenter.current().delegate = NotificationPresentationDelegate.shared
        LocalNotificationScheduler.registerNotificationCategories()
        if !AppEnvironment.isRunningTests {
            MobileAds.shared.start()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(
                viewModel: AlarmViewModel(routeWeatherService: AppEnvironment.routeWeatherService),
                showsWeatherAttribution: AppEnvironment.showsWeatherAttribution
            )
        }
    }
}
