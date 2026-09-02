/* ═══════════════ home.js — home page ═══════════════ */
(() => {
  const $ = s => document.querySelector(s);
  const S = App.S;

  const VOTD_REFS = [
    ['john', 3, 16], ['psalms', 23, 1], ['philippians', 4, 13], ['jeremiah', 29, 11],
    ['romans', 8, 28], ['proverbs', 3, 5], ['isaiah', 40, 31], ['joshua', 1, 9],
    ['psalms', 46, 1], ['matthew', 11, 28], ['1_corinthians', 13, 4], ['galatians', 5, 22],
    ['ephesians', 2, 8], ['hebrews', 11, 1], ['james', 1, 5], ['1_peter', 5, 7],
    ['psalms', 119, 105], ['romans', 12, 2], ['colossians', 3, 23], ['micah', 6, 8],
    ['zephaniah', 3, 17], ['lamentations', 3, 22], ['psalms', 27, 1], ['john', 14, 6],
    ['matthew', 6, 33], ['isaiah', 41, 10], ['2_timothy', 1, 7], ['1_john', 4, 19],
    ['psalms', 118, 24], ['revelation', 21, 4], ['deuteronomy', 31, 6],
  ];

  function renderBookGrids() {
    const gOT = $('#bookGridOT'), gNT = $('#bookGridNT');
    gOT.innerHTML = ''; gNT.innerHTML = '';
    for (const b of DATA.state.books) {
      const a = document.createElement('a');
      a.className = 'bookbtn' + (b.slug === S.slug ? ' current' : '');
      a.href = `read.html#/${S.code}/${b.slug}/1`;
      a.textContent = b.name;
      a.title = `${b.name} — ${b.chapters} chapters`;
      (b.testament === 'OT' ? gOT : gNT).appendChild(a);
    }
  }

  async function renderHome() {
    const now = new Date();
    $('#homeDate').textContent = now.toLocaleDateString(undefined, { weekday: 'long', month: 'long', day: 'numeric' });
    const h = now.getHours();
    $('#homeGreet').textContent = h < 12 ? 'Good morning ☀️' : h < 17 ? 'Good afternoon 🌤' : 'Good evening 🌙';

    const dayIdx = Math.floor(now.getTime() / 864e5) % VOTD_REFS.length;
    const [slug, ch, v] = VOTD_REFS[dayIdx];
    try {
      const data = await App.getChapter(slug, ch);
      const verse = data.verses.find(x => x.verse === v);
      const book = App.bookBySlug(slug);
      $('#votdText').textContent = verse && verse.text ? verse.text : '';
      $('#votdRef').textContent = `${book.name} ${ch}:${v} · ${S.code.toUpperCase()}`;
      $('#votdRead').dataset.href = `read.html#/${S.code}/${slug}/${ch}/${v}`;
    } catch {}

    const book = App.bookBySlug(S.slug);
    $('#tileContinue').textContent = `${book ? book.name : ''} ${S.chapter}`;
    $('#tileLibrary').textContent = `${S.bookmarks.length} bookmark${S.bookmarks.length !== 1 ? 's' : ''}`;
    $('#tileQuiz').textContent = S.quiz.played ? `Best: ${S.quiz.best}%` : 'Test your knowledge';
    $('#tilePlan').textContent = App.planProgress(S.activePlan) + '% complete';
    $('#streakDays').textContent = `${S.streak.days} day${S.streak.days !== 1 ? 's' : ''}`;
  }

  $('#votdRead').addEventListener('click', () => {
    const href = $('#votdRead').dataset.href;
    if (href) location.href = href;
  });
  $('#votdShare').addEventListener('click', async () => {
    const txt = `"${$('#votdText').textContent}" — ${$('#votdRef').textContent}`;
    if (navigator.share) { try { await navigator.share({ text: txt }); } catch {} }
    else { try { await navigator.clipboard.writeText(txt); App.toast('Copied to clipboard'); } catch {} }
  });
  $('#votdCopy').addEventListener('click', async () => {
    const txt = `"${$('#votdText').textContent}" — ${$('#votdRef').textContent}`;
    try { await navigator.clipboard.writeText(txt); App.toast('Copied to clipboard'); } catch { App.toast('Copy failed'); }
  });
  $('#tileRandom').addEventListener('click', e => { e.preventDefault(); App.randomChapter(); });

  App.init('home').then(() => {
    renderBookGrids();
    renderHome().then(() => App.showLoading(false)).catch(err => App.fail(String(err)));
  }).catch(err => App.fail(String(err)));
})();
