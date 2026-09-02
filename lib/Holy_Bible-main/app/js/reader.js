/* ═══════════════ reader.js — reader page ═══════════════ */
(() => {
  const $ = s => document.querySelector(s);
  const $$ = s => [...document.querySelectorAll(s)];
  const S = App.S;

  let activeVerse = null;

  /* ─────────── verse sheet (bookmark / highlight / note / share) ─────────── */
  function openVerseSheet(slug, ch, v, text) {
    if (!text) return;
    activeVerse = { slug, ch, v, text };
    const book = App.bookBySlug(slug);
    $('#vsRef').textContent = `${book.name} ${ch}:${v} · ${S.code.toUpperCase()}`;
    $('#vsText').textContent = text;
    $('#vsNotebox').hidden = true;
    $('#vsNoteText').value = S.notes[App.hlKey(slug, ch, v)] || '';
    const isBm = S.bookmarks.some(b => b.slug === slug && b.ch === ch && b.v === v);
    $('#vsBookmark').innerHTML = `<span>🔖</span>${isBm ? 'Remove' : 'Bookmark'}`;
    App.openSheet('#sheetVerse');
  }

  const verseShareText = () => {
    const { slug, ch, v, text } = activeVerse;
    return `"${text}" — ${App.bookBySlug(slug).name} ${ch}:${v} (${S.code.toUpperCase()})`;
  };

  /* ─────────── reader ─────────── */
  function renderVerses(sel, data, slug, ch, isRTL, interactive) {
    const wrap = $(sel);
    wrap.innerHTML = '';
    for (const v of data.verses) {
      const div = document.createElement('div');
      div.className = 'verse';
      if (isRTL) div.classList.add('rtl');
      const color = S.highlights[App.hlKey(slug, ch, v.verse)];
      if (color) div.classList.add('hl-' + color);
      if (interactive) {
        if (S.bookmarks.some(b => b.slug === slug && b.ch === ch && b.v === v.verse)) div.classList.add('bookmarked');
        if (S.notes[App.hlKey(slug, ch, v.verse)]) div.classList.add('has-note');
      }
      if (!v.text) {
        div.classList.add('omitted');
        div.innerHTML = `<span class="vnum">${v.verse}</span>${v.merged_with ? `(joined with verse ${v.merged_with})` : '(not in this manuscript tradition)'}`;
      } else {
        div.innerHTML = `<span class="vnum">${v.verse}</span>${App.esc(v.text)}`;
      }
      div.dataset.verse = v.verse;
      if (interactive) div.addEventListener('click', () => openVerseSheet(slug, ch, v.verse, v.text));
      wrap.appendChild(div);
    }
  }

  async function loadChapter(slug, ch, { scrollVerse, silent } = {}) {
    stopAudio();
    S.slug = slug; S.chapter = ch;
    STORE.set('slug', slug); STORE.set('chapter', ch);
    const book = App.bookBySlug(slug);
    App.renderHeader();
    $('#readerBookName').textContent = book.name;
    $('#readerChapterNum').textContent = ch;

    const data = await App.getChapter(slug, ch);
    const isRTL = S.code === 'original' && book.id <= 39;
    renderVerses('#verses', data, slug, ch, isRTL, true);

    if (S.compareOn && S.code !== S.compareCode) {
      $('#versesCompare').hidden = false;
      $('#versesWrap').classList.add('compare-on');
      try {
        const cd = await App.getChapter(slug, ch, S.compareCode);
        const cBook = (await App.loadBooks(S.compareCode)).find(b => b.slug === slug);
        const cRTL = S.compareCode === 'original' && cBook && cBook.id <= 39;
        renderVerses('#versesCompare', cd, slug, ch, cRTL, false);
      } catch { $('#versesCompare').innerHTML = ''; }
    } else {
      $('#versesCompare').hidden = true;
      $('#versesWrap').classList.remove('compare-on');
    }

    $('#btnPrevCh').disabled = ch <= 1 && book.id === 1;
    $('#btnNextCh').disabled = ch >= book.chapters && book.id === 66;
    updateMarkReadBtn();
    App.updateStreak();
    if (!silent) setHash();
    if (scrollVerse) {
      setTimeout(() => {
        const el = $('#verses').querySelector(`[data-verse="${scrollVerse}"]`);
        if (el) { el.scrollIntoView({ behavior: 'smooth', block: 'center' }); el.style.background = 'var(--hl-yellow)'; setTimeout(() => (el.style.background = ''), 1800); }
      }, 120);
    }
  }

  function updateMarkReadBtn() {
    const btn = $('#btnMarkRead');
    const done = App.isRead(S.slug, S.chapter);
    btn.textContent = done ? '✓ Chapter read' : 'Mark chapter read';
    btn.classList.toggle('done', done);
  }

  function markCurrentRead() {
    const key = App.rcKey(S.slug, S.chapter);
    if (S.readChapters[key]) return;
    S.readChapters[key] = true;
    STORE.set('readChapters', S.readChapters);
    updateMarkReadBtn();
    App.renderProgress();
  }

  async function stepChapter(dir) {
    const book = App.bookBySlug(S.slug);
    let slug = S.slug, ch = S.chapter + dir;
    if (ch < 1) {
      const prev = App.bookById(book.id - 1);
      if (!prev) return;
      slug = prev.slug; ch = prev.chapters;
    } else if (ch > book.chapters) {
      const next = App.bookById(book.id + 1);
      if (!next) return;
      slug = next.slug; ch = 1;
    }
    if (dir > 0) markCurrentRead();
    await loadChapter(slug, ch);
    window.scrollTo({ top: 0 });
  }

  /* ─────────── read-aloud ─────────── */
  let speaking = false, speakQueue = [], speakIdx = 0;
  function verseLang(book) {
    if (S.code === 'original') return book.id <= 39 ? 'he-IL' : 'el-GR';
    return 'en-US';
  }
  function stopAudio() {
    if (window.speechSynthesis) speechSynthesis.cancel();
    speaking = false; speakQueue = [];
    updateAudioBtn();
    $$('#verses .verse').forEach(v => v.classList.remove('speaking'));
  }
  function updateAudioBtn() {
    $('#btnAudio').classList.toggle('active', speaking);
    $('#btnAudio .audio-ico-play').style.display = speaking ? 'none' : '';
    $('#btnAudio .audio-ico-pause').style.display = speaking ? '' : 'none';
    $('#audioLabel').textContent = speaking ? 'Stop' : 'Listen';
  }
  function speakChapter() {
    if (!window.speechSynthesis) { App.toast('Speech not supported in this browser'); return; }
    if (speaking) { stopAudio(); return; }
    const book = App.bookBySlug(S.slug);
    const lang = verseLang(book);
    const cached = DATA.state.chapterCache?.[`${S.code}/${S.slug}/${S.chapter}`];
    speakQueue = cached ? cached.verses.filter(v => v.text) : [];
    if (!speakQueue.length) { App.toast('Nothing to read'); return; }
    speaking = true; speakIdx = 0;
    updateAudioBtn();
    speakNext(lang);
  }
  function speakNext(lang) {
    if (!speaking || speakIdx >= speakQueue.length) { stopAudio(); return; }
    const v = speakQueue[speakIdx];
    const u = new SpeechSynthesisUtterance(v.text);
    u.lang = lang;
    u.rate = parseFloat($('#audioRate').value || '1');
    $$('#verses .verse').forEach(x => x.classList.remove('speaking'));
    const el = $('#verses').querySelector(`[data-verse="${v.verse}"]`);
    if (el) { el.classList.add('speaking'); el.scrollIntoView({ behavior: 'smooth', block: 'center' }); }
    u.onend = () => { speakIdx++; speakNext(lang); };
    u.onerror = () => { speakIdx++; speakNext(lang); };
    speechSynthesis.speak(u);
  }

  /* ─────────── compare ─────────── */
  function ensureCompareCode() {
    const others = DATA.TRANSLATIONS.filter(t => t.code !== S.code);
    if (!others.some(t => t.code === S.compareCode)) {
      S.compareCode = others[0] ? others[0].code : S.compareCode;
      STORE.set('compareCode', S.compareCode);
    }
    const sel = $('#compareCode');
    sel.innerHTML = '';
    for (const t of DATA.TRANSLATIONS) {
      if (t.code === S.code) continue;
      const o = document.createElement('option');
      o.value = t.code; o.textContent = t.name;
      if (t.code === S.compareCode) o.selected = true;
      sel.appendChild(o);
    }
  }
  function toggleCompare() {
    S.compareOn = !S.compareOn;
    STORE.set('compareOn', S.compareOn);
    $('#compareStrip').hidden = !S.compareOn;
    $('#btnCompare').classList.toggle('active', S.compareOn);
    if (S.compareOn) ensureCompareCode();
    loadChapter(S.slug, S.chapter, { silent: true });
  }

  const setFontSize = n => { S.fontSize = Math.max(14, Math.min(28, n)); STORE.set('fontSize', S.fontSize); App.applyPrefs(); };

  /* ─────────── book / chapter picker ─────────── */
  let pickerSlug = null;
  function renderPicker() {
    const gOT = $('#gridOT'), gNT = $('#gridNT');
    gOT.innerHTML = ''; gNT.innerHTML = '';
    for (const b of DATA.state.books) {
      const btn = document.createElement('button');
      let allRead = true;
      for (let c = 1; c <= b.chapters; c++) if (!App.isRead(b.slug, c)) { allRead = false; break; }
      btn.className = 'bookbtn' + (b.slug === S.slug ? ' current' : '') + (allRead ? ' complete' : '');
      btn.innerHTML = `${b.name}<span class="bk-dot"></span>`;
      btn.addEventListener('click', () => { pickerSlug = b.slug; showPickerChapters(b); });
      (b.testament === 'OT' ? gOT : gNT).appendChild(btn);
    }
    $('#pickerBooks').hidden = false;
    $('#pickerChapters').hidden = true;
    $('#ptabChapter').disabled = true;
    $$('.ptab').forEach(t => t.classList.toggle('active', t.dataset.pt === 'book'));
  }
  function showPickerChapters(book) {
    const grid = $('#gridChapters');
    grid.innerHTML = '';
    for (let n = 1; n <= book.chapters; n++) {
      const btn = document.createElement('button');
      btn.className = 'chapbtn' + (book.slug === S.slug && n === S.chapter ? ' current' : '') + (App.isRead(book.slug, n) ? ' read' : '');
      btn.textContent = n;
      btn.addEventListener('click', async () => { App.closeSheets(); await loadChapter(book.slug, n); });
      grid.appendChild(btn);
    }
    $('#pickerBooks').hidden = true;
    $('#pickerChapters').hidden = false;
    $('#ptabChapter').disabled = false;
    $$('.ptab').forEach(t => t.classList.toggle('active', t.dataset.pt === 'chapter'));
  }

  /* ─────────── deep links ─────────── */
  function setHash() {
    try { history.replaceState(null, '', `read.html#/${S.code}/${S.slug}/${S.chapter}`); } catch {}
  }
  function parseHash() {
    const h = location.hash.replace(/^#\/?/, '');
    if (!h) return null;
    const parts = h.split('/');
    let code = S.code, slug, ch, v;
    if (parts.length >= 4) { code = parts[0]; slug = parts[1]; ch = parts[2]; v = parts[3]; }
    else if (parts.length === 3) { code = parts[0]; slug = parts[1]; ch = parts[2]; }
    else if (parts.length === 2) { slug = parts[0]; ch = parts[1]; }
    else return null;
    if (!DATA.TRANSLATIONS.find(x => x.code === code)) code = S.code;
    const book = DATA.state.books.find(b => b.slug === slug);
    if (!book) return null;
    ch = parseInt(ch, 10);
    if (ch < 1 || ch > book.chapters) return null;
    v = v ? parseInt(v, 10) : null;
    return { code, slug, ch, v };
  }

  /* ─────────── wire events (chrome must be injected first) ─────────── */
  function wireEvents() {
    $('#vsColors').addEventListener('click', e => {
      const btn = e.target.closest('.vs-color');
      if (!btn || !activeVerse) return;
      const { slug, ch, v } = activeVerse;
      const key = App.hlKey(slug, ch, v);
      if (btn.dataset.color) S.highlights[key] = btn.dataset.color;
      else delete S.highlights[key];
      STORE.set('highlights', S.highlights);
      App.closeSheets();
      loadChapter(slug, ch, { silent: true });
      App.toast(btn.dataset.color ? 'Highlighted' : 'Highlight removed');
    });

    $('#vsBookmark').addEventListener('click', () => {
      const { slug, ch, v, text } = activeVerse;
      const book = App.bookBySlug(slug).name;
      const i = S.bookmarks.findIndex(b => b.slug === slug && b.ch === ch && b.v === v);
      if (i >= 0) { S.bookmarks.splice(i, 1); App.toast('Bookmark removed'); }
      else { S.bookmarks.push({ code: S.code, slug, ch, v, text, book }); App.toast('Bookmarked ✓'); }
      STORE.set('bookmarks', S.bookmarks);
      App.closeSheets();
      loadChapter(slug, ch, { silent: true });
    });

    $('#vsCopy').addEventListener('click', async () => {
      try { await navigator.clipboard.writeText(verseShareText()); App.toast('Copied to clipboard'); }
      catch { App.toast('Copy failed'); }
      App.closeSheets();
    });
    $('#vsShare').addEventListener('click', async () => {
      const txt = verseShareText();
      if (navigator.share) { try { await navigator.share({ text: txt }); } catch {} }
      else { try { await navigator.clipboard.writeText(txt); App.toast('Copied (no share available)'); } catch {} }
      App.closeSheets();
    });
    $('#vsNote').addEventListener('click', () => { $('#vsNotebox').hidden = !$('#vsNotebox').hidden; });
    $('#vsNoteSave').addEventListener('click', () => {
      const { slug, ch, v } = activeVerse;
      const key = App.hlKey(slug, ch, v);
      const val = $('#vsNoteText').value.trim();
      if (val) S.notes[key] = val; else delete S.notes[key];
      STORE.set('notes', S.notes);
      App.closeSheets();
      loadChapter(slug, ch, { silent: true });
      App.toast(val ? 'Note saved' : 'Note removed');
    });

    $('#btnPrevCh').addEventListener('click', () => stepChapter(-1));
    $('#btnNextCh').addEventListener('click', () => stepChapter(1));
    $('#btnMarkRead').addEventListener('click', () => {
      const key = App.rcKey(S.slug, S.chapter);
      if (S.readChapters[key]) { delete S.readChapters[key]; App.toast('Marked unread'); }
      else { S.readChapters[key] = true; App.toast('Chapter marked read ✓'); }
      STORE.set('readChapters', S.readChapters);
      updateMarkReadBtn();
      App.renderProgress();
    });
    $('#btnLibraryCta').addEventListener('click', () => (location.href = 'library.html'));

    $('#btnAudio').addEventListener('click', speakChapter);
    $('#btnCompare').addEventListener('click', toggleCompare);
    $('#compareCode').addEventListener('change', e => {
      S.compareCode = e.target.value;
      STORE.set('compareCode', S.compareCode);
      loadChapter(S.slug, S.chapter, { silent: true });
    });
    $('#fontMinusReader').addEventListener('click', () => setFontSize(S.fontSize - 1));
    $('#fontPlusReader').addEventListener('click', () => setFontSize(S.fontSize + 1));

    $('#topbarTitle').addEventListener('click', e => { e.preventDefault(); renderPicker(); App.openSheet('#sheetPicker'); });
    $$('.ptab').forEach(t => t.addEventListener('click', () => {
      if (t.dataset.pt === 'book') renderPicker();
      else if (pickerSlug) showPickerChapters(App.bookBySlug(pickerSlug));
    }));

    document.addEventListener('keydown', e => {
      if (e.target.matches('input, textarea, select')) return;
      if (e.metaKey || e.ctrlKey || e.altKey) return;
      if (e.key === 'ArrowRight') { e.preventDefault(); stepChapter(1); }
      else if (e.key === 'ArrowLeft') { e.preventDefault(); stepChapter(-1); }
      else if (e.key === 'Escape') App.closeSheets();
      else if (e.key === 'h') location.href = 'index.html';
      else if (e.key === '/') location.href = 'search.html';
    });
  }

  /* ─────────── boot ─────────── */
  App.init('read').then(async () => {
    App.showLoading(true);
    wireEvents();
    const link = parseHash();
    if (link) {
      if (link.code !== S.code) await App.setTranslation(link.code);
      S.slug = link.slug; S.chapter = link.ch;
      STORE.set('slug', link.slug); STORE.set('chapter', link.ch);
    }
    $('#compareStrip').hidden = !S.compareOn;
    $('#btnCompare').classList.toggle('active', S.compareOn);
    if (S.compareOn) ensureCompareCode();
    await loadChapter(S.slug, S.chapter, { scrollVerse: link ? link.v : null });
    App.showLoading(false);
  }).catch(err => App.fail(String(err)));
})();
