/* ═══════════════ shell.js — shared chrome, state & helpers ═══════════════
   Loaded on every page. Injects the shared layout (sidebar, topbar, bottom
   nav, drawer, sheets, toast, loading) and exposes a single `App` global.
   Page scripts call `App.init(pageId).then(...)` to boot. */
(() => {
  const $ = s => document.querySelector(s);
  const $$ = s => [...document.querySelectorAll(s)];
  const TOTAL_CHAPTERS = 1189;

  /* ─────────── shared state (persisted via STORE) ─────────── */
  const S = {
    code: STORE.get('translation', 'kjv'),
    slug: STORE.get('slug', 'genesis'),
    chapter: STORE.get('chapter', 1),
    theme: STORE.get('theme', 'dark'),
    fontFamily: STORE.get('fontFamily', 'serif'),
    fontSize: STORE.get('fontSize', 18),
    leading: STORE.get('leading', 'normal'),
    showVnums: STORE.get('showVnums', true),
    justify: STORE.get('justify', false),
    compareCode: STORE.get('compareCode', 'niv'),
    compareOn: STORE.get('compareOn', false),
    bookmarks: STORE.get('bookmarks', []),
    highlights: STORE.get('highlights', {}),
    notes: STORE.get('notes', {}),
    readChapters: STORE.get('readChapters', {}),
    streak: STORE.get('streak', { days: 0, last: '' }),
    quiz: STORE.get('quiz', { played: 0, best: 0, points: 0 }),
    activePlan: STORE.get('activePlan', 'whole'),
  };

  /* ─────────── helpers ─────────── */
  const esc = s => String(s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  const hlKey = (slug, ch, v) => `${slug}/${ch}/${v}`;
  const rcKey = (slug, ch) => `${slug}/${ch}`;
  const isRead = (slug, ch) => !!S.readChapters[rcKey(slug, ch)];
  const isDarkPreferred = () => window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches;

  function toast(msg) {
    const t = $('#toast');
    t.textContent = msg; t.hidden = false;
    clearTimeout(t._t);
    t._t = setTimeout(() => (t.hidden = true), 2200);
  }

  function applyPrefs() {
    let theme = S.theme;
    if (theme === 'auto') theme = isDarkPreferred() ? 'dark' : 'light';
    document.body.dataset.theme = theme;
    document.body.dataset.font = S.fontFamily;
    document.documentElement.style.setProperty('--verse-size', S.fontSize + 'px');
    const leading = { compact: 1.5, normal: 1.75, relaxed: 2.05 }[S.leading] || 1.75;
    document.documentElement.style.setProperty('--verse-leading', leading);
    document.body.classList.toggle('hide-vnums', !S.showVnums);
    document.body.classList.toggle('justified', S.justify);
    const fp = $('#fontPreview'); if (fp) fp.textContent = S.fontSize;
    $$('#segTheme button').forEach(b => b.classList.toggle('active', b.dataset.theme === S.theme));
    $$('#segFont button').forEach(b => b.classList.toggle('active', b.dataset.font === S.fontFamily));
    $$('#segLeading button').forEach(b => b.classList.toggle('active', b.dataset.leading === S.leading));
    const vn = $('#setVnums'); if (vn) vn.checked = S.showVnums;
    const jf = $('#setJustify'); if (jf) jf.checked = S.justify;
  }

  function updateStreak() {
    const today = new Date().toISOString().slice(0, 10);
    if (S.streak.last === today) return;
    const yest = new Date(Date.now() - 864e5).toISOString().slice(0, 10);
    S.streak.days = S.streak.last === yest ? S.streak.days + 1 : 1;
    S.streak.last = today;
    STORE.set('streak', S.streak);
  }

  /* ─────────── header / progress rendering ─────────── */
  function renderHeader() {
    const book = DATA.bookBySlug(S.slug);
    const t = DATA.TRANSLATIONS.find(x => x.code === S.code) || DATA.TRANSLATIONS[0];
    const tb = $('#topbarBook'); if (tb) tb.textContent = `${book ? book.name : 'Genesis'} ${S.chapter}`;
    const bt = $('#btnTranslation'); if (bt) bt.textContent = t.short;
    const dt = $('#drawerTrans'); if (dt) dt.textContent = t.name;
    const st = $('#sideTrans'); if (st) st.textContent = t.name;
  }

  function renderProgress() {
    const read = Object.keys(S.readChapters).length;
    const pct = Math.round((read / TOTAL_CHAPTERS) * 100);
    const p = $('#sideProgressPct'); if (p) p.textContent = pct + '%';
    const b = $('#sideProgressBar'); if (b) b.style.width = pct + '%';
    const s = $('#sideProgressSub'); if (s) s.textContent = `${read.toLocaleString()} of ${TOTAL_CHAPTERS.toLocaleString()} chapters read`;
  }

  /* ─────────── sheets ─────────── */
  function openSheet(id) { closeSheets(); $('#overlay').hidden = false; $(id).hidden = false; document.body.style.overflow = 'hidden'; }
  function closeSheets() {
    $('#overlay').hidden = true;
    $$('.sheet').forEach(s => (s.hidden = true));
    $('#drawer').hidden = true;
    document.body.style.overflow = '';
  }

  function renderTranslations() {
    const list = $('#translationList');
    list.innerHTML = '';
    for (const t of DATA.TRANSLATIONS) {
      const btn = document.createElement('button');
      btn.className = 'trans-item' + (t.code === S.code ? ' current' : '');
      btn.innerHTML = `<span class="trans-code">${t.short}</span><span><b>${t.name}</b><small>${t.desc}</small></span>`;
      btn.addEventListener('click', async () => {
        closeSheets();
        App.showLoading(true);
        await App.setTranslation(t.code);
        location.reload();
      });
      list.appendChild(btn);
    }
  }

  /* ─────────── shared chrome markup ─────────── */
  function chromeHTML() {
    return `
<div class="app">
  <aside class="sidebar" id="sidebar">
    <a class="side-logo" href="index.html">
      <div class="side-logo-mark">✝</div>
      <div class="side-logo-txt"><b>Holy Bible</b><small id="sideTrans">King James Version</small></div>
    </a>
    <nav class="side-nav">
      <a class="side-item" data-page="home" href="index.html"><span class="si-ico">🏠</span>Home</a>
      <a class="side-item" data-page="read" href="read.html"><span class="si-ico">📖</span>Read</a>
      <a class="side-item" data-page="search" href="search.html"><span class="si-ico">🔍</span>Search</a>
      <a class="side-item" data-page="plan" href="plan.html"><span class="si-ico">🗓️</span>Reading Plan</a>
      <a class="side-item" data-page="quiz" href="quiz.html"><span class="si-ico">🏆</span>Quiz</a>
      <a class="side-item" data-page="library" href="library.html"><span class="si-ico">🔖</span>My Library</a>
    </nav>
    <div class="side-progress">
      <div class="side-progress-head"><span>Your Progress</span><span id="sideProgressPct">0%</span></div>
      <div class="progressbar"><div id="sideProgressBar"></div></div>
      <div class="side-progress-sub" id="sideProgressSub">0 of 1,189 chapters read</div>
    </div>
    <div class="side-foot">
      <button class="side-item" id="sideSettings"><span class="si-ico">⚙️</span>Settings</button>
      <button class="side-item" id="sideRandom"><span class="si-ico">🎲</span>Random Chapter</button>
      <button class="side-item" id="sideVotd"><span class="si-ico">✦</span>Verse of the Day</button>
    </div>
  </aside>

  <div class="app-main">
    <header class="topbar" id="topbar">
      <button class="icon-btn btnMenu" id="btnMenu" aria-label="Menu">
        <svg viewBox="0 0 24 24"><path d="M3 6h18M3 12h18M3 18h18" stroke="currentColor" stroke-width="2" stroke-linecap="round"/></svg>
      </button>
      <a class="topbar-title" id="topbarTitle" href="read.html">
        <span id="topbarBook">Genesis 1</span>
        <svg viewBox="0 0 24 24" class="chev"><path d="M6 9l6 6 6-6" stroke="currentColor" stroke-width="2" fill="none" stroke-linecap="round" stroke-linejoin="round"/></svg>
      </a>
      <div class="topbar-actions">
        <button class="pill" id="btnTranslation" title="Translation">KJV</button>
        <a class="icon-btn" href="search.html" aria-label="Search">
          <svg viewBox="0 0 24 24"><circle cx="11" cy="11" r="7" stroke="currentColor" stroke-width="2" fill="none"/><path d="M20 20l-3.5-3.5" stroke="currentColor" stroke-width="2" stroke-linecap="round"/></svg>
        </a>
        <button class="icon-btn" id="btnSettings" aria-label="Settings">
          <svg viewBox="0 0 24 24"><path d="M12 15a3 3 0 100-6 3 3 0 000 6z" stroke="currentColor" stroke-width="2" fill="none"/><path d="M19.4 15a1.65 1.65 0 00.33 1.82l.06.06a2 2 0 11-2.83 2.83l-.06-.06a1.65 1.65 0 00-1.82-.33 1.65 1.65 0 00-1 1.51V21a2 2 0 11-4 0v-.09a1.65 1.65 0 00-1-1.51 1.65 1.65 0 00-1.82.33l-.06.06a2 2 0 11-2.83-2.83l.06-.06a1.65 1.65 0 00.33-1.82 1.65 1.65 0 00-1.51-1H3a2 2 0 110-4h.09a1.65 1.65 0 001.51-1 1.65 1.65 0 00-.33-1.82l-.06-.06a2 2 0 112.83-2.83l.06.06a1.65 1.65 0 001.82.33h.01a1.65 1.65 0 001-1.51V3a2 2 0 114 0v.09a1.65 1.65 0 001 1.51h.01a1.65 1.65 0 001.82-.33l.06-.06a2 2 0 112.83 2.83l-.06.06a1.65 1.65 0 00-.33 1.82v.01a1.65 1.65 0 001.51 1H21a2 2 0 110 4h-.09a1.65 1.65 0 00-1.51 1z" stroke="currentColor" stroke-width="1.6" fill="none"/></svg>
        </button>
      </div>
    </header>
    <main id="main"></main>
  </div>
</div>

<nav class="bottomnav" id="bottomnav">
  <a class="bnav" data-page="home" href="index.html"><svg viewBox="0 0 24 24"><path d="M3 10.5L12 3l9 7.5V21a1 1 0 01-1 1h-5v-7h-6v7H4a1 1 0 01-1-1z" stroke="currentColor" stroke-width="1.8" fill="none" stroke-linejoin="round"/></svg><span>Home</span></a>
  <a class="bnav" data-page="read" href="read.html"><svg viewBox="0 0 24 24"><path d="M12 6c-2-1.5-4.5-2-8-2v14c3.5 0 6 .5 8 2 2-1.5 4.5-2 8-2V4c-3.5 0-6 .5-8 2zM12 6v14" stroke="currentColor" stroke-width="1.8" fill="none" stroke-linejoin="round"/></svg><span>Read</span></a>
  <a class="bnav" data-page="search" href="search.html"><svg viewBox="0 0 24 24"><circle cx="11" cy="11" r="7" stroke="currentColor" stroke-width="1.8" fill="none"/><path d="M20 20l-3.5-3.5" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/></svg><span>Search</span></a>
  <a class="bnav" data-page="quiz" href="quiz.html"><svg viewBox="0 0 24 24"><path d="M8 21h8M12 17v4M6 3h12v5a6 6 0 01-12 0V3z" stroke="currentColor" stroke-width="1.8" fill="none" stroke-linejoin="round"/><path d="M6 5H3v2a4 4 0 003 3.87M18 5h3v2a4 4 0 01-3 3.87" stroke="currentColor" stroke-width="1.8" fill="none"/></svg><span>Quiz</span></a>
  <a class="bnav" data-page="library" href="library.html"><svg viewBox="0 0 24 24"><path d="M6 3h12v18l-6-4-6 4V3z" stroke="currentColor" stroke-width="1.8" fill="none" stroke-linejoin="round"/></svg><span>Library</span></a>
</nav>

<div class="overlay" id="overlay" hidden></div>

<!-- book / chapter picker (reader) -->
<div class="sheet" id="sheetPicker" hidden>
  <div class="sheet-handle"></div>
  <div class="picker-tabs">
    <button class="ptab active" data-pt="book">Book</button>
    <button class="ptab" data-pt="chapter" id="ptabChapter" disabled>Chapter</button>
  </div>
  <div class="picker-body">
    <div id="pickerBooks">
      <div class="picker-testament">Old Testament</div>
      <div class="book-grid" id="gridOT"></div>
      <div class="picker-testament">New Testament</div>
      <div class="book-grid" id="gridNT"></div>
    </div>
    <div id="pickerChapters" hidden><div class="chapter-grid" id="gridChapters"></div></div>
  </div>
</div>

<!-- translation picker -->
<div class="sheet" id="sheetTranslation" hidden>
  <div class="sheet-handle"></div>
  <h3 class="sheet-title">Choose Translation</h3>
  <div id="translationList"></div>
</div>

<!-- verse actions (reader) -->
<div class="sheet" id="sheetVerse" hidden>
  <div class="sheet-handle"></div>
  <div class="verse-sheet-ref" id="vsRef"></div>
  <p class="verse-sheet-text" id="vsText"></p>
  <div class="vs-colors" id="vsColors">
    <button class="vs-color" data-color="yellow" style="--c:#f6d743"></button>
    <button class="vs-color" data-color="green" style="--c:#7ed99a"></button>
    <button class="vs-color" data-color="blue" style="--c:#7cc4f5"></button>
    <button class="vs-color" data-color="pink" style="--c:#f5a3c0"></button>
    <button class="vs-color" data-color="purple" style="--c:#c6a6f2"></button>
    <button class="vs-color none" data-color="">✕</button>
  </div>
  <div class="vs-actions">
    <button class="vs-act" id="vsBookmark"><span>🔖</span>Bookmark</button>
    <button class="vs-act" id="vsCopy"><span>📋</span>Copy</button>
    <button class="vs-act" id="vsShare"><span>📤</span>Share</button>
    <button class="vs-act" id="vsNote"><span>📝</span>Note</button>
  </div>
  <div class="vs-notebox" id="vsNotebox" hidden>
    <textarea id="vsNoteText" placeholder="Write your note…"></textarea>
    <button class="vs-save" id="vsNoteSave">Save Note</button>
  </div>
</div>

<!-- settings -->
<div class="sheet" id="sheetSettings" hidden>
  <div class="sheet-handle"></div>
  <h3 class="sheet-title">Settings</h3>
  <div class="set-row">
    <span>Theme</span>
    <div class="seg" id="segTheme">
      <button data-theme="light">☀️ Light</button>
      <button data-theme="sepia">📜 Sepia</button>
      <button class="active" data-theme="dark">🌙 Dark</button>
      <button data-theme="auto">✨ Auto</button>
    </div>
  </div>
  <div class="set-row">
    <span>Font</span>
    <div class="seg" id="segFont">
      <button data-font="serif" class="active">Serif</button>
      <button data-font="sans">Sans</button>
      <button data-font="book">Book</button>
    </div>
  </div>
  <div class="set-row">
    <span>Text Size</span>
    <div class="seg">
      <button id="fontMinus">A−</button>
      <span class="font-preview" id="fontPreview">18</span>
      <button id="fontPlus">A+</button>
    </div>
  </div>
  <div class="set-row">
    <span>Line Spacing</span>
    <div class="seg" id="segLeading">
      <button data-leading="compact">Compact</button>
      <button data-leading="normal" class="active">Normal</button>
      <button data-leading="relaxed">Relaxed</button>
    </div>
  </div>
  <div class="set-row">
    <span>Verse Numbers</span>
    <label class="switch"><input type="checkbox" id="setVnums" checked><i></i></label>
  </div>
  <div class="set-row">
    <span>Justified Text</span>
    <label class="switch"><input type="checkbox" id="setJustify"><i></i></label>
  </div>
  <h4 class="set-group">Your Data</h4>
  <div class="set-row">
    <span>Export library</span>
    <button class="seg-btn" id="btnExport">Download</button>
  </div>
  <div class="set-row">
    <span>Import library</span>
    <button class="seg-btn" id="btnImport">Choose file</button>
    <input type="file" id="importFile" accept="application/json" hidden>
  </div>
  <div class="set-row danger">
    <span>Reset all data</span>
    <button class="seg-btn danger-btn" id="btnReset">Reset</button>
  </div>
  <div class="set-about">Holy Bible · KJV / NIV / NLT / NWT + Original Hebrew &amp; Greek<br>All scripture data bundled — works fully offline.</div>
</div>

<!-- shortcuts help -->
<div class="sheet" id="sheetHelp" hidden>
  <div class="sheet-handle"></div>
  <h3 class="sheet-title">Keyboard Shortcuts</h3>
  <div class="help-grid">
    <div><kbd>←</kbd><kbd>→</kbd></div><span>Previous / next chapter</span>
    <div><kbd>/</kbd></div><span>Focus search</span>
    <div><kbd>Esc</kbd></div><span>Close sheets</span>
    <div><kbd>h</kbd></div><span>Go home</span>
    <div><kbd>r</kbd></div><span>Go to reader</span>
  </div>
</div>

<!-- mobile drawer -->
<div class="drawer" id="drawer" hidden>
  <div class="drawer-head">
    <div class="drawer-logo">✝</div>
    <div><b>Holy Bible</b><small id="drawerTrans">King James Version</small></div>
  </div>
  <a class="d-item" href="index.html"><span>🏠</span>Home</a>
  <a class="d-item" href="read.html"><span>📖</span>Read Bible</a>
  <a class="d-item" href="search.html"><span>🔍</span>Search</a>
  <a class="d-item" href="plan.html"><span>🗓️</span>Reading Plan</a>
  <a class="d-item" href="quiz.html"><span>🏆</span>Bible Quiz</a>
  <a class="d-item" href="library.html"><span>🔖</span>My Library</a>
  <hr>
  <button class="d-item" id="dRandom"><span>🎲</span>Random Chapter</button>
  <button class="d-item" id="dVotd"><span>✦</span>Verse of the Day</button>
  <button class="d-item" id="dSettings"><span>⚙️</span>Settings</button>
  <button class="d-item" id="dHelp"><span>⌨️</span>Keyboard Shortcuts</button>
</div>

<div class="toast" id="toast" hidden></div>
<div class="loading" id="loading"><div class="spinner"></div><div>Loading Scripture…</div></div>`;
  }

  /* ─────────── settings wiring ─────────── */
  function wireSettings() {
    $('#segTheme').addEventListener('click', e => {
      const b = e.target.closest('button[data-theme]'); if (!b) return;
      S.theme = b.dataset.theme; STORE.set('theme', S.theme); applyPrefs();
    });
    $('#segFont').addEventListener('click', e => {
      const b = e.target.closest('button[data-font]'); if (!b) return;
      S.fontFamily = b.dataset.font; STORE.set('fontFamily', S.fontFamily); applyPrefs();
    });
    $('#segLeading').addEventListener('click', e => {
      const b = e.target.closest('button[data-leading]'); if (!b) return;
      S.leading = b.dataset.leading; STORE.set('leading', S.leading); applyPrefs();
    });
    const setFont = n => { S.fontSize = Math.max(14, Math.min(28, n)); STORE.set('fontSize', S.fontSize); applyPrefs(); };
    $('#fontMinus').addEventListener('click', () => setFont(S.fontSize - 1));
    $('#fontPlus').addEventListener('click', () => setFont(S.fontSize + 1));
    $('#setVnums').addEventListener('change', e => { S.showVnums = e.target.checked; STORE.set('showVnums', S.showVnums); applyPrefs(); });
    $('#setJustify').addEventListener('change', e => { S.justify = e.target.checked; STORE.set('justify', S.justify); applyPrefs(); });

    $('#btnExport').addEventListener('click', () => {
      const payload = {
        app: 'holybible', version: 2, exported: new Date().toISOString(),
        bookmarks: S.bookmarks, highlights: S.highlights, notes: S.notes,
        readChapters: S.readChapters, quiz: S.quiz, streak: S.streak, activePlan: S.activePlan,
      };
      const blob = new Blob([JSON.stringify(payload, null, 2)], { type: 'application/json' });
      const a = document.createElement('a');
      a.href = URL.createObjectURL(blob); a.download = 'holy-bible-library.json'; a.click();
      URL.revokeObjectURL(a.href);
      toast('Library exported');
    });
    $('#btnImport').addEventListener('click', () => $('#importFile').click());
    $('#importFile').addEventListener('change', async e => {
      const file = e.target.files[0]; if (!file) return;
      try {
        const data = JSON.parse(await file.text());
        if (data.app !== 'holybible') throw new Error('invalid file');
        for (const k of ['bookmarks', 'highlights', 'notes', 'readChapters', 'quiz', 'streak', 'activePlan']) {
          if (data[k] !== undefined) { S[k] = data[k]; STORE.set(k, data[k]); }
        }
        toast('Library imported ✓'); renderProgress(); closeSheets();
      } catch (err) { toast('Import failed: ' + err.message); }
      e.target.value = '';
    });
    $('#btnReset').addEventListener('click', () => {
      if (!confirm('Reset ALL data (bookmarks, highlights, notes, progress, settings)? This cannot be undone.')) return;
      Object.keys(localStorage).filter(k => k.startsWith('holybible.')).forEach(k => localStorage.removeItem(k));
      location.reload();
    });
  }

  /* ─────────── build chrome & wire events ─────────── */
  function renderChrome(pageId) {
    const pc = document.getElementById('pageContent');
    const shell = document.getElementById('shell');
    shell.insertAdjacentHTML('afterend', chromeHTML());
    shell.remove();
    document.getElementById('main').appendChild(pc);

    $('#overlay').addEventListener('click', closeSheets);
    $('#btnMenu').addEventListener('click', () => { $('#overlay').hidden = false; $('#drawer').hidden = false; });
    $('#btnTranslation').addEventListener('click', () => { renderTranslations(); openSheet('#sheetTranslation'); });
    $('#btnSettings').addEventListener('click', () => openSheet('#sheetSettings'));
    $('#sideSettings').addEventListener('click', () => openSheet('#sheetSettings'));
    $('#dSettings').addEventListener('click', () => openSheet('#sheetSettings'));
    $('#dHelp').addEventListener('click', () => openSheet('#sheetHelp'));
    $('#sideRandom').addEventListener('click', () => App.randomChapter());
    $('#dRandom').addEventListener('click', () => { closeSheets(); App.randomChapter(); });
    $('#sideVotd').addEventListener('click', () => (location.href = 'index.html'));
    $('#dVotd').addEventListener('click', () => (location.href = 'index.html'));
    wireSettings();

    // highlight current page in nav
    $$('.side-item[data-page], .bnav[data-page]').forEach(el => el.classList.toggle('active', el.dataset.page === pageId));
  }

  /* ─────────── boot ─────────── */
  async function init(pageId) {
    applyPrefs();
    renderChrome(pageId);
    try { await DATA.setTranslation(S.code); }
    catch (e) { S.code = 'kjv'; STORE.set('translation', 'kjv'); await DATA.setTranslation('kjv'); }
    DATA.state.code = S.code;
    renderHeader();
    renderProgress();
    window.matchMedia?.('(prefers-color-scheme: dark)')?.addEventListener?.('change', applyPrefs);
    if ('serviceWorker' in navigator) navigator.serviceWorker.register('./sw.js').catch(() => {});
  }

  function showLoading(on) { const l = $('#loading'); if (l) l.style.display = on ? 'grid' : 'none'; }

  function fail(msg) {
    const l = $('#loading');
    if (l) l.innerHTML = `<div style="text-align:center;padding:24px;max-width:340px">⚠️ Could not load Bible data.<br><small>${esc(msg)}</small><br><br>Serve this repository over HTTP (e.g. <code>python3 -m http.server</code>), not file://.</div>`;
  }

  function randomChapter() {
    const books = DATA.state.books;
    const b = books[Math.floor(Math.random() * books.length)];
    const ch = 1 + Math.floor(Math.random() * b.chapters);
    location.href = `read.html#/${S.code}/${b.slug}/${ch}`;
  }

  /* ─────────── reading plans (shared) ─────────── */
  function planDefs() {
    const slugs = set => DATA.state.books.filter(b => set.includes(b.slug));
    return [
      { id: 'gospels', name: 'The Gospels', desc: 'Matthew, Mark, Luke & John', books: slugs(['matthew', 'mark', 'luke', 'john']) },
      { id: 'psalms', name: 'Psalms & Proverbs', desc: 'Wisdom & worship', books: slugs(['psalms', 'proverbs']) },
      { id: 'nt', name: 'New Testament', desc: 'All 27 books', books: DATA.state.books.filter(b => b.testament === 'NT') },
      { id: 'ot', name: 'Old Testament', desc: 'All 39 books', books: DATA.state.books.filter(b => b.testament === 'OT') },
      { id: 'whole', name: 'The Whole Bible', desc: 'Genesis to Revelation', books: DATA.state.books },
    ];
  }
  function planChapters(def) {
    const out = [];
    for (const b of def.books) for (let c = 1; c <= b.chapters; c++) out.push({ slug: b.slug, ch: c, book: b.name });
    return out;
  }
  function planProgress(id) {
    const def = planDefs().find(d => d.id === id);
    if (!def) return 0;
    const chapters = planChapters(def);
    if (!chapters.length) return 0;
    const read = chapters.filter(x => isRead(x.slug, x.ch)).length;
    return Math.round((read / chapters.length) * 100);
  }
  function planNext(id) {
    const def = planDefs().find(d => d.id === id);
    if (!def) return null;
    const chapters = planChapters(def);
    return chapters.find(x => !isRead(x.slug, x.ch)) || null;
  }

  /* ─────────── expose global ─────────── */
  window.App = {
    S, esc, toast, applyPrefs, hlKey, rcKey, isRead, updateStreak,
    translation: () => DATA.TRANSLATIONS.find(x => x.code === S.code) || DATA.TRANSLATIONS[0],
    bookBySlug: s => DATA.bookBySlug(s),
    bookById: i => DATA.bookById(i),
    setTranslation: async c => { S.code = c; STORE.set('translation', c); await DATA.setTranslation(c); renderHeader(); },
    getChapter: (s, c, code) => DATA.getChapter(s, c, code || S.code),
    getBundle: code => DATA.getBundle(code || S.code),
    loadBooks: code => DATA.loadBooks(code || S.code),
    openSheet, closeSheets, renderHeader, renderProgress, showLoading, fail, init, randomChapter,
    planDefs, planChapters, planProgress, planNext,
    save: (k, v) => { S[k] = v; STORE.set(k, v); },
    go: href => (location.href = href),
    TOTAL_CHAPTERS,
  };
})();
