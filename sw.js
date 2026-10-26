// 설치 가능 조건용 최소 서비스 워커: 화면 파일은 인터넷이 있으면 항상 최신, 없으면 저장본.
const CACHE = 'teacher-calendar-v1'
self.addEventListener('install', () => self.skipWaiting())
self.addEventListener('activate', e => e.waitUntil(clients.claim()))
self.addEventListener('fetch', e => {
  const u = new URL(e.request.url)
  if (e.request.method !== 'GET' || u.origin !== location.origin) return
  e.respondWith(fetch(e.request).then(r => {
    const copy = r.clone(); caches.open(CACHE).then(c => c.put(e.request, copy)); return r
  }).catch(() => caches.match(e.request)))
})
