# App Store Urdu Listing

The **Urdu** localization of the App Store listing for **Al-Quran | Beginner Quran**. In App Store Connect
(Urdu listings since 2026-03-31), add the Urdu localization, then fill Name and Subtitle under App Information
and the other four fields on the version page. Screenshots can stay English: App Store Connect shows the
primary language's screenshots for a localization that has none of its own.
People whose device is set to Urdu see this listing instead of the English one. In the Urdu interface the app
calls itself القرآن (its home-screen name and the title of its Quran screen), and the Islam and Settings tabs
are اسلام and ترتیبات; the listing uses the same words.
Modeled on this folder's `Arabic Listing.md`, whose structure and honesty rules this file follows, and on
Al-Islam's `Docs/App Store/Urdu Listing.md`, whose Urdu style it follows.

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
  `python3 -c 'import re;f=chr(96)*3;t=open("Docs/App Store/Urdu Listing.md").read();[print(len(b)) for b in re.findall(f+"\n(.*?)\n"+f,t,re.S)]'`
- **Standard Urdu as Apple's own Urdu pages read it**, with the respectful register (نبی کریم صلی اللہ علیہ وسلم، قرآن مجید). The honorific is always spelled out: App Store Connect rejects the one-glyph ligature (U+FDFA) as an invalid character.
  Feature names are the labels the app shows (Al-Islam's `Resources/Localizable.xcstrings`, which Al-Quran
  receives in its sync; see the glossary below).
- **Inside a sentence the app is «القرآن ایپ»**, the name first, with feminine verbs (القرآن ایپ ... کرتی
  ہے). A bare قرآن in running text is the Quran itself, which the listing calls قرآن مجید; القرآن alone names
  the app only as the name, as the screen title, or inside a quoted label.
- **No em dash, and no spaced hyphen used as a dash.** Use a colon, the comma ، or a new sentence. A leading
  "- " bullet is fine; the English fields use the same.
- **Urdu punctuation** (۔ ، ؟) and Western digits (60، 5:27), as Urdu in Pakistan writes them. No version
  numbers.
- **Urdu letters, never their Arabic look-alikes:** ی ک ہ ھ ۃ, not ي ك ه ة.
- **Characters App Store Connect refuses.** On 2026-10-29 it rejected Al-Islam's Urdu What's New and
  Description ("This field contains one or more invalid characters"), and neither held a hidden character.
  Store text therefore leaves out the Urdu digits ۰-۹, the izafat zer (ختم قرآن، قراءات عشرہ), the superscript alef
  and ۃ (فتوے، زکات), and « » (a label goes in plain "quotes"). Which of the description's four it
  objects to is not pinned down, so all four stay out of every field in all three apps' Urdu listings.
  Notes outside the code blocks and the glossary may keep the app's own spellings.
- **Brand names stay Latin:** Apple, Siri, Apple Watch, Apple Intelligence, iPhone, iPad, Mac, iOS; so does
  OC Ummah (the app's Urdu wallpaper label spells it «او سی امہ»; the store keeps the Latin brand, as the
  Arabic listing does).
- **No zabar, zer or shadda in the name, subtitle or keywords:** nobody types them in a search. The
  description and What's New leave out the izafat zer too, even where the app's own label has it
  (ختم قرآن، قراءات عشرہ، اثبات اسلام): see the rule above.
- **Only what the English listing claims.** Every feature named here is in the Arabic listing, which is
  checked against Al-Quran's English `App Store Description.md` and `Whats New.md`. Al-Quran has no prayer
  times and no Hadith tab: no prayer or hadith features and no prayer search terms. CarPlay is left out
  because the English listing does not mention it; add it to all three languages together.
- **Be honest about what is still English:** the in-depth articles of the Islam tab (Proving Islam, the
  How-To Guides, the pillars and the miracles libraries among them); AI search by meaning, which matches
  English phrases only; and the Quran translations (The Clear Quran and Saheeh International), so the
  description says انگریزی ترجمہ, where an Urdu reader would otherwise expect an Urdu one.
- **Siri has no Urdu.** Siri cannot be set to Urdu, so on an Urdu phone it runs in English or Arabic. The
  listing never says Siri speaks Urdu; where the Arabic listing says to ask Siri in Arabic, this one says to
  ask in English or Arabic.
- **No scripture quoted.** No Quranic text and no hadith presented as the Prophet's words.
- Keep in sync with the English docs (`App Store Description.md`, `Keywords.md`, `Promotional Text.md`,
  `Whats New.md`) and with `Arabic Listing.md`: when a field changes for a feature, change it here too.

## 1. Name

Names are unique across the store, so a bare القرآن will not be accepted. Each option keeps القرآن first,
then a short descriptor after a separator, as the English name does with "|".

**Recommended:**

```
القرآن | تلاوت، تفسیر، تجوید
```

**28 / 30 characters.**

Three bare search words, the same shape as the Arabic name: recitation (over 60 reciters), tafsir and
tajweed. The Arabic name's مصحف becomes تلاوت: تلاوت is the everyday Urdu word ("قرآن کی تلاوت"), مصحف a
bookish one, and page mode is still named in the description (مصحف موڈ).

**Alternate A:**

```
القرآن | قرآن سیکھیں، تجوید
```

**27 / 30 characters.**

Closest to the English name: Urdu says "قرآن سیکھیں" (learn the Quran) where English says "Beginner", and the
bare قرآن joins the name. With it, use the subtitle تلاوت، تفسیر، حفظ، قراءات (25 characters), and in the
keyword field replace تعلیم, which سیکھیں now covers, with عشرہ.

**Alternate B:**

```
القرآن | قرآن مجید، تفسیر
```

**25 / 30 characters.**

Puts "قرآن مجید", the name this listing gives the Quran and the most common formal Urdu one, in the name, but
drops تلاوت and تجوید. With it, use the subtitle تلاوت، تجوید، حفظ، قراءات (25 characters), and in the keyword
field replace مجید with دہرائی (97 characters).

## 2. Subtitle

**Recommended** (with the recommended name):

```
حفظ قرآن، دہرائی، قراءات عشرہ
```

**29 / 30 characters.**

Memorization (the Quran Planner, the Revision plan and Test Mode) and the Ten Qiraat, the app's most
distinctive feature. "حفظ قرآن" is how Urdu says it, and its bare قرآن matters: the name has only القرآن,
with ال, so this word is what the keyword field's مجید، پاک، شریف complete into قرآن مجید، قرآن پاک، قرآن
شریف. The Arabic subtitle's تلاوة is in the name here.

**Alternate:**

```
قرآن مجید، حفظ، قراءات عشرہ
```

**27 / 30 characters.**

The phrase "قرآن مجید" whole, at the cost of دہرائی. With it, replace مجید in the keyword field with دہرائی
(97 characters).

## 3. Keywords

Written for the recommended name and subtitle. No word repeats one of theirs (القرآن، تلاوت، تفسیر، تجوید،
حفظ، قرآن، دہرائی، قراءات، عشرہ); as in the Arabic field, a word without its madda is a search term of its
own. If an alternate ships, re-check that and swap in the words it dropped.

```
قران,مجید,پاک,شریف,پارہ,سورت,سورہ,قاری,حافظ,ختم,ترجمہ,ابن,کثیر,ناظرہ,تعلیم,عربی,اذکار,دعا,تسبیح
```

**95 / 100 characters.**

Why these terms:
- **قران، مجید، پاک، شریف:** the spelling without the madda that many people type, and the three words Urdu
  adds to the Quran's name (قرآن مجید، قرآن پاک، قرآن شریف); with the subtitle's قرآن they cover all three
  phrases.
- **پارہ، سورت، سورہ:** a juz and a surah the ways Urdu writes them: سورت alone, and سورہ before a name
  ("سورہ یاسین"). سورۃ is out: App Store Connect may refuse ۃ (see the Guidelines).
- **قاری، حافظ، ختم:** a reciter (over 60 in the app), a hafiz (memorization and its Revision plan), and
  "ختم قرآن" with the Quran Planner.
- **ترجمہ:** "قرآن ترجمہ" and "ترجمے کے ساتھ". The translations are English, and the description says so
  (انگریزی ترجمہ); if App Analytics shows these searchers leave, it is the first word to swap.
- **ابن، کثیر:** "تفسیر ابن کثیر", with the name's تفسیر; the app has it in English and in Arabic.
- **ناظرہ، تعلیم، عربی:** "ناظرہ قرآن" (reading the Quran from the page), "قرآن کی تعلیم" and "عربی حروف",
  with the Reading Test and the Urdu Tajweed Course.
- **اذکار، دعا، تسبیح:** the Islam tab's adhkar and dua collections and its tasbih counter.

Left out for room, to rotate in from App Analytics: مصحف، رمضان، سیکھیں، قرآنی، and surah names
(یاسین، رحمن، ملک، کہف). Deliberately excluded: prayer terms (نماز، اوقات، اذان، قبلہ), since Al-Quran has no
prayer times; اردو (for "اردو ترجمہ"), since the app has no Urdu translation of the Quran; معارف (for "معارف
القرآن"), since the app has that tafsir in English only and an Urdu search for it wants the Urdu original;
and reciters' names until each one is checked against the app's reciter list. If Apple's Urdu search turns
out to fold the madda (آ to ا), قران is redundant: it is the first to swap.

## 4. Promotional Text

Leads with the Urdu interface. Where the Arabic one names Siri in Arabic, this one names the Urdu tajweed
course, since Siri has no Urdu. Update it with the next release like the English one.

```
نیا: مکمل اردو انٹرفیس، دائیں سے بائیں، سورتوں کے عربی ناموں اور 58 اسباق کے اردو تجوید کورس کے ساتھ۔ قرآن مجید، تفسیر، تلاوت اور حفظ ایک مفت ایپ میں، بغیر اشتہارات کے۔
```

**168 / 170 characters.**

## 5. Description

An Urdu rendering of `App Store Description.md`, section for section, with the English ALL-CAPS headers as
short Urdu headings on their own lines. It keeps the Arabic listing's three differences from the English
(Ask AI names all four kinds of source it cites; the 58-lesson course is named by its own tile, «تجوید کورس»;
a line on the interface opens آپ کے انداز میں), and adds two of its own:
- **Translation:** the Arabic says الترجمة; the Urdu says انگریزی ترجمہ, because the app's Quran translations
  are English.
- **Tajweed Course:** called اردو, since its 58 lessons are in Urdu (Tilawa's).

```
القرآن ایپ قرآن مجید پڑھنے میں آپ کی ساتھی ہے، چاہے آپ پیدائشی مسلمان ہوں، حال ہی میں اسلام قبول کیا ہو، یا پہلی بار عربی حروف سیکھ رہے ہوں۔ مکمل قرآن مجید، تفسیر، 60 سے زیادہ قراء، پڑھنے اور حفظ کے لیے پلانر، اور آپ کی ڈیوائس پر اے آئی سے تلاش، سب ایک سادہ ایپ میں: مکمل طور پر مفت، بغیر اشتہارات کے، اور آپ کی رازداری کے ساتھ۔

حفظ اور دہرائی
- قرآن پلانر: ختم قرآن کی تاریخ مقرر کریں، ایسی روزانہ مقدار کے ساتھ جو کوئی دن چھوٹ جائے تو خود بخود بدل جاتی ہے۔
- حفظ کی ہوئی سورتوں کے لیے "دہرائی" کا منصوبہ: پاروں کی ایک حد یا آپ کی چنی ہوئی سورتیں، جنہیں آپ ہر چند دن بعد دہراتے ہیں۔
- "ٹیسٹ موڈ" متن کو تب تک چھپائے رکھتا ہے جب تک آپ آیت پر ٹیپ نہ کریں، تاکہ آپ زبانی پڑھ کر ہر آیت جانچ سکیں۔
- مسلسل دن، ہفتہ وار چارٹ اور یاد دہانیاں آپ کو اپنی رفتار پر قائم رکھتی ہیں۔

مکمل قرآن مجید
- سورت، پارے یا صفحے کے حساب سے پڑھیں، فہرست موڈ یا مصحف موڈ میں، اور افقی رخ میں آمنے سامنے دو صفحات کے ساتھ۔
- عربی متن، رومن تلفظ اور انگریزی ترجمہ ساتھ ساتھ، اور آپ کے پسندیدہ رنگوں میں رنگین تجوید۔
- ہر آیت کی تفسیر: انگریزی میں ابن کثیر، معارف القرآن اور تذکیر القرآن، اور عربی میں ابن کثیر، طبری اور سعدی، آف لائن دستیاب۔
- "لفظ کا مطالعہ": کسی بھی لفظ پر دو بار ٹیپ کر کے اس کا معنی، نحو، مادہ اور قرآن میں اس کے تمام مقامات دیکھیں۔
- روایت حفص اور قراءات عشرہ کی انیس دیگر روایات، "قراءات ایکسپلورر" میں ساتھ ساتھ موازنے کے ساتھ۔
- کوئی بھی آیت سورت اور آیت کے نمبر (جیسے 5:27)، صفحے، پارے، لفظ یا معنی سے ڈھونڈیں، جہاں بھی آپ پڑھ رہے ہوں۔
- ملتی جلتی آیات، "موضوع کے لحاظ سے دیکھیں"، آج کا لفظ، بک مارکس، اور کسی بھی آیت پر نوٹس۔

تلاوت سنیں
- 60 سے زیادہ قراء اور مختلف روایات میں تلاوتیں: "سورت چلائیں" یا "آیت بہ آیت چلائیں"، اور آف لائن سننے کے لیے ڈاؤن لوڈز۔
- "آیت سے چلائیں" صفحے، سورت، پارے یا پورے قرآن کے آخر تک، یا "لامحدود تکرار"۔
- وہیں سے جاری رکھیں جہاں چھوڑا تھا، آخری پڑھی یا سنی گئی سورت اور آیت کے ساتھ۔

آپ کی ڈیوائس پر اے آئی سے تلاش
- قرآن میں الفاظ کے بجائے معنی کے لحاظ سے تلاش کریں: "patience in hardship" صبر کی آیات ڈھونڈ لیتا ہے۔ معنی سے تلاش فی الحال انگریزی جملوں سے ہوتی ہے۔
- Apple Intelligence کے ساتھ، "اے آئی سے پوچھیں" انہی آیات، تفاسیر، مضامین اور دعاؤں سے جواب دیتا ہے جن کا وہ حوالہ دیتا ہے، اور کبھی فتوے نہیں دیتا۔

روزانہ کی یاد دہانی اور سیکھنا
- "آج": آج کی آیت، آج کا لفظ، آج کی دعا اور اللہ کے ناموں میں سے ایک نام، روزانہ یاد دہانی کے کارڈ، "سنت کی یاد دہانیاں" اور ڈائری کے ساتھ۔
- 21 درجوں کے "ریڈنگ ٹیسٹ" کے ساتھ عربی حروف سیکھیں، اور 58 اسباق کے اردو "تجوید کورس" میں تجوید۔
- مستند اذکار، حصن المسلم اور دعاؤں کے مجموعے حوالوں اور آڈیو کے ساتھ، اور تسبیح کاؤنٹر۔
- اللہ کے ننانوے نام تفصیل سے، قرآن کے معجزات، اثبات اسلام، عملی رہنمائی، اور پانچ ارکان اسلام اور چھ ارکان ایمان۔

آپ کے انداز میں
- انٹرفیس اردو، عربی اور انگریزی میں، اس زبان کے مطابق جو آپ iOS کی سیٹنگز میں ایپ کے لیے منتخب کریں۔ اسلام ٹیب کے تفصیلی مضامین فی الحال انگریزی میں ہیں۔
- "سادہ موڈ" صرف بنیادی چیزیں سامنے رکھتا ہے، اور آپ جب چاہیں مکمل موڈ پر جا سکتے ہیں۔
- متن کا سائز، عربی فونٹس اور نمایاں رنگ، اور ترتیبات کے ہر صفحے پر تلاش۔
- آج کی آیت، منتخب آیت، آخری پڑھی گئی آیت اور "آخری بار سنا" کے ویجیٹس۔
- iPhone، iPad، Mac اور Apple Watch پر، اور کلائی پر پوری سورت کی تلاوت۔

مفت، بغیر اشتہارات، آپ کی رازداری محفوظ
القرآن ایپ مکمل طور پر مفت ہے۔ نہ اشتہارات، نہ اکاؤنٹس، نہ سبسکرپشن، نہ ٹریکنگ: آپ کی کوئی سرگرمی جمع یا شیئر نہیں کی جاتی۔

چاہے آپ پڑھنا، سننا، حفظ کرنا یا عربی حروف سیکھنا چاہیں، آج ہی القرآن ایپ ڈاؤن لوڈ کریں اور اللہ کے کلام کے ساتھ اپنا سفر شروع کریں۔
```

**3,405 / 4,000 characters.**

## 6. What's New

Version 2.6.6, the release that adds the Urdu interface. The Urdu interface comes first: Al-Islam's Urdu sections اردو
انٹرفیس and زبان کا انتخاب, adapted to Al-Quran. Al-Islam's hadith-book names and prayer-notification lines
are gone (Al-Quran has neither); the Arabic listing's home-screen name and search-digit lines are added; and
Siri, which the Arabic listing puts in the interface section, stays in زبان کا انتخاب with English or Arabic,
as Al-Islam's Urdu has it. The language section gains one line saying the app speaks Arabic too (the English "Languages"
line). Below them are the English notes at the top of `Whats New.md` (Version 2.6.6), translated
under the Arabic listing's headings. Version 2.6.5 went live on 2026-10-15 with English notes only, so nothing from it is repeated here.

Translation notes:
- **The juz rail** is on "the edge" of the Quran tab, not "the right edge": the Urdu layout mirrors the
  screen, so the rail is on the left there.
- **Catalog labels with izafat zer or ۂ** (عربی حروفِ تہجی، حروفِ علت، ہمزۂ وصل) appear without them,
  per the character rule in the Guidelines; the honorific is spelled out.

```
القرآن ایپ اب پوری کی پوری اردو میں ہے، قرآن پڑھنے اور سننے، اسلام ٹیب اور ترتیبات میں دائیں سے بائیں انٹرفیس کے ساتھ۔

اردو انٹرفیس:
- تمام اسکرینیں، مینیو، ترتیبات، اطلاعات اور ویجیٹس اردو میں، iPhone، iPad، Mac اور Apple Watch پر۔
- ہر جگہ دائیں سے بائیں ترتیب، جبکہ انگریزی متن، جیسے تراجم اور انگریزی تفاسیر، آسانی سے پڑھنے کے لیے بائیں سے دائیں رہتا ہے۔
- سورتوں اور پاروں کے نام عربی میں۔
- ہوم اسکرین پر ایپ کا نام اردو میں: "القرآن"۔
- تجوید کا 58 اسباق کا پورا کورس اردو میں۔
- ہندسے iOS کی ترتیبات کے مطابق: عام طور پر 0-9، اور اگر آپ نے اردو ہندسے چنے ہیں تو اردو ہندسے۔
- تلاش کے خانے عربی اور اردو ہندسے بھی قبول کرتے ہیں۔

زبان کا انتخاب:
- القرآن ایپ اس زبان کی پیروی کرتی ہے جو آپ iOS کی سیٹنگز میں اس کے لیے منتخب کریں، اور ایپ کی ترتیبات میں "زبان" کی قطار آپ کو وہاں لے جاتی ہے۔
- القرآن ایپ عربی میں بھی دستیاب ہے۔
- زبان بدلنے پر آپ کی اطلاعات نئی زبان میں دوبارہ ترتیب پاتی ہیں۔
- Siri اردو نہیں بولتا، اس لیے Siri سے انگریزی یا عربی میں بات کریں: کوئی سورت اس کے نام سے چلائیں یا کھولیں، اور تلاوت وہیں سے جاری رکھیں جہاں چھوڑی تھی۔
- اسلام ٹیب کے تفصیلی مضامین فی الحال انگریزی میں ہیں۔

قرآن:
- ہمزہ وصل جیسے آپ چاہیں: "مطبوعہ نسخے کے مطابق"، یا صاد یا نقطے کے ساتھ، تمام 20 روایات میں۔
- قرآن ٹیب کے کنارے پر پاروں کی پٹی، اور لمبی فہرستوں میں نمبروں والی پٹیاں۔
- "حصہ چلائیں" کی شیٹ نئے سرے سے: آیات یا صفحات، گنتی کی تکرار یا لامحدود، اور آپ کا قاری، سب ایک جگہ۔
- کسی آیت پر دو بار ٹیپ کر کے اسے چلائیں، اور چلانے کا بٹن پلے بیک مینیو کھولتا ہے۔
- ہر روایت کا صفحہ اب بتاتا ہے کہ اس میں کیا نمایاں ہے۔
- مصحف موڈ میں زیادہ ہموار صفحہ پلٹنا، اور ایک سطر کی تلاش کی پٹی۔
- جڑے ہوئے حروف کے اندر اور آخری راء پر تجوید کے رنگ درست کر دیے گئے۔

اسلام ٹیب:
- "نبی کریم صلی اللہ علیہ وسلم کی سنتیں": روزانہ کی 129 سنتیں، ان کے حوالوں کے ساتھ۔
- "عربی حروف تہجی": ہمزہ وصل، حروف علت، الف مقصورہ اور یاء کا فرق، اور "نحو" کا حصہ، ہر ایک مشقوں کے ساتھ۔
- "تجوید ٹیسٹ": کورس سے بنے سوالات، 10 ابواب میں درجہ بہ درجہ۔
- خطبے اور رقیہ کی نئی رہنمائی، اور جمعہ کی مزید مکمل رہنمائی۔
- کسی بھی ٹیب کے حصے سمیٹیں یا چھپائیں، اور ہر وسیلے میں تلاش کی پٹی۔

ترتیبات:
- ترتیبات کا ہر صفحہ ایک ہی انداز میں، ہر کنٹرول کے نیچے وضاحت کے ساتھ۔
- "اسلام کی ترتیبات"، "سنت کی یاد دہانیوں" کے ساتھ۔
- App Store پر نئی اپ ڈیٹ آنے پر "اپ ڈیٹ دستیاب ہے" کی اطلاع۔

اصلاحات اور بہتریاں:
- ترتیبات کی تیز تر اسکرینیں، بغیر اٹکے چلنے والے مینیو، اور iPhone، iPad، Mac اور Apple Watch پر اصلاحات۔
```

**2,394 / 4,000 characters.**

## Glossary

The Urdu the app shows for the features the listing names (Al-Islam's `Resources/Localizable.xcstrings`,
synced to Al-Quran). Two labels differ from Al-Islam's Urdu listing, which writes عملی رہنما and معنی کے لحاظ
سے تلاش: the app's labels are عملی رہنمائی and معنی کے لحاظ سے تلاش کریں, and this listing uses them. The one
marked * is not a label of its own: اسلام is the tab's label, and ٹیب is the word Al-Islam's Urdu listing uses.

| English | Urdu |
|---|---|
| Al-Quran (the app and its Quran screen), the Islam tab*, Settings | القرآن («القرآن ایپ» in a sentence)، اسلام ٹیب، ترتیبات |
| Simple Mode / Full | سادہ موڈ / مکمل |
| Quran Planner, Revision, Khatm | قرآن پلانر، دہرائی، ختمِ قرآن |
| Test Mode | ٹیسٹ موڈ |
| Streak | مسلسل دن |
| List mode, page mode | فہرست موڈ، مصحف موڈ |
| Transliteration | رومن تلفظ |
| Word Study (Meaning, Grammar, Root, Themes) | لفظ کا مطالعہ (معنی، نحو، مادہ، موضوعات) |
| Qiraat Explorer, the Ten Qiraat, riwayah, Hafs | قراءات ایکسپلورر، قراءاتِ عشرہ، روایت، حفص |
| All Riwayat, Compare Two (Qiraat Explorer) | تمام روایات، دو کا موازنہ |
| Reciters, Reciter | قراء، قاری |
| Play Surah, Play Ayah by Ayah | سورت چلائیں، آیت بہ آیت چلائیں |
| Repeat Forever, Play From Ayah | لامحدود تکرار، آیت سے چلائیں |
| Similar Ayahs, Browse by Theme, Word of the Day | ملتی جلتی آیات، موضوع کے لحاظ سے دیکھیں، آج کا لفظ |
| Bookmarks, Notes, Pin | بک مارکس، نوٹس، پن کریں |
| Ask AI, Search by meaning, Summarize | اے آئی سے پوچھیں، معنی کے لحاظ سے تلاش کریں، خلاصہ کریں |
| Ayah of the Day, Dua of the day | آج کی آیت، آج کی دعا |
| Chosen Ayah, Last Listened (widgets) | منتخب آیت، آخری بار سنا |
| Last Read Ayah | آخری پڑھی گئی آیت |
| Today, Sunnah Reminders, Daily Reminder | آج، سنت کی یاد دہانیاں، روزانہ یاد دہانی |
| Journal, Tasbih Counter, Hisn al-Muslim | ڈائری، تسبیح کاؤنٹر، حصن المسلم |
| 99 Names of Allah | اللہ کے ننانوے نام |
| Reading Test | ریڈنگ ٹیسٹ |
| Tajweed Course, Tajweed Foundations | تجوید کورس، تجوید کی بنیادیں |
| Heavy and Light, Rule (tajweed) | تفخیم اور ترقیق، حکم |
| How-To Guides | عملی رہنمائی |
| Proving Islam, Miracles of the Quran | اثباتِ اسلام، قرآن کے معجزات |
| Miracles of the Prophets, Prophecies of the Prophet | انبیاء کے معجزات، نبی کریم صلی اللہ علیہ وسلم کی پیش گوئیاں |
| The Five Pillars and Six Beliefs | پانچ ارکانِ اسلام اور چھ ارکانِ ایمان |
| Tips & Tricks, Language (Settings row) | تجاویز اور ترکیبیں، زبان |
| Text Size, Arabic Font, Accent Color | متن کا سائز، عربی فونٹ، نمایاں رنگ |
| Lock Screen, Widgets, Wallpapers | لاک اسکرین، ویجیٹس، وال پیپرز |
| Notifications, Reminder | اطلاعات، یاد دہانی |
| Play Range, Riwayah | حصہ چلائیں، روایت |
| Hamzat al-Wasl: Follow the Print, Saad, Dot (store spelling, no ۂ) | ہمزہ وصل: مطبوعہ نسخے کے مطابق، صاد، نقطہ |
| Sunnahs of the Prophet (the honorific spelled out) | نبی کریم صلی اللہ علیہ وسلم کی سنتیں |
| Arabic Alphabet, Vowel Letters, Grammar, Tajweed Test (store spelling, no zer) | عربی حروف تہجی، حروف علت، نحو، تجوید ٹیسٹ |
| Islam Settings, Sunnah Reminders, Update Available | اسلام کی ترتیبات، سنت کی یاد دہانیاں، اپ ڈیٹ دستیاب ہے |
