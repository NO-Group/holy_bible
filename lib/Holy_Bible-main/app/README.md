# Holy Bible App (pure HTML/CSS/JS)

A complete, high-polish Bible app — **no npm, no build step, no frameworks**.
A multi-page site (one page per section) that reads scripture straight from
the repo's `bible/` JSON dataset. Each page is a full HTML document; shared
chrome (sidebar, topbar, nav, drawer, settings) is injected by `app/js/shell.js`
so there is a single source of truth. All assets (CSS, JS, manifest, icon)
live here in `app/`.

## Features

- 📖 **Reader** — book/chapter picker, prev/next navigation, beautiful serif
  typography, chapter header, verse-numbers toggle, per-chapter "mark read"
- 🔊 **Read aloud** — text-to-speech with adjustable speed and active-verse
  highlighting (speaks Hebrew/Greek in the `original` translation)
- 🌍 **5 translations** — KJV, NIV, NLT, NWT and the Original manuscripts
  (Hebrew shown right-to-left for the OT, Greek for the NT)
- ⇄ **Compare** — read two translations side by side
- 🗓️ **Reading plans** — Gospels, Psalms & Proverbs, NT, OT, and the Whole
  Bible, with automatic progress tracking
- ✓ **Progress** — every chapter read is saved; global + per-book progress
- ✦ **Verse of the Day** — rotates daily from 31 beloved verses
- 🔍 **Search** — full-text search (all/OT/NT scope) plus smart reference
  jump (type `John 3:16` or `1 Kings 2`)
- 🖍️ **Highlights** — 5 colors, tap any verse
- 🔖 **Bookmarks, 📝 Notes** — organized in My Library, with JSON export/import
- 🏆 **Bible Quiz** — 4 modes (Mixed, Finish the Verse, Which Book?, Book
  Order), 10 questions per round, scores/best/points saved
- 🔥 **Daily reading streak**
- 🎨 **Themes** (Dark / Light / Sepia / Auto), 3 fonts, adjustable text size &
  line spacing, justified text
- 🔗 **Deep links** — the current chapter is reflected in the URL (`#/kjv/genesis/1`)
- ⌨️ **Keyboard shortcuts** — `←`/`→` chapters, `/` search, `Esc` close
- 📤 Copy & share verses (uses native share sheet when available)
- 📦 **Installable PWA** — manifest + service worker, fully offline after first load
- 💾 Everything persists in `localStorage`; all data is local — works fully
  offline once bundled

## Run locally

Any static file server from the **repository root** (the app fetches
`bible/...` relative to each page):

```bash
python3 -m http.server 8000
# open http://localhost:8000/
```

> Note: opening pages via `file://` won't work because browsers block
> `fetch()` on local files — always serve over HTTP, or embed as below.

## Pages & deep links

| Page | File | Deep link |
|------|------|-----------|
| Home | `index.html` | — |
| Reader | `read.html` | `read.html#/{code}/{book}/{chapter}[/{verse}]` |
| Search | `search.html` | `search.html?q=grace` |
| Reading Plan | `plan.html` | — |
| Quiz | `quiz.html` | — |
| My Library | `library.html` | — |

Every book link, search result, bookmark, note and plan step points at a
shareable `read.html` URL, so any verse can be deep-linked and bookmarked in
the browser. State (translation, last location, settings, progress) is shared
across pages via `localStorage`.

## Architecture

```
index.html            # Home page
read.html             # Reader page
search.html           # Search page
plan.html             # Reading plans page
quiz.html             # Quiz page
library.html          # My Library page
app/
├── icon.svg          # app icon (also used as favicon + PWA icon)
├── manifest.webmanifest
├── css/style.css     # design system, themes via CSS variables
└── js/
    ├── data.js       # data layer: lazy chapter loading + compact bundle cache
    ├── quiz.js       # quiz engine: questions generated from scripture data
    ├── shell.js      # shared chrome/state — injected into every page
    ├── home.js       # Home page controller
    ├── reader.js     # Reader: navigation, audio, compare, picker, verse actions
    ├── search.js     # Search page controller
    ├── plan.js       # Reading plans controller
    ├── quiz-page.js  # Quiz page controller
    └── library.js    # My Library controller
sw.js                 # service worker (app-shell + runtime chapter caching)
scripts/
├── build_bible.py    # dataset builder
├── check_ids.js      # asserts every DOM id referenced in JS exists (no deps)
└── smoke_test.js     # loads every page in jsdom & reports boot errors
```

- Chapters are fetched lazily (`bible/translations/{code}/{slug}/chapter_{n}.json`,
  2–8 KB each) and cached in memory.
- Search & quiz load the compact single-file bundle (`all.min.json`, ~4 MB)
  once per translation, on demand.
- No external dependencies except Google Fonts (falls back gracefully offline).

## Embedding in Flutter (Dart) — WebView

The whole app is static files, so embedding is easy with `webview_flutter`
+ a tiny local server (e.g. `shelf_static`), or with `flutter_inappwebview`'s
built-in asset server:

1. Copy the app files (the root `*.html` pages, `sw.js`, `app/`, and `bible/`)
   into your Flutter project's `assets/` folder and declare them in
   `pubspec.yaml`:

   ```yaml
   flutter:
     assets:
       - assets/app/
       - assets/bible/
       - assets/index.html
       - assets/read.html
       - assets/search.html
       - assets/plan.html
       - assets/quiz.html
       - assets/library.html
       - assets/sw.js
   ```

2. **Easiest route — `flutter_inappwebview`** (serves assets over a local
   HTTP server automatically):

   ```dart
   final _server = InAppLocalhostServer(documentRoot: 'assets');

   @override
   void initState() {
     super.initState();
     _server.start();
   }

  InAppWebView(
    initialUrlRequest: URLRequest(
      url: WebUri('http://localhost:8080/index.html'),
    ),
  )
  ```

  (The other pages — `read.html`, `search.html`, etc. — are reachable by
  relative links from `index.html`.)

3. Or with `webview_flutter`, run a `shelf_static` server on `127.0.0.1`
   inside the app and point the WebView at `http://127.0.0.1:<port>/index.html`.

Because everything (scripture JSON included) ships inside the app bundle, the
result is a fully offline Bible app.

### Android Studio (native WebView)

`WebViewAssetLoader` maps `https://appassets.androidplatform.net/assets/...`
to your `assets/` dir — put `index.html`, `sw.js`, `app/` and `bible/` under
`src/main/assets/` and load
`https://appassets.androidplatform.net/assets/index.html`.
