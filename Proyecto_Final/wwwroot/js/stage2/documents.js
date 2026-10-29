"use strict";
(() => {
  const history = document.querySelector('[data-djj-document-history="true"]');
  if (history) history.focus();
  if (!window.jQuery) return;
  document.querySelectorAll("[data-djj-document-form]").forEach(form => {
    window.jQuery(form).on("invalid-form.validate", () => {
      const summary = form.querySelector("[data-djj-validation-summary]");
      if (summary) window.requestAnimationFrame(() => summary.focus());
    });
  });
})();
