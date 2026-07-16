import SwiftUI
import Combine
import WidgetKit
import os

let logger = Logger(subsystem: AppIdentifiers.bundleIdentifier, category: "Settings")

/// The single source of truth for all user settings.
///
/// **Why everything lives in this one file:** `@AppStorage` / `@Published` are stored property wrappers, and
/// Swift only allows stored properties in a type's primary declaration — never in an extension. So the
/// settings themselves can't be physically moved into separate Quran/Adhan files; the *behavior* that uses
/// them is what's split out, into `SettingsAdhan.swift` (prayer times, notifications, location) and
/// `SettingsQuran.swift` (reciters, bookmarks, khatm, …).
///
/// The declarations below are grouped, in order, into the four buckets:
///   1. **App Group** — `@Published`, mirrored into `appGroupUserDefaults` so widgets/extensions see them.
///   2. **App Storage — Adhan/Prayer** — `@AppStorage` prayer state, notifications, travel, calculation.
///   3. **App Storage — Quran** — `@AppStorage` reciter, favorites, sajdah/muqatta'at, bookmarks, khatm.
///   4. **App Storage — Arabic/Names + appearance/misc** — fonts, themes, haptics, color scheme.
/// Keep new settings in the matching section (and storage mechanism) so the split stays clean.
final class Settings: ObservableObject {
    static let shared = Settings()
    private let appGroupUserDefaults = UserDefaults(suiteName: AppIdentifiers.appGroupSuiteName)
    @Published private(set) var isReadyForUI = false

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
        self.accentColor = AccentColor(rawValue: appGroupUserDefaults?.string(forKey: "accentColor") ?? AppIdentifiers.mainColorString) ?? AppIdentifiers.mainColor
        self.customAccentColorHex = appGroupUserDefaults?.string(forKey: "customAccentColorHex") ?? "34C759"
        self.customBackgroundColorHex = appGroupUserDefaults?.string(forKey: "customBackgroundColorHex") ?? "1C1C1E"
        
        loadKhatmProgressCacheFromStorage()
        runQuranStartupMigrations()
        isReadyForUI = true
    }

    func waitUntilReady() async {
        while true {
            let isReady = await MainActor.run { self.isReadyForUI }
            if isReady { return }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }
    
    /// Restores every *preference* (appearance, prayer, and Quran options) to its default while keeping the
    /// user's content. We wipe the app's standard-defaults domain — which clears all the `@AppStorage`
    /// preferences in one shot — but first snapshot the content keys and write them back afterward, then
    /// reset the app-group-backed `@Published` preferences (accent, calculation, madhab, traveling, Hijri
    /// offset) to their defaults via their setters so the shared store + widgets update too. Location and
    /// other app-group content are left untouched.
    @MainActor
    func resetAllSettings() {
        // Bookmarks, favorites, khatm progress, saved reading/listening positions, and search history are
        // content, not settings — preserve them across the domain wipe.
        let contentKeys = [
            "favoriteSurahsData", "bookmarkedAyahsData", "favoriteLetterData", "favoriteNameNumbersData",
            "khatmCompletedAyahsData", "favoriteReciterIDsData", "favoriteQiraahTagsData",
            "favoriteEnglishTranslationIDsData", "savedSajdahAyahIDsData", "savedBrokenLetterAyahIDsData",
            "lastReadSurah", "lastReadAyah", "lastListenedAyahData", "lastListenedSurahData",
            "quranSearchHistoryData",
        ]

        let standard = UserDefaults.standard
        let preserved = contentKeys.reduce(into: [String: Any]()) { dict, key in
            if let value = standard.object(forKey: key) { dict[key] = value }
        }

        if let bundleID = Bundle.main.bundleIdentifier {
            standard.removePersistentDomain(forName: bundleID)
        }

        for (key, value) in preserved {
            standard.set(value, forKey: key)
        }

        // App-group preferences are mirrored by these @Published properties; reassigning to the defaults
        // re-persists them through each didSet. (Mirrors the init defaults.)
        accentColor = AppIdentifiers.mainColor
        customAccentColorHex = "34C759"
        customBackgroundColorHex = "1C1C1E"

        objectWillChange.send()
        #if os(iOS) || os(watchOS)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    // MARK: - App group — shared with widgets / extensions

    @Published var accentColor: AccentColor {
        didSet {
            guard Bundle.main.bundleIdentifier?.contains("Widget") != true else { return }
            appGroupUserDefaults?.setValue(accentColor.rawValue, forKey: "accentColor")
        }
    }

    /// Hex ("RRGGBB") backing `AccentColor.custom`, set via the Appearance color picker.
    @Published var customAccentColorHex: String {
        didSet {
            guard Bundle.main.bundleIdentifier?.contains("Widget") != true else { return }
            appGroupUserDefaults?.setValue(customAccentColorHex, forKey: "customAccentColorHex")
        }
    }
    
    /// Hex ("RRGGBB") of the user-picked app background, used when the "custom" color theme is active. Kept
    /// `@Published` (not `@AppStorage`) so dragging the color picker updates the background live everywhere.
    @Published var customBackgroundColorHex: String {
        didSet {
            guard Bundle.main.bundleIdentifier?.contains("Widget") != true else { return }
            appGroupUserDefaults?.setValue(customBackgroundColorHex, forKey: "customBackgroundColorHex")
        }
    }

    // MARK: - Quran — @AppStorage

    /// Big vs. small in-app Now Playing player. An in-app UI preference, not shared with the widget/watch.
    @AppStorage("nowPlayingExpanded") var nowPlayingExpanded: Bool = false

    @AppStorage("reciter") var reciter: String = "Muhammad Al-Minshawi (Murattal)"

    /// Disambiguates reciters that share the same display name (qiraah / surah base URL).
    @AppStorage("reciterId") var reciterId: String = ""

    @AppStorage("favoriteReciterIDsData") private var favoriteReciterIDsData = Data()
    var favoriteReciterIDs: [String] {
        get {
            (try? Self.decoder.decode([String].self, from: favoriteReciterIDsData)) ?? []
        }
        set {
            let normalized = Array(NSOrderedSet(array: newValue.compactMap {
                let trimmed = $0.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            })) as? [String] ?? []
            favoriteReciterIDsData = (try? Self.encoder.encode(normalized)) ?? Data()
        }
    }

    @AppStorage("favoriteQiraahTagsData") private var favoriteQiraahTagsData = Data()
    var favoriteQiraahTags: [String] {
        get {
            (try? Self.decoder.decode([String].self, from: favoriteQiraahTagsData)) ?? []
        }
        set {
            let normalized = Array(NSOrderedSet(array: newValue.map(Self.normalizeLegacyRiwayahTag))) as? [String] ?? []
            favoriteQiraahTagsData = (try? Self.encoder.encode(normalized)) ?? Data()
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
    var favoriteSurahs: [Int] {
        get {
            (try? Self.decoder.decode([Int].self, from: favoriteSurahsData)) ?? []
        }
        set {
            favoriteSurahsData = (try? Self.encoder.encode(newValue)) ?? Data()
        }
    }

    @AppStorage("khatmCompletedAyahsData") var khatmCompletedAyahsData = Data()
    @AppStorage("automaticKhatmCompletion") var automaticKhatmCompletion = true
    var khatmCompletedAyahSetCache: Set<String> = []
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

    @AppStorage("bookmarkedAyahsData") private var bookmarkedAyahsData = Data()
    var bookmarkedAyahs: [BookmarkedAyah] {
        get {
            (try? Self.decoder.decode([BookmarkedAyah].self, from: bookmarkedAyahsData)) ?? []
        }
        set {
            bookmarkedAyahsData = (try? Self.encoder.encode(newValue)) ?? Data()
        }
    }

    @AppStorage("showBookmarks") var showBookmarks = true
    @AppStorage("showFavorites") var showFavorites = true
    /// One master grid toggle (driven by the toolbar button) for every list on the Quran tab except the
    /// summary: bookmarked ayahs, favorite surahs, and the surah / juz browse list.
    @AppStorage("quranGridMode") var quranGridMode = false
    /// Reads a surah as swipeable mushaf pages instead of a scrolling ayah list. Toggled from the Quran tab's
    /// toolbar, but only takes effect inside SurahView — the surah browse list itself is unchanged.
    @AppStorage("quranPageMode") var quranPageMode = false
    /// Shows the spelled-out pronunciation aid above muqatta'at ayahs (e.g. أَلِفۡ لَآم مِيٓمۡ). Off by default.
    @AppStorage("showMuqattaatHelper") var showMuqattaatHelper = false

    @AppStorage("shareShowAyahInformation") var showAyahInformation: Bool = true
    @AppStorage("shareShowSurahInformation") var showSurahInformation: Bool = false

    @AppStorage("beginnerMode") var beginnerMode: Bool = false

    @AppStorage("quranSortMode") var quranSortModeRaw: String = QuranSortMode.surah.rawValue
    @AppStorage("quranSortDirection") var quranSortDirectionRaw: String = QuranSortDirection.ascending.rawValue

    var quranSortMode: QuranSortMode {
        get { QuranSortMode(rawValue: quranSortModeRaw) ?? .surah }
        set { quranSortModeRaw = newValue.rawValue }
    }

    var quranSortDirection: QuranSortDirection {
        get { QuranSortDirection(rawValue: quranSortDirectionRaw) ?? .ascending }
        set { quranSortDirectionRaw = newValue.rawValue }
    }

    var groupBySurah: Bool { quranSortMode == .surah }
    /// In Khatm mode, the Surah/Juz toggle (which replaces the Asc/Desc control). When on, surahs are grouped
    /// under juz headers, each surah shown once in the juz it *starts* in — so juz that no surah opens (e.g.
    /// juz 2, 5) appear empty.
    @AppStorage("khatmGroupByJuz") var khatmGroupByJuz: Bool = false
    @AppStorage("searchForSurahs") var searchForSurahs: Bool = true
    @AppStorage("ignoreSilentLettersInQuranSearch") var ignoreSilentLettersInQuranSearch: Bool = true

    @AppStorage("lastReadSurah") var lastReadSurah: Int = 0
    @AppStorage("lastReadAyah") var lastReadAyah: Int = 0

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

    @AppStorage("lastListenedAyahData") private var lastListenedAyahData: Data?
    var lastListenedAyah: LastListenedAyah? {
        get {
            guard let data = lastListenedAyahData else { return nil }
            do {
                return try Self.decoder.decode(LastListenedAyah.self, from: data)
            } catch {
                logger.debug("Failed to decode last listened ayah: \(error)")
                return nil
            }
        }
        set {
            if let newValue = newValue {
                do {
                    lastListenedAyahData = try Self.encoder.encode(newValue)
                } catch {
                    logger.debug("Failed to encode last listened ayah: \(error)")
                }
            } else {
                lastListenedAyahData = nil
            }
        }
    }

    @AppStorage("lastListenedSurahData") private var lastListenedSurahData: Data?
    var lastListenedSurah: LastListenedSurah? {
        get {
            guard let data = lastListenedSurahData else { return nil }
            do {
                return try Self.decoder.decode(LastListenedSurah.self, from: data)
            } catch {
                logger.debug("Failed to decode last listened surah: \(error)")
                return nil
            }
        }
        set {
            if let newValue = newValue {
                do {
                    lastListenedSurahData = try Self.encoder.encode(newValue)
                } catch {
                    logger.debug("Failed to encode last listened surah: \(error)")
                }
            } else {
                lastListenedSurahData = nil
            }
        }
    }

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
    var quranSearchHistory: [String] {
        get {
            (try? Self.decoder.decode([String].self, from: quranSearchHistoryData)) ?? []
        }
        set {
            quranSearchHistoryData = (try? Self.encoder.encode(Array(newValue.prefix(10)))) ?? Data()
        }
    }

    @AppStorage("englishFontSize") var englishFontSize: Double = Double(UIFont.preferredFont(forTextStyle: .body).pointSize)

    // MARK: - Arabic letters & 99 Names
    
    @AppStorage("THEfontArabic") var fontArabic: String = "KFGQPCHAFSUthmanicScript-Regula"
    @AppStorage("fontArabicSize") var fontArabicSize: Double = Double(UIFont.preferredFont(forTextStyle: .title1).pointSize)
    @AppStorage("useFontArabic") var useFontArabic = true

    // MARK: - Arabic Alphabet screen size

    /// The Arabic Alphabet screens (ArabicView / ArabicLetterView) expose a size slider. This is its position
    /// as an index into `arabicLetterDynamicTypeSizes`. The views apply the result as a Dynamic-Type *floor*
    /// so text only ever grows from the device size, and the custom Arabic glyphs (built with `relativeTo:`)
    /// grow along with every other label.
    @AppStorage("arabicLetterSizeIndex") var arabicLetterSizeIndex: Int = 0

    /// Starts at `.xSmall`, not `.large`: a floor is a *minimum*, so anchoring it at `.large` silently forced
    /// the alphabet up to the default text size for anyone whose system Dynamic Type is set smaller. The
    /// lowest slider position must mean "whatever the device is set to", which only `.xSmall` guarantees.
    static let arabicLetterDynamicTypeSizes: [DynamicTypeSize] =
        [.xSmall, .small, .medium, .large, .xLarge, .xxLarge, .xxxLarge, .accessibility1, .accessibility2, .accessibility3]

    var arabicLetterDynamicTypeSize: DynamicTypeSize {
        let sizes = Self.arabicLetterDynamicTypeSizes
        return sizes[min(max(arabicLetterSizeIndex, 0), sizes.count - 1)]
    }

    /// A custom Arabic font that scales with Dynamic Type (so the Arabic Alphabet size slider affects it).
    /// `base` is the point size at the default (`.large`) content size.
    func scalableArabicFont(base: CGFloat, relativeTo style: Font.TextStyle) -> Font {
        .custom(fontArabic, size: base, relativeTo: style)
    }

    @AppStorage("favoriteLetterData") private var favoriteLetterData = Data()
    var favoriteLetters: [LetterData] {
        get {
            (try? Self.decoder.decode([LetterData].self, from: favoriteLetterData)) ?? []
        }
        set {
            favoriteLetterData = (try? Self.encoder.encode(newValue)) ?? Data()
        }
    }
    
    func toggleLetterFavorite(letterData: LetterData) {
        withAnimation {
            if isLetterFavorite(letterData: letterData) {
                favoriteLetters.removeAll(where: { $0.id == letterData.id })
            } else {
                favoriteLetters.append(letterData)
            }
        }
    }

    func isLetterFavorite(letterData: LetterData) -> Bool {
        favoriteLetters.contains { $0.id == letterData.id }
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
    
    // MARK: Arabic search normalization

    func cleanSearch(_ text: String, whitespace: Bool = false) -> String {
        // Single scalar walk: fold each Arabic scalar through the canonical map (dagger alif → alif, hamza
        // carriers → bare letters, teh marbuta → heh, …) and drop unwanted punctuation/marks in the SAME
        // pass. Replaces the old 22 sequential `replacingOccurrences` scans (each a full-string pass +
        // allocation) plus a separate filter pass — this runs on every keystroke query and ~7×/ayah during
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
    
    // MARK: - App-wide appearance & misc @AppStorage

    @AppStorage("THEfirstLaunch") var firstLaunch = true

    @AppStorage("hapticOn") var hapticOn: Bool = true

    @AppStorage("defaultView") var defaultView: Bool = true

    @AppStorage("colorSchemeString") var colorSchemeString: String = "system"
    var colorScheme: ColorScheme? {
        get {
            colorSchemeFromString(colorSchemeString)
        }
        set {
            colorSchemeString = colorSchemeToString(newValue)
        }
    }

    // MARK: - Global helpers (not Quran- or Adhan-specific)

    func hapticFeedback() {
        #if os(iOS)
        if hapticOn { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
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

    // MARK: - Reading themes (Sepia / Gray)
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
