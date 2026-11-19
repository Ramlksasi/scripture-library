# Scripture Library first release

## Reader and discovery

The Flutter app opens to a categorized library with title and alternate-spelling search. The launch catalog covers Sanskrit works. An in-app passage contains Romanized Sanskrit followed by one English translation. Readers can swipe between passages and chapters, open the chapter picker, change the text size, and resume on the same device. External editions open on the source website.

The supplied catalog contributes 688 candidate records, 19 categories, and 66 category and subcategory pairs. It contains 44 foundation candidates, 347 expansion candidates, 235 specialized candidates, and 62 research candidates. The public catalog has 12 titles across six categories, with one full in-app edition and 11 external reading links. The editorial register retains every candidate and its stable ID, including the regional-language backlog. The app uses each candidate's original category and subcategory.

## Bhagavad Gītā edition

The app ships all 18 chapters of Annie Besant's English translation in the 1922 fourth edition, using the Sanskrit printed alongside it. This edition numbers Arjuna's opening verse in Chapter 13 as 13.1 and has **701 numbered verses**. The Sanskrit was transliterated to IAST for the app. The English preserves the historical rendering, including the speaker headings. Notes and page furniture are omitted from both text layers. [Wikisource edition and public-domain statement](https://en.wikisource.org/wiki/Bhagavad-Gita_(Besant_4th))

The importer checks the Sanskrit sequence and the English labels against the edition's chapter counts. It accounts for two blank and two repeated English labels in the Wikisource transcription by matching the facing Sanskrit order. Verse 1.21 and verse 1.28 retain the English opening sentence that appears in a separate paragraph. The repository credits the source and its contributors. [Discourse 1](https://en.wikisource.org/wiki/Bhagavad-Gita_(Besant_4th)/Discourse_1) · [Discourse 10](https://en.wikisource.org/wiki/Bhagavad-Gita_(Besant_4th)/Discourse_10) · [Discourse 11](https://en.wikisource.org/wiki/Bhagavad-Gita_(Besant_4th)/Discourse_11) · [Discourse 13](https://en.wikisource.org/wiki/Bhagavad-Gita_(Besant_4th)/Discourse_13) · [Discourse 17](https://en.wikisource.org/wiki/Bhagavad-Gita_(Besant_4th)/Discourse_17) · [Discourse 18](https://en.wikisource.org/wiki/Bhagavad-Gita_(Besant_4th)/Discourse_18)

Each linked title has a direct reading entry. The external site's presentation and available translations vary by work. When migrating one inward, verify reuse separately for the Sanskrit edition or transliteration and the English translation. Record the credited edition, redistribution terms and stable verse or sutra references before publishing. [Heritage Scripture Server terms](https://heritage.iitk.ac.in/license) · [Rig Veda](https://sacred-texts.com/book/the-rig-veda) · [Bhāgavata Purāṇa](https://vedabase.io/en/library/sb/)

## Firestore and content migration

Each book has one catalog document keyed by its workbook ID. It can point to a source website or an active hosted edition. Each hosted edition stores ordered chapter or section documents. Each section contains paired passages with a stable reference. This permits loading one section at a time and splitting large chapters within Firestore's 1 MiB document limit. [Firestore limits](https://firebase.google.com/docs/firestore/quotas)

The publisher writes a complete edition before changing the book document to point to it. The reader uses the bundled version directly when its edition ID matches and fetches other hosted editions from Firestore. Security rules allow public reads of published books and their active editions. Administrative credentials control writes. A reading position from the starter edition follows the book and verse when that reference exists in the full edition.

Search indexes the published catalog in Flutter by title, aliases, and category. This keeps discovery local and accepts diacritic-free input. A future edition can use the same two-layer reader for a regional original in Roman script and an English translation.

## Release checks

The app can open the bundled library and read the entire Gītā offline. The Flutter test suite covers alternate spellings, external source actions, saved positions, and swiping across chapter boundaries. The mobile workflow builds an Android test APK and an iOS simulator app. A production Firestore project and signing credentials are required for a connected store release. [Setup instructions](../README.md)
