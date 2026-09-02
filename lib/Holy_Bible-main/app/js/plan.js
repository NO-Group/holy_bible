/* ═══════════════ plan.js — reading plans page ═══════════════ */
(() => {
  const $ = s => document.querySelector(s);
  const S = App.S;

  function renderPlan() {
    const list = $('#planList');
    list.innerHTML = '';
    const activeDef = App.planDefs().find(d => d.id === S.activePlan) || App.planDefs()[0];
    const next = App.planNext(S.activePlan);

    // today's reading card
    const today = document.createElement('div');
    if (next) {
      today.className = 'plan-today';
      today.innerHTML = `<div class="plan-today-ico">📖</div><div><b>${next.book} ${next.ch}</b><small>Continue “${activeDef.name}” — tap to read</small></div>`;
      today.addEventListener('click', () => (location.href = `read.html#/${S.code}/${next.slug}/${next.ch}`));
    } else {
      today.className = 'plan-today';
      today.innerHTML = `<div class="plan-today-ico">🎉</div><div><b>“${activeDef.name}” complete!</b><small>Well done — pick another plan below.</small></div>`;
    }
    list.appendChild(today);

    for (const def of App.planDefs()) {
      const pct = App.planProgress(def.id);
      const chapters = App.planChapters(def);
      const read = chapters.filter(x => App.isRead(x.slug, x.ch)).length;
      const isActive = def.id === S.activePlan;
      const card = document.createElement('div');
      card.className = 'plan-card';
      card.innerHTML = `
        <div class="plan-card-head">
          <div class="plan-name">${def.name}<small>${def.desc}</small></div>
          <div style="color:var(--accent);font-weight:800;font-size:15px">${pct}%</div>
        </div>
        <div class="progressbar"><div style="width:${pct}%"></div></div>
        <div class="plan-card-meta"><span>${read.toLocaleString()} of ${chapters.length.toLocaleString()} chapters</span><span>${chapters.length} ch · ${def.books.length} books</span></div>
        <div class="plan-actions">
          <button class="plan-btn" data-continue="${def.id}">${read ? 'Continue' : 'Start'}</button>
          ${isActive ? '<button class="plan-btn ghost" disabled>Current plan</button>' : '<button class="plan-btn ghost" data-set="' + def.id + '">Set as current</button>'}
        </div>`;
      list.appendChild(card);

      card.querySelector('[data-continue]').addEventListener('click', () => {
        S.activePlan = def.id;
        STORE.set('activePlan', def.id);
        const n = App.planNext(def.id);
        if (n) location.href = `read.html#/${S.code}/${n.slug}/${n.ch}`;
        else renderPlan();
      });
      const setBtn = card.querySelector('[data-set]');
      if (setBtn) setBtn.addEventListener('click', () => {
        S.activePlan = def.id;
        STORE.set('activePlan', def.id);
        renderPlan();
        App.toast(`“${def.name}” is now your plan`);
      });
    }
  }

  App.init('plan').then(() => {
    renderPlan();
    App.showLoading(false);
  }).catch(err => App.fail(String(err)));
})();
