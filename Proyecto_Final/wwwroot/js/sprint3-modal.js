/* =========================================================
   SPRINT 3 - FASE 1.3
   Modal propio reutilizable para reemplazar confirmaciones
   nativas del navegador en acciones críticas.
   ========================================================= */

(function () {
    'use strict';

    var modalState = {
        backdrop: null,
        dialog: null,
        icon: null,
        title: null,
        kicker: null,
        message: null,
        confirmBtn: null,
        cancelBtn: null,
        closeBtn: null,
        resolver: null,
        lastFocused: null
    };

    var confirmedForms = new WeakSet();

    function iconFor(type) {
        switch ((type || '').toLowerCase()) {
            case 'success': return 'fa-check-circle';
            case 'danger':
            case 'error': return 'fa-exclamation-triangle';
            case 'info': return 'fa-info-circle';
            case 'warning': return 'fa-exclamation-circle';
            default: return 'fa-question-circle';
        }
    }

    function ensureModal() {
        if (modalState.backdrop) {
            return;
        }

        var backdrop = document.createElement('div');
        backdrop.className = 's3-modal-backdrop';
        backdrop.setAttribute('aria-hidden', 'true');

        backdrop.innerHTML = '' +
            '<div class="s3-modal-dialog" role="dialog" aria-modal="true" aria-labelledby="s3ModalTitle" aria-describedby="s3ModalMessage" data-type="warning">' +
            '  <div class="s3-modal-head">' +
            '    <div class="s3-modal-icon"><i class="fa fa-question-circle"></i></div>' +
            '    <div>' +
            '      <h2 class="s3-modal-title" id="s3ModalTitle">Confirmar acción</h2>' +
            '      <p class="s3-modal-kicker">Revisá la información antes de continuar.</p>' +
            '    </div>' +
            '    <button type="button" class="s3-modal-close" aria-label="Cerrar"><i class="fa fa-times"></i></button>' +
            '  </div>' +
            '  <div class="s3-modal-body">' +
            '    <p class="s3-modal-message" id="s3ModalMessage"></p>' +
            '  </div>' +
            '  <div class="s3-modal-actions">' +
            '    <button type="button" class="btn btn-outline-dark s3-modal-btn-cancel">Cancelar</button>' +
            '    <button type="button" class="btn btn-primary s3-modal-btn-confirm">Continuar</button>' +
            '  </div>' +
            '</div>';

        document.body.appendChild(backdrop);

        modalState.backdrop = backdrop;
        modalState.dialog = backdrop.querySelector('.s3-modal-dialog');
        modalState.icon = backdrop.querySelector('.s3-modal-icon i');
        modalState.title = backdrop.querySelector('#s3ModalTitle');
        modalState.kicker = backdrop.querySelector('.s3-modal-kicker');
        modalState.message = backdrop.querySelector('#s3ModalMessage');
        modalState.confirmBtn = backdrop.querySelector('.s3-modal-btn-confirm');
        modalState.cancelBtn = backdrop.querySelector('.s3-modal-btn-cancel');
        modalState.closeBtn = backdrop.querySelector('.s3-modal-close');

        modalState.confirmBtn.addEventListener('click', function () { closeModal(true); });
        modalState.cancelBtn.addEventListener('click', function () { closeModal(false); });
        modalState.closeBtn.addEventListener('click', function () { closeModal(false); });

        backdrop.addEventListener('click', function (event) {
            if (event.target === backdrop) {
                closeModal(false);
            }
        });

        document.addEventListener('keydown', function (event) {
            if (!modalState.backdrop || !modalState.backdrop.classList.contains('is-open')) {
                return;
            }

            if (event.key === 'Escape') {
                event.preventDefault();
                closeModal(false);
            }
        });
    }

    function closeModal(result) {
        if (!modalState.backdrop || !modalState.backdrop.classList.contains('is-open')) {
            return;
        }

        modalState.backdrop.classList.remove('is-open');
        modalState.backdrop.setAttribute('aria-hidden', 'true');
        document.body.classList.remove('s3-modal-lock');

        var resolver = modalState.resolver;
        modalState.resolver = null;

        if (modalState.lastFocused && typeof modalState.lastFocused.focus === 'function') {
            setTimeout(function () {
                try { modalState.lastFocused.focus(); } catch (e) { }
            }, 0);
        }

        if (typeof resolver === 'function') {
            resolver(!!result);
        }
    }

    function openModal(options) {
        ensureModal();

        var settings = options || {};
        var type = settings.type || 'warning';
        var isAlert = settings.mode === 'alert';

        modalState.lastFocused = document.activeElement;
        modalState.dialog.setAttribute('data-type', type);
        modalState.icon.className = 'fa ' + iconFor(type);
        modalState.title.textContent = settings.title || (isAlert ? 'Mensaje del sistema' : 'Confirmar acción');
        modalState.kicker.textContent = settings.kicker || (isAlert ? 'Información importante.' : 'Revisá la información antes de continuar.');
        modalState.message.textContent = settings.message || '¿Desea continuar?';
        modalState.confirmBtn.textContent = settings.okText || (isAlert ? 'Entendido' : 'Continuar');
        modalState.cancelBtn.textContent = settings.cancelText || 'Cancelar';
        modalState.cancelBtn.style.display = isAlert ? 'none' : '';

        modalState.backdrop.classList.add('is-open');
        modalState.backdrop.setAttribute('aria-hidden', 'false');
        document.body.classList.add('s3-modal-lock');

        setTimeout(function () {
            modalState.confirmBtn.focus();
        }, 30);

        return new Promise(function (resolve) {
            modalState.resolver = resolve;
        });
    }

    function readOptionsFromElement(element) {
        return {
            title: element.getAttribute('data-s3-confirm-title') || 'Confirmar acción',
            message: element.getAttribute('data-s3-confirm') || '¿Desea continuar?',
            type: element.getAttribute('data-s3-confirm-type') || 'warning',
            okText: element.getAttribute('data-s3-confirm-ok') || 'Sí, continuar',
            cancelText: element.getAttribute('data-s3-confirm-cancel') || 'Cancelar',
            kicker: element.getAttribute('data-s3-confirm-kicker') || 'Esta acción puede modificar información del sistema.'
        };
    }

    function initializeConfirmInterceptors() {
        document.addEventListener('submit', function (event) {
            var form = event.target;

            if (!form || !form.matches || !form.matches('form[data-s3-confirm]')) {
                return;
            }

            if (confirmedForms.has(form)) {
                confirmedForms.delete(form);
                return;
            }

            event.preventDefault();
            event.stopPropagation();

            openModal(readOptionsFromElement(form)).then(function (accepted) {
                if (!accepted) {
                    return;
                }

                confirmedForms.add(form);

                if (typeof form.requestSubmit === 'function') {
                    form.requestSubmit();
                } else {
                    form.submit();
                }
            });
        }, true);

        document.addEventListener('click', function (event) {
            var link = event.target && event.target.closest ? event.target.closest('a[data-s3-confirm]') : null;

            if (!link) {
                return;
            }

            event.preventDefault();
            event.stopPropagation();

            openModal(readOptionsFromElement(link)).then(function (accepted) {
                if (accepted && link.href) {
                    window.location.href = link.href;
                }
            });
        }, true);
    }

    window.S3Modal = {
        confirm: function (options) {
            return openModal(Object.assign({ mode: 'confirm' }, options || {}));
        },
        alert: function (options) {
            return openModal(Object.assign({ mode: 'alert' }, options || {}));
        },
        success: function (message, title) {
            return openModal({ mode: 'alert', type: 'success', title: title || 'Proceso completado', message: message, okText: 'Entendido' });
        },
        error: function (message, title) {
            return openModal({ mode: 'alert', type: 'error', title: title || 'No se pudo completar', message: message, okText: 'Entendido' });
        },
        warning: function (message, title) {
            return openModal({ mode: 'alert', type: 'warning', title: title || 'Atención', message: message, okText: 'Entendido' });
        },
        info: function (message, title) {
            return openModal({ mode: 'alert', type: 'info', title: title || 'Información', message: message, okText: 'Entendido' });
        }
    };

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', initializeConfirmInterceptors);
    } else {
        initializeConfirmInterceptors();
    }
})();
