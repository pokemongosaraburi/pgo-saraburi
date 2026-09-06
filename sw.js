/* PGO Saraburi — Service Worker */
const CACHE = 'pgo-v1';

self.addEventListener('install', e => {
  self.skipWaiting();
});
self.addEventListener('activate', e => {
  e.waitUntil(clients.claim());
});

// ── Push handler ──────────────────────────────────────────────────────────────
self.addEventListener('push', e => {
  let data = { title: 'PGO Saraburi', body: 'มีกิจกรรมใหม่!', url: '/' };
  try { data = { ...data, ...e.data.json() }; } catch (_) {}

  const options = {
    body: data.body,
    icon: '/icon-192.png',
    badge: '/icon-192.png',
    tag: 'pgo-event',
    renotify: true,
    data: { url: data.url },
  };
  // รูปภาพประกอบ (rich notification) — เบราว์เซอร์ที่รองรับ (Chrome/Android) จะแสดงเป็นภาพขนาดใหญ่ในแจ้งเตือน
  if (data.image) options.image = data.image;

  e.waitUntil(
    self.registration.showNotification(data.title, options)
  );
});

// ── Notification click: open/focus the app ────────────────────────────────────
self.addEventListener('notificationclick', e => {
  e.notification.close();
  const target = e.notification.data?.url || '/';
  e.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then(wins => {
      const existing = wins.find(w => w.url.includes(self.location.origin));
      if (existing) { existing.focus(); return existing.navigate(target); }
      return clients.openWindow(target);
    })
  );
});
