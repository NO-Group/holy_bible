/* ═══════════════ search.js — search page ═══════════════ */
(() => {
  const $ = s => document.querySelector(s);
  const $$ = s => [...document.querySelectorAll(s)];
  const S = App.S;

  const REF_RE = /^\s*([1-3]?\s?[a-z]+(?:\s(?:of\s)?[a-z]+)*)\s+(\d+)(?::(\d+))?\s*$/i;
  let searchTimer = null;

  function parseRef(q) {
    const m = q.match(REF_RE);
    if (!m) return null;
    const name = m[1].toLowerCase().replace(/\s+/g, ' ').trim();
    const book = DATA.state.books.find(b =>
      b.name.toLowerCase() === name ||
      b.slug.replace(/_/g, ' ') === name ||
      b.name.toLowerCase().startsWith(name));
    if (!book) return null;
    const ch = parseInt(m[2], 10);
    if (ch < 1 || ch > book.chapters) return null;
    return { book, ch, v: m[3] ? parseInt(m[3], 10) : null };
  }

  async function runSearch(q) {
    const status = $('#searchStatus');
    const out = $('#searchResults');
    out.innerHTML = '';
    const ref = parseRef(q);
    if (ref) {
      status.textContent = '';
      const a = document.createElement('a');
      a.className = 'sresult';
      a.href = `read.html#/${S.code}/${ref.book.slug}/${ref.ch}${ref.v ? '/' + ref.v : ''}`;
      a.innerHTML = `<div class="sresult-ref">📖 Go to ${ref.book.name} ${ref.ch}${ref.v ? ':' + ref.v : ''}</div>`;
      out.appendChild(a);
      if (!ref.v) return;
    }
    if (q.length < 3) { status.textContent = 'Type at least 3 characters to search.'; return; }

    status.textContent = 'Searching…';
    const bundle = await App.getBundle();
    const scope = document.querySelector('input[name="scope"]:checked').value;
    const needle = q.toLowerCase();
    const results = [];
    const from = scope === 'nt' ? 39 : 0;
    const to = scope === 'ot' ? 39 : bundle.books.length;
    for (let bi = from; bi < to && results.length < 100; bi++) {
      const book = bundle.books[bi];
      for (let c = 0; c < book.chapters.length && results.length < 100; c++) {
        const verses = book.chapters[c];
        for (let v = 0; v < verses.length && results.length < 100; v++) {
          if (verses[v] && verses[v].toLowerCase().includes(needle)) {
            results.push({ book, c: c + 1, v: v + 1, text: verses[v] });
          }
        }
      }
    }
    status.textContent = results.length
      ? `${results.length === 100 ? '100+' : results.length} result${results.length !== 1 ? 's' : ''}`
      : 'No results found.';
    const hlRe = new RegExp(`(${q.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')})`, 'ig');
    for (const r of results) {
      const a = document.createElement('a');
      a.className = 'sresult';
      a.href = `read.html#/${S.code}/${r.book.slug}/${r.c}/${r.v}`;
      a.innerHTML = `<div class="sresult-ref">${r.book.name} ${r.c}:${r.v}</div>
        <div class="sresult-text">${App.esc(r.text).replace(hlRe, '<mark>$1</mark>')}</div>`;
      out.appendChild(a);
    }
  }

  $('#searchInput').addEventListener('input', e => {
    clearTimeout(searchTimer);
    searchTimer = setTimeout(() => runSearch(e.target.value.trim()), 300);
  });
  $$('input[name="scope"]').forEach(r => r.addEventListener('change', () => {
    const q = $('#searchInput').value.trim();
    if (q) runSearch(q);
  }));

  App.init('search').then(() => {
    App.showLoading(false);
    setTimeout(() => $('#searchInput').focus(), 80);
    // support ?q= prefilled query
    const q = new URLSearchParams(location.search).get('q');
    if (q) { $('#searchInput').value = q; runSearch(q); }
  }).catch(err => App.fail(String(err)));
})();
