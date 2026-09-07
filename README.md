# Selah — Holy Bible (Flutter)

**Selah v2.0** is an advanced, *fully offline* Bible app for Flutter, built
around the complete Scripture dataset already shipped in this repository
(`lib/Holy_Bible-main/bible`). No network, no API keys, no scraping — the whole
Bible lives inside the app bundle.

## Download the APK

Every commit triggers the **Build APK** GitHub Actions workflow
(`.github/workflows/build.yml`): it runs `flutter analyze` + the full test
suite, then builds and uploads:

- `selah-apk` — **universal APK** (`selah-universal-release.apk`) plus per-ABI
  builds (`arm64-v8a`, `armeabi-v7a`, `x86_64`)
- `selah-appbundle` — Android App Bundle for Play Store deployment

Grab them from the Actions run page
(**Actions → Build APK → latest run → Artifacts**), or from the
`arena/artifacts-bin` branch (`artifacts/selah-2.0.0.apk`) for the universal
build.

## What's inside

- **66 books · 1,189 chapters · 31,104 verses per version**, all offline.
- **Five translations**, switchable instantly:
  - KJV — King James Version
  - NIV — New International Version
  - NLT — New Living Translation
  - NWT — New World Translation (2013)
  - ORIG — Original manuscripts: Hebrew (Westminster Leningrad Codex) for the
    Old Testament, Greek (Textus Receptus) for the New Testament
- **Reader**: swipeable pager across all 1,189 chapters, verse numbers,
  justified text, adjustable size/line-height, **serif/sans/mono fonts**,
  five hand-tuned themes (Parchment, Sepia, Slate, Midnight),
  jump-to-verse deep links, word count and ~reading-time estimate.
- **Chapter audio**: listen to any chapter read aloud (device text-to-speech)
  with a live spotlight on the verse being spoken.
- **Parallel mode**: read any two translations side by side.
- **Per-verse actions**: copy, share, bookmark, 5-color highlights, personal
  notes, memorize toggle, one-tap jump to the original-language text.
- **Memorize studio**: hide-and-reveal flashcard drills over famous verses
  with first-letter hints and a personal memorized treasury.
- **Search**: instant full-text search across every verse (offline) with a
  per-translation selector, OT/NT/book scopes, highlighted matches, and a smart
  reference parser (`john 3:16`, `psalm 23`, `1 cor 5` jump straight to the
  verse).
- **Topical study**: 12 themes (love, faith, hope, prayer, wisdom, …) with
  verses gathered live from the current translation.
- **Reading plans**: Whole Bible (365d), Old Testament (180d), New Testament
  (90d), Gospels (30d), Wisdom & Worship (31d), Paul's Letters (40d) — with
  day-by-day progress rings and "read today" shortcuts.
- **Scripture Quiz**: rounds of 10 questions generated live from the text —
  which book, finish the famous verse, book order, chapter counts — with
  per-mode best scores.
- **Stats & streaks**: reading streak, chapters/verses read, books finished,
  7-day activity chart, Bible-completion meter, plan progress, and
  **16 achievements** (chapters, streaks, quizzes, memory, notes).
- **Everything persists** (shared_preferences): settings, last position,
  progress, bookmarks, highlights, notes, plans, quiz records.

## Run it

```bash
# 1. fetch dependencies (only shared_preferences is added)
flutter pub get

# 2. run on any Flutter target
flutter run                 # picks the connected device
flutter run -d chrome       # web
flutter run -d linux        # desktop
```

Building for Android/iOS bundles the dataset automatically via the asset
declaration in `pubspec.yaml` (≈ 22 MB of JSON). No permissions or services are
needed.

> Note: this sandbox has no Flutter SDK installed, so the app was authored and
> statically checked here; run `flutter analyze` and `flutter test` on a machine
> with the Flutter SDK (>= 3.38 / Dart >= 3.12, as pinned in `pubspec.yaml`).

## App architecture

```
lib/
├── main.dart                     # bootstrap
└── app/
    ├── app.dart                  # MaterialApp + theme wiring
    ├── store.dart                # AppStore: settings, progress, annotations,
    │                             #   quiz records (ChangeNotifier + prefs)
    ├── theme.dart                # AppTheme palettes & highlight colors
    ├── data/
    │   ├── models.dart           # TranslationMeta, BookInfo, ChapterData, …
    │   ├── repository.dart       # asset loading, LRU bundle cache, global
    │   │                         #   chapter index, reference parser
    │   ├── plans.dart            # plan definitions + progress math
    │   ├── quiz_engine.dart      # generated question builders
    │   └── verse_refs.dart       # verse-of-the-day + famous verse lists
    └── ui/
        ├── scope.dart            # InheritedNotifier for AppStore
        ├── home_shell.dart       # bottom-navigation shell
        ├── home_page.dart        # dashboard (VOTD, continue, plan, chart)
        ├── reader_page.dart      # swipe pager, compare, verse sheets,
        │                         #   chapter picker, reading settings
        ├── search_page.dart      # full-text search + reference jump
        ├── library_page.dart     # books, bookmarks, highlights, notes
        ├── plans_page.dart       # reading plans
        ├── quiz_page.dart        # quiz flow
        ├── stats_page.dart       # stats dashboard
        ├── settings_page.dart    # preferences + reset
        └── widgets.dart          # shared components
```

Data flows from `lib/Holy_Bible-main/bible/translations/{code}/all.min.json`
(one compact, identical JSON schema per translation) — it is loaded lazily on
first use and cached with a small LRU, so startup stays instant and chapters
render without any network.

The original `lib/Holy_Bible-main` folder — the dataset plus the reference
HTML/JS app it came with — is preserved untouched.

## License / content notes

The app code here is original. Scripture text belongs to the respective
publishers (or, for the original-language portions, public-domain editions of
the Westminster Leningrad Codex and the Textus Receptus) and is included as
repository data, matching its original packaging.

---

*SelahApp — "Scripture, beautifully deep."*
