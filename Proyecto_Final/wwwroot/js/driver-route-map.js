(function () {
    "use strict";
    var cfg = window.driverRouteConfig || {};
    var storage = window.DistribuidoraJJOfflineStorage;
    var scope = "driver-route-v2:" + cfg.routeId;
    var stops = Array.isArray(cfg.stops) ? cfg.stops : [];
    var banner = document.getElementById("noCoordsBanner");

    document.getElementById("refreshRouteBtn")?.addEventListener("click", function () { window.location.reload(); });
    if (!navigator.onLine) {
        try {
            var cached = storage?.read(scope);
            if (Array.isArray(cached) && cached.length) {
                stops = cached;
                var offlineBanner = document.getElementById("mapOfflineBanner");
                offlineBanner.textContent = "Sin conexión: se muestran las paradas guardadas. El mapa requiere conexión.";
                offlineBanner.hidden = false;
            }
        } catch (error) { /* Live stop details remain available below the map. */ }
    } else {
        try { storage?.write(scope, stops, 12 * 60 * 60 * 1000); }
        catch (error) { /* A denied cache must not prevent route navigation. */ }
    }

    stops = stops.filter(function (stop) {
        return stop && Number.isFinite(Number(stop.lat)) && Number.isFinite(Number(stop.lng))
            && stop.lat !== null && stop.lng !== null && Math.abs(Number(stop.lat)) <= 90 && Math.abs(Number(stop.lng)) <= 180;
    }).sort(function (a, b) { return Number(a.seq) - Number(b.seq); });
    if (!stops.length) { banner.hidden = false; return; }
    if (!window.L) {
        banner.textContent = "No se pudo cargar el mapa. Podés usar los enlaces de navegación de cada entrega.";
        banner.hidden = false;
        return;
    }

    var map = L.map("routeMap");
    var accent = getComputedStyle(document.documentElement).getPropertyValue("--djj-color-primary").trim();
    L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", { maxZoom: 19, attribution: "© OpenStreetMap" }).addTo(map);
    var coordinates = [];
    stops.forEach(function (stop) {
        var ll = [Number(stop.lat), Number(stop.lng)];
        coordinates.push(ll);
        var pin = document.createElement("div");
        pin.className = "djj-field-route-pin";
        pin.textContent = String(stop.seq);
        var icon = L.divIcon({ className: "", html: pin, iconSize: [26, 26], iconAnchor: [13, 13] });
        var popup = document.createElement("div");
        var title = document.createElement("strong");
        var address = document.createElement("span");
        var status = document.createElement("em");
        title.textContent = "#" + stop.seq + " · " + stop.cliente;
        address.textContent = stop.dir;
        status.textContent = stop.estado;
        popup.append(title, document.createElement("br"), address, document.createElement("br"), status);
        L.marker(ll, { icon: icon }).addTo(map).bindPopup(popup);
    });
    if (coordinates.length > 1) L.polyline(coordinates, { color: accent, weight: 3, opacity: 0.7 }).addTo(map);
    map.fitBounds(L.latLngBounds(coordinates).pad(0.2));
    // Reconnection is handled by driver-deliveries.js; reloading here would cancel queue synchronization.
})();
