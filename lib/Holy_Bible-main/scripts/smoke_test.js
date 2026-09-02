/* Smoke test: load each page in jsdom against a running http.server and
   report runtime errors / boot completion.
   Requires jsdom: `npm i jsdom` (then run `node scripts/smoke_test.js`
   while `python3 -m http.server 8000` is serving the repo root). */
let jsdom;
try { jsdom = require('jsdom'); }
catch { try { jsdom = require('/tmp/node_modules/jsdom'); } catch { console.error('jsdom not found — run `npm i jsdom`'); process.exit(2); } }
const { JSDOM, VirtualConsole } = jsdom;

const BASE = process.env.BASE || 'http://localhost:8000';
const pages = ['index.html', 'read.html', 'search.html', 'plan.html', 'quiz.html', 'library.html'];
const IGNORE = /fonts\.(googleapis|gstatic)|Could not load (link|img|external)|serviceWorker|navigator\.share/i;

function loadPage(path) {
  return new Promise((resolve) => {
    const errors = [];
    const vc = new VirtualConsole();
    vc.on('jsdomError', e => { if (!IGNORE.test(e.message)) errors.push('jsdomError: ' + e.message); });
    vc.on('error', (...a) => { const m = a.join(' '); if (!IGNORE.test(m)) errors.push('console.error: ' + m); });

    JSDOM.fromURL(`${BASE}/${path}`, {
      resources: 'usable',
      runScripts: 'dangerously',
      pretendToBeVisual: true,
      virtualConsole: vc,
      beforeParse(window) {
        window.fetch = (u, o) => globalThis.fetch(new URL(u, window.location.href).href, o);
        window.matchMedia = q => ({ matches: false, media: q, addEventListener() {}, removeEventListener() {}, addListener() {}, removeListener() {} });
        window.scrollTo = () => {};
        if (!window.HTMLElement.prototype.scrollIntoView) window.HTMLElement.prototype.scrollIntoView = () => {};
      },
    }).then(dom => {
      const start = Date.now();
      const finish = () => {
        const d = dom.window.document;
        const main = d.getElementById('main');
        const loading = d.getElementById('loading');
        const doneState = loading && (loading.style.display === 'none' || loading.innerHTML.includes('Could not load'));
        resolve({ path, errors, hasContent: !!(main && main.children.length > 0), doneState, title: d.title });
        dom.window.close();
      };
      (function poll() {
        const d = dom.window.document;
        const loading = d && d.getElementById('loading');
        const main = d && d.getElementById('main');
        const doneState = loading && (loading.style.display === 'none' || loading.innerHTML.includes('Could not load'));
        if (doneState && main && main.children.length > 0) return finish();
        if (Date.now() - start > 5000) return finish();
        setTimeout(poll, 100);
      })();
    }).catch(err => resolve({ path, errors: [String(err)], hasContent: false, doneState: false }));
  });
}

(async () => {
  let ok = true;
  for (const p of pages) {
    const r = await loadPage(p);
    const good = r.hasContent && r.doneState && r.errors.length === 0;
    if (!good) ok = false;
    console.log(`${good ? 'PASS' : 'FAIL'}  ${r.path}  content=${r.hasContent} bootDone=${r.doneState}  [${r.title}]`);
    r.errors.forEach(e => console.log('        ' + e));
  }
  process.exit(ok ? 0 : 1);
})();
