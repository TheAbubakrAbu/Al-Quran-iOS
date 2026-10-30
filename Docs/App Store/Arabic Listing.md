# App Store Arabic Listing

The **Arabic** localization of the App Store listing for **Al-Quran | Beginner Quran**. In App Store Connect,
add the Arabic localization, then fill Name and Subtitle under App Information and the other four fields on
the version page.
People whose device is set to Arabic see this listing instead of the English one. In the Arabic interface the
app calls itself القرآن, and its tabs are القرآن، الإسلام and الإعدادات; the listing uses the same words.
Modeled on Al-Islam's `Docs/App Store/Arabic Listing.md`, whose style and glossary this file follows.

| Field | Limit | Editable without a new version? |
|---|---|---|
| Name | 30 | No |
| Subtitle | 30 | No |
| Keywords | 100 | No |
| Promotional Text | 170 | Yes |
| Description | 4,000 | No |
| What's New | 4,000 | No |

## Guidelines

- **Counts are Python `len()`** of the exact text inside each code block (the bold tally lines are for this
  file, not the store). Re-check after any edit:
  `python3 -c 'import re;f=chr(96)*3;t=open("Docs/App Store/Arabic Listing.md").read();[print(len(b)) for b in re.findall(f+"\n(.*?)\n"+f,t,re.S)]'`
- **Modern Standard Arabic as Apple's own Arabic pages read it**, with the respectful register (النبي صلى الله عليه وسلم). The honorific is always spelled out: App Store Connect rejects the one-glyph ligature (U+FDFA) as an invalid character.
  Feature names are the labels the app shows (Al-Islam's `Resources/Localizable.xcstrings`, which Al-Quran
  receives in its sync; see the glossary below).
- **Inside a sentence the app is تطبيق القرآن.** A bare القرآن in running text reads as the Quran itself;
  it names the app alone only as the name, as the tab, or inside a quoted label.
- **No em dash, and no spaced hyphen used as a dash.** Use a colon, the Arabic comma ، or a new sentence.
  A leading "- " bullet is fine; the English fields use the same.
- **Arabic punctuation** (، ؛ ؟) and Arabic-Indic digits (٦٠، ٥:٢٧) in the store text. No version numbers.
- **Brand names stay Latin:** Apple, Siri, Apple Watch, Apple Intelligence, iPhone, iPad, Mac, iOS; so does
  OC Ummah.
- **No harakat in the name, subtitle or keywords.** A shadda is a character of its own and nobody types one
  in a search. The description and notes may use them where the app's own label does (مخطِّط القرآن).
- **Only what the English listing claims.** Every feature named here is in Al-Quran's English
  `App Store Description.md` or `Whats New.md`. Al-Quran has no prayer times and no Hadith tab: no prayer or
  hadith features and no prayer search terms. CarPlay is left out because the English listing does not
  mention it; add it to both languages together.
- **Be honest about what is still English:** the in-depth articles of the Islam tab (Proving Islam, the
  How-To Guides, the pillars and the miracles libraries among them), and AI search by meaning, which matches
  English phrases only.
- **No scripture quoted.** No Quranic text and no hadith presented as the Prophet's words.
- Keep in sync with the English docs: `App Store Description.md`, `Keywords.md`, `Promotional Text.md` and
  `Whats New.md`. When an English field changes for a feature, change the Arabic one in the same pass.

## 1. Name

Names are unique across the store, so a bare القرآن will not be accepted. Each option keeps القرآن first,
then a short descriptor after a separator, as the English name does with "|".

**Recommended:**

```
القرآن | مصحف، تفسير، تجويد
```

**27 / 30 characters.**

Three bare search words, as Al-Islam's recommended name does: the mushaf (page mode), tafsir and tajweed.
Each is a search term of its own (no و attached to it). The English "Beginner Quran" matters less to a
reader who already reads Arabic; it is Alternate A.

**Alternate A:**

```
القرآن | مصحف للمبتدئين
```

**23 / 30 characters.**

Closest to the English name, and للمبتدئين is how "القرآن للمبتدئين" and "تجويد للمبتدئين" are typed. With
it, use the subtitle تفسير، تجويد، تلاوة، حفظ (24 characters), and in the keyword field replace اعراب with
قراءات.

**Alternate B:**

```
القرآن الكريم | مصحف، تفسير
```

**27 / 30 characters.**

Puts "القرآن الكريم", the most common Quran search, in the name, but drops تجويد. With it, replace الكريم
in the keyword field with تجويد.

## 2. Subtitle

**Recommended** (with the recommended name):

```
تلاوة، حفظ، القراءات العشر
```

**26 / 30 characters.**

Recitation (over 60 reciters), memorization (the Quran Planner, the Revision plan and Test Mode) and the Ten
Qiraat, the app's most distinctive feature.

**Alternate:**

```
تلاوة، حفظ، مراجعة، ختمة
```

**24 / 30 characters.**

All memorization. With it, replace مراجعة and ختمة in the keyword field with قراءات and العشر.

## 3. Keywords

Written for the recommended name and subtitle. No word repeats one of theirs (القرآن، مصحف، تفسير، تجويد،
تلاوة، حفظ، القراءات، العشر); as in Al-Islam's field, a word without ال or without its madda is a search
term of its own. If an alternate ships, re-check that and swap in the words it dropped.

```
القران,قران,الكريم,ابن,كثير,السعدي,سورة,جزء,ختمة,ورد,مراجعة,تحفيظ,ورش,قالون,اعراب,تعليم,اذكار,دعاء
```

**98 / 100 characters.**

Why these terms:
- **القران، قران، الكريم:** the name has القرآن with the madda; these add the spelling without it that
  most people type, the form without ال, and الكريم for "القرآن الكريم".
- **ابن، كثير، السعدي:** "تفسير ابن كثير" and "تفسير السعدي", two of the most searched tafsirs, both in the
  app (with the name's تفسير); Ibn Kathir is also one of the ten imams of the qiraat.
- **سورة، جزء:** "سورة الكهف", "جزء عم" and every search that starts with سورة or جزء.
- **ختمة، ورد، مراجعة، تحفيظ:** the Quran Planner (a khatm with a daily amount), the Revision plan, and
  "تحفيظ القرآن" (with Test Mode).
- **ورش، قالون:** "مصحف ورش" and "مصحف قالون", two of the twenty riwayat, the readings of North and West
  Africa.
- **اعراب:** Word Study's grammar, for "اعراب القرآن".
- **تعليم:** "تعليم القرآن" and "تعليم التجويد", with the Reading Test and the Tajweed Course.
- **اذكار، دعاء:** the Islam tab's adhkar and dua collections.

Left out for room, to rotate in from App Analytics: قرآن، المصحف، الطبري، حفص، حصن، مسلم (for "حصن المسلم")،
تسبيح، للمبتدئين، معاني، تدبر، رمضان. Deliberately excluded: prayer terms (مواقيت، أذان، قبلة), since
Al-Quran has no prayer times, and reciters' names until each one is checked against the app's reciter list.
If Apple's Arabic search turns out to fold the madda (آ to ا) or to ignore ال, القران and قران are
redundant and are the first to swap.

## 4. Promotional Text

Leads with the Arabic interface. Update it with the next release like the English one.

```
جديد: واجهة عربية كاملة من اليمين إلى اليسار، بأسماء عربية للسور، ومع Siri بالعربية لتشغيل أي سورة باسمها. القرآن والتفسير والتلاوة والحفظ في تطبيق مجاني بلا إعلانات.
```

**166 / 170 characters.**

## 5. Description

An Arabic rendering of `App Store Description.md`, section for section, with the English ALL-CAPS headers as
short Arabic headings on their own lines. Three differences from the English:
- **Ask AI:** the English says it answers "citing only the ayahs it shows", but it also cites tafsir,
  articles and duas, so the Arabic names all four.
- **Tajweed:** the 58-lesson course is named by its own tile, «دورة التجويد» (Tajweed Course), beside
  Tajweed Foundations.
- **Arabic interface:** a line on it opens على طريقتك, as in Al-Islam's listing.

```
تطبيق القرآن رفيقك في قراءة القرآن الكريم، سواء نشأت على الإسلام أو اعتنقته حديثًا أو بدأت تتعلّم الحروف العربية لأول مرة. القرآن كاملًا والتفسير وأكثر من ٦٠ قارئًا ومخطِّط للقراءة والحفظ والبحث بالذكاء الاصطناعي على جهازك، في تطبيق واحد بسيط: مجاني تمامًا، بلا إعلانات، ويحفظ خصوصيتك.

الحفظ والمراجعة
- مخطِّط القرآن: حدّد موعدًا لإتمام ختمتك، مع مقدار يومي يتعدّل من تلقاء نفسه إذا فاتك يوم.
- خطة «المراجعة» للسور التي تحفظها: نطاق من الأجزاء أو سور تختارها، تراجعها كل بضعة أيام.
- «وضع الاختبار» يُخفي النص حتى تضغط على الآية، فتتلو من حفظك وتتحقق من كل آية.
- سلسلة الأيام ورسم بياني أسبوعي وتذكيرات تُبقيك على وتيرتك.

القرآن الكريم كاملًا
- اقرأ حسب السورة أو الجزء أو الصفحة، في وضع القائمة أو وضع المصحف، مع صفحتين متجاورتين في الوضع الأفقي.
- النص العربي والكتابة اللاتينية والترجمة جنبًا إلى جنب، مع تجويد ملوّن بألوان تختارها.
- تفسير لكل آية: ابن كثير ومعارف القرآن وتذكير القرآن بالإنجليزية، وابن كثير والطبري والسعدي بالعربية، متاحة دون اتصال.
- دراسة الكلمة: اضغط على أي كلمة مرتين لمعناها وإعرابها وجذرها وكل مواضعها في القرآن.
- رواية حفص وتسع عشرة رواية أخرى من القراءات العشر، مع المقارنة بينها جنبًا إلى جنب في «مستكشف القراءات».
- اعثر على أي آية برقم السورة والآية (مثل ٥:٢٧)، أو بالصفحة أو الجزء أو الكلمة أو المعنى، من أي مكان تقرأ فيه.
- الآيات المتشابهة، والتصفّح حسب الموضوع، وكلمة اليوم، والعلامات، والملاحظات على أي آية.

الاستماع
- أكثر من ٦٠ قارئًا وتلاوات بروايات مختلفة، مع تشغيل السورة كاملة أو آية بآية، وتنزيلات للاستماع دون اتصال.
- «التشغيل من الآية» حتى آخر الصفحة أو السورة أو الجزء أو القرآن كله، أو «تكرار بلا توقف».
- تابع من حيث توقفت، مع آخر سورة وآية قرأتهما أو استمعت إليهما.

البحث بالذكاء الاصطناعي على جهازك
- ابحث في القرآن بالمعنى لا بالكلمة وحدها: عبارة «patience in hardship» تجد آيات الصبر. يعمل البحث بالمعنى بالعبارات الإنجليزية حاليًا.
- مع Apple Intelligence، يجيبك «اسأل الذكاء الاصطناعي» من الآيات والتفاسير والمقالات والأدعية التي يستشهد بها، ولا يُصدر فتوى أبدًا.

التذكير اليومي والتعلّم
- «اليوم»: آية اليوم وكلمة اليوم ودعاء اليوم واسم من أسماء الله الحسنى، مع بطاقة تذكير يومي و«تذكيرات السنة» ودفتر يوميات.
- تعلّم الحروف العربية مع «اختبار القراءة» في ٢١ مستوًى، والتجويد في «دورة التجويد» من ٥٨ درسًا.
- أذكار موثّقة وحصن المسلم ومجموعات أدعية بمصادرها وتسجيلاتها الصوتية، مع عدّاد للتسبيح.
- أسماء الله الحسنى بالتفصيل، ومعجزات القرآن، وإثبات الإسلام، والأدلة العملية، وأركان الإسلام والإيمان.

على طريقتك
- الواجهة بالعربية والإنجليزية، حسب اللغة التي تختارها للتطبيق في إعدادات iOS. أما المقالات المفصّلة في تبويب الإسلام فبالإنجليزية حاليًا.
- «الوضع المبسّط» يُبقي الأساسيات على الشاشة، وبإمكانك التبديل إلى الوضع الكامل متى شئت.
- أحجام النص، والخطوط العربية، وألوان التمييز، مع شريط بحث في كل صفحة إعدادات.
- أدوات لآية اليوم، ولأي آية تختارها، ولآخر آية قرأتها، ولآخر سورة استمعت إليها.
- على iPhone وiPad وMac وApple Watch، مع تلاوة السورة كاملة على معصمك.

مجاني، بلا إعلانات، ويحفظ خصوصيتك
تطبيق القرآن مجاني تمامًا. لا إعلانات، ولا حسابات، ولا اشتراكات، ولا تتبّع: لا يُجمَع شيء مما تفعله ولا يُشارَك.

سواء أردت أن تقرأ أو تستمع أو تحفظ أو تتعلّم الحروف العربية، حمّل تطبيق القرآن اليوم وابدأ رحلتك مع كلام الله.
```

**3,098 / 4,000 characters.**

## 6. What's New

Version 2.6.6, the release that adds the Arabic interface. The Arabic interface and the choice of
language come first, unchanged; the language section gains one line saying the app speaks Urdu too
(the English "Languages" line). Below them are the English notes at the top of `Whats New.md`
(Version 2.6.6), translated under the same headings, with Islamic Tools as تبويب الإسلام. Version 2.6.5 went live on 2026-10-15 with English notes only, so nothing from it is repeated here.

Translation notes:
- **The juz rail** is on "the edge" of the Quran tab, not "the right edge": the Arabic layout mirrors the
  screen, so the rail is on the left there.
- **Sunnahs of the Prophet:** the catalog's label ends in the one-glyph honorific; the store spells it out.

```
تطبيق القرآن كله الآن بالعربية، بواجهة من اليمين إلى اليسار في القراءة والاستماع وتبويب الإسلام والإعدادات.

الواجهة العربية:
- الشاشات والقوائم والإعدادات والإشعارات والأدوات كلها بالعربية، على iPhone وiPad وMac وApple Watch.
- تخطيط من اليمين إلى اليسار في كل مكان، وتبقى النصوص الإنجليزية، كالترجمات والتفاسير الإنجليزية، من اليسار إلى اليمين لتُقرأ بسهولة.
- أسماء السور والأجزاء بالعربية.
- يظهر اسم التطبيق بالعربية على الشاشة الرئيسية: «القرآن».
- تحدّث إلى Siri بالعربية: شغّل سورة أو افتحها باسمها العربي، وتابع التلاوة من حيث توقفت.
- تتبع الأرقام منطقة جهازك، فتظهر هكذا ١٢٣ أو هكذا 123 حسب إعدادات المنطقة في iOS.
- تقبل حقول البحث الأرقام العربية، مثل ٢:٢٥٥.

اختيار اللغة:
- يتبع التطبيق اللغة التي تختارها له في إعدادات iOS، ويوصلك إليها صف «اللغة» في إعدادات التطبيق.
- التطبيق متاح بالأردية أيضًا.
- عند تغيير اللغة تُعاد جدولة إشعاراتك باللغة الجديدة.
- تبقى المقالات المفصّلة في تبويب الإسلام بالإنجليزية حاليًا.

القرآن:
- همزة الوصل كما تريد: «كما في المطبوع»، أو بصاد، أو بنقطة، في الروايات العشرين كلها.
- شريط للأجزاء على حافة تبويب القرآن، وأشرطة مرقمة في القوائم الطويلة.
- نافذة «تشغيل النطاق» بتصميم جديد: آيات أو صفحات، وتكرار بعدد أو بلا توقف، والقارئ، كلها في مكان واحد.
- اضغط على الآية مرتين لتشغيلها، وزر التشغيل يفتح قائمة التشغيل.
- صفحة كل رواية تذكر الآن ما يميزها.
- تقليب أنعم للصفحات في وضع المصحف، وشريط بحث في سطر واحد.
- إصلاح ألوان التجويد داخل الحروف المتشابكة وعلى الراء في آخر الكلمة.

تبويب الإسلام:
- «سنن النبي صلى الله عليه وسلم»: ١٢٩ سنة يومية مع مصادرها.
- «الأبجدية العربية»: همزة الوصل، وحروف العلة، والألف المقصورة والياء، وقسم «الإعراب»، ولكل منها تدريبات.
- «اختبار التجويد»: أسئلة متدرجة في ١٠ فصول، مأخوذة من دورة التجويد.
- أدلة جديدة للخطبة والرقية، ودليل أوفى لصلاة الجمعة.
- طي أقسام أي تبويب أو إخفاؤها، وشريط بحث في كل مصدر.

الإعدادات:
- صفحات الإعدادات كلها بأسلوب واحد، مع شرح تحت كل خيار.
- «إعدادات الإسلام»، ومعها «تذكيرات السنة».
- تنبيه «يتوفر تحديث» عند صدور إصدار أحدث في App Store.

إصلاحات وتحسينات:
- شاشات إعدادات أسرع، وقوائم بلا تأخير، وإصلاحات على iPhone وiPad وMac وApple Watch.
```

**2,063 / 4,000 characters.**

## Glossary

The Arabic the app shows for the features the listing names (Al-Islam's `Resources/Localizable.xcstrings`,
synced to Al-Quran). The one marked * has no label of its own in the catalog: it is the word Apple's Arabic
pages use.

| English | Arabic |
|---|---|
| Al-Quran (the app and its tab), the Islam tab, Settings | القرآن (تطبيق القرآن in a sentence)، تبويب الإسلام، الإعدادات |
| Simple Mode / Full | الوضع المبسّط / كامل |
| Quran Planner, Revision | مخطِّط القرآن، المراجعة |
| Test Mode | وضع الاختبار |
| Streak | سلسلة الأيام |
| List mode, page mode | وضع القائمة، وضع المصحف |
| Transliteration | الكتابة اللاتينية |
| Word Study | دراسة الكلمة |
| Qiraat Explorer, the Ten Qiraat, riwayah | مستكشف القراءات، القراءات العشر، الرواية |
| Reciters | القرّاء |
| Repeat Forever, Play From Ayah | تكرار بلا توقف، التشغيل من الآية |
| Similar Ayahs, Browse by Theme, Word of the Day | الآيات المتشابهة، تصفّح حسب الموضوع، كلمة اليوم |
| Bookmarks, Notes | العلامات، الملاحظات |
| Ask AI, Search by meaning | اسأل الذكاء الاصطناعي، البحث بالمعنى |
| Ayah of the Day, Chosen Ayah, Last Listened (widgets) | آية اليوم، الآية المختارة، آخر استماع |
| Last Read Ayah | آخر آية قرأتها |
| Today, Sunnah Reminders, Daily Reminder | اليوم، تذكيرات السنة، تذكير يومي |
| Journal, Tasbih, Hisn al-Muslim | اليوميات، التسبيح، حصن المسلم |
| 99 Names of Allah | أسماء الله الحسنى |
| Reading Test | اختبار القراءة |
| Tajweed Course, Tajweed Foundations | دورة التجويد، أساسيات التجويد |
| How-To Guides | الأدلة العملية |
| Proving Islam, Miracles of the Quran | إثبات الإسلام، معجزات القرآن |
| Miracles of the Prophets, Prophecies of the Prophet | معجزات الأنبياء، نبوءات النبي صلى الله عليه وسلم |
| Tips & Tricks, Language (Settings row) | نصائح وحيل، اللغة |
| Accent Color, Lock Screen | لون التمييز، شاشة القفل |
| widgets* | الأدوات |
| Play Range, Riwayah | تشغيل النطاق، الرواية |
| Hamzat al-Wasl: Follow the Print, Saad, Dot | همزة الوصل: كما في المطبوع، الصاد، النقطة |
| Sunnahs of the Prophet (the honorific spelled out) | سنن النبي صلى الله عليه وسلم |
| Arabic Alphabet, Vowel Letters, Grammar, Tajweed Test | الأبجدية العربية، حروف العلة، الإعراب، اختبار التجويد |
| Islam Settings, Sunnah Reminders, Update Available | إعدادات الإسلام، تذكيرات السنة، يتوفر تحديث |
