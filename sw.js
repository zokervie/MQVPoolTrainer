// Service worker: lưu sẵn ứng dụng để chơi không cần mạng.
const VERSION = 'mqv-v1';
const SHELL = [
  './', 'index.html', 'manifest.webmanifest', 'icons/icon-192.png', 'icons/icon-512.png',
  'src/style.css', 'src/main.js', 'src/render.js', 'src/physics.js', 'src/table.js', 'src/systems.js',
  'src/drills.js', 'src/diagram.js', 'src/textures.js', 'src/audio.js',
  'vendor/three.module.js', 'vendor/three.core.js', 'vendor/RoomEnvironment.js',
];

self.addEventListener('install', (e) => {
  e.waitUntil(caches.open(VERSION).then((c) => c.addAll(SHELL)).then(() => self.skipWaiting()));
});
self.addEventListener('activate', (e) => {
  e.waitUntil(caches.keys().then((keys) => Promise.all(keys.filter((k) => k !== VERSION).map((k) => caches.delete(k)))).then(() => self.clients.claim()));
});
// mạng trước (để luôn có bản mới), không có mạng thì dùng bản lưu
self.addEventListener('fetch', (e) => {
  if (e.request.method !== 'GET') return;
  e.respondWith(
    fetch(e.request).then((res) => {
      if (res.ok && (res.type === 'basic' || res.type === 'cors' || res.type === 'opaque')) {
        const copy = res.clone(); caches.open(VERSION).then((c) => c.put(e.request, copy));
      }
      return res;
    }).catch(() => caches.match(e.request, { ignoreSearch: true })),
  );
});
