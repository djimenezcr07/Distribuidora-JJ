/*
 * CU-082 E2 — Actualización de estado de entrega con soporte offline.
 * Los cambios se encolan en localStorage y se reenvían al recuperar señal.
 * La idempotencia se garantiza en el servidor con un SyncGuid único por cambio.
 */
(function () {
    "use strict";

    var cfg = window.driverDeliveriesConfig || {};
    var STORAGE_SCOPE = "driver-delivery-queue-v2";
    var STORAGE_TTL_MS = 24 * 60 * 60 * 1000;
    var offlineStorage = window.DistribuidoraJJOfflineStorage;
    var flushing = false;

    function uuid() {
        if (window.crypto && typeof window.crypto.randomUUID === "function") {
            return window.crypto.randomUUID();
        }
        // Respaldo RFC4122 v4
        return "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g, function (c) {
            var r = (Math.random() * 16) | 0;
            var v = c === "x" ? r : (r & 0x3) | 0x8;
            return v.toString(16);
        });
    }

    function getQueue() {
        var queue = offlineStorage ? offlineStorage.read(STORAGE_SCOPE) : null;
        return Array.isArray(queue) ? queue : [];
    }

    function setQueue(q) {
        if (!offlineStorage) throw new Error("El almacenamiento privado no está disponible.");
        if (q.length === 0) {
            offlineStorage.remove(STORAGE_SCOPE);
            return;
        }
        offlineStorage.write(STORAGE_SCOPE, q, STORAGE_TTL_MS);
    }

    function enqueue(item) {
        var q = getQueue();
        q.push(item);
        setQueue(q);
        updatePendingBadge();
    }

    function updatePendingBadge() {
        var badge = document.getElementById("pendingSyncBadge");
        if (!badge) return;
        var count = getQueue().length;
        badge.textContent = count;
        badge.parentElement.hidden = count === 0;
    }

    function updateConnectionBadge() {
        var badge = document.getElementById("connectionBadge");
        if (!badge) return;
        badge.dataset.online = String(navigator.onLine);
        badge.textContent = navigator.onLine ? "En línea" : "Sin conexión";
    }

    function labelEstado(estado) {
        if (estado === "EnRuta") return "En ruta";
        return estado;
    }

    function setCardState(card, estado, pending) {
        card.setAttribute("data-estado", estado);
        var label = card.querySelector(".delivery-status-label");
        if (label) {
            label.textContent = pending ? (labelEstado(estado) + " (pendiente de sincronizar)") : labelEstado(estado);
        }
        // Deshabilitar acciones si el estado es final
        card.querySelectorAll("[data-action]").forEach(function (b) { b.disabled = estado === "Entregado" || estado === "Fallido"; });
    }

    function postUpdate(item) {
        var body = new URLSearchParams();
        body.append("rutaPedidoId", item.rutaPedidoId);
        body.append("nuevoEstado", item.nuevoEstado);
        body.append("syncGuid", item.syncGuid);
        if (item.motivoFallo) body.append("motivoFallo", item.motivoFallo);
        if (cfg.token) body.append("__RequestVerificationToken", cfg.token);

        return fetch(cfg.updateUrl, {
            method: "POST",
            headers: { "Content-Type": "application/x-www-form-urlencoded" },
            body: body.toString()
        }).then(function (resp) {
            if (resp.redirected || resp.status === 401 || resp.status === 403) {
                var sessionError = new Error("La sesión necesita verificarse. Los cambios pendientes se conservan.");
                sessionError.sessionRequired = true;
                throw sessionError;
            }
            if (!resp.ok) throw new Error("HTTP " + resp.status);
            return resp.json();
        });
    }

    function flush() {
        if (flushing) return Promise.resolve();
        if (!navigator.onLine) { updateConnectionBadge(); return Promise.resolve(); }

        flushing = true;
        var appliedOnline = false;

        function step() {
            var q = getQueue();
            if (q.length === 0) {
                flushing = false;
                updatePendingBadge();
                if (appliedOnline) {
                    // Recargar para reflejar el estado autoritativo del servidor.
                    window.location.reload();
                }
                return Promise.resolve();
            }

            var item = q[0];
            return postUpdate(item).then(function (data) {
                var rest = getQueue();
                rest = rest.filter(function (queued) { return queued.syncGuid !== item.syncGuid; });
                setQueue(rest);
                updatePendingBadge();
                if (data && data.ok) {
                    appliedOnline = true;
                } else if (data && data.message) {
                    // Error de negocio (no reintentable): informar y continuar.
                    var card = document.querySelector('.delivery-card[data-rutapedidoid="' + Number(item.rutaPedidoId) + '"]');
                    if (card && item.previousState) setCardState(card, item.previousState, false);
                    showToast(data.message, true);
                }
                return step();
            }).catch(function (error) {
                // Error de red: conservar la cola y detener el reenvío.
                flushing = false;
                updateConnectionBadge();
                updatePendingBadge();
                if (error.sessionRequired) showToast(error.message, true);
                return Promise.resolve();
            });
        }

        return step();
    }

    function showToast(message, isError) {
        var box = document.getElementById("driverToast");
        if (!box) { if (window.S3Modal) { S3Modal.info(message); } else { alert(message); } return; }
        box.textContent = message;
        box.className = "djj-field-toast" + (isError ? " djj-field-toast--error" : "");
        box.hidden = false;
        setTimeout(function () { box.hidden = true; }, 4000);
    }

    function handleAction(card, estado, motivo) {
        var item = {
            syncGuid: uuid(),
            rutaPedidoId: parseInt(card.getAttribute("data-rutapedidoid"), 10),
            nuevoEstado: estado,
            previousState: card.getAttribute("data-estado"),
            motivoFallo: motivo || null
        };
        try { enqueue(item); }
        catch (error) { showToast("No se pudo guardar el cambio en este dispositivo. La entrega sigue sin actualizarse.", true); return; }
        setCardState(card, estado, true);
        flush();
        if (!navigator.onLine) {
            showToast("Cambio guardado localmente. Se sincronizará al recuperar señal.", false);
        }
    }

    function init() {
        updateConnectionBadge();
        updatePendingBadge();

        getQueue().forEach(function (item) {
            var card = document.querySelector('.delivery-card[data-rutapedidoid="' + Number(item.rutaPedidoId) + '"]');
            if (card) setCardState(card, item.nuevoEstado, true);
        });

        document.querySelectorAll(".delivery-card").forEach(function (card) {
            card.querySelectorAll("[data-action]").forEach(function (btn) {
                btn.addEventListener("click", function () {
                    var action = btn.getAttribute("data-action");
                    if (action === "Fallido") {
                        var box = card.querySelector(".fallido-box");
                        if (box) { box.hidden = false; return; }
                    }
                    if (action === "Fallido-confirm") {
                        var input = card.querySelector(".fallido-motivo");
                        var motivo = input ? input.value.trim() : "";
                        if (!motivo) { if (input) input.focus(); showToast("Indique el motivo del fallo.", true); return; }
                        handleAction(card, "Fallido", motivo);
                        return;
                    }
                    handleAction(card, action, null);
                });
            });
        });

        window.addEventListener("online", function () { updateConnectionBadge(); flush(); });
        window.addEventListener("offline", updateConnectionBadge);

        // Intento inicial de reenvío de pendientes de sesiones anteriores.
        flush();
    }

    if (document.readyState === "loading") {
        document.addEventListener("DOMContentLoaded", init);
    } else {
        init();
    }
})();
