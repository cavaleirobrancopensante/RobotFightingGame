self.addEventListener('install', function () { self.skipWaiting(); });
self.addEventListener('activate', function (event) {
	event.waitUntil((async function () {
		var keys = await caches.keys();
		await Promise.all(keys.map(function (k) { return caches.delete(k); }));
		await self.registration.unregister();
		var all = await self.clients.matchAll({ type: 'window' });
		all.forEach(function (c) { c.navigate(c.url); });
	})());
});
