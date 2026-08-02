#if os(iOS)
import SwiftUI

/// The app's foreground/background orchestration, in one named place.
///
/// This is deliberately NOT in `Settings`: a phase change touches several subsystems (playback
/// persistence, widgets, the in-app adhan player, the fasting Live Activity, Hadith of the Day,
/// location, watch sync), and `Settings` should not know most of them exist.
///
/// ORGANIZED FOR THE COMPANION APPS: every function below is one app domain, whole and
/// self-contained. When this file is copied into Al-Adhan, delete the Al-Quran and Al-Hadith functions
/// (and their calls); into Al-Quran, delete the Adhan and Al-Hadith ones. Nothing in one domain's
/// block depends on another's.
enum AppLifecycle {

    /// Main-actor because it was lifted out of a SwiftUI `.onChange` closure and everything it
    /// touches (players, stores, location) is main-actor state.
    @MainActor
    static func scenePhaseChanged(to phase: ScenePhase) {
        quranScenePhaseChanged(to: phase)
        sharedScenePhaseChanged(to: phase)
    }

    // MARK: - Al-Quran (playback persistence, Quran widgets, reading progress)

    @MainActor
    private static func quranScenePhaseChanged(to phase: ScenePhase) {
        let settings = Settings.shared

        QuranPlayer.shared.saveLastListenedSurah()
        QuranPlayer.shared.saveLastListenedAyah()

        // Only when LEAVING the foreground: that's when the widgets become visible and need the fresh
        // snapshot. Running this on every transition (including becoming active) paid a JSON encode plus
        // a reload of every widget timeline each time, against WidgetKit's daily reload budget.
        if phase != .active {
            settings.refreshQuranWidgets()
            // A page flip within the last second may still have its last-read write pending.
            settings.flushPendingLastRead()
            // A khatm mark made in the last 250ms is still on the debounce timer; persist it before
            // the system can suspend or kill the process.
            settings.flushPendingKhatmProgress()
        }
    }

    // MARK: - Shared (watch sync - keep in every app that ships a watch companion)

    @MainActor
    private static func sharedScenePhaseChanged(to phase: ScenePhase) {
        guard phase != .active else { return }
        // Send any just-made setting change before the app is suspended, so it can't be lost (and
        // can't be reverted by a stale synced value on the next launch).
        WatchConnectivityManager.shared.flushPendingSync()
    }
}
#endif
