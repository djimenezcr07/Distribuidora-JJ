(function () {
    "use strict";

    var PREFIX = "distribuidorajj:user:";
    var LEGACY_EXACT_KEYS = [
        "distribuidorajj_seller_offline_orders_v1",
        "distribuidorajj_seller_catalog_v1",
        "driverDeliveryQueue"
    ];
    var LEGACY_PREFIXES = ["driverRoute_"];

    function currentUserId() {
        var raw = document.body ? document.body.getAttribute("data-authenticated-user-id") : "";
        var value = parseInt(raw || "0", 10);
        return value > 0 ? value : 0;
    }

    function key(scope, userId) {
        if (!scope || userId <= 0) throw new Error("Se requiere usuario y ámbito de almacenamiento.");
        return PREFIX + userId + ":" + scope;
    }

    function removeSafely(storageKey) {
        try { localStorage.removeItem(storageKey); } catch (error) { /* Storage can be denied by browser policy. */ }
    }

    function removeLegacyKeys() {
        LEGACY_EXACT_KEYS.forEach(function (legacyKey) { localStorage.removeItem(legacyKey); });
        for (var index = localStorage.length - 1; index >= 0; index -= 1) {
            var candidate = localStorage.key(index);
            if (candidate && LEGACY_PREFIXES.some(function (prefix) { return candidate.indexOf(prefix) === 0; })) {
                localStorage.removeItem(candidate);
            }
        }
    }

    function read(scope) {
        var userId = currentUserId();
        if (userId <= 0) return null;

        var storageKey = key(scope, userId);
        try {
            var envelope = JSON.parse(localStorage.getItem(storageKey) || "null");
            if (!envelope || envelope.ownerUserId !== userId || !envelope.expiresAt || Date.now() >= envelope.expiresAt) {
                removeSafely(storageKey);
                return null;
            }
            return envelope.value;
        } catch (error) {
            removeSafely(storageKey);
            return null;
        }
    }

    function write(scope, value, ttlMilliseconds) {
        var userId = currentUserId();
        if (userId <= 0) throw new Error("No existe un usuario autenticado para almacenar datos privados.");
        if (!Number.isFinite(ttlMilliseconds) || ttlMilliseconds <= 0) throw new Error("El TTL debe ser positivo.");

        localStorage.setItem(key(scope, userId), JSON.stringify({
            ownerUserId: userId,
            expiresAt: Date.now() + ttlMilliseconds,
            value: value
        }));
    }

    function remove(scope) {
        var userId = currentUserId();
        if (userId > 0) localStorage.removeItem(key(scope, userId));
    }

    function clearCurrentUser() {
        var userId = currentUserId();
        if (userId <= 0) return;
        var userPrefix = PREFIX + userId + ":";
        try {
            for (var index = localStorage.length - 1; index >= 0; index -= 1) {
                var candidate = localStorage.key(index);
                if (candidate && candidate.indexOf(userPrefix) === 0) localStorage.removeItem(candidate);
            }
        } catch (error) { /* Logout must remain available when storage is denied. */ }
    }

    function purgeExpired() {
        removeLegacyKeys();
        for (var index = localStorage.length - 1; index >= 0; index -= 1) {
            var candidate = localStorage.key(index);
            if (!candidate || candidate.indexOf(PREFIX) !== 0) continue;
            try {
                var envelope = JSON.parse(localStorage.getItem(candidate) || "null");
                if (!envelope || !envelope.expiresAt || Date.now() >= envelope.expiresAt) localStorage.removeItem(candidate);
            } catch (error) {
                localStorage.removeItem(candidate);
            }
        }
    }

    window.DistribuidoraJJOfflineStorage = {
        read: read,
        write: write,
        remove: remove,
        clearCurrentUser: clearCurrentUser,
        purgeExpired: purgeExpired
    };

    try { purgeExpired(); } catch (error) { /* Keep the page usable when private storage is unavailable. */ }
    document.querySelectorAll("form[data-clear-private-storage='true']").forEach(function (form) {
        form.addEventListener("submit", clearCurrentUser);
    });
})();
