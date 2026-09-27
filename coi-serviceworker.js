/*! coi-serviceworker v0.1.7 - Guido Zuidhof and nicolo-ribaudo, licensed under MIT */
/*
 * This service worker intercepts all fetch requests and adds the
 * Cross-Origin-Embedder-Policy and Cross-Origin-Opener-Policy headers
 * needed for SharedArrayBuffer support on GitHub Pages (which doesn't
 * let you set custom headers).
 */
if (typeof window === 'undefined') {
    // Service Worker install/activate
    self.addEventListener("install", () => self.skipWaiting());
    self.addEventListener("activate", (event) =>
        event.waitUntil(self.clients.claim())
    );

    self.addEventListener("fetch", function (event) {
        if (
            event.request.cache === "only-if-cached" &&
            event.request.mode !== "same-origin"
        ) {
            return;
        }

        event.respondWith(
            fetch(event.request).then((response) => {
                if (response.status === 0) {
                    return response;
                }

                const newHeaders = new Headers(response.headers);
                newHeaders.set(
                    "Cross-Origin-Embedder-Policy",
                    "require-corp"
                );
                newHeaders.set("Cross-Origin-Opener-Policy", "same-origin");

                return new Response(response.body, {
                    status: response.status,
                    statusText: response.statusText,
                    headers: newHeaders,
                });
            })
        );
    });
} else {
    // Window context — register the service worker
    (async function () {
        if ("serviceWorker" in navigator) {
            const registration = await navigator.serviceWorker.register(
                window.document.currentScript.src
            );

            if (registration.active && !navigator.serviceWorker.controller) {
                // The page was loaded before the service worker was active.
                // Reload so the service worker can intercept requests.
                window.location.reload();
            }
        }
    })();
}
