/* Service worker — caches the app shell (HTML/CSS/JS) and runtime-caches
   fetched chapters so the app works offline after first use.
   Lives at the repo root so its scope covers the whole site. */
const CACHE = 'holybible-v2';
const SHELL = [
  './',
  './index.html',
  './read.html',
  './search.html',
  './plan.html',
  './quiz.html',
  './library.html',
  './app/css/style.css',
  './app/js/data.js',
  './app/js/quiz.js',
  './app/js/shell.js',
  './app/js/home.js',
  './app/js/reader.js',
  './app/js/search.js',
  './app/js/plan.js',
  './app/js/quiz-page.js',
  './app/js/library.js',
  './app/manifest.webmanifest',
  './app/icon.svg',
  './bible/translations.json',
];

self.addEventListener('install', e => {
  e.waitUntil(
    caches.open(CACHE).then(c => c.addAll(SHELL)).then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', e => {
  e.waitUntil(
    caches.keys().then(keys =>
      Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k)))
    ).then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', e => {
  const url = new URL(e.request.url);
  if (e.request.method !== 'GET' || url.origin !== location.origin) return;
  // Network-first for navigation; cache-first for the app shell & data.
  if (e.request.mode === 'navigate') {
    e.respondWith(
      fetch(e.request).catch(() => caches.match('./index.html'))
    );
    return;
  }
  e.respondWith(
    caches.match(e.request).then(cached => {
      const fetchPromise = fetch(e.request).then(res => {
        if (res && res.ok && (url.pathname.includes('/bible/') || url.pathname.includes('/app/'))) {
          const clone = res.clone();
          caches.open(CACHE).then(c => c.put(e.request, clone));
        }
        return res;
      }).catch(() => cached);
      return cached || fetchPromise;
    })
  );
});
