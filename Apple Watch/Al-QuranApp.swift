import SwiftUI

@main
struct AlQuranApp: App {
    // Plain references, not `@StateObject` (the iPhone root's rule): observing the stores here re-ran
    // this body (and the whole TabView under it) on every publish of any of them. What the root reads
    // comes from `RootAppearance` through `.appearanceEnvironment()`.
    private let settings = Settings.shared
    private let quranData = QuranData.shared
    private let quranPlayer = QuranPlayer.shared
    private let namesData = NamesViewModel.shared

    @Environment(\.scenePhase) private var scenePhase
    @State private var isLaunching = true

    init() {
        LaunchClock.mark("app init")
        #if DEBUG
        LaunchClock.installStallWatch()
        #endif
        // Nothing is revealed until the launch cover lifts (`isLaunching` flips in the finale): every
        // task parked on `AppReveal` (the Quran parse below among them) waits for the reveal, the
        // iPhone root's rule. Without this the mirror read its default (true) under the cover.
        AppReveal.revealed = false
        // Activate WatchConnectivity early so settings sync with the iPhone both ways.
        _ = WatchConnectivityManager.shared
        LaunchClock.mark("app init: watch connectivity up")
    }

    private enum WatchTab: Hashable { case quran, islam, settings }

    @State private var selectedTab: WatchTab = .quran
    @State private var didWarm = false
    /// The three tabs are placeholders until the launch cover's first frame has committed (see
    /// `tabContent`); flipped by `mountTabsThenWarm`.
    @State private var tabsMounted = false

    var body: some Scene {
        WindowGroup {
            // The tabs mount from the first frame UNDER the launch cover (the same trick as the iPhone's
            // MainTabView), so each tab's view tree can be built and retained while the launch animation
            // plays. Before this, tabs only mounted after the reveal, and the first swipe into a tab paid its
            // whole build cost as a visible hitch.
            // ...but never in the cover's own first transaction (the iPhone's launch rule): each tab is a
            // `Color.clear` until `LaunchWarmup` reports the cover up, then all three mount under it and
            // the walk below realizes them one by one.
            ZStack {
                TabView(selection: $selectedTab) {
                    tabContent { QuranView() }.tag(WatchTab.quran)

                    tabContent { IslamView() }.tag(WatchTab.islam)

                    tabContent { SettingsView() }.tag(WatchTab.settings)
                }
                .task { await mountTabsThenWarm() }

                if isLaunching {
                    LaunchScreen(isLaunching: $isLaunching)
                        .zIndex(1)
                        .transition(.opacity)
                }
            }
            .environmentObject(settings)
            .environmentObject(quranData)
            .environmentObject(quranPlayer)
            .environmentObject(namesData)
            // Accent, tint, color scheme and the shared chrome's `AppearanceEnvironment`, live. Without
            // this every `\.appearance` reader (glass, row backgrounds, icon chips, section pills) sits on
            // the key's one-time launch snapshot, so an accent change only showed after a restart.
            .appearanceEnvironment()
            // The app-wide SF Rounded design, same as the iPhone root: it covers every system-font Text on
            // the watch, styled or not (watchOS 9.1+; a visual no-op earlier).
            .appFontDesign()
            // Every Toggle breathes, same as the iPhone root (see `PaddedSwitchToggleStyle`).
            .toggleStyle(PaddedSwitchToggleStyle())
            .transition(.opacity)
            .animation(.easeInOut, value: isLaunching)
            // The live mirror of `isLaunching` for the views that read it and for the tasks parked on
            // `AppReveal`.
            .environment(\.appRevealed, !isLaunching)
            .onChange(of: isLaunching) { launching in
                AppReveal.revealed = !launching
            }
        }
        // No `.onChange` refreshes for settings here (the iPhone root's rule): each setting's own didSet
        // performs its side effects (`accentColor` repaints the widgets from Settings on every write
        // path), so a refresh here paid a second timeline reload per flip. Phase transitions delegate to
        // the one place that orchestrates them (AppLifecycle.swift's watch half: the pending last-read,
        // khatm and watch-sync flushes).
        .onChange(of: scenePhase) { phase in
            AppLifecycle.scenePhaseChanged(to: phase)
        }
    }

    /// A tab's content, or a clear placeholder while the launch cover's first frame is still pending.
    @ViewBuilder
    private func tabContent<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        if tabsMounted {
            content()
        } else {
            Color.clear
        }
    }

    /// Mount the three tabs once the cover's first frame has committed (at once when there is no cover),
    /// give that mount its own run-loop pass, then walk them.
    @MainActor
    private func mountTabsThenWarm() async {
        if isLaunching {
            await LaunchWarmup.shared.waitUntilCoverUp(maxWaitNanos: 1_000_000_000)
        }
        tabsMounted = true
        LaunchClock.mark("tabs mounted")
        // One frame: the mount realizes the selected page (and its neighbour) in the next pass, and the
        // walk's first selection change must not land in that same transaction.
        try? await Task.sleep(nanoseconds: 16_000_000)
        await warmUnderCover()
    }

    /// Walk each tab under the launch cover so its view tree is built and retained before the reveal -
    /// Quran, then Islam, then Settings, settling on the landing tab. The whole walk overlaps the finale
    /// animation's hold, so the warming costs no visible launch time.
    @MainActor
    private func warmUnderCover() async {
        guard !didWarm else { return }
        didWarm = true
        // The watch defers the Quran parse past the launch cover (`QuranData.shared`), so this root
        // kicks it at the REVEAL: its landing is ~100 ms of main thread, which under the finale's hold
        // would stall the animation. `QuranView.onAppear` is only a backstop for a visit after the walk,
        // and the Quran tab is this app's landing tab, already on screen, so without this kick it would
        // show its loading state until it next appeared.
        defer {
            Task { @MainActor in
                await AppReveal.waitUntilRevealed()
                quranData.ensureLoading()
            }
        }

        guard isLaunching else { LaunchWarmup.shared.markWarm(); return }

        // Jumps, not slides: the paging TabView animates a selection change. Nothing is visible under
        // the cover, so the selection moves in a transaction with animations off, and each tab gets two
        // frames to realize.
        for tab in [WatchTab.quran, .islam, .settings, launchTab] {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { selectedTab = tab }
            try? await Task.sleep(nanoseconds: 32_000_000)
        }

        LaunchWarmup.shared.markWarm()
    }

    /// The tab the watch lands on after the under-cover warm. Always Quran for users; a DEBUG launch
    /// argument lets automation land straight on a tab it wants to exercise.
    private var launchTab: WatchTab {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-launchTabIslam") { return .islam }
        if ProcessInfo.processInfo.arguments.contains("-launchTabSettings") { return .settings }
        #endif
        return .quran
    }
}
