# Holy Bible — Consistent JSON Dataset + App

**➡ Try the app: serve this repo (`python3 -m http.server 8000`) and open
`http://localhost:8000/`** — a complete Bible app in pure HTML/CSS/JS
(reader, search, highlights, bookmarks, notes, quiz, reading plans, read-aloud,
side-by-side translations, themes, installable PWA; no npm, no build step).
It's a multi-page site — `index.html` (Home), `read.html`, `search.html`,
`plan.html`, `quiz.html`, `library.html` — with its assets in `app/`. See
[`app/README.md`](app/README.md) for details and for embedding it in a
Flutter/Android WebView.

The complete Holy Bible (66 books, 1,189 chapters) in **four English translations
plus the original-language manuscripts**, all stored in **one identical JSON
format** designed for easy app rendering.

| Code | Translation | Chapters | Verse slots | With text |
|------|-------------|----------|-------------|-----------|
| `kjv` | King James Version | 1,189 | 31,104 | 31,102 |
| `niv` | New International Version | 1,189 | 31,104 | 31,087 |
| `nlt` | New Living Translation | 1,189 | 31,104 | 31,064 |
| `nwt` | New World Translation (2013 Revision) | 1,189 | 31,104 | 31,062 |
| `original` | Original Manuscripts — Hebrew & Greek | 1,189 | 31,104 | 31,097 |

The `original` translation contains the scriptures in their original languages:

- **Old Testament (books 1–39): Hebrew** — the Westminster Leningrad Codex
  (WLC), a digital edition of the Leningrad Codex (1008 CE), the oldest
  complete manuscript of the Hebrew Masoretic Text, with full vowel points
  and cantillation marks. Hebrew versification has been remapped to the KJV
  versification used across this dataset.
- **New Testament (books 40–66): Greek** — the Textus Receptus (1550/1894),
  the Greek text underlying the King James Version.

Each book in `original`'s `books.json` carries a `"language"` field
(`"Hebrew"` or `"Greek"`).

**Every chapter has the exact same verse numbers in every translation** —
numbering is always continuous (1..N), so apps can render and align
translations side by side without special cases.

## Directory layout

```
bible/
├── translations.json                     # master index of all translations
└── translations/
    └── {code}/                           # kjv | niv | nlt | nwt | original
        ├── books.json                    # 66-book index with metadata
        └── {book_slug}/                  # e.g. genesis, 1_samuel, song_of_solomon
            ├── chapter_1.json
            ├── chapter_2.json
            └── ...
```

Example path: `bible/translations/nlt/genesis/chapter_1.json`

Book slugs are lowercase with underscores: `genesis`, `1_chronicles`,
`song_of_solomon`, `revelation`, …

## File formats

### `bible/translations.json`

```json
{
  "format_version": 1,
  "books": 66,
  "chapters_per_bible": 1189,
  "translations": [
    {
      "code": "kjv",
      "name": "King James Version",
      "path": "translations/kjv",
      "books_index": "translations/kjv/books.json",
      "chapter_path_pattern": "translations/kjv/{book_slug}/chapter_{n}.json"
    }
  ]
}
```

### `bible/translations/{code}/books.json`

```json
{
  "translation": "KJV",
  "name": "King James Version",
  "books": [
    {
      "id": 1,
      "name": "Genesis",
      "slug": "genesis",
      "testament": "OT",
      "chapters": 50,
      "verses": 1533,
      "text_verses": 1533
    }
  ]
}
```

`verses` counts every verse slot (including placeholders);
`text_verses` counts only verses with actual text.

### `bible/translations/{code}/{book_slug}/chapter_{n}.json`

Identical schema for every translation:

```json
{
  "translation": "KJV",
  "book": "Genesis",
  "book_id": 1,
  "chapter": 1,
  "verses": [
    { "verse": 1, "text": "In the beginning God created the heaven and the earth." },
    { "verse": 2, "text": "And the earth was without form, and void; ..." }
  ]
}
```

## Data conventions

- **All numbers are integers** (`book_id`, `chapter`, `verse`) — no string numbers.
- **Plain text only** — no embedded HTML (`<br>`, `<i>`, …) and no markup.
- Unicode is NFC-normalized; whitespace is collapsed to single spaces.
- **Continuous numbering** — every chapter contains verse numbers 1..N with no
  gaps, and the set of verse numbers is identical across all four translations.
  Verse *i* is always at array index *i − 1*.
- **Omitted verses** — modern translations (NIV, NLT, NWT) omit certain
  late-manuscript verses (e.g. Matthew 17:21, Acts 8:37; in NWT also
  Mark 16:9–20 and John 7:53–8:11). These keep their slot as a placeholder:

  ```json
  { "verse": 21, "text": "", "omitted": true }
  ```

- **Merged verses** — the NLT sometimes combines consecutive verses into one
  (e.g. Numbers 1:20–21). The text lives on the first verse; the rest point
  back to it:

  ```json
  { "verse": 21, "text": "", "merged_with": 20 }
  ```

- Renderers can show omitted verses as a dash or footnote, and merged verses
  as part of the verse they reference. Checking `if (verse.text)` is enough
  to know whether there is anything to display.
- Book IDs 1–39 are the Old Testament (`"testament": "OT"`),
  40–66 the New Testament (`"testament": "NT"`).

## Rendering tips

1. Load `bible/translations.json` once to list available translations.
2. Load `translations/{code}/books.json` to build the book/chapter picker.
3. Fetch single chapters on demand — each file is small (typically 2–8 KB),
   ideal for lazy loading or bundling.

## Provenance

- KJV, NIV and NLT were migrated from this repository's original
  (heterogeneous) data with normalization applied.
- NWT (2013 Revision) text was parsed from the plain-text dump in
  [Witty-Kitty/ALP-MT](https://github.com/Witty-Kitty/ALP-MT).
- `original` texts come from
  [scrollmapper/bible_databases](https://github.com/scrollmapper/bible_databases)
  (Westminster Leningrad Codex for Hebrew OT, Textus Receptus 1550/1894 for
  Greek NT). Hebrew (BHS) versification was remapped to KJV versification via
  the BHSA→KJV mapping from
  [eliranwong/OpenHebrewBible](https://github.com/eliranwong/OpenHebrewBible).
  Only 7 slots lack text (e.g. Isaiah 64:1 merged in Hebrew numbering,
  3 John 1:15 / Revelation 12:18 which follow later versification) — marked
  `omitted`/`merged_with` like everywhere else.
- The migration/validation scripts are kept in `scripts/`
  (`build_bible.py`, `fill_missing_verses.py`). Every translation is
  validated for: exactly 66 books, canonical chapter counts (1,189 total),
  and continuous identical verse numbering across translations.
