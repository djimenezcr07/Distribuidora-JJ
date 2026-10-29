"use strict";
document.querySelectorAll("[data-djj-toggle]").forEach(button => {
  const panel = document.getElementById(button.dataset.djjToggle);
  if (!panel) return;
  button.addEventListener("click", () => {
    panel.hidden = !panel.hidden;
    button.setAttribute("aria-expanded", String(!panel.hidden));
    if (!panel.hidden) panel.querySelector("input:not([type=hidden]),textarea,select,button")?.focus();
  });
});
document.querySelectorAll("[data-djj-evidence]").forEach(figure => {
  const image = figure.querySelector("img");
  const fallback = figure.querySelector("figcaption");
  const unavailable = () => { image.hidden = true; fallback.hidden = false; };
  image.addEventListener("error", unavailable);
  if (image.complete && image.naturalWidth === 0) unavailable();
});
