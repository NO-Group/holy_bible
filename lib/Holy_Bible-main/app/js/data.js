/* ═══════════════ Data layer — reads the bible/ JSON dataset ═══════════════
   No frameworks, no build step. Chapters load lazily from
   bible/translations/{code}/{slug}/chapter_{n}.json ; full-text search
   and quiz use the compact bundle all.min.json (loaded on demand). */

const DATA = (() => {
  // Resolve the dataset root relative to the document (index.html at repo root).
  // Works whether the site is served from the root or a sub-path (e.g. GitHub Pages).
  const BASE = 'bible';

  const TRANSLATIONS = [
    { code: 'kjv', short: 'KJV', name: 'King James Version', desc: 'Classic English, 1611' },
    { code: 'niv', short: 'NIV', name: 'New International Version', desc: 'Modern English' },
    { code: 'nlt', short: 'NLT', name: 'New Living Translation', desc: 'Easy to read' },
    { code: 'nwt', short: 'NWT', name: 'New World Translation', desc: '2013 Revision' },
    { code: 'original', short: 'ORIG', name: 'Original Manuscripts', desc: 'Hebrew (OT) · Greek (NT)' },
  ];

  const state = {
    code: 'kjv',
    books: null,            // books.json -> books array for current translation
    booksByCode: {},        // cache
    chapterCache: {},       // key: code/slug/n
    bundle: {},             // code -> all.min.json (for search & quiz)
  };

  async function fetchJSON(url) {
    const r = await fetch(url);
    if (!r.ok) throw new Error(`HTTP ${r.status} for ${url}`);
    return r.json();
  }

  async function loadBooks(code) {
    if (!state.booksByCode[code]) {
      const bi = await fetchJSON(`${BASE}/translations/${code}/books.json`);
      state.booksByCode[code] = bi.books;
    }
    return state.booksByCode[code];
  }

  async function setTranslation(code) {
    state.code = code;
    state.books = await loadBooks(code);
    return state.books;
  }

  async function getChapter(slugName, n, code = state.code) {
    const key = `${code}/${slugName}/${n}`;
    if (!state.chapterCache[key]) {
      state.chapterCache[key] = await fetchJSON(
        `${BASE}/translations/${code}/${slugName}/chapter_${n}.json`);
      // simple cache cap
      const keys = Object.keys(state.chapterCache);
      if (keys.length > 60) delete state.chapterCache[keys[0]];
    }
    return state.chapterCache[key];
  }

  async function getBundle(code = state.code) {
    if (!state.bundle[code]) {
      state.bundle[code] = await fetchJSON(`${BASE}/translations/${code}/all.min.json`);
    }
    return state.bundle[code];
  }

  function bookBySlug(slugName) {
    return state.books.find(b => b.slug === slugName);
  }
  function bookById(id) {
    return state.books.find(b => b.id === id);
  }

  return {
    TRANSLATIONS, state,
    setTranslation, getChapter, getBundle, loadBooks, bookBySlug, bookById,
  };
})();

/* ─────────── tiny persistent store (localStorage) ─────────── */
const STORE = (() => {
  const K = 'holybible.';
  function get(key, fallback) {
    try {
      const v = localStorage.getItem(K + key);
      return v === null ? fallback : JSON.parse(v);
    } catch { return fallback; }
  }
  function set(key, val) {
    try { localStorage.setItem(K + key, JSON.stringify(val)); } catch {}
  }
  return { get, set };
})();
