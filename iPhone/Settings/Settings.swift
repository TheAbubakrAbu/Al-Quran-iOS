import SwiftUI
import CoreLocation
import WidgetKit
import Combine
import os

// DOMAIN MAP FOR THE COMPANION APPS (Al-Adhan / Al-Quran / Al-Hadith): the sections of this class
// are labelled with the app domain that owns them - see the [Al-Adhan] / [Al-Quran] / [Al-Hadith] /
// [Islam tab] / [Shared] MARK prefixes. When this file is copied into a companion app, delete the
// sections for domains it doesn't ship and keep every [Shared] one. The top of the class (init,
// app-group plumbing, accent/appearance) is [Shared]. The domain-specific extensions live in their
// own files already: SettingsAdhan.swift is wholly Al-Adhan, SettingsQuran.swift wholly Al-Quran.

let logger = Logger(subsystem: AppIdentifiers.bundleIdentifier, category: "Settings")

/// The single source of truth for all user settings.
///
/// **Why everything lives in this one file:** `@AppStorage` / `@Published` are stored property wrappers, and
/// Swift only allows stored properties in a type's primary declaration - never in an extension. So the
/// settings themselves can't be physically moved into separate Quran/Adhan files; the *behavior* that uses
/// them is what's split out, into `SettingsAdhan.swift` (prayer times, notifications, location) and
/// `SettingsQuran.swift` (reciters, bookmarks, khatm, …).
///
/// The declarations below are grouped, in order, into the four buckets:
///   1. **App Group** - `@Published`, mirrored into `appGroupUserDefaults` so widgets/extensions see them.
///   2. **App Storage - Adhan/Prayer** - `@AppStorage` prayer state, notifications, travel, calculation.
///   3. **App Storage - Quran** - `@AppStorage` reciter, favorites, sajdah/muqatta'at, bookmarks, khatm.
///   4. **App Storage - Arabic/Names + appearance/misc** - fonts, themes, haptics, color scheme.
/// Keep new settings in the matching section (and storage mechanism) so the split stays clean.
final class Settings: ObservableObject {
    static let shared = Settings()
    // Internal (not private): the per-domain extension files (SettingsQuran and friends) mirror their
    // typed accessors into the App Group suite for widgets/Siri, same as the members below do.
    let appGroupUserDefaults = UserDefaults(suiteName: AppIdentifiers.appGroupSuiteName)
    @Published private(set) var isReadyForUI = false

    /// Trailing-debounce work items so the launch burst of `fetchPrayerTimes` calls (onAppear + location
    /// callback + onChange + watch sync) collapses to a single notification reschedule / widget reload,
    /// off the synchronous first-paint path. Only used for callers that pass no completion (see
    /// `scheduleNotifications(deferred:)`); the background-refresh task path stays synchronous.
    /// (Not `private` because the coalescing helpers live in the `SettingsAdhan` extension, another file.)
    var pendingNotificationScheduleWorkItem: DispatchWorkItem?
    var pendingWidgetReloadWorkItem: DispatchWorkItem?
    
    static let encoder: JSONEncoder = {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .millisecondsSince1970
        return enc
    }()

    static let decoder: JSONDecoder = {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .millisecondsSince1970
        return dec
    }()

    private init() {
        let storedAccent = AccentColor(rawValue: appGroupUserDefaults?.string(forKey: "accentColor") ?? AppIdentifiers.mainColorString) ?? AppIdentifiers.mainColor
        self.accentColor = storedAccent
        self.customAccentColorHex = appGroupUserDefaults?.string(forKey: "customAccentColorHex") ?? "34C759"
        self.customBackgroundColorHex = appGroupUserDefaults?.string(forKey: "customBackgroundColorHex") ?? "1C1C1E"

        // The Al-Islam glow defaults ON, but only makes sense on the DEFAULT accent. An existing
        // install that already moved to another accent gets no accent-CHANGE event to auto-disable
        // it (see `accentColor.didSet`), so the very first launch with no stored choice seeds it
        // off for them - exactly what the didSet would have done had this shipped earlier.
        if UserDefaults.standard.object(forKey: "alIslamGlow") == nil,
           storedAccent != AppIdentifiers.mainColor {
            UserDefaults.standard.set(false, forKey: "alIslamGlow")
        }

        loadKhatmProgressCacheFromStorage()

        runQuranStartupMigrations()
        runWatchSyncKeyMigration()

        // Hadith Allah-highlighting used to follow the Quran toggle; when the setting split in two,
        // seed the new key from the old one so nothing visibly changes until the user flips it.
        if UserDefaults.standard.object(forKey: "highlightAllahNamesHadith") == nil {
            UserDefaults.standard.set(UserDefaults.standard.bool(forKey: "highlightAllahNames"), forKey: "highlightAllahNamesHadith")
        }
        isReadyForUI = true
    }

    func waitUntilReady() async {
        while true {
            let isReady = await MainActor.run { self.isReadyForUI }
            if isReady { return }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }
    
    /// Reload widget timelines, coalescing the launch burst the same way as `scheduleNotifications`.
    func reloadWidgets(deferred: Bool) {
        // See `scheduleNotifications`: a widget must not reload widget timelines - that is a self-reload loop.
        guard Settings.isAppProcess else { return }
        pendingWidgetReloadWorkItem?.cancel()
        pendingWidgetReloadWorkItem = nil
        guard deferred else {
            WidgetCenter.shared.reloadAllTimelines()
            return
        }
        let work = DispatchWorkItem { [weak self] in
            self?.pendingWidgetReloadWorkItem = nil
            WidgetCenter.shared.reloadAllTimelines()
        }
        pendingWidgetReloadWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
    }

    /// Restores every *preference* (appearance, prayer, and Quran options) to its default while keeping the
    /// user's content. We wipe the app's standard-defaults domain - which clears all the `@AppStorage`
    /// preferences in one shot - but first snapshot the content keys and write them back afterward, then
    /// reset the app-group-backed `@Published` preferences (accent, calculation, madhab, traveling, Hijri
    /// offset) to their defaults via their setters so the shared store + widgets update too. Location and
    /// other app-group content are left untouched.
    @MainActor
    func resetAllSettings(keepingContent: Bool = true) {
        // Bookmarks, favorites, khatm progress, saved reading/listening positions, and search history are
        // content, not settings - preserved across the domain wipe unless the user asked to erase everything.
        let contentKeys = [
            "favoriteSurahsData", "bookmarkedAyahsData", "favoriteLetterData", "favoriteNameNumbersData",
            "khatmCompletedAyahsData", "quranPlanData", "favoriteReciterIDsData", "favoriteQiraahTagsData",
            "favoriteEnglishTranslationIDsData", "savedSajdahAyahIDsData", "savedBrokenLetterAyahIDsData",
            "lastReadSurah", "lastReadAyah", "lastReadTimestamp", "lastListenedAyahData", "lastListenedSurahData",
            "quranSearchHistoryData",
            // The prayer tracker and menses-pause record: months of marks and exempt days - the most
            // clearly "the user's, not a preference" data in the app.
            "prayerTrackerData", "prayerTrackerExemptDaysData", "mensesPauseActive", "mensesPauseStartStamp",
            // Hadith content: marks, favorites, reading positions, search history, daily-hadith history.
            "hadithFavoriteBooks", "hadithFavoriteChapters", "hadithBookmarks",
            "hadithLastReadByBook", "hadithSearchHistoryData", "hadithOfTheDayHistory", "hadithBookCounts",
            // Tally counts (and the free counter's custom label, which is the user's own text).
            "tasbihFreeCount", "tasbihPresetCounts", "tasbihFreeLabel",
            // Only wiped by a full erase: these are stats/history rather than saved items, but they're still
            // the user's, not preferences.
            "surahOpenCountsData", "surahPlayCountsData",
        ]

        let standard = UserDefaults.standard
        let preserved = keepingContent
            ? contentKeys.reduce(into: [String: Any]()) { dict, key in
                if let value = standard.object(forKey: key) { dict[key] = value }
            }
            : [:]

        if let bundleID = Bundle.main.bundleIdentifier {
            standard.removePersistentDomain(forName: bundleID)
        }

        for (key, value) in preserved {
            standard.set(value, forKey: key)
        }

        // A full erase also clears the shared app-group store - the saved location, the cached prayer times,
        // the widgets' copy of everything, and the one-shot migration flags. That's what makes it equivalent to
        // deleting and reinstalling the app, rather than just to clearing this process's defaults.
        if !keepingContent {
            appGroupUserDefaults?.removePersistentDomain(forName: AppIdentifiers.appGroupSuiteName)
            explicitlySetKeys.removeAll()
        }

        // App-group preferences are mirrored by these @Published properties; reassigning to the defaults
        // re-persists them through each didSet. (Mirrors the init defaults.)
        accentColor = AppIdentifiers.mainColor
        customAccentColorHex = "34C759"
        customBackgroundColorHex = "1C1C1E"

        // The domain wipe changed the data underneath every in-memory cache. The memo-style caches
        // (favorites, bookmarks, sky palette) self-heal because they key on the stored bytes; these
        // presence-checked ones kept serving the erased values until a cold launch.
        loadKhatmProgressCacheFromStorage()

        objectWillChange.send()
        #if os(iOS) || os(watchOS)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    // MARK: - [Shared] App group - shared with widgets / extensions

    /// True in the iPhone app and the Watch app; false in every app extension.
    ///
    /// Extensions build a throwaway `Settings` and assign into it to render from the app group - see
    /// `PrayersProvider.makeEntry()`. They must never write back. The old test for this was
    /// `bundleIdentifier.contains("Widget")`, which silently missed the watch complication
    /// (`…watchkitapp.complication1`), letting that process persist its *fallback defaults* over the user's
    /// real values. Bundle layout, not naming, decides this: every extension lives in a `.appex`.
    static let isAppProcess = Bundle.main.bundleURL.pathExtension != "appex"

    /// The app-group keys holding a value the user (or an applied sync) actually chose, as opposed to one
    /// that merely sits at its default. `watchSyncSnapshot()` transmits only these, so a device that has
    /// never been configured cannot broadcast its defaults over an established peer.
    ///
    /// A plain `object(forKey:) != nil` check used to stand in for this, and it was wrong: any process that
    /// assigned a default created the key, and the default then looked chosen.
    private static let explicitKeysDefaultsKey = "settings.explicitlySetKeys"

    private(set) lazy var explicitlySetKeys: Set<String> =
        Set(appGroupUserDefaults?.stringArray(forKey: Self.explicitKeysDefaultsKey) ?? [])

    private func markExplicitlySet(_ key: String) {
        guard Self.isAppProcess, !explicitlySetKeys.contains(key) else { return }
        explicitlySetKeys.insert(key)
        appGroupUserDefaults?.set(Array(explicitlySetKeys), forKey: Self.explicitKeysDefaultsKey)
    }

    /// Backfills `explicitlySetKeys` once, and only on the iPhone.
    ///
    /// The iPhone's app group was never written by an extension (the iOS widget's bundle ID *did* contain
    /// "Widget", so the old guard held there), so every key present in it is a real choice and can be seeded.
    /// The watch's app group was polluted by the complication, so it is deliberately left to start empty:
    /// the watch will re-mark each key the moment it applies a snapshot or the user changes it there.
    ///
    /// Clearing the sync digest makes the phone re-push its true configuration on the next WC activation,
    /// with a fresh timestamp - which is what pulls a watch that has been broadcasting green back in line.
    private func runWatchSyncKeyMigration() {
        #if os(iOS)
        let migrationKey = "settings.didSeedExplicitKeys"
        guard Self.isAppProcess,
              let appGroup = appGroupUserDefaults,
              !appGroup.bool(forKey: migrationKey) else { return }

        let syncedAppGroupKeys = [
            "accentColor", "customAccentColorHex", "customBackgroundColorHex", "prayerCalculation",
            "hanafiMadhab", "travelingMode", "hijriOffset", "highLatitudeRule", "customPrayerNames",
        ]
        explicitlySetKeys.formUnion(syncedAppGroupKeys.filter { appGroup.object(forKey: $0) != nil })
        appGroup.set(Array(explicitlySetKeys), forKey: Self.explicitKeysDefaultsKey)
        appGroup.removeObject(forKey: "watchSync.lastSyncedSettingsData")
        appGroup.set(true, forKey: migrationKey)
        #endif
    }

    @Published var accentColor: AccentColor {
        didSet {
            guard Self.isAppProcess else { return }
            appGroupUserDefaults?.setValue(accentColor.rawValue, forKey: "accentColor")
            markExplicitlySet("accentColor")
            // The Al-Islam glow rides the DEFAULT accent: it's on out of the box, but the moment the
            // user picks any other accent it switches off so the glow follows their color instead of
            // clashing with it. One-way only - coming back to the default never re-enables it; that
            // takes the Appearance toggle. (Compared against `AppIdentifiers.mainColor`, not a
            // hardcoded green: companion apps ship different default accents.)
            if oldValue == AppIdentifiers.mainColor, accentColor != AppIdentifiers.mainColor {
                alIslamGlow = false
            }
            // Every widget renders in the accent, so a change must repaint them. Owned here (not an
            // `.onChange` at the app root) so every write path - the pickers, a synced snapshot, a
            // settings reset - repaints without each caller remembering to. Deferred so a burst of
            // writes (reset, sync apply) coalesces into one reload against WidgetKit's daily budget.
            reloadWidgets(deferred: true)
        }
    }

    /// Hex ("RRGGBB") backing `AccentColor.custom`'s primary stop, set via the Appearance color picker.
    @Published var customAccentColorHex: String {
        didSet {
            guard Self.isAppProcess else { return }
            appGroupUserDefaults?.setValue(customAccentColorHex, forKey: "customAccentColorHex")
            markExplicitlySet("customAccentColorHex")
        }
    }

    /// Hex ("RRGGBB") of the user-picked app background, used when the "custom" color theme is active. Kept
    /// `@Published` (not `@AppStorage`) so dragging the color picker updates the background live everywhere.
    @Published var customBackgroundColorHex: String {
        didSet {
            guard Self.isAppProcess else { return }
            appGroupUserDefaults?.setValue(customBackgroundColorHex, forKey: "customBackgroundColorHex")
            markExplicitlySet("customBackgroundColorHex")
        }
    }


    // MARK: - [Al-Quran] Quran - @AppStorage

    /// Big vs. small in-app Now Playing player. An in-app UI preference, not shared with the widget/watch.
    @AppStorage("nowPlayingExpanded") var nowPlayingExpanded: Bool = false

    @AppStorage("reciter") var reciter: String = "Muhammad Al-Minshawi (Murattal)"

    /// Disambiguates reciters that share the same display name (qiraah / surah base URL).
    @AppStorage("reciterId") var reciterId: String = ""

    @AppStorage("favoriteReciterIDsData") private var favoriteReciterIDsData = Data()
    /// Memoized like `favoriteSurahs`: `isReciterFavorite` runs inside a `.filter` over the whole
    /// reciter list per body pass, which used to be a full JSON decode per element.
    private static var favoriteReciterIDsCache: (data: Data, value: [String])?
    var favoriteReciterIDs: [String] {
        get {
            if let cached = Self.favoriteReciterIDsCache, cached.data == favoriteReciterIDsData {
                return cached.value
            }
            let decoded = (try? Self.decoder.decode([String].self, from: favoriteReciterIDsData)) ?? []
            Self.favoriteReciterIDsCache = (favoriteReciterIDsData, decoded)
            return decoded
        }
        set {
            let normalized = Array(NSOrderedSet(array: newValue.compactMap {
                let trimmed = $0.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            })) as? [String] ?? []
            let encoded = (try? Self.encoder.encode(normalized)) ?? Data()
            Self.favoriteReciterIDsCache = (encoded, normalized)
            favoriteReciterIDsData = encoded
        }
    }

    @AppStorage("favoriteQiraahTagsData") private var favoriteQiraahTagsData = Data()
    private static var favoriteQiraahTagsCache: (data: Data, value: [String])?
    var favoriteQiraahTags: [String] {
        get {
            if let cached = Self.favoriteQiraahTagsCache, cached.data == favoriteQiraahTagsData {
                return cached.value
            }
            let decoded = (try? Self.decoder.decode([String].self, from: favoriteQiraahTagsData)) ?? []
            Self.favoriteQiraahTagsCache = (favoriteQiraahTagsData, decoded)
            return decoded
        }
        set {
            let normalized = Array(NSOrderedSet(array: newValue.map(Self.normalizeLegacyRiwayahTag))) as? [String] ?? []
            let encoded = (try? Self.encoder.encode(normalized)) ?? Data()
            Self.favoriteQiraahTagsCache = (encoded, normalized)
            favoriteQiraahTagsData = encoded
        }
    }

    @AppStorage("favoriteEnglishTranslationIDsData") private var favoriteEnglishTranslationIDsData = Data()
    var favoriteEnglishTranslationIDs: [String] {
        get {
            (try? Self.decoder.decode([String].self, from: favoriteEnglishTranslationIDsData)) ?? []
        }
        set {
            let normalized = Array(NSOrderedSet(array: newValue.compactMap {
                let trimmed = $0.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            })) as? [String] ?? []
            favoriteEnglishTranslationIDsData = (try? Self.encoder.encode(normalized)) ?? Data()
        }
    }

    // Saved user flags: sajdah ayahs and broken-letter (muqatta'at) ayahs.
    @AppStorage("savedSajdahAyahIDsData") private var savedSajdahAyahIDsData = Data()
    var savedSajdahAyahIDs: Set<String> {
        get {
            (try? Self.decoder.decode([String].self, from: savedSajdahAyahIDsData)) .flatMap { Set($0) } ?? Set()
        }
        set {
            let arr = Array(newValue)
            savedSajdahAyahIDsData = (try? Self.encoder.encode(arr)) ?? Data()
            objectWillChange.send()
        }
    }

    @AppStorage("savedBrokenLetterAyahIDsData") private var savedBrokenLetterAyahIDsData = Data()
    var savedBrokenLetterAyahIDs: Set<String> {
        get {
            (try? Self.decoder.decode([String].self, from: savedBrokenLetterAyahIDsData)) .flatMap { Set($0) } ?? Set()
        }
        set {
            let arr = Array(newValue)
            savedBrokenLetterAyahIDsData = (try? Self.encoder.encode(arr)) ?? Data()
            objectWillChange.send()
        }
    }

    @AppStorage("reciteType") var reciteType: String = "Continue to Next"

    @AppStorage("favoriteSurahsData") private var favoriteSurahsData = Data()
    /// Decoded-favorites memo. These getters are read from every surah row's body and from
    /// `QuranView.searchDisplayContext` on every render - without the memo each read re-ran a full
    /// JSONDecoder pass, so scrolling the list decoded the same bytes once per visible row per frame.
    private static var favoriteSurahsCache: (data: Data, value: [Int])?
    var favoriteSurahs: [Int] {
        get {
            if let cached = Self.favoriteSurahsCache, cached.data == favoriteSurahsData {
                return cached.value
            }
            let decoded = (try? Self.decoder.decode([Int].self, from: favoriteSurahsData)) ?? []
            Self.favoriteSurahsCache = (favoriteSurahsData, decoded)
            return decoded
        }
        set {
            let encoded = (try? Self.encoder.encode(newValue)) ?? Data()
            Self.favoriteSurahsCache = (encoded, newValue)
            favoriteSurahsData = encoded
        }
    }

    @AppStorage("khatmCompletedAyahsData") var khatmCompletedAyahsData = Data()
    @AppStorage("automaticKhatmCompletion") var automaticKhatmCompletion = true
    /// The Quran Planner's plan (goal + per-day bookkeeping), iOS-only UI in QuranPlannerView.swift.
    /// Declared here because extensions can't add stored properties; harmless on the other targets.
    @AppStorage("quranPlanData") var quranPlanData = Data()
    var khatmCompletedAyahSetCache: Set<String> = []
    /// Int-keyed mirror of `khatmCompletedAyahSetCache` (surah * 1000 + ayah). `isKhatmAyahComplete`
    /// runs per ayah row per render while scrolling in khatm mode - the mirror answers it without
    /// building and hashing a "surah:ayah" String each call. Maintained by every mutation site in
    /// SettingsQuran.swift; the String set stays authoritative for persistence.
    var khatmCompletedAyahIntCache: Set<Int> = []
    var khatmCompletedSurahCountsCache: [Int: Int] = [:]
    var khatmProgressSaveTask: Task<Void, Never>?
    /// Bumped on every khatm mark. The single debounce task re-arms itself while this keeps changing, so a
    /// burst of auto-marks (scrolling) rides one timer instead of cancelling/recreating a Task per ayah.
    var khatmSaveGeneration = 0
    /// Whether the pending debounce task should also fire a UI refresh (set by auto-marks; manual marks
    /// refresh synchronously and leave this false).
    var khatmProgressRefreshPending = false

    var khatmCompletedAyahs: [String] {
        get {
            Array(khatmCompletedAyahSetCache)
        }
        set {
            applyKhatmCompletedAyahKeys(newValue, persistImmediately: true)
        }
    }

    // Raw storage only; the typed `bookmarkedAyahs: [BookmarkedAyah]` accessor lives in SettingsQuran.swift
    // so this core file names no Quran model type (ports to sibling apps without the Quran module). Not
    // `private` so that extension can reach it.
    @AppStorage("bookmarkedAyahsData") var bookmarkedAyahsData = Data()

    @AppStorage("showBookmarks") var showBookmarks = true
    @AppStorage("showFavorites") var showFavorites = true

    /// Reads a surah as swipeable mushaf pages instead of a scrolling ayah list. Toggled from the Quran tab's
    /// toolbar, but only takes effect inside SurahView - the surah browse list itself is unchanged.
    @AppStorage("quranPageMode") var quranPageMode = false
    /// Reading mode shrinks each mushaf page's Arabic until the whole page fits on screen, the way a printed
    /// mushaf sets it. Off, the page renders at the chosen font size and scrolls.
    @AppStorage("mushafFitPage") var mushafFitPage = true

    /// What page mode draws as each page's BODY text. "arabic" (default) is the mushaf itself; the English
    /// options replace the page's text wholesale - same canonical page boundaries, same fit-to-page - with
    /// the transliteration, The Clear Quran, or Saheeh International. Headings follow the page's language.
    @AppStorage("mushafPageLanguage") var mushafPageLanguage: String = MushafPageLanguage.arabic.rawValue

    var resolvedMushafPageLanguage: MushafPageLanguage {
        MushafPageLanguage(rawValue: mushafPageLanguage) ?? .arabic
    }
    /// Shows the spelled-out pronunciation aid above muqatta'at ayahs (e.g. أَلِفۡ لَآم مِيٓمۡ). Off by default.
    @AppStorage("showMuqattaatHelper") var showMuqattaatHelper = false

    @AppStorage("shareShowAyahInformation") var showAyahInformation: Bool = true
    @AppStorage("shareShowSurahInformation") var showSurahInformation: Bool = false

    @AppStorage("beginnerMode") var beginnerMode: Bool = false

    // Raw storage only; the typed `quranSortMode`/`quranSortDirection` accessors (and `groupBySurah`) live
    // in SettingsQuran.swift so this core file names no Quran sort enum. The defaults are the enum cases'
    // raw values written as literals (QuranSortMode.surah / QuranSortDirection.ascending) - a rawValue
    // change to either case must be mirrored here.
    @AppStorage("quranSortMode") var quranSortModeRaw: String = "surah"
    @AppStorage("quranSortDirection") var quranSortDirectionRaw: String = "ascending"
    /// In Khatm mode, the Surah/Juz toggle (which replaces the Asc/Desc control). When on, surahs are grouped
    /// under juz headers, each surah shown once in the juz it *starts* in - so juz that no surah opens (e.g.
    /// juz 2, 5) appear empty.
    @AppStorage("khatmGroupByJuz") var khatmGroupByJuz: Bool = false
    @AppStorage("searchForSurahs") var searchForSurahs: Bool = true
    // Silent-letter-insensitive Arabic ayah search is ALWAYS on (was `ignoreSilentLettersInQuranSearch`,
    // a toggle removed by request - the recitation-style fold is strictly additive, so there is no
    // reason to turn it off). The old UserDefaults key is simply orphaned.

    @AppStorage("lastReadSurah") var lastReadSurah: Int = 0
    @AppStorage("lastReadAyah") var lastReadAyah: Int = 0
    /// When the last-read position was recorded, for the summary tile's "Today 5:30 PM" caption.
    /// Stamped via `stampLastRead()` at both real save paths (list reader, mushaf pager flush) -
    /// clearing the position deliberately does not stamp. 0 = saved by a build without stamps.
    @AppStorage("lastReadTimestamp") private var lastReadTimestampRaw: Double = 0

    var lastReadDate: Date? {
        lastReadTimestampRaw > 0 ? Date(timeIntervalSince1970: lastReadTimestampRaw) : nil
    }

    func stampLastRead() {
        lastReadTimestampRaw = Date().timeIntervalSince1970
    }

    /// Debounced last-read bookkeeping for the mushaf pager.
    ///
    /// Recording the last-read position used to run inline on EVERY page turn, and it is expensive twice over:
    /// the `@AppStorage` writes fire `objectWillChange` (re-rendering every Settings-observing view, including
    /// all mounted pages), and `refreshQuranWidgets()` does a synchronous widget-snapshot disk write plus
    /// `WidgetCenter.reloadAllTimelines()`. None of that needs to happen mid-flip - only where the reader
    /// *stops* matters - so page turns note the position here and the write settles once the flipping pauses.
    /// `flushPendingLastRead()` runs on backgrounding so a quick exit can't lose the position.
    private var pendingLastRead: (surah: Int, ayah: Int)?
    private var pendingLastReadWorkItem: DispatchWorkItem?

    func noteLastRead(surah: Int, ayah: Int) {
        guard saveLastReadAyah else { return }
        guard lastReadSurah != surah || lastReadAyah != ayah else { return }
        pendingLastRead = (surah, ayah)

        pendingLastReadWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.flushPendingLastRead() }
        pendingLastReadWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: work)
    }

    func flushPendingLastRead() {
        pendingLastReadWorkItem?.cancel()
        pendingLastReadWorkItem = nil
        guard let pending = pendingLastRead else { return }
        pendingLastRead = nil

        lastReadSurah = pending.surah
        lastReadAyah = pending.ayah
        stampLastRead()
        refreshQuranWidgets()
    }

    // MARK: - [Al-Quran] Surah stats (times opened / played)
    // A tiny [surahID: count] map JSON-encoded in one key each - at most 114 small entries, so it costs
    // almost nothing in memory and is only decoded when a surah header is shown.
    @AppStorage("surahOpenCountsData") private var surahOpenCountsData: Data = Data()
    @AppStorage("surahPlayCountsData") private var surahPlayCountsData: Data = Data()

    private func decodeSurahCounts(_ data: Data) -> [Int: Int] {
        data.isEmpty ? [:] : ((try? Self.decoder.decode([Int: Int].self, from: data)) ?? [:])
    }

    func surahOpenCount(_ surahID: Int) -> Int { decodeSurahCounts(surahOpenCountsData)[surahID] ?? 0 }
    func surahPlayCount(_ surahID: Int) -> Int { decodeSurahCounts(surahPlayCountsData)[surahID] ?? 0 }

    func recordSurahOpened(_ surahID: Int) {
        guard (1...114).contains(surahID) else { return }
        var counts = decodeSurahCounts(surahOpenCountsData)
        counts[surahID, default: 0] += 1
        if let data = try? Self.encoder.encode(counts) { surahOpenCountsData = data }
    }

    func recordSurahPlayed(_ surahID: Int) {
        guard (1...114).contains(surahID) else { return }
        var counts = decodeSurahCounts(surahPlayCountsData)
        counts[surahID, default: 0] += 1
        if let data = try? Self.encoder.encode(counts) { surahPlayCountsData = data }
    }

    /// When off, the app neither saves nor shows the "Last Read Ayah" / "Last Listened Surah" sections.
    @AppStorage("saveLastReadAyah") var saveLastReadAyah: Bool = true
    @AppStorage("saveLastListenedSurah") var saveLastListenedSurah: Bool = true
    /// When off, the app neither saves nor shows the "Last Listened Ayah" section.
    @AppStorage("saveLastListenedAyah") var saveLastListenedAyah: Bool = true
    /// When on, the Quran tab shows the daily "Ayah of the Day" card.
    @AppStorage("showAyahOfTheDay") var showAyahOfTheDay: Bool = true
    /// When on, the Quran tab collapses the Ayah of the Day / Last Listened / Last Read cards into one
    /// compact section of tiles. On by default.
    @AppStorage("quranSummaryMode") var quranSummaryMode: Bool = true
    /// Day key (yyyy-MM-dd) for which the Ayah of the Day card has been hidden via "Hide for Today".
    @AppStorage("ayahOfTheDayHiddenDate") var ayahOfTheDayHiddenDate: String = ""
    /// A shuffled replacement for TODAY's Ayah of the Day, as "dayKey|surahID|ayahID". Stale days no
    /// longer match the key and are ignored, so the deterministic pick quietly resumes tomorrow.
    @AppStorage("ayahOfTheDayOverride") var ayahOfTheDayOverride: String = ""

    // The TYPED accessors over these two stores (`lastListenedAyah` / `lastListenedSurah`) live in
    // SettingsQuran.swift: they name Quran model types, and this core file stays free of every domain's
    // types except the prayer engine it structurally contains. Only the raw `Data` storage lives here
    // (stored properties can't move to extensions); internal so the extension can reach it.
    @AppStorage("lastListenedAyahData") var lastListenedAyahData: Data?
    @AppStorage("lastListenedSurahData") var lastListenedSurahData: Data?

    /// Which qiraah/riwayah to show for Arabic text. Empty or "Hafs" = Hafs an Asim (default). Transliteration and translations only apply to Hafs.
    @AppStorage("displayQiraah") var displayQiraah: String = ""

    /// When on, SurahView shows a qiraat picker above the search bar to compare riwayat in that view.
    @AppStorage("qiraatComparisonMode") var qiraatComparisonMode: Bool = false

    /// When on, ReciterListView reveals non-Hafs qiraat reciters.
    @AppStorage("showOtherQiraatReciters") var showOtherQiraatReciters: Bool = false

    /// Shared expand/collapse state for qiraah details in Quran settings and reciter lists.
    var showQiraahDetails: Bool {
        get { showOtherQiraatReciters }
        set { showOtherQiraatReciters = newValue }
    }

    /// Pass to Ayah.displayArabic(qiraah:clean:). Nil means Hafs.
    var displayQiraahForArabic: String? {
        let normalized = Self.normalizeLegacyRiwayahTag(displayQiraah)
        return normalized.isEmpty ? nil : normalized
    }

    /// When false, only Arabic is shown (no transliteration or English), since those are for Hafs an Asim only.
    var isHafsDisplay: Bool {
        Self.normalizeLegacyRiwayahTag(displayQiraah).isEmpty
    }

    /// Arabic riwayah line for settings section headers (matches on-screen Arabic text riwayah).
    var displayQiraahArabicCaption: String {
        let key = Self.normalizeLegacyRiwayahTag(displayQiraah)
        return Self.Riwayah.arabicCaptionByTag[key] ?? Self.Riwayah.arabicCaptionByTag[Self.Riwayah.hafsTag]!
    }

    @AppStorage("showArabicText") var showArabicText: Bool = true
    @AppStorage("highlightAllahNames") var highlightAllahNames: Bool = false
    @AppStorage("showTajweedColors") var showTajweedColors: Bool = false
    @AppStorage("showTajweedTafkhim") var showTajweedTafkhim: Bool = true
    @AppStorage("showTajweedQalqalah") var showTajweedQalqalah: Bool = true
    @AppStorage("showTajweedLamShamsiyah") var showTajweedLamShamsiyah: Bool = true
    @AppStorage("showTajweedSukoonJazm") var showTajweedDroppedLetter: Bool = true
    @AppStorage("showTajweedBareNuunMeem") var showTajweedIdghamBiGhunnahLight: Bool = true
    @AppStorage("showTajweedIdghamBiGhunnahHeavy") var showTajweedIdghamBiGhunnahHeavy: Bool = true
    @AppStorage("showTajweedGeneralGhunnah") var showTajweedGeneralGhunnah: Bool = true
    @AppStorage("showTajweedIkhfaa") var showTajweedIkhfaa: Bool = true
    @AppStorage("showTajweedIqlab") var showTajweedIqlab: Bool = true
    @AppStorage("showTajweedIdghamBilaGhunnah") var showTajweedIdghamBilaGhunnah: Bool = true
    @AppStorage("showTajweedHamzatWaslSilent") var showTajweedHamzatWaslSilent: Bool = true
    @AppStorage("showTajweedMaddNatural2") var showTajweedMaddNatural2: Bool = true
    @AppStorage("showTajweedMaddNaturalMiniature") var showTajweedMaddNaturalMiniature: Bool = true
    @AppStorage("showTajweedMadd246") var showTajweedMaddAaridLisSukoon: Bool = true
    @AppStorage("showTajweedMaddNecessary6") var showTajweedMaddNecessary6: Bool = true
    @AppStorage("showTajweedMaddSeparated") var showTajweedMaddSeparated: Bool = true
    @AppStorage("showTajweedMaddConnected") var showTajweedMaddConnected: Bool = true
    @AppStorage("cleanArabicText") var cleanArabicText: Bool = false
    @AppStorage("removeArabicDots") var removeArabicDots: Bool = false

    @AppStorage("showTransliteration") var showTransliteration: Bool = false
    @AppStorage("showEnglishSaheeh") var showEnglishSaheeh: Bool = true
    @AppStorage("showEnglishMustafa") var showEnglishMustafa: Bool = false
    @AppStorage("copyAyahArabic") var copyAyahArabic: Bool = true
    @AppStorage("copyAyahTransliteration") var copyAyahTransliteration: Bool = false
    @AppStorage("copyAyahEnglishSaheeh") var copyAyahEnglishSaheeh: Bool = false
    @AppStorage("copyAyahEnglishMustafa") var copyAyahEnglishMustafa: Bool = false
    @AppStorage("showPageJuzDividers") var showPageJuzDividers: Bool = true
    @AppStorage("showFullSurahRow") var showFullSurahRow: Bool = false

    @AppStorage("quranSearchHistoryData") private var quranSearchHistoryData = Data()
    /// Memoized: the Quran search bar reads this per render while focused (per keystroke).
    private static var quranSearchHistoryCache: (data: Data, value: [String])?
    var quranSearchHistory: [String] {
        get {
            if let cached = Self.quranSearchHistoryCache, cached.data == quranSearchHistoryData {
                return cached.value
            }
            let decoded = (try? Self.decoder.decode([String].self, from: quranSearchHistoryData)) ?? []
            Self.quranSearchHistoryCache = (quranSearchHistoryData, decoded)
            return decoded
        }
        set {
            let capped = Array(newValue.prefix(10))
            let encoded = (try? Self.encoder.encode(capped)) ?? Data()
            Self.quranSearchHistoryCache = (encoded, capped)
            quranSearchHistoryData = encoded
        }
    }

    // The Hadith tab's recent searches - the Quran search history's exact twin (chips over the search bar).
    @AppStorage("hadithSearchHistoryData") private var hadithSearchHistoryData = Data()
    /// Memoized like `favoriteSurahs`: the chips row stays mounted and reads this on every render pass.
    private static var hadithSearchHistoryCache: (data: Data, value: [String])?
    var hadithSearchHistory: [String] {
        get {
            if let cached = Self.hadithSearchHistoryCache, cached.data == hadithSearchHistoryData {
                return cached.value
            }
            let decoded = (try? Self.decoder.decode([String].self, from: hadithSearchHistoryData)) ?? []
            Self.hadithSearchHistoryCache = (hadithSearchHistoryData, decoded)
            return decoded
        }
        set {
            let capped = Array(newValue.prefix(10))
            let encoded = (try? Self.encoder.encode(capped)) ?? Data()
            Self.hadithSearchHistoryCache = (encoded, capped)
            hadithSearchHistoryData = encoded
        }
    }

    func addHadithSearchHistory(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        var history = hadithSearchHistory.filter {
            $0.caseInsensitiveCompare(trimmed) != .orderedSame
        }
        history.insert(trimmed, at: 0)
        hadithSearchHistory = Array(history.prefix(10))
    }

    func removeHadithSearchHistory(_ query: String) {
        hadithSearchHistory.removeAll { $0.caseInsensitiveCompare(query) == .orderedSame }
    }

    @AppStorage("englishFontSize") var englishFontSize: Double = Double(UIFont.preferredFont(forTextStyle: .body).pointSize)
    
    // MARK: - [Al-Hadith] Hadith display

    /// Which parts of a hadith render in the Hadith tab (both default on; hiding one gives a pure-Arabic or
    /// pure-English reading experience).
    @AppStorage("showHadithArabic") var showHadithArabic = true
    @AppStorage("showHadithEnglish") var showHadithEnglish = true
    /// Hadith's own "Highlight Allah" toggle, split from the Quran's `highlightAllahNames` so the two
    /// readers can differ. Seeded from the Quran toggle once in `init` so the split changes nothing
    /// until the user actually flips it.
    @AppStorage("highlightAllahNamesHadith") var highlightAllahNamesHadith: Bool = false
    /// Show the narrator ("It is narrated on the authority of...") line above the English text.
    @AppStorage("showHadithNarrator") var showHadithNarrator = true
    /// Hadith text sizes, independent of the Quran's own sliders.
    @AppStorage("hadithArabicFontSize") var hadithArabicFontSize: Double = Double(UIFont.preferredFont(forTextStyle: .body).pointSize + 4)
    @AppStorage("hadithEnglishFontSize") var hadithEnglishFontSize: Double = Double(UIFont.preferredFont(forTextStyle: .body).pointSize)

    // MARK: - [Islam tab] Arabic letters & 99 Names
    
    /// THE grid toggle, app-wide: the Quran tab's lists, the Arabic alphabet, the 99 Names, and the Islam
    /// resources all follow this one switch - flipping it anywhere flips it everywhere. (The key keeps its
    /// historical name so existing users' Quran preference carries over. The retired per-screen
    /// `arabicDisplayMode` / `namesDisplayMode` strings are no longer migrated - those screens default to
    /// list until re-toggled.)
    @AppStorage("quranGridMode") var gridMode = false
    
    /// Per-screen grid choices (Arabic Alphabet / 99 Names / Islam tab; the Hadith tab and the Quran tab
    /// own theirs). -1 = "not chosen yet": falls back to the app-wide `gridMode`, so existing users keep
    /// their current look until they flip that screen's own toggle - after which each grid icon controls
    /// only its own screen.
    @AppStorage("gridModeArabicRaw") var gridModeArabicRaw: Int = -1
    @AppStorage("gridModeNamesRaw") var gridModeNamesRaw: Int = -1
    @AppStorage("gridModeIslamRaw") var gridModeIslamRaw: Int = -1

    var arabicGridMode: Bool {
        get { gridModeArabicRaw == -1 ? gridMode : gridModeArabicRaw == 1 }
        set { gridModeArabicRaw = newValue ? 1 : 0 }
    }

    var namesGridMode: Bool {
        get { gridModeNamesRaw == -1 ? gridMode : gridModeNamesRaw == 1 }
        set { gridModeNamesRaw = newValue ? 1 : 0 }
    }

    var islamGridMode: Bool {
        get { gridModeIslamRaw == -1 ? gridMode : gridModeIslamRaw == 1 }
        set { gridModeIslamRaw = newValue ? 1 : 0 }
    }
    
    @AppStorage("THEfontArabic") var fontArabic: String = "KFGQPCHAFSUthmanicScript-Regula"
    @AppStorage("fontArabicSize") var fontArabicSize: Double = Double(UIFont.preferredFont(forTextStyle: .title1).pointSize)
    @AppStorage("useFontArabic") var useFontArabic = true

    /// The Arabic face for the NON-Quran Arabic screens (Hadith, Adhkar, Duas, 99 Names, Arabic Alphabet).
    /// Independent of the Quran's own font picker.
    enum IslamArabicFace: String, CaseIterable {
        case uthmani, indopak, basic

        /// Outside the Quran, "Uthmani" is ALWAYS the Qiraat Uthmani face - never the Hafs Quran face,
        /// which is reserved for the mushaf itself.
        var fontName: String {
            switch self {
            case .uthmani: return Settings.qiraatUthmaniFontName
            case .indopak: return Settings.indopakFontName
            case .basic: return Settings.systemArabicFontName
            }
        }
    }

    /// Raw storage for `islamArabicFace`. Empty means "not chosen yet" - the legacy two-way
    /// Quranic-vs-Basic toggle (`useFontArabic`) seeds the richer choice on first read.
    @AppStorage("islamArabicFontFace") var islamArabicFaceRaw: String = ""

    var islamArabicFace: IslamArabicFace {
        get {
            if let face = IslamArabicFace(rawValue: islamArabicFaceRaw) { return face }
            return useFontArabic ? .uthmani : .basic
        }
        set {
            islamArabicFaceRaw = newValue.rawValue
            // Keep the legacy flag in step - the watch sync channel still speaks Quranic-vs-Basic.
            useFontArabic = newValue != .basic
        }
    }

    /// True when the Quran Arabic font picker is set to "Basic" (the standard Apple system font).
    var quranUsesSystemArabicFont: Bool { fontArabic == Settings.systemArabicFontName }

    /// True when Quran Arabic renders in a real bundled face (Uthmani / Qiraat / IndoPak) rather than the system
    /// font. Views pass this to `arabicFontDesign(custom:)` so the app-wide rounded design skips the bundled faces
    /// but still applies when "Basic" is selected. See the note in `Globals.swift`.
    var quranUsesCustomArabicFace: Bool { !quranUsesSystemArabicFont }

    /// Same question for the non-Quran Arabic screens (Hadith, Adhkar, Duas, 99 Names, Arabic Alphabet):
    /// true whenever their three-way face picker is on a real bundled face rather than "Basic".
    var islamUsesCustomArabicFace: Bool { islamArabicFace != .basic }

    /// The Arabic font for the non-Quran Arabic screens, straight from the three-way face choice:
    /// Uthmani (the Qiraat face - never the Hafs Quran face), IndoPak, or Basic (system).
    var nonQuranArabicFontName: String { islamArabicFace.fontName }

    // MARK: - [Islam tab] Arabic Alphabet screen size
    
    static let randomReciterName = "Random Reciter"
    static let hafsUthmaniFontName = "KFGQPCHAFSUthmanicScript-Regula"
    static let qiraatUthmaniFontName = "KFGQPCQUMBULUthmanicScript-Regu"
    static let indopakFontName = "Al_Mushaf"
    /// Sentinel `fontArabic` value meaning "use the standard Apple system font" for Quran Arabic. It is not a
    /// real installed font, so any stray `.custom(_)` with it falls back to the system font anyway.
    static let systemArabicFontName = "AlIslamSystemArabicFont"

    /// The Arabic Alphabet screens (ArabicView / ArabicLetterView) expose a size slider. This is its position
    /// as an index into `arabicLetterDynamicTypeSizes`. The views apply the result as a Dynamic-Type *floor*
    /// so text only ever grows from the device size, and the custom Arabic glyphs (built with `relativeTo:`)
    /// grow along with every other label.
    @AppStorage("arabicLetterSizeIndex") var arabicLetterSizeIndex: Int = 0

    /// Hides the English readings ("ba", "bi", "bu") under the tashkeel glyphs on the Arabic Alphabet screens, so
    /// the marks can be practised from the Arabic alone rather than read off the transliteration.
    @AppStorage("hideEnglishInArabicLetters") var hideEnglishInArabicLetters: Bool = false

    /// Starts at `.xSmall`, not `.large`: a floor is a *minimum*, so anchoring it at `.large` silently forced
    /// the alphabet up to the default text size for anyone whose system Dynamic Type is set smaller. The
    /// lowest slider position must mean "whatever the device is set to", which only `.xSmall` guarantees.
    static let arabicLetterDynamicTypeSizes: [DynamicTypeSize] =
        [.xSmall, .small, .medium, .large, .xLarge, .xxLarge, .xxxLarge, .accessibility1, .accessibility2, .accessibility3]

    var arabicLetterDynamicTypeSize: DynamicTypeSize {
        let sizes = Self.arabicLetterDynamicTypeSizes
        return sizes[min(max(arabicLetterSizeIndex, 0), sizes.count - 1)]
    }

    /// The Islam tab's Arabic face (`nonQuranArabicFontName`), scaling with Dynamic Type so the Arabic
    /// Alphabet size slider affects it. `base` is the point size at the default (`.large`) content size.
    ///
    /// Deliberately the NON-Quran face: every Islam-tab surface that shows standard Arabic - dua, dhikr,
    /// the 99 Names, the alphabet and its letter detail - answers to the one `IslamArabicFontPicker`, so
    /// this must read the same setting the rows beside it do. It used to read `fontArabic` (the *Quran*
    /// picker's face), which is why flipping the alphabet's own picker to IndoPak restyled the letter rows
    /// but left the big glyph on the detail screen in the mushaf face.
    func scalableIslamArabicFont(base: CGFloat, relativeTo style: Font.TextStyle) -> Font {
        Font.arabic(nonQuranArabicFontName, size: base, relativeTo: style)
    }

    // Raw storage only; the typed `favoriteLetters: [LetterData]` accessor + toggles live next to the
    // `LetterData` type in ArabicLetters.swift, so this core file names no letter model type. Not `private`
    // so that extension can reach it.
    @AppStorage("favoriteLetterData") var favoriteLetterData = Data()

    /// Pinned Islam-tab resources, stored as the destination enum's raw values, comma-joined (a dozen short
    /// identifiers - a Codable blob would be ceremony).
    @AppStorage("favoriteIslamResources") private var favoriteIslamResourcesRaw = ""

    func isIslamResourceFavorite(_ id: String) -> Bool {
        favoriteIslamResourcesRaw.components(separatedBy: ",").contains(id)
    }

    func toggleIslamResourceFavorite(_ id: String) {
        var ids = favoriteIslamResourcesRaw.components(separatedBy: ",").filter { !$0.isEmpty }
        if let index = ids.firstIndex(of: id) {
            ids.remove(at: index)
        } else {
            ids.append(id)
        }
        favoriteIslamResourcesRaw = ids.joined(separator: ",")
    }

    @AppStorage("favoriteNameNumbersData") private var favoriteNameNumbersData = Data()
    var favoriteNameNumbers: [Int] {
        get {
            (try? Self.decoder.decode([Int].self, from: favoriteNameNumbersData)) ?? []
        }
        set {
            favoriteNameNumbersData = (try? Self.encoder.encode(newValue)) ?? Data()
        }
    }

    @AppStorage("showDescription") var showDescription = false

    func toggleNameFavorite(number: Int) {
        withAnimation {
            if isNameFavorite(number: number) {
                favoriteNameNumbers.removeAll(where: { $0 == number })
            } else {
                favoriteNameNumbers.append(number)
            }
        }
    }

    func isNameFavorite(number: Int) -> Bool {
        favoriteNameNumbers.contains(number)
    }
    
    // MARK: - [Shared] Arabic search normalization

    func cleanSearch(_ text: String, whitespace: Bool = false) -> String {
        // Single scalar walk: fold each Arabic scalar through the canonical map (dagger alif → alif, hamza
        // carriers → bare letters, teh marbuta → heh, …) and drop unwanted punctuation/marks in the SAME
        // pass. Replaces the old 22 sequential `replacingOccurrences` scans (each a full-string pass +
        // allocation) plus a separate filter pass - this runs on every keystroke query and ~7×/ayah during
        // index build, so collapsing 23 passes into 1 is a real win. Behavior is identical: all map keys are
        // single scalars, normalization still happens before the unwanted-char filter, lowercasing after.
        var built = ""
        built.unicodeScalars.reserveCapacity(text.unicodeScalars.count)
        for scalar in text.unicodeScalars {
            if let mapped = Self.canonicalArabicSearchScalarMap[scalar] {
                guard let replacement = mapped else { continue }   // map → nil means "drop" (e.g. bare hamza)
                if Self.unwantedCharSet.contains(replacement) { continue }
                built.unicodeScalars.append(replacement)
            } else {
                if Self.unwantedCharSet.contains(scalar) { continue }
                built.unicodeScalars.append(scalar)
            }
        }
        var cleaned = collapsingWhitespace(built.lowercased())

        if whitespace {
            cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return cleaned
    }

    func cleanSearchIgnoringSilentArabicLetters(_ text: String, whitespace: Bool = false) -> String {
        cleanSearch(text.removingSilentArabicLettersForSearch, whitespace: whitespace)
    }

    /// Scalar form of `canonicalArabicSearchMap`, built once: `key scalar → replacement scalar`, or `nil`
    /// to drop the scalar entirely. Lets `cleanSearch` normalize in a single pass instead of 22 string scans.
    /// (All `canonicalArabicSearchMap` keys are single scalars and values are one scalar or empty.)
    private static let canonicalArabicSearchScalarMap: [UnicodeScalar: UnicodeScalar?] = {
        var out: [UnicodeScalar: UnicodeScalar?] = [:]
        for (key, value) in canonicalArabicSearchMap {
            let keyScalars = Array(key.unicodeScalars)
            guard keyScalars.count == 1 else { continue }
            let valueScalars = Array(value.unicodeScalars)
            if valueScalars.isEmpty {
                out.updateValue(nil, forKey: keyScalars[0])              // store .none → drop
            } else if valueScalars.count == 1 {
                out.updateValue(valueScalars[0], forKey: keyScalars[0])  // store replacement scalar
            }
        }
        return out
    }()

    private static let canonicalArabicSearchMap: [String: String] = [
        // Alif family
        "\u{0670}": "ا", // dagger alif
        "ٱ": "ا",
        // Hamza family folds to plain carrier letters for forgiving search.
        "أ": "ا",
        "إ": "ا",
        "آ": "ا",
        "ٲ": "ا",
        "ٳ": "ا",
        "ٵ": "ا",
        "ؤ": "و",
        "ئ": "ي",
        "ء": "",
        "ٴ": "",
        "ٶ": "و",
        "ٷ": "و",
        "ٸ": "ي",
        // Waw variants
        "ۥ": "و",
        // Ya variants
        "ۦ": "ي",
        "ى": "ا", // alif maqsurah -> alif (matches both ى and ا forms in search)
        // Teh marbuta equivalence (broad)
        "ة": "ه"
    ]

    private static let unwantedCharSet: CharacterSet = {
        var set = CharacterSet.punctuationCharacters
            .union(.symbols)
            .union(.nonBaseCharacters)
        // Keep boolean-search operators in the normalized query.
        set.remove(charactersIn: "&|!#")
        return set
    }()

    private func collapsingWhitespace(_ text: String) -> String {
        text
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
    
    // MARK: - [Shared] App-wide appearance & misc @AppStorage

    @AppStorage("THEfirstLaunch") var firstLaunch = true

    @AppStorage("hapticOn") var hapticOn: Bool = true

    @AppStorage("defaultView") var defaultView: Bool = true

    /// The soft accent-colored radial wash at the top of every list (see `washedListBackground`).
    @AppStorage("showAccentGlow") var showAccentGlow: Bool = true

    /// Colors that wash with Al-Islam's brand yellow-and-green instead of the accent. ON by default -
    /// it IS the app's signature look on the default accent - and auto-disabled the moment the accent
    /// leaves the default (see `accentColor.didSet`); from there only the Appearance toggle brings it
    /// back.
    @AppStorage("alIslamGlow") var alIslamGlow: Bool = true

    @AppStorage("colorSchemeString") var colorSchemeString: String = "system"
    var colorScheme: ColorScheme? {
        get {
            colorSchemeFromString(colorSchemeString)
        }
        set {
            colorSchemeString = colorSchemeToString(newValue)
        }
    }

    // MARK: - [Shared] Global helpers (not Quran- or Adhan-specific)

    #if os(iOS)
    /// One reused, prepared generator: allocating a fresh `UIImpactFeedbackGenerator` per tap added
    /// latency/jitter on the highest-frequency taps in the app (the tasbih counter). Re-preparing after
    /// each impact keeps the Taptic Engine warm for the next one.
    private static let impactGenerator = UIImpactFeedbackGenerator(style: .light)
    #endif

    func hapticFeedback() {
        #if os(iOS)
        if hapticOn {
            Self.impactGenerator.impactOccurred()
            Self.impactGenerator.prepare()
        }
        #endif

        #if os(watchOS)
        if hapticOn { WKInterfaceDevice.current().play(.click) }
        #endif
    }

    func colorSchemeFromString(_ colorScheme: String) -> ColorScheme? {
        switch colorScheme {
        case "light", "sepia":
            return .light
        case "dark", "gray":
            return .dark
        case "custom":
            // Pick a light or dark base from the chosen background's brightness so text stays readable.
            return (customBackgroundLuminance ?? 1) < 0.5 ? .dark : .light
        default:
            return nil
        }
    }

    /// RGB components (0…1) of a "RRGGBB" hex string, or nil if invalid.
    private func rgbComponents(fromHex hex: String) -> (r: Double, g: Double, b: Double)? {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let rgb = UInt64(s, radix: 16) else { return nil }
        return (Double((rgb >> 16) & 0xFF) / 255, Double((rgb >> 8) & 0xFF) / 255, Double(rgb & 0xFF) / 255)
    }

    /// Perceived luminance (0…1) of the custom background, used to choose its light/dark base and derive shades.
    private var customBackgroundLuminance: Double? {
        guard let c = rgbComponents(fromHex: customBackgroundColorHex) else { return nil }
        return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b
    }

    /// The custom background nudged brighter/darker by `delta`, for deriving the row and glass-tint shades.
    private func adjustedCustomBackground(by delta: Double) -> Color? {
        guard let c = rgbComponents(fromHex: customBackgroundColorHex) else { return nil }
        func clampAdj(_ v: Double) -> Double { max(0, min(1, v + delta)) }
        return Color(red: clampAdj(c.r), green: clampAdj(c.g), blue: clampAdj(c.b))
    }

    // MARK: - [Shared] Reading themes (Sepia / Gray)
    // These layer custom background + row colors on top of a light (Sepia) or dark (Gray) base, so the app
    // offers warm/neutral reading looks beyond plain Light / Dark / System. Light/Dark/System return nil here
    // and keep the standard system grouped colors (no behavior change for existing users).

    /// True when the active theme paints its own background/row colors instead of the system grouped colors.
    var hasCustomThemeColors: Bool {
        colorSchemeString == "sepia" || colorSchemeString == "gray" || colorSchemeString == "custom"
    }

    /// Background shown behind list content for custom themes (warm cream / neutral charcoal / user-picked).
    var themeBackgroundColor: Color? {
        switch colorSchemeString {
        case "sepia": return Color(red: 0.90, green: 0.83, blue: 0.69)
        case "gray":  return Color(red: 0.13, green: 0.13, blue: 0.14)
        case "custom": return Color(hex: customBackgroundColorHex)
        default:      return nil
        }
    }

    /// Row / card color for plain (non-glass) list rows in custom themes, set apart from the background.
    var themeRowBackgroundColor: Color? {
        switch colorSchemeString {
        case "sepia": return Color(red: 0.93, green: 0.90, blue: 0.82)
        case "gray":  return Color(red: 0.19, green: 0.19, blue: 0.20)
        // A shade offset from the picked background (lighter on dark, darker on light) so cards stand out.
        case "custom": return adjustedCustomBackground(by: (customBackgroundLuminance ?? 1) < 0.5 ? 0.06 : -0.06)
        default:      return nil
        }
    }

    /// Tint blended into Liquid Glass cards/controls for custom themes, so glass reads as warm cream
    /// (Sepia) or neutral charcoal (Gray) instead of plain white/black. Nil = untinted system glass.
    var themeGlassTint: Color? {
        switch colorSchemeString {
        case "sepia": return Color(red: 0.85, green: 0.74, blue: 0.50).opacity(0.55)
        case "gray":  return Color(red: 0.33, green: 0.33, blue: 0.35).opacity(0.55)
        case "custom": return adjustedCustomBackground(by: (customBackgroundLuminance ?? 1) < 0.5 ? 0.12 : -0.08)?.opacity(0.55)
        default:      return nil
        }
    }

    func colorSchemeToString(_ colorScheme: ColorScheme?) -> String {
        switch colorScheme {
        case .light:
            return "light"
        case .dark:
            return "dark"
        default:
            return "system"
        }
    }
}
