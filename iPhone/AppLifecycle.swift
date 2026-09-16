#if os(iOS)
import SwiftUI

/// The one owner of `isIdleTimerDisabled` (Phase 5 step 12): the display stays awake while a Quran
/// reader is on screen (reading, or following a recitation), and only on the full tier. Playback
/// used to own it, which kept the screen on while audio played from any tab.
@MainActor
enum ScreenAwake {
    static var readerVisible = false {
        didSet { apply() }
    }

    static func apply() {
        let wanted = readerVisible && PerformanceProfile.shared.tier != .reduced
        if UIApplication.shared.isIdleTimerDisabled != wanted {
            UIApplication.shared.isIdleTimerDisabled = wanted
        }
    }
}

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
        installMemoryWarningPurge()
        quranScenePhaseChanged(to: phase)
        sharedScenePhaseChanged(to: phase)
    }

    // MARK: - Al-Quran (playback persistence, Quran widgets, reading progress)

    @MainActor
    private static func quranScenePhaseChanged(to phase: ScenePhase) {
        let settings = Settings.shared

        QuranPlayer.shared.saveLastListenedSurah()
        // Immediate: a pending 0.8 s settle would be lost to a suspension.
        QuranPlayer.shared.saveLastListenedAyah(immediate: true)

        // Only when LEAVING the foreground: that's when the widgets become visible and need the fresh
        // snapshot. Running this on every transition (including becoming active) paid a JSON encode plus
        // a reload of every widget timeline each time, against WidgetKit's daily reload budget.
        if phase == .active {
            // The daily surfaces: the widgets' corpus and Fajr table, and the one-shot nudges that
            // depend on today's reading. Each is a no-op within its own day.
            DailyReminderStore.shared.refreshWidgets()
            ActivityLog.shared.refreshSummaryIfDayChanged()
            ExtraRemindersStore.shared.rearmIfNeeded()
        }
        if phase != .active {
            settings.refreshQuranWidgets()
            ActivityLog.shared.flush()
            // A page flip within the last second may still have its last-read write pending.
            settings.flushPendingLastRead()
            // A khatm mark made in the last 250ms is still on the debounce timer; persist it before
            // the system can suspend or kill the process.
            settings.flushPendingKhatmProgress()
        }
    }

    // MARK: - Memory pressure (Phase 5 step 13)

    /// The Quran module's session caches that are pure speed-ups and rebuild themselves on demand:
    /// the riwayah alignment and diff tables, the mushaf's fallback renders, the print-line tables,
    /// the highlighter's swatch images, the facsimile's measured crops, and the inflated solidpack
    /// bodies. One observer, installed on the first scene-phase change (the `NSCache`s already shed
    /// on their own).
    private static var memoryWarningObserver: NSObjectProtocol?

    @MainActor
    private static func installMemoryWarningPurge() {
        guard memoryWarningObserver == nil else { return }
        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: .main
        ) { _ in
            Task { @MainActor in purgeQuranSessionCaches() }
        }
    }

    @MainActor
    private static func purgeQuranSessionCaches() {
        QiraahComparison.purgeCaches()
        MushafPageRenderCache.purgeFallbackRenders()
        MushafPrintLines.purge()
        AyahHighlightColor.purgeSwatchCache()
        MushafPDFLibrary.purgeMeasuredCrops()
        SolidPack.purgeInflatedBodies()
        MemoryTrim.trimAll()
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

/// The one owner of the memory-warning trim for the stores the Tilawa port added (Tilawa Guide,
/// Phase 8 step 5): every large store registers here rather than growing an observer of its own.
/// Each call is safe when nothing is loaded.
enum MemoryTrim {
    @MainActor
    static func trimAll() {
        // The Miracles library and its decoded illustrations (a 40-frame animation is ~27 MB).
        MiraclesStore.shared.unload()
        MiracleImageLoader.purgeDecodedImages()
        // The explorer's computed place tables and counts.
        QiraatPlacesStore.shared.purgeComputed()
        #if DEBUG
        MemoryFootprint.logLater("memory warning trim", delay: 2)
        #endif
    }
}

#elseif os(watchOS)
import SwiftUI

/// The watch app's foreground/background orchestration - the iPhone `AppLifecycle`'s little sibling,
/// and the same contract: the app root delegates its scene-phase transition HERE in one line, and
/// this is the only place that knows which subsystems care. Deliberately much smaller than the
/// iPhone's: no adhan player, no Live Activity, no Quran-widget snapshots, no daily hadith on the
/// wrist - add a domain section only when the watch actually ships the feature.
enum AppLifecycle {

    @MainActor
    static func scenePhaseChanged(to phase: ScenePhase) {
        let settings = Settings.shared

        if phase == .active {
            // No location work here: prayer times (and the location sensing they need) are
            // Al-Islam/Al-Adhan features; this app's watch wake needs nothing refreshed.
        } else {
            // A page flip within the last second may still have its last-read write pending.
            settings.flushPendingLastRead()
            // A khatm mark made in the last 250ms is still on the debounce timer; persist it before
            // the system can suspend or kill the process.
            settings.flushPendingKhatmProgress()
            // Flush any just-made setting change before suspension so it reliably reaches the iPhone.
            WatchConnectivityManager.shared.flushPendingSync()
        }
    }
}
#endif
