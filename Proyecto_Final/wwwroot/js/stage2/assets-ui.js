"use strict";
document.querySelectorAll("[data-djj-return-toggle]").forEach(button => {
  const panel = document.getElementById(button.dataset.djjReturnToggle);
  if (!panel) return;
  button.addEventListener("click", () => {
    panel.hidden = !panel.hidden;
    button.setAttribute("aria-expanded", String(!panel.hidden));
    if (!panel.hidden) panel.querySelector("select,input:not([type=hidden]),textarea,button")?.focus();
  });
  panel.addEventListener("keydown", event => {
    if (event.key !== "Escape") return;
    event.preventDefault(); panel.hidden = true; button.setAttribute("aria-expanded", "false"); button.focus();
  });
});
