# App Store Keywords (ASO)

Keyword research and the App Store Connect **Keywords** field for **Al-Quran | Beginner Quran**.
Keep this in sync whenever a major feature ships (e.g. Tafsir, AI Search).

---

## How the keyword field works

- **100 characters**, comma-separated, entered in App Store Connect (Keywords field, per localization).
- **No spaces after commas** - every space wastes a character. Use `tafsir,tajweed`, never `tafsir, tajweed`.
- **Never repeat** words already in the app **name** or **subtitle** - Apple already indexes those. So do **not** spend keyword characters on: `al`, `quran`, or `beginner`. This is the single biggest difference from Al-Islam's keyword field, where `quran` is worth its seven characters - here the name spends it for you, twice.
- **Apple auto-combines** single keywords into phrases, so `learn,arabic` already ranks for "learn arabic." Don't waste characters on multi-word phrases.
- **Apple stems** singular/plural and common variants - pick one form (`surah`, not `surah,surahs`).
- **Alternate spellings matter** - many terms have several common transliterations (`quran`/`koran`, `dhikr`/`zikr`, `tajweed`/`tajwid`, `hifz`/`hifdh`). These are distinct search terms, so it's worth spending characters on the high-value ones. `koran` earns its place precisely because `quran` is already covered by the name.
- The keyword field is **not** shown to users - it is purely for ranking. The name, subtitle, and description do the human-facing work.

---

## Recommended keyword field (primary)

```
tafsir,tajweed,mushaf,koran,arabic,learn,reciter,surah,ayah,juz,dua,dhikr,hifz,memorize,muslim,islam
```

**100 / 100 characters.** Covers the app's biggest search surfaces - tafsir, tajweed and the mushaf, recitation, Quran structure, Arabic learning, and the everyday-tools terms - while avoiding the name/subtitle words. (2.6.0: `tafsir` and `mushaf` added for the new tafsir sheets and retypeset mushaf; `recitation` was dropped in favor of `reciter`, since Apple stems the two together and the shorter form freed characters for `hifz` and `memorize`.)

### Why each term

| Keyword | Reason |
|---|---|
| `tafsir` | New in this release; Ibn Kathir, al-Tabari, as-Sa'di, Maarif, Tazkirul. Low-competition, high-intent. |
| `tajweed` | Color-coded tajweed plus the Tajweed Foundations reference. High-intent for anyone learning to recite. |
| `mushaf` | The retypeset page-by-page reader; the term readers use when they want a real mushaf, not a verse list. |
| `koran` | The alternate transliteration. `quran` is already spent by the app name, so this is the only way to reach the spelling a large share of English searchers actually type. |
| `arabic` | Arabic Beginner Mode, the alphabet, the fonts. Auto-combines with `learn` for "learn arabic." |
| `learn` | Auto-combines broadly (`learn arabic`, `learn tajweed`); the app's core promise for beginners. |
| `reciter` | Over 60 reciters and qiraat. Stems toward "reciters" and "recite." |
| `surah` | Core structural term; auto-combines (`surah audio`, `surah juz`). |
| `ayah` | The verse-level search, sharing, and notes; stems toward "ayat." |
| `juz` | Juz browsing and Juz search; short, cheap, and high-intent for readers on a khatm. |
| `dua` | Dua collections; very high volume, stems toward "duas." |
| `dhikr` | Adhkar + Tasbih counter. |
| `hifz` | Memorization intent - the single most-searched term by students of the Quran. |
| `memorize` | The English counterpart to `hifz`; auto-combines for "memorize quran." |
| `muslim` | Broad audience term. |
| `islam` | Not in this app's name or subtitle (unlike Al-Islam), so it is worth holding here - it reaches everyone searching the category generally. |

---

## Alternate fields to A/B test

Swap these in when a term underperforms in App Analytics (Search sources) or seasonally.

**Learning / convert focus** (lean into Beginner Mode + the Arabic alphabet):
```
tafsir,tajweed,arabic,alphabet,learn,revert,convert,mushaf,surah,ayah,juz,dua,dhikr,muslim,islam
```

**Recitation / audio focus** (lean into the 60+ reciters and qiraat):
```
tafsir,reciter,recitation,mp3,audio,offline,qiraat,warsh,mushaf,surah,ayah,juz,dua,muslim,islam
```

**Ramadan season push** (weeks before Ramadan):
```
tafsir,tajweed,mushaf,ramadan,khatm,fasting,taraweeh,recite,arabic,surah,ayah,juz,dua,muslim,islam
```

---

## Full keyword research (by theme)

Ranked roughly by value to this app. Bold = currently in the primary field.

### Quran
**tafsir**, **tajweed**, **mushaf**, **koran**, **surah**, **ayah**, **juz**, qiraat, warsh, hafs, transliteration, translation, saheeh, khattab, offline, tajwid, ayat

### Recitation
**reciter**, recitation, recite, mp3, audio, murattal, mujawwad, alafasy, sudais, minshawi, husary, listen

### Memorization
**hifz**, **memorize**, hifdh, hafiz, khatm, plan, planner, daily, streak

### Arabic learning
**arabic**, **learn**, alphabet, letters, harakat, tashkeel, read, pronunciation

### Daily worship / tools
**dua**, **dhikr**, tasbih, zikr, adhkar, supplication, misbaha, tasbeeh, hijri, calendar, wallpaper, allah, names

### AI features (2.6.0)
ai (very short, only worth testing in an alternate field - AI Search and Ask AI are described in the description, which is not a ranking input, so `ai` competes on its own)

### Identity / audience
**muslim**, **islam**, islamic, deen, iman, faith, sunni, worship, revert, convert, new

> Terms deliberately **excluded** from the keyword field because they're in the app name/subtitle: al, quran, beginner.

---

## Localization (other App Store storefronts)

Each localization has its **own** 100-character keyword field. High-value additions per market:

- **Arabic (ar)**: قرآن, تفسير, مصحف, تجويد, حفظ, ختمة, تلاوة, قارئ, سورة, آية, جزء, دعاء, ذكر, تسبيح, رمضان
- **Urdu / Pakistan, India**: `hifz`, `qirat`, `tarjuma`, `nazra`, `ramzan`, `dars`.
- **Turkish (tr)**: `kuran`, `mushaf`, `tecvid`, `ezber`, `hatim`, `meal`, `sure`, `ayet`, `dua`, `zikir`.
- **Indonesian / Malay (id, ms)**: `quran`, `tafsir`, `tajwid`, `mushaf`, `murottal`, `hafalan`, `juz`, `doa`, `dzikir`.
- **French (fr)**: `coran`, `tafsir`, `tajwid`, `mushaf`, `arabe`, `apprendre`, `recitation`, `sourate`, `doua`.

Keep the transliteration variants that match how each region actually types - that is where most of the incremental installs come from.

---

## Companion metadata (for reference)

The keyword field is one of three ranking inputs. The others, already written elsewhere, should stay keyword-rich:

- **App name / subtitle** - carry "Al-Quran" and "Beginner Quran," so the keyword field doesn't have to.
- **Description** - see `App Store Description.md`; leads with the Quran, tafsir, reciters, and AI search.
- **Promotional text** - see `Promotional Text.md`; updated per release, does not affect ranking but drives conversion.

---

## Maintenance checklist

When a major feature ships:
1. Add its highest-intent term to the primary field (trim the weakest current term to stay ≤ 100 chars).
2. Add the feature to `App Store Description.md` and `Promotional Text.md`.
3. Add any new data-source attribution to `CREDITS.md` and the in-app Credits view.
4. After release, watch **App Analytics → Sources → Search** and rotate underperforming keywords using the alternates above.
