(() => {
  "use strict";

  document.querySelectorAll("img[data-djj-product-image]").forEach((image) => {
    const fallback = () => {
      if (image.dataset.djjImageMissing === "true") return;
      image.dataset.djjImageMissing = "true";
      image.removeAttribute("srcset");
      image.src = image.dataset.djjImageFallback;
    };
    image.addEventListener("error", fallback, { once: true });
    if (image.complete && image.naturalWidth === 0) fallback();
  });

  const focusableSelector = [
    "a[href]", "button:not([disabled])", "input:not([disabled])", "select:not([disabled])",
    "textarea:not([disabled])", "[tabindex]:not([tabindex='-1'])"
  ].join(",");

  const setPageLocked = (locked) => document.documentElement.toggleAttribute("data-djj-scroll-locked", locked);
  const visibleControls = (container) => [...container.querySelectorAll(focusableSelector)]
    .filter((element) => element.getClientRects().length && !element.disabled && !element.closest("[inert]"));
  const isolate = (regions) => {
    const previous = new Map();
    return (locked) => {
      regions.forEach((region) => {
        if (!region) return;
        if (locked) {
          if (!previous.has(region)) previous.set(region, region.inert);
          region.inert = true;
        } else if (previous.has(region)) {
          region.inert = previous.get(region);
        }
      });
      if (!locked) previous.clear();
    };
  };
  const trapFocus = (container, event) => {
    if (event.key !== "Tab") return;
    const controls = visibleControls(container);
    const first = controls[0];
    const last = controls[controls.length - 1];
    if (!first) return;
    if (event.shiftKey && document.activeElement === first) { event.preventDefault(); last.focus(); }
    if (!event.shiftKey && document.activeElement === last) { event.preventDefault(); first.focus(); }
  };

  const setupDrawer = (drawer) => {
    const openButton = document.querySelector(`[data-djj-drawer-open][aria-controls="${drawer.id}"]`);
    const closeButtons = drawer.querySelectorAll("[data-djj-drawer-close]");
    const scrim = document.querySelector(`[data-djj-drawer-scrim][aria-controls="${drawer.id}"]`);
    let returnFocus = null;
    const lockBackground = isolate([...document.body.children].filter((element) => element !== drawer && element !== scrim && element.tagName !== "SCRIPT"));
    drawer.inert = true;

    const close = () => {
      lockBackground(false);
      returnFocus?.focus();
      drawer.dataset.open = "false";
      drawer.setAttribute("aria-hidden", "true");
      drawer.inert = true;
      openButton?.setAttribute("aria-expanded", "false");
      if (scrim) scrim.hidden = true;
      setPageLocked(false);
    };

    const open = () => {
      returnFocus = document.activeElement;
      drawer.dataset.open = "true";
      drawer.setAttribute("aria-hidden", "false");
      drawer.inert = false;
      openButton?.setAttribute("aria-expanded", "true");
      if (scrim) scrim.hidden = false;
      setPageLocked(true);
      lockBackground(true);
      visibleControls(drawer)[0]?.focus();
    };

    openButton?.addEventListener("click", open);
    closeButtons.forEach((button) => button.addEventListener("click", close));
    scrim?.addEventListener("click", close);
    drawer.addEventListener("keydown", (event) => {
      if (event.key === "Escape") close();
      if (event.key !== "Tab") return;
      trapFocus(drawer, event);
    });
    window.matchMedia("(max-width: 63.99rem)").addEventListener("change", () => {
      if (drawer.dataset.open === "true") close();
    });
  };

  document.querySelectorAll("[data-djj-drawer]").forEach(setupDrawer);

  const workspaceSidebar = document.querySelector("[data-djj-workspace-sidebar]");
  const workspaceShell = document.querySelector("[data-djj-workspace-shell]");
  const workspaceOpen = document.querySelector("[data-djj-workspace-open]");
  const workspaceScrim = document.querySelector("[data-djj-workspace-scrim]");
  const workspaceCollapse = document.querySelector("[data-djj-workspace-collapse]");
  const workspaceClose = document.querySelector("[data-djj-workspace-close]");
  const mobileWorkspace = window.matchMedia("(max-width: 63.99rem)");
  const lockWorkspaceBackground = isolate([document.querySelector(".djj-workspace-main"), document.querySelector(".djj-skip-link")]);

  const closeWorkspace = () => {
    lockWorkspaceBackground(false);
    if (mobileWorkspace.matches && workspaceSidebar?.contains(document.activeElement)) workspaceOpen?.focus();
    workspaceSidebar?.setAttribute("data-open", "false");
    workspaceOpen?.setAttribute("aria-expanded", "false");
    workspaceSidebar?.setAttribute("aria-hidden", String(mobileWorkspace.matches));
    if (workspaceSidebar) workspaceSidebar.inert = mobileWorkspace.matches;
    workspaceSidebar?.removeAttribute("role");
    workspaceSidebar?.removeAttribute("aria-modal");
    if (workspaceScrim) workspaceScrim.hidden = true;
    setPageLocked(false);
  };

  workspaceOpen?.addEventListener("click", () => {
    workspaceSidebar?.setAttribute("data-open", "true");
    workspaceOpen.setAttribute("aria-expanded", "true");
    workspaceSidebar?.setAttribute("aria-hidden", "false");
    if (workspaceSidebar) workspaceSidebar.inert = false;
    workspaceSidebar?.setAttribute("role", "dialog");
    workspaceSidebar?.setAttribute("aria-modal", "true");
    if (workspaceScrim) workspaceScrim.hidden = false;
    setPageLocked(true);
    lockWorkspaceBackground(true);
    if (workspaceSidebar) visibleControls(workspaceSidebar)[0]?.focus();
  });
  const dismissWorkspace = () => { closeWorkspace(); workspaceOpen?.focus(); };
  workspaceScrim?.addEventListener("click", dismissWorkspace);
  workspaceClose?.addEventListener("click", dismissWorkspace);
  workspaceSidebar?.addEventListener("keydown", (event) => {
    if (!mobileWorkspace.matches) return;
    if (event.key === "Escape") dismissWorkspace();
    trapFocus(workspaceSidebar, event);
  });
  mobileWorkspace.addEventListener("change", () => {
    workspaceShell?.setAttribute("data-sidebar-collapsed", "false");
    workspaceCollapse?.setAttribute("aria-expanded", "true");
    workspaceCollapse?.setAttribute("aria-label", "Contraer navegación");
    closeWorkspace();
  });
  if (workspaceSidebar) closeWorkspace();

  workspaceCollapse?.addEventListener("click", () => {
    const collapsed = workspaceShell?.getAttribute("data-sidebar-collapsed") !== "true";
    workspaceShell?.setAttribute("data-sidebar-collapsed", String(collapsed));
    workspaceCollapse.setAttribute("aria-expanded", String(!collapsed));
    workspaceCollapse.setAttribute("aria-label", collapsed ? "Expandir navegación" : "Contraer navegación");
  });

  const connection = document.querySelector("[data-djj-connection]");
  const updateConnection = () => {
    if (!connection) return;
    connection.dataset.online = String(navigator.onLine);
    connection.textContent = navigator.onLine ? "En línea" : "Sin conexión";
  };
  window.addEventListener("online", updateConnection);
  window.addEventListener("offline", updateConnection);
  updateConnection();

  document.querySelectorAll("form[data-djj-confirm]").forEach((form) => {
    form.addEventListener("submit", (event) => {
      if (!window.confirm(form.dataset.djjConfirm)) event.preventDefault();
    });
  });

  document.querySelectorAll("button[data-djj-confirm]").forEach((button) => {
    button.addEventListener("click", (event) => {
      if (!window.confirm(button.dataset.djjConfirm)) event.preventDefault();
    });
  });

  const validationSummary = document.querySelector("[data-djj-validation-summary]");
  if (validationSummary?.textContent.trim()) validationSummary.focus();

  document.querySelectorAll("[data-djj-print]").forEach((button) => {
    button.addEventListener("click", () => window.print());
  });

  document.addEventListener("change", (event) => {
    const input = event.target.closest("input[type='file'][data-file-label]");
    if (!input) return;
    const label = document.getElementById(input.dataset.fileLabel);
    if (!label) return;
    const file = input.files?.[0];
    label.textContent = file ? `${file.name} · ${Math.max(1, Math.round(file.size / 1024))} KB` : "Ningún archivo seleccionado";
  });

  document.addEventListener("input", (event) => {
    const input = event.target.closest("[data-expense-money]");
    if (!input) return;
    const form = input.closest("form");
    const output = form?.querySelector("[data-expense-total]");
    if (!output) return;
    const total = [...form.querySelectorAll("[data-expense-money]")].reduce((sum, field) => {
      const value = Number.parseFloat(field.value);
      return Number.isFinite(value) && value > 0 ? sum + value : sum;
    }, 0);
    output.textContent = new Intl.NumberFormat("es-CR", { style: "currency", currency: "CRC" }).format(total);
  });
})();
