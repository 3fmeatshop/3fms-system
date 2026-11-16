/* 3FMS staff app: opens even with no signal.
   Online  → always loads the newest app from the internet (and keeps a copy).
   Offline → opens the last copy kept on this phone. Server calls (Google / Supabase) are never cached. */
const C = '3fms-staff-v1';
self.addEventListener('install', e => { self.skipWaiting(); e.waitUntil(caches.open(C).then(c => c.addAll(['./', '../config.js']).catch(() => {}))); });
self.addEventListener('activate', e => { e.waitUntil(caches.keys().then(k => Promise.all(k.filter(n => n !== C && n.startsWith('3fms-staff')).map(n => caches.delete(n)))).then(() => self.clients.claim())); });
self.addEventListener('fetch', e => {
  const r = e.request, u = new URL(r.url);
  if (r.method !== 'GET' || u.origin !== location.origin) return;                 // Google, Supabase, fonts: straight to the internet
  const page = r.mode === 'navigate' || /\/staff\/(index\.html)?$/.test(u.pathname), cfg = /\/config\.js$/.test(u.pathname);
  if (!page && !cfg) return;
  const key = page ? './' : '../config.js';
  e.respondWith(fetch(r).then(res => { if (res.ok) { const cp = res.clone(); caches.open(C).then(c => c.put(key, cp)); } return res; })
    .catch(() => caches.open(C).then(c => c.match(key)).then(m => m || new Response('<h2 style="font-family:sans-serif;padding:24px">📴 No signal — open the app once with internet first.</h2>', { headers: { 'content-type': 'text/html' } }))));
});
