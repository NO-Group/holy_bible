/* ═══════════════ library.js — My Library page (bookmarks / highlights / notes) ═══════════════ */
(() => {
  const $ = s => document.querySelector(s);
  const $$ = s => [...document.querySelectorAll(s)];
  const S = App.S;
  let tab = 'bookmarks';

  function renderLibrary() {
    const list = $('#libraryList');
    list.innerHTML = '';
    $$('.lib-tab').forEach(t => t.classList.toggle('active', t.dataset.tab === tab));
    const empty = (ico, msg) => { list.innerHTML = `<div class="lib-empty"><div class="big">${ico}</div>${msg}</div>`; };

    if (tab === 'bookmarks') {
      if (!S.bookmarks.length) return empty('🔖', 'No bookmarks yet.<br>Tap any verse while reading to bookmark it.');
      for (const b of S.bookmarks) {
        const div = document.createElement('div');
        div.className = 'lib-item';
        div.innerHTML = `<div class="lib-item-ref">${b.book} ${b.ch}:${b.v} · ${(b.code || 'kjv').toUpperCase()}</div>
          <div class="lib-item-text">${App.esc(b.text)}</div>
          <button class="lib-del">✕</button>`;
        div.querySelector('.lib-del').addEventListener('click', e => {
          e.stopPropagation();
          S.bookmarks = S.bookmarks.filter(x => x !== b);
          STORE.set('bookmarks', S.bookmarks);
          renderLibrary();
        });
        div.addEventListener('click', () => (location.href = `read.html#/${b.code || S.code}/${b.slug}/${b.ch}/${b.v}`));
        list.appendChild(div);
      }
    } else if (tab === 'highlights') {
      const keys = Object.keys(S.highlights);
      if (!keys.length) return empty('🖍️', 'No highlights yet.<br>Tap a verse and pick a colour.');
      const colors = { yellow: '#f6d743', green: '#7ed99a', blue: '#7cc4f5', pink: '#f5a3c0', purple: '#c6a6f2' };
      for (const key of keys) {
        const [slug, ch, v] = key.split('/');
        const book = App.bookBySlug(slug);
        if (!book) continue;
        const div = document.createElement('div');
        div.className = 'lib-item';
        div.innerHTML = `<div class="lib-item-ref"><span class="hl-dot" style="background:${colors[S.highlights[key]]}"></span>${book.name} ${ch}:${v}</div>
          <button class="lib-del">✕</button>`;
        div.querySelector('.lib-del').addEventListener('click', e => {
          e.stopPropagation();
          delete S.highlights[key];
          STORE.set('highlights', S.highlights);
          renderLibrary();
        });
        div.addEventListener('click', () => (location.href = `read.html#/${S.code}/${slug}/${ch}/${v}`));
        list.appendChild(div);
      }
    } else {
      const keys = Object.keys(S.notes);
      if (!keys.length) return empty('📝', 'No notes yet.<br>Tap a verse → Note to write one.');
      for (const key of keys) {
        const [slug, ch, v] = key.split('/');
        const book = App.bookBySlug(slug);
        if (!book) continue;
        const div = document.createElement('div');
        div.className = 'lib-item';
        div.innerHTML = `<div class="lib-item-ref">${book.name} ${ch}:${v}</div>
          <div class="lib-item-note">${App.esc(S.notes[key])}</div>
          <button class="lib-del">✕</button>`;
        div.querySelector('.lib-del').addEventListener('click', e => {
          e.stopPropagation();
          delete S.notes[key];
          STORE.set('notes', S.notes);
          renderLibrary();
        });
        div.addEventListener('click', () => (location.href = `read.html#/${S.code}/${slug}/${ch}/${v}`));
        list.appendChild(div);
      }
    }
  }

  $$('.lib-tab').forEach(t => t.addEventListener('click', () => { tab = t.dataset.tab; renderLibrary(); }));

  App.init('library').then(() => {
    renderLibrary();
    App.showLoading(false);
  }).catch(err => App.fail(String(err)));
})();
