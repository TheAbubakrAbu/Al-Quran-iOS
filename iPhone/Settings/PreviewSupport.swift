import SwiftUI

enum AlIslamPreviewData {
    /// True only inside an Xcode preview canvas.
    ///
    /// Previews run in-process against the SINGLETONS (`Settings.shared`, `QuranPlayer.shared`), so a
    /// preview that seeds a persisted flag - `nowPlayingExpanded`, `quranPageMode`, the mushaf fold -
    /// writes the real `UserDefaults` of whatever simulator the canvas is using, and that value then
    /// outlives the preview: it leaks into the next preview, and into an ordinary run of the app on
    /// that device. A seeded `quranPageMode` has already cost a launch crash once that way.
    ///
    /// `seedPersisted` below routes such writes through a throwaway suite instead, so a preview can
    /// still show the state it is for without leaving anything behind.
    static var isRunningInPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    /// Writes a persisted flag for the canvas only, remembering what was there first so the value can
    /// be put back. Outside a preview it is a no-op, so a stray call in shipping code is inert.
    ///
    /// The canvas shares one simulator container with ordinary runs of the app on that device, which
    /// is why this is not a plain `set`: an unrestored `quranPageMode` or mushaf-fold flag is a real
    /// state change to the installed app, not just to the preview.
    static func seedPersisted(_ key: String, _ value: Bool) {
        guard isRunningInPreview else { return }
        let defaults = UserDefaults.standard
        if restorePoints[key] == nil {
            restorePoints[key] = defaults.object(forKey: key)
        }
        defaults.set(value, forKey: key)
    }

    /// Puts every flag `seedPersisted` touched back as it was. Hung off the preview's `.onDisappear`.
    static func restoreSeededDefaults() {
        guard isRunningInPreview else { return }
        let defaults = UserDefaults.standard
        for (key, original) in restorePoints {
            if let original { defaults.set(original, forKey: key) } else { defaults.removeObject(forKey: key) }
        }
        restorePoints.removeAll()
    }

    /// Original values of the flags a preview overwrote; `nil` means the key was unset.
    private static var restorePoints: [String: Any?] = [:]

    static let settings: Settings = {
        let settings = Settings.shared
        return settings
    }()

    static let quranData = QuranData.shared
    static let quranPlayer = QuranPlayer.shared
    static let namesData = NamesViewModel.shared

    static var surah: Surah {
        quranData.quran.first ?? fallbackSurah
    }

    static var ayah: Ayah {
        surah.ayahs.first(where: { $0.existsInQiraah(settings.displayQiraahForArabic) })
            ?? surah.ayahs.first
            ?? fallbackAyah
    }

    static var juz: Juz {
        QuranData.juzList.first ?? fallbackJuz
    }

    private static var fallbackAyah: Ayah {
        Ayah(
            id: 1,
            idArabic: "١",
            textHafs: "بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ",
            textTransliteration: "Bismillahi ar-Rahmani ar-Raheem",
            textEnglishSaheeh: "In the name of Allah, the Entirely Merciful, the Especially Merciful.",
            textEnglishMustafa: "In the Name of Allah, the Most Compassionate, the Most Merciful.",
            juz: 1,
            page: 1,
            textWarsh: nil,
            textQaloon: nil,
            textDuri: nil,
            textBuzzi: nil,
            textQunbul: nil,
            textShubah: nil,
            textSusi: nil
        )
    }

    private static var fallbackSurah: Surah {
        Surah(
            id: 1,
            idArabic: "١",
            nameArabic: "الفاتحة",
            nameTransliteration: "Al-Fatihah",
            nameEnglish: "The Opening",
            type: "makkan",
            numberOfAyahs: 7,
            ayahs: [fallbackAyah]
        )
    }

    private static var fallbackJuz: Juz {
        Juz(
            id: 1,
            nameArabic: "الم",
            nameTransliteration: "Alif Lam Mim",
            startSurah: 1,
            startAyah: 1,
            endSurah: 2,
            endAyah: 141
        )
    }
}

struct AlIslamPreviewContainer<Content: View>: View {
    private let embedInNavigation: Bool
    private let content: Content

    init(embedInNavigation: Bool = true, @ViewBuilder content: () -> Content) {
        self.embedInNavigation = embedInNavigation
        self.content = content()
    }

    var body: some View {
        previewContent
            .accentColor(AlIslamPreviewData.settings.accentColor.color)
            .tint(AlIslamPreviewData.settings.accentColor.color)
            .environmentObject(AlIslamPreviewData.settings)
            .environmentObject(AlIslamPreviewData.quranData)
            .environmentObject(AlIslamPreviewData.quranPlayer)
            .environmentObject(AlIslamPreviewData.namesData)
    }

    @ViewBuilder
    private var previewContent: some View {
        if embedInNavigation {
            NavigationView {
                content
            }
        } else {
            content
        }
    }
}

#Preview {
    AlIslamPreviewContainer(embedInNavigation: false) {
        Text("Preview Support")
            .padding()
    }
}
