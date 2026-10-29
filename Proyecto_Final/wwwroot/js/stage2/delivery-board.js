"use strict";
(() => {
  const root = document.querySelector("[data-snapshot-url]");
  if (!root) return;
  const body = document.getElementById("delivery-board-body");
  const status = document.getElementById("board-status");
  const pause = document.getElementById("board-pause");
  const search = document.getElementById("board-search");
  const state = document.getElementById("board-state");
  const canRoutes = root.dataset.canViewRoutes === "true";
  let paused = false, busy = false;
  const count = value => Number.isSafeInteger(value) && value >= 0;
  const text = (tag, value, className = "") => {
    const node = document.createElement(tag);
    node.textContent = String(value ?? ""); node.className = className;
    return node;
  };
  const tones = new Map([["Planificada", "warning"], ["Despachada", "info"], ["Completada", "success"], ["Cancelada", "danger"]]);
  const tone = value => tones.get(value) || "neutral";
  function filter() {
    const needle = search.value.trim().toLocaleLowerCase("es-CR");
    body.querySelectorAll("[data-board-row]").forEach(row => {
      const badge = row.querySelector(".djj-badge");
      row.hidden = !row.textContent.toLocaleLowerCase("es-CR").includes(needle) || (state.value !== "" && badge.textContent !== state.value);
    });
    const rows = Array.from(body.querySelectorAll("[data-board-row]"));
    body.querySelector("[data-board-empty]")?.remove();
    if (rows.length && rows.every(row => row.hidden)) {
      const row = document.createElement("tr"), cell = text("td", "No hay rutas que coincidan con los filtros.");
      row.dataset.boardEmpty = ""; cell.colSpan = canRoutes ? 6 : 5; row.append(cell); body.append(row);
    }
  }
  function valid(data) {
    return data && [data.rutasActivas, data.entregasPendientes, data.entregasCompletadas, data.entregasFallidas].every(count)
      && Number.isFinite(Date.parse(data.generadoUtc)) && Array.isArray(data.rutas) && data.rutas.length <= 10000
      && data.rutas.every(route => route && Number.isSafeInteger(route.rutaId) && route.rutaId > 0
        && [route.totalPedidos, route.entregados, route.fallidos, route.pendientes].every(count)
        && [route.codigo, route.zona, route.chofer, route.vehiculoPlaca, route.estado].every(value => typeof value === "string")
        && (route.fechaDespacho == null || Number.isFinite(Date.parse(route.fechaDespacho))));
  }
  function render(data) {
    const fragment = document.createDocumentFragment();
    data.rutas.forEach(route => {
      const row = document.createElement("tr"); row.dataset.boardRow = "";
      const identity = document.createElement("td"); identity.append(text("strong", route.codigo), text("small", route.zona, "djj-table__note"));
      const assignment = text("td", route.chofer); assignment.append(text("small", route.vehiculoPlaca, "djj-table__note"));
      const stateCell = document.createElement("td"); stateCell.append(text("span", route.estado, "djj-badge djj-badge--" + tone(route.estado)));
      const progress = text("td", route.totalPedidos + " pedidos"); progress.append(text("small", `${route.entregados} entregadas · ${route.fallidos} fallidas · ${route.pendientes} pendientes`, "djj-table__note"));
      row.append(identity, assignment, stateCell, text("td", route.fechaDespacho ? new Date(route.fechaDespacho).toLocaleString("es-CR") : "Sin despacho", "djj-table__nowrap"), progress);
      if (canRoutes) {
        const cell = document.createElement("td"), link = text("a", "Ver ruta " + route.codigo, "djj-button djj-button--outline");
        link.href = root.dataset.routeDetailBase.replace(/\/$/, "") + "/" + encodeURIComponent(route.rutaId);
        cell.append(link); row.append(cell);
      }
      fragment.append(row);
    });
    if (!data.rutas.length) { const row = document.createElement("tr"), cell = text("td", "No hay rutas para mostrar."); cell.colSpan = canRoutes ? 6 : 5; row.append(cell); fragment.append(row); }
    body.replaceChildren(fragment);
    [["active-routes",data.rutasActivas],["pending-deliveries",data.entregasPendientes],["completed-deliveries",data.entregasCompletadas],["failed-deliveries",data.entregasFallidas]].forEach(([id,value]) => { document.getElementById(id).textContent = value; });
    document.getElementById("board-updated").textContent = "Actualizado: " + new Date(data.generadoUtc).toLocaleTimeString("es-CR");
    const attention = document.getElementById("board-attention");
    attention.hidden = data.entregasFallidas === 0;
    attention.textContent = `Atención requerida: ${data.entregasFallidas} entrega(s) fallida(s). Consultá el detalle de las rutas para revisar los motivos.`;
    filter();
  }
  async function refresh() {
    if (paused || busy || document.hidden || body.contains(document.activeElement)) return;
    busy = true;
    const abort = new AbortController(), timeout = window.setTimeout(() => abort.abort(), 8000);
    try {
      const response = await fetch(root.dataset.snapshotUrl, { credentials: "same-origin", headers: { Accept: "application/json" }, cache: "no-store", signal: abort.signal });
      if (!response.ok || response.redirected || !response.headers.get("content-type")?.includes("application/json")) throw new Error("Snapshot unavailable");
      const data = await response.json();
      if (!valid(data)) throw new Error("Invalid snapshot");
      render(data); status.textContent = "";
    } catch { status.textContent = "No se pudo actualizar. Se conservan los últimos datos; el siguiente ciclo reintentará."; }
    finally { window.clearTimeout(timeout); busy = false; }
  }
  pause.addEventListener("click", () => { paused = !paused; pause.setAttribute("aria-pressed", String(paused)); pause.textContent = paused ? "Reanudar actualización" : "Pausar actualización"; status.textContent = paused ? "Actualización pausada." : ""; if (!paused) refresh(); });
  search.addEventListener("input", filter); state.addEventListener("change", filter);
  document.getElementById("board-filter").addEventListener("submit", event => { event.preventDefault(); filter(); });
  document.getElementById("board-filter").addEventListener("reset", () => window.setTimeout(filter, 0));
  window.setInterval(refresh, 15000);
})();
