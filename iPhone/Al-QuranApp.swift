import SwiftUI
import WidgetKit

@main
struct AlQuranApp: App {
    // Plain references, NOT `@StateObject`: the root used to observe all four stores, so every publish
    // of any of them (each of Settings' fields, every QuranPlayer progress tick, every step of the
    // Quran load pipeline) re-evaluated this body, the window, the tab host and every mounted tab
    // root. The stores are still handed down as environment objects for the views that want them;
    // what the root itself reads (first launch, the About You question) comes from `RootAppearance`,
    // which publishes only when one of those changes.
    private let settings = Settings.shared
    private let quranData = QuranData.shared
    private let quranPlayer = QuranPlayer.shared
    private let namesData = NamesViewModel.shared
    @ObservedObject private var appearance = RootAppearance.shared

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    @State private var isLaunching = true
    // Keeps the splash mounted through its fade-out (see `rootContent`).
    @State private var splashPresented = false
    // The same for the About You question, which follows the splash (or, for everyone who already
    // had the app, follows the launch screen directly).
    @State private var aboutYouPresented = false
    /// True once this launch has shown the splash: About You then knows it is talking to a new
    /// install, the only reader whose suggested settings it may switch on ahead of time.
    @State private var sawSplashThisLaunch = false

    init() {
        LaunchClock.mark("app init")
        #if DEBUG
        LaunchClock.installStallWatch()
        #endif
        // Activate WatchConnectivity so settings sync (and watch app-installed detection) work both ways.
        _ = WatchConnectivityManager.shared

        // The daily corpora (Reminder of the Day, Word of the Day) start now, before the under-cover
        // tab walk builds the Islam and Quran roots that read them, so neither root ever parses on
        // the main thread.
        DailyReminderStore.shared.prewarm()
        WordOfDayStore.prewarm()

        if #unavailable(iOS 26.0) {
            // Pre-Liquid-Glass, a scroll view resting at its bottom edge flips the tab bar to its
            // scroll-edge appearance, which iOS leaves fully TRANSPARENT by default, so list content
            // collided bare with the tab icons. Pin the standard blurred bar in that state too. iOS
            // 26's Liquid Glass bar handles its own legibility and must not be overridden.
            let bottomEdge = UITabBarAppearance()
            bottomEdge.configureWithDefaultBackground()
            UITabBar.appearance().scrollEdgeAppearance = bottomEdge
        }
    }

    private enum RootStage: Equatable {
        case launch
        case splash
        /// "Which describes you best?" (AboutYouView.swift). A stage rather than a sheet so that every
        /// launch prompt (the review card, a tapped notification's target) waits behind it instead of
        /// racing it: `appRevealed` is false until `.main`.
        case aboutYou
        case main
    }

    private var rootStage: RootStage {
        if isLaunching {
            return .launch
        }
        if appearance.firstLaunch { return .splash }
        return appearance.needsAboutYou ? .aboutYou : .main
    }

    private var rootTransitionAnimation: Animation {
        .easeInOut(duration: 0.5)
    }

    var body: some Scene {
        WindowGroup {
            rootContent
                // Every system font in the app is SF Rounded. Views that render a bundled Arabic face opt back
                // out with `arabicFontDesign(custom:)` (see the note in `Globals.swift`).
                .appFontDesign()
                // iPad and Mac read one Dynamic Type step larger (see `regularIdiomTypeBoost`).
                .regularIdiomTypeBoost()
                // Every Toggle in the app breathes: the standard switch with 2pt of vertical padding
                // (user rule), applied once here so no individual row can forget it.
                .toggleStyle(PaddedSwitchToggleStyle())
                .environmentObject(settings)
                .environmentObject(quranData)
                .environmentObject(quranPlayer)
                .environmentObject(namesData)
                // Accent, tint, color scheme and the shared chrome's `AppearanceEnvironment`, live. Without
                // this every `\.appearance` reader (glass, row backgrounds, icon chips, section pills) sits on
                // the key's one-time launch snapshot, so an accent change only showed after a restart.
                .appearanceEnvironment()
                .appReviewPrompt()
                // Set ABOVE (outside) `.appReviewPrompt()` too, or its `@Environment(\.appRevealed)`
                // reads the key's default (true): the copy inside `rootContent` sits BELOW the review
                // modifier in the tree, and environment only flows down: the launch-cover gate on the
                // review sheet was silently inert without this.
                .environment(\.appRevealed, rootStage == .main)
                // Watches the stores the badges are thresholds on. The banner itself is NOT hosted
                // here: it lives in its own window above the app (see `AchievementBannerPresenter`
                // and BannerWindow.swift) so it can still be seen when the thing that earned it
                // happened inside a sheet.
                .achievementTracking()
                //.statusBarHidden()
        }
        // No `.onChange` refreshes for settings here: each setting's own didSet performs its side
        // effects (`accentColor` repaints the widgets from Settings). Phase transitions delegate to the
        // one place that orchestrates them.
        .onChange(of: scenePhase) { phase in
            AppLifecycle.scenePhaseChanged(to: phase)
        }
    }

    @ViewBuilder
    private var rootContent: some View {
        ZStack {
            // Keep the tabs mounted from the very first frame (even while the launch/splash screen still covers
            // the screen) so the Quran tab can realize its (heavy) view tree behind that cover instead of on
            // the first visible tap. The launch/splash screens overlay on top and fade out to reveal it.
            MainTabView(isCovered: rootStage != .main)
                // Always opaque underneath the covers. The launch/splash screens are opaque and simply fade
                // themselves out (below) to reveal it: a clean single-layer dissolve, no mid-transition dip.
                .zIndex(1)

            // Above the tabs but below the covers: a letter / surah / name blown up to fill the screen. It
            // lives here (rather than on the row that opened it) so it can sit over the tab bar and fade in
            // as a plain overlay instead of a system sheet.
            FocusOverlayHost()
                .zIndex(1.5)

            if rootStage == .launch {
                LaunchScreen(isLaunching: $isLaunching)
                    .zIndex(3)
                    .transition(.opacity)
            }

            // The splash fades via an explicit `.opacity` (kept mounted through the fade), NOT a removal
            // `.transition`: SplashScreen wraps a NavigationView, which doesn't animate SwiftUI removal
            // transitions; it just snaps. A plain opacity animation on the hosted content works, giving the
            // splash → main hand-off a real cross-fade. It's unmounted a beat after the fade completes.
            if splashPresented {
                SplashScreen()
                    .opacity(rootStage == .splash ? 1 : 0)
                    .allowsHitTesting(rootStage == .splash)
                    .zIndex(2)
            }

            // About You sits UNDER the splash and the launch screen, opaque from the moment it is
            // mounted, so whichever cover precedes it dissolves onto it (a view that faded IN here
            // would show the tabs through two half-transparent covers mid-way). It fades only on its
            // own way out, by the same explicit opacity as the splash and for the same reason.
            if aboutYouPresented {
                AboutYouView(isNewInstall: sawSplashThisLaunch)
                    .opacity(rootStage == .main ? 0 : 1)
                    .allowsHitTesting(rootStage == .aboutYou)
                    .zIndex(1.8)
            }
        }
        .animation(rootTransitionAnimation, value: rootStage)
        // The tabs are mounted before the cover lifts; let them hold user-facing prompts until we're
        // actually on screen.
        .environment(\.appRevealed, rootStage == .main)
        // Seed the LIVE mirror at mount: `onChange` below only fires on transitions, and the mirror
        // defaults to `true`: without this, the launch window would read as revealed.
        .onAppear {
            AppReveal.revealed = (rootStage == .main)
            // Mounted from the first frame when it is going to be needed, under the launch cover, so
            // the cover never lifts onto the tabs for a frame before the question arrives.
            if appearance.needsAboutYou { aboutYouPresented = true }
        }
        .onChange(of: rootStage) { stage in
            // Keep the LIVE mirror in sync for escaping tasks (see `AppReveal`): the environment value
            // above only reaches view bodies, and a frozen captured copy is what broke the review prompt.
            AppReveal.revealed = (stage == .main)
            if stage == .splash { sawSplashThisLaunch = true }
            if stage == .aboutYou {
                aboutYouPresented = true
            } else if aboutYouPresented {
                // Answered or skipped: its opacity is animating to 0 above; unmount after the fade.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    if rootStage != .aboutYou { aboutYouPresented = false }
                }
            }
            if stage == .splash {
                splashPresented = true
            } else if splashPresented {
                // Leaving the splash: its opacity is animating to 0 above; unmount once that fade is done.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    if rootStage != .splash { splashPresented = false }
                }
            }
        }
    }
}

private struct MainTabView: View {
    // Deliberately NOT observing Settings, QuranData or QuranPlayer: this body reads none of them, but
    // an `@ObservedObject` subscription re-evaluated the ENTIRE TabView on every publish. The warm
    // walk reaches the singletons directly.
    private let settings = Settings.shared
    /// True while a launch/splash screen still covers the tabs (drives the under-cover warm below).
    let isCovered: Bool

    private enum AppTab: String, Hashable { case quran, islam, settings }

    #if DEBUG
    /// Headless tab switching for verification runs: `Settings`' `-settingsProbe` posts this with the
    /// tab's raw value ("quran") so a probe can change a setting on one tab and then LOOK at another -
    /// the only way to reproduce cross-tab staleness without tap tooling.
    static let debugSwitchTabNotification = Notification.Name("AlIslamDebugSwitchTab")
    #endif

    // Quran is the opening tab. Its content waits for the launch cover's first frame (`quranTab`), and
    // `warmUnderCover()` walks every tab so `TabView` builds and RETAINS each view tree before the
    // reveal, then settles on the opening tab. All of this happens behind the launch cover, and the
    // launch screen waits for it to finish (see `LaunchWarmup`) before it reveals.
    @State private var selectedTab: AppTab = .quran
    /// A deep link (an ayah widget's tap, a Sunnah reminder's) arrived before the under-cover warm
    /// finished: the warm's last step must land on the Quran tab.
    @State private var landOnQuranAfterWarm = false
    @State private var didWarm = false
    /// The opening Quran tab's content waits for the launch cover's first frame, like the warm walk
    /// below: built in the same pass, it would hold that frame (and the cover's animation task) back.
    /// Behind an opaque cover either way; true from the start when nothing covers the tabs.
    @State private var initialTabMounted: Bool

    init(isCovered: Bool) {
        self.isCovered = isCovered
        _initialTabMounted = State(initialValue: !isCovered)
    }

    var body: some View {
        #if DEBUG
        let _ = LaunchClock.markOnce("main tab view: first body")
        #endif
        tabs
            #if DEBUG
            .onAppear { LaunchClock.markOnce("main tab view: on appear") }
            .onReceive(NotificationCenter.default.publisher(for: Self.debugSwitchTabNotification)) { note in
                if let raw = note.object as? String, let tab = AppTab(rawValue: raw) {
                    selectedTab = tab
                }
            }
            #endif
            // A Sunnah reminder's tap (or its "Open" row anywhere in Settings) lands on the Quran
            // tab; the tab's own `.onReceive` opens the reader from there.
            .onReceive(AppNavigation.shared.$pendingQuran) { target in
                guard target != nil else { return }
                selectedTab = .quran
                if !LaunchWarmup.shared.isWarm { landOnQuranAfterWarm = true }
            }
            // A tap on an ayah widget (`QuranDeepLink`, alislam://ayah/2/255) opens that ayah: the
            // same route a Sunnah reminder's tap takes, so page mode and list mode both land on it.
            .onOpenURL { url in
                guard let target = QuranDeepLink.parseAyah(url) else { return }
                AppNavigation.shared.open(.ayah(target.surah, target.ayah))
            }
            // iPad: a Dynamic Type change inside the tab bar's selection animation is the UIKit hang
            // DynamicTypeCoalescer.swift describes; the coalescer holds one until the switch settles.
            .onChange(of: selectedTab) { _ in
                DynamicTypeCoalescer.noteTabSelectionChanged()
            }
            // A Reminder of the Day card's "Open" lands on the Islam tab; the Islam tab's own
            // `.onReceive` pushes the resource from there. (This app has no Hadith tab: a request for
            // it lands on the Islam tab.)
            .onReceive(AppNavigation.shared.$pendingIslam) { target in
                guard let target else { return }
                selectedTab = .islam
                switch target {
                case .tab, .hadithTab: AppNavigation.shared.pendingIslam = nil
                default: break
                }
            }
            // Launch warmups, one .task per app domain (like AppLifecycle's sections).
            // Shared: the tab walk behind the launch cover.
            .task { await warmUnderCover() }
            #if DEBUG
            // "-chosenAyahProbe": the Chosen Ayah widget's picker, run in-process (ChosenAyahIntent.swift).
            .task { await ChosenAyahProbe.runIfRequested() }
            // "-askAITextProbe": Ask AI's pure text functions on the audit's failing inputs (AskAIText.swift).
            .task { AskAITextProbe.runIfRequested() }
            // "-auditPacks": fingerprint every bundled pack and loose payload through the app's own
            // readers (see PackAudit); run before and after a repack and diff Documents/packaudit.txt.
            // The #if DEBUG is load-bearing: PackAudit.swift is itself `#if DEBUG && os(iOS)`.
            .task {
                guard ProcessInfo.processInfo.arguments.contains("-auditPacks") else { return }
                await Task.detached(priority: .utility) { PackAudit.run() }.value
            }
            #endif
            // Al-Quran: the reader's font/page prewarm.
            .task {
                // The gloss pack parses alongside the Quran text, off-main, so the first glossed row
                // finds it resident instead of parsing ~2 MB of JSON in its body.
                if settings.wordByWordMeanings || settings.wordByWordInline { WordByWordStore.shared.prewarm() }
                await QuranLaunchWarmup.prewarmAll()
            }
            // POST-REVEAL SCHEDULE. Everything below waits for the cover to lift and then takes its own
            // slot, so the sweeps never collide with each other or with the user's first taps:
            //   +1.0 s  the legacy tafsir download cache purge (once)
            //   +1.5 s  cross-language lexicon + Islam article corpus (detached, utility)
            //   +1.5 s  the reminders' launch pass (one pending fetch, the adds off-main; ReminderKinds.swift)
            //   +2.0 s  AI-search NLEmbedding probe (detached, utility)
            //   +3.5 s  the 6,236-entry ayah search index (utility; full tier only, otherwise on demand)
            //   +4.0 s  the ranked search's corpus lanes, once the index is there (utility; full tier only)
            .task {
                await AppReveal.waitUntilRevealed()
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { return }
                // Tafsir ships inside the app now: delete the pre-pack download cache, once, off-main.
                TafsirStore.purgeLegacyDownloadCache()
            }
            // Al-Quran: the AI-search capability probe loads a disk-backed NLEmbedding model, off-main,
            // AFTER the reveal: it's only needed once a search field gains focus. Full tier only; on the
            // reduced tier the model loads on the first search field focus instead.
            .task {
                await AppReveal.waitUntilRevealed()
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                guard !Task.isCancelled, !AppPerformance.shouldAvoidBroadPrewarm else { return }
                Task.detached(priority: .utility) { SemanticSearchEngine.prewarmOffMain() }
            }
            // Al-Quran: the ayah search index, built ahead of the first search on the full tier; on the
            // reduced tier it is built on demand when the search field gains focus.
            .task {
                await AppReveal.waitUntilRevealed()
                try? await Task.sleep(nanoseconds: 3_500_000_000)
                guard !Task.isCancelled, !AppPerformance.shouldAvoidBroadPrewarm else { return }
                await QuranData.shared.waitUntilCoreLoaded()
                guard !Task.isCancelled else { return }
                QuranData.shared.ensureVerseSearchIndex(priority: .utility)
            }
            // Shared: the cross-language highlight's lexicon and the Islam article corpus, inflated
            // off-main after the reveal (the under-cover walk realizes the tabs that used to kick them).
            .task {
                await AppReveal.waitUntilRevealed()
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                guard !Task.isCancelled else { return }
                await QuranData.shared.waitUntilCoreLoaded()
                guard !Task.isCancelled else { return }
                if !AppPerformance.shouldAvoidBroadPrewarm {
                    CrossLanguageWordHighlight.prewarmLexicon()
                }
                IslamArticleSearchModel.prewarm()
            }
            // Al-Quran: the ranked search's corpus lanes, right after the verse index the +3.5 s task
            // builds, so the first ranked query never builds them under the reader's thumb.
            .task {
                await AppReveal.waitUntilRevealed()
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                guard !Task.isCancelled, !AppPerformance.shouldAvoidBroadPrewarm else { return }
                let quranData = QuranData.shared
                for await ready in quranData.$isVerseSearchReady.values where ready { break }
                guard !Task.isCancelled, let snapshot = quranData.verseSearchSnapshot() else { return }
                Task.detached(priority: .utility) { QuranRankedSearch.prewarmLanes(snapshot: snapshot) }
            }
            // Shared: the reminders' one launch pass (the Sunnah presets re-added, the extra kinds
            // rebuilt only when their inputs changed). The AppDelegate leaves it to this schedule.
            .task {
                await AppReveal.waitUntilRevealed()
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                guard !Task.isCancelled else { return }
                await ReminderScheduler.rearmAfterLaunch()
            }
            #if DEBUG
            // "-simulateReminderTap surah:67" (or "ayah:2:285", "open"): what a reminder's or a daily
            // card's tap does, two seconds after the reveal, from whichever tab the launch landed on.
            .task {
                let arguments = ProcessInfo.processInfo.arguments
                guard let index = arguments.firstIndex(of: "-simulateReminderTap"),
                      arguments.indices.contains(index + 1) else { return }
                await AppReveal.waitUntilRevealed()
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                if let target = QuranOpenTarget(encoded: arguments[index + 1]) {
                    AppNavigation.shared.open(target)
                }
            }
            #endif
    }

    /// Build + retain every tab behind the launch cover, settle on the opening tab, then signal
    /// `LaunchWarmup` that the UI is ready to reveal. Runs once. If we were mounted already-uncovered
    /// (not a cold launch), there's nothing to hide, so we just mark warm immediately.
    ///
    /// The walk runs in FRONT of the finale, never under it: SwiftUI drives the finale's springs, blur
    /// and shimmer from the main thread, so a tab build under them froze the bloom and then jumped it.
    /// The light tabs are realized while the Quran text decodes on a background thread, and only the
    /// Quran tab waits for the text.
    @MainActor
    private func warmUnderCover() async {
        guard !didWarm else { return }
        didWarm = true

        guard isCovered else { LaunchWarmup.shared.markWarm(); return }

        // Never before the cover's own first frame: a tab build in the same run-loop pass would sit
        // between the window and the icon.
        await LaunchWarmup.shared.waitUntilCoverUp(maxWaitNanos: 1_000_000_000)
        try? await Task.sleep(nanoseconds: 16_000_000)
        if Task.isCancelled { LaunchWarmup.shared.markWarm(); return }

        // 1) The light tabs, while the Quran text is still decoding off-main. One frame between tabs.
        //    Low Power Mode / low-memory devices: walk ONLY the heavy Quran tab; the other two realize
        //    on their first real visit instead.
        if !AppPerformance.shouldAvoidBroadPrewarm {
            for tab in [AppTab.islam, .settings] {
                selectedTab = tab
                try? await Task.sleep(nanoseconds: 16_000_000)
            }
        }
        LaunchClock.mark("light tabs walked")

        // 2) The heavy Quran tab, once the real surah list can be built (not the empty loading state).
        await QuranData.shared.waitUntilCoreLoaded()
        LaunchClock.mark("quran core loaded")
        if Task.isCancelled { LaunchWarmup.shared.markWarm(); return }

        // Readiness, not a fixed settle: the tab reports its first body (list mode) or its pushed reader
        // (page mode, where the pager wrapping ~604 page identities is the single heaviest view
        // realization in the app) through `LaunchWarmup.markQuranTabLaidOut`; the sleeps are only the
        // cap for a tab that never reports. One more frame after the report lets that layout commit.
        selectedTab = .quran
        await LaunchWarmup.shared.waitUntilQuranTabLaidOut(
            maxWaitNanos: settings.quranPageMode ? 900_000_000 : 350_000_000
        )
        try? await Task.sleep(nanoseconds: 32_000_000)
        LaunchClock.mark("quran tab settled")

        // 3) Back on the landing tab; let it become the rendered tab again before the reveal. A
        // launch from a Sunnah reminder's tap or an ayah widget lands on the Quran tab instead.
        selectedTab = landOnQuranAfterWarm || AppNavigation.shared.pendingQuran != nil ? .quran : launchTab
        landOnQuranAfterWarm = false
        try? await Task.sleep(nanoseconds: 80_000_000)

        LaunchWarmup.shared.markWarm()
    }

    /// The tab the app lands on after the under-cover warm: the Quran tab (this app does not offer
    /// "Open the App On", `LaunchTab.isOffered`; a stored Islam choice is still honoured). A DEBUG
    /// launch argument wins, so UI automation can land straight on the tab it wants to exercise.
    private var launchTab: AppTab {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-launchTabQuran") { return .quran }
        if ProcessInfo.processInfo.arguments.contains("-launchTabIslam") { return .islam }
        if ProcessInfo.processInfo.arguments.contains("-launchTabSettings") { return .settings }
        #endif
        switch settings.launchTab {
        case .islam: return .islam
        default: return .quran
        }
    }

    @ViewBuilder
    private var quranTab: some View {
        if initialTabMounted {
            QuranView(isActiveTab: selectedTab == .quran)
        } else {
            Color.clear
                .task {
                    await LaunchWarmup.shared.waitUntilCoverUp(maxWaitNanos: 1_000_000_000)
                    initialTabMounted = true
                }
        }
    }

    @ViewBuilder
    private var tabs: some View {
        if #available(iOS 18.0, *) {
            TabView(selection: $selectedTab) {
                Tab("Quran", systemImage: "character.book.closed.ar", value: AppTab.quran) {
                    quranTab
                }

                Tab("Islam", systemImage: "moon.stars", value: AppTab.islam) {
                    IslamView()
                }

                Tab("Settings", systemImage: "gearshape", value: AppTab.settings) {
                    SettingsView()
                }
            }
        } else {
            TabView(selection: $selectedTab) {
                quranTab
                    .tabItem {
                        Image(systemName: "character.book.closed.ar")
                        Text("Quran")
                    }
                    .tag(AppTab.quran)

                IslamView()
                    .tabItem {
                        Image(systemName: "moon.stars")
                        Text("Islam")
                    }
                    .tag(AppTab.islam)

                SettingsView()
                    .tabItem {
                        Image(systemName: "gearshape")
                        Text("Settings")
                    }
                    .tag(AppTab.settings)
            }
        }
    }
}
