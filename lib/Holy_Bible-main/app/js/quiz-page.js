/* ═══════════════ quiz-page.js — quiz page controller ═══════════════ */
(() => {
  const $ = s => document.querySelector(s);
  const $$ = s => [...document.querySelectorAll(s)];
  const S = App.S;

  let quizRound = null, quizIdx = 0, quizScore = 0, quizMode = 'mixed';

  function renderQuizHome() {
    $('#quizHome').hidden = false;
    $('#quizGame').hidden = true;
    $('#quizResults').hidden = true;
    $('#qsPlayed').textContent = S.quiz.played;
    $('#qsBest').textContent = S.quiz.best + '%';
    $('#qsPoints').textContent = S.quiz.points;
  }

  async function startQuiz(mode) {
    quizMode = mode;
    App.showLoading(true);
    const code = S.code === 'original' ? 'kjv' : S.code;
    const bundle = await App.getBundle(code);
    App.showLoading(false);
    quizRound = QUIZ.buildRound(bundle, mode);
    quizIdx = 0; quizScore = 0;
    $('#quizHome').hidden = true;
    $('#quizResults').hidden = true;
    $('#quizGame').hidden = false;
    showQuestion();
  }

  function showQuestion() {
    const q = quizRound[quizIdx];
    $('#quizQnum').textContent = `Question ${quizIdx + 1} of ${quizRound.length}`;
    $('#quizProgress').style.width = `${(quizIdx / quizRound.length) * 100}%`;
    $('#quizScore').textContent = quizScore;
    $('#quizQuestion').innerHTML = App.esc(q.question) + (q.quote ? `<span class="qq-quote">${App.esc(q.quote)}</span>` : '');
    const opts = $('#quizOptions');
    opts.innerHTML = '';
    q.options.forEach((o, i) => {
      const btn = document.createElement('button');
      btn.className = 'qopt';
      btn.textContent = o;
      btn.addEventListener('click', () => answer(i));
      opts.appendChild(btn);
    });
    $('#quizFeedback').textContent = '';
    $('#quizFeedback').className = 'quiz-feedback';
    $('#quizNext').hidden = true;
  }

  function answer(i) {
    const q = quizRound[quizIdx];
    const btns = $$('#quizOptions .qopt');
    btns.forEach(b => (b.disabled = true));
    btns[q.answer].classList.add('correct');
    const fb = $('#quizFeedback');
    if (i === q.answer) {
      quizScore++;
      fb.textContent = '✓ Correct!';
      fb.className = 'quiz-feedback good';
    } else {
      btns[i].classList.add('wrong');
      fb.textContent = '✗ Not quite.';
      fb.className = 'quiz-feedback bad';
    }
    if (q.explain) fb.innerHTML += `<small>${App.esc(q.explain)}</small>`;
    $('#quizScore').textContent = quizScore;
    $('#quizNext').hidden = false;
    $('#quizNext').textContent = quizIdx + 1 < quizRound.length ? 'Next Question →' : 'See Results 🏁';
  }

  $('#quizNext').addEventListener('click', () => {
    quizIdx++;
    if (quizIdx < quizRound.length) showQuestion();
    else finishQuiz();
  });
  $('#quizQuit').addEventListener('click', renderQuizHome);

  async function finishQuiz() {
    const pct = Math.round((quizScore / quizRound.length) * 100);
    S.quiz.played++;
    S.quiz.points += quizScore * 10;
    if (pct > S.quiz.best) S.quiz.best = pct;
    STORE.set('quiz', S.quiz);
    $('#quizGame').hidden = true;
    $('#quizResults').hidden = false;
    $('#qrScore').textContent = `${quizScore}/${quizRound.length}`;
    $('#qrEmoji').textContent = pct >= 90 ? '🏆' : pct >= 70 ? '🎉' : pct >= 50 ? '💪' : '📖';
    $('#qrTitle').textContent = pct >= 90 ? 'Outstanding!' : pct >= 70 ? 'Well done!' : pct >= 50 ? 'Good effort!' : 'Keep studying!';
    try {
      const code = S.code === 'original' ? 'kjv' : S.code;
      const d = await App.getChapter('2_timothy', 2, code);
      const v = d.verses.find(x => x.verse === 15);
      if (v) $('#qrVerse').innerHTML = `${App.esc(v.text)}<b>2 Timothy 2:15</b>`;
    } catch {}
  }

  $$('.quiz-mode[data-mode]').forEach(b => b.addEventListener('click', () => startQuiz(b.dataset.mode)));
  $('#qrAgain').addEventListener('click', () => startQuiz(quizMode));
  $('#qrHome').addEventListener('click', renderQuizHome);

  App.init('quiz').then(() => {
    renderQuizHome();
    App.showLoading(false);
  }).catch(err => App.fail(String(err)));
})();
