#if os(iOS)
import BackgroundTasks
import CoreLocation
import UIKit
import UserNotifications

class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    private let taskID = AppIdentifiers.backgroundFetchPrayerTimesTaskIdentifier
    private let reciterDownloadsSessionID = AppIdentifiers.reciterDownloadsBackgroundSessionIdentifier
    
    // Connects iOS background URL session wakeups to the reciter download manager.
    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        guard identifier == reciterDownloadsSessionID else {
            completionHandler()
            return
        }

        ReciterDownloadManager.shared.backgroundSessionCompletionHandler(completionHandler)
    }

    // Performs startup setup: installs the notification delegate. (Al-Quran ships no prayer domain,
    // so there is no background prayer-times refresh to register here - the Sunnah and Quran
    // reminders schedule themselves from `ReminderScheduler.rearmAfterLaunch`, run by MainTabView's
    // post-reveal schedule.)
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    // Shows in-app notifications as banner + sound when a notification arrives in foreground, and keeps
    // them in Notification Center (.list) so a missed banner isn't lost.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }

    // A Sunnah reminder: open the Quran where the reminder points (`SunnahReminderStore`). The
    // target is parked on `AppNavigation`; the tab view and the Quran tab take it from there.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if let encoded = response.notification.request.content.userInfo[SunnahReminderStore.targetUserInfoKey] as? String,
           let target = QuranOpenTarget(encoded: encoded) {
            DispatchQueue.main.async { AppNavigation.shared.open(target) }
        }
        completionHandler()
    }

}
#endif
