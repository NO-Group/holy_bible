/* ═══════════════ Quiz engine — questions generated from Scripture ═══════════════ */

const QUIZ = (() => {
  const QUESTIONS_PER_ROUND = 10;

  /* Famous verse references for "Finish the Verse" (slug, chapter, verse) */
  const FAMOUS = [
    ['genesis', 1, 1], ['genesis', 1, 27], ['exodus', 20, 3], ['exodus', 20, 12],
    ['deuteronomy', 6, 5], ['joshua', 1, 9], ['psalms', 23, 1], ['psalms', 23, 4],
    ['psalms', 119, 105], ['psalms', 46, 1], ['psalms', 27, 1], ['psalms', 121, 1],
    ['proverbs', 3, 5], ['proverbs', 3, 6], ['proverbs', 22, 6], ['ecclesiastes', 3, 1],
    ['isaiah', 40, 31], ['isaiah', 53, 5], ['isaiah', 9, 6], ['jeremiah', 29, 11],
    ['micah', 6, 8], ['matthew', 5, 16], ['matthew', 6, 33], ['matthew', 7, 7],
    ['matthew', 11, 28], ['matthew', 28, 19], ['mark', 12, 30], ['mark', 16, 15],
    ['luke', 6, 31], ['john', 1, 1], ['john', 3, 16], ['john', 8, 32],
    ['john', 11, 25], ['john', 14, 6], ['acts', 1, 8], ['romans', 3, 23],
    ['romans', 6, 23], ['romans', 8, 28], ['romans', 12, 2], ['1_corinthians', 10, 13],
    ['1_corinthians', 13, 4], ['1_corinthians', 13, 13], ['galatians', 5, 22],
    ['ephesians', 2, 8], ['philippians', 4, 6], ['philippians', 4, 13],
    ['colossians', 3, 23], ['2_timothy', 3, 16], ['hebrews', 11, 1], ['hebrews', 13, 8],
    ['james', 1, 22], ['1_peter', 5, 7], ['1_john', 1, 9], ['1_john', 4, 8],
    ['revelation', 3, 20], ['revelation', 21, 4],
  ];

  const rnd = n => Math.floor(Math.random() * n);
  const shuffle = a => { const x = [...a]; for (let i = x.length - 1; i > 0; i--) { const j = rnd(i + 1); [x[i], x[j]] = [x[j], x[i]]; } return x; };
  const sample = (a, n) => shuffle(a).slice(0, n);

  function refLabel(bundle, bIdx, c, v) {
    return `${bundle.books[bIdx].name} ${c + 1}:${v + 1}`;
  }

  /* random verse with decent length; returns {bIdx, c, v, text} */
  function randomVerse(bundle, minWords = 8, maxWords = 40) {
    for (let tries = 0; tries < 200; tries++) {
      const bIdx = rnd(bundle.books.length);
      const chapters = bundle.books[bIdx].chapters;
      const c = rnd(chapters.length);
      const v = rnd(chapters[c].length);
      const text = chapters[c][v];
      if (!text) continue;
      const w = text.split(' ').length;
      if (w >= minWords && w <= maxWords) return { bIdx, c, v, text };
    }
    return null;
  }

  /* ── question builders — each returns {question, quote?, options[], answer, explain} ── */

  function qWhichBook(bundle) {
    const ver = randomVerse(bundle);
    if (!ver) return null;
    const correct = bundle.books[ver.bIdx].name;
    const wrongPool = bundle.books.map(b => b.name).filter(n => n !== correct);
    const options = shuffle([correct, ...sample(wrongPool, 3)]);
    return {
      question: 'Which book is this verse from?',
      quote: `“${ver.text}”`,
      options,
      answer: options.indexOf(correct),
      explain: refLabel(bundle, ver.bIdx, ver.c, ver.v),
    };
  }

  function qFinishVerse(bundle) {
    const [slug, ch, vs] = FAMOUS[rnd(FAMOUS.length)];
    const bIdx = bundle.books.findIndex(b => b.slug === slug);
    if (bIdx < 0) return null;
    const text = bundle.books[bIdx].chapters[ch - 1]?.[vs - 1];
    if (!text) return null;
    const words = text.split(' ');
    if (words.length < 8) return null;
    const cut = Math.max(4, Math.floor(words.length * 0.55));
    const stem = words.slice(0, cut).join(' ');
    const correct = words.slice(cut).join(' ');
    // wrong endings: endings of other random verses
    const wrongs = [];
    for (let i = 0; i < 40 && wrongs.length < 3; i++) {
      const rv = randomVerse(bundle, 8, 50);
      if (!rv) continue;
      const w = rv.text.split(' ');
      const end = w.slice(Math.max(0, w.length - (words.length - cut))).join(' ');
      if (end && end !== correct && !wrongs.includes(end)) wrongs.push(end);
    }
    if (wrongs.length < 3) return null;
    const options = shuffle([correct, ...wrongs]);
    return {
      question: 'Finish the verse:',
      quote: `“${stem} …”`,
      options: options.map(o => `… ${o}`),
      answer: options.indexOf(correct),
      explain: `${bundle.books[bIdx].name} ${ch}:${vs}`,
    };
  }

  function qBookOrder(bundle) {
    const names = bundle.books.map(b => b.name);
    const type = rnd(3);
    if (type === 0) {                      // which comes after X?
      const i = rnd(names.length - 1);
      const correct = names[i + 1];
      const wrong = sample(names.filter(n => n !== correct && n !== names[i]), 3);
      const options = shuffle([correct, ...wrong]);
      return {
        question: `Which book comes right after ${names[i]}?`,
        options, answer: options.indexOf(correct),
        explain: `${names[i]} → ${correct}`,
      };
    }
    if (type === 1) {                      // nth book?
      const i = rnd(names.length);
      const correct = names[i];
      const wrong = sample(names.filter(n => n !== correct), 3);
      const options = shuffle([correct, ...wrong]);
      const ord = n => n + (['st','nd','rd'][((n+90)%100-10)%10-1] || 'th');
      return {
        question: `What is the ${ord(i + 1)} book of the Bible?`,
        options, answer: options.indexOf(correct),
        explain: `Book #${i + 1} is ${correct}`,
      };
    }
    // OT or NT?
    const i = rnd(names.length);
    const isOT = i < 39;
    const options = ['Old Testament', 'New Testament'];
    return {
      question: `Is ${names[i]} in the Old or New Testament?`,
      options, answer: isOT ? 0 : 1,
      explain: `${names[i]} is book #${i + 1}${isOT ? ' (OT has 39 books)' : ' (NT starts at Matthew, #40)'}`,
    };
  }

  function qChapterCount(bundle) {
    const known = bundle.books.filter(b => b.chapters.length >= 10);
    const b = known[rnd(known.length)];
    const correct = b.chapters.length;
    const wrongs = new Set();
    while (wrongs.size < 3) {
      const off = [-15, -10, -7, -5, -3, 3, 5, 7, 10, 15][rnd(10)];
      const w = correct + off;
      if (w > 0 && w !== correct) wrongs.add(w);
    }
    const options = shuffle([correct, ...wrongs]);
    return {
      question: `How many chapters does ${b.name} have?`,
      options: options.map(String),
      answer: options.indexOf(correct),
      explain: `${b.name} has ${correct} chapters`,
    };
  }

  const BUILDERS = {
    whichbook: [qWhichBook],
    whosaid: [qFinishVerse],
    order: [qBookOrder, qChapterCount],
    mixed: [qWhichBook, qFinishVerse, qBookOrder, qChapterCount],
  };

  function buildRound(bundle, mode) {
    const builders = BUILDERS[mode] || BUILDERS.mixed;
    const out = [];
    let guard = 0;
    while (out.length < QUESTIONS_PER_ROUND && guard++ < 300) {
      const q = builders[rnd(builders.length)](bundle);
      if (q && !out.some(x => x.question === q.question && x.quote === q.quote)) out.push(q);
    }
    return out;
  }

  return { buildRound, QUESTIONS_PER_ROUND };
})();
