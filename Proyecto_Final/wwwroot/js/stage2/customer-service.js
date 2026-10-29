"use strict";
(() => {
  document.querySelectorAll("[data-djj-service-form]").forEach(form => {
    if (window.jQuery) window.jQuery(form).on("invalid-form.validate", () => {
      const summary = form.querySelector("[data-djj-validation-summary]");
      if (summary) window.requestAnimationFrame(() => summary.focus());
    });
  });
  const state = document.getElementById("EstadoSelect");
  const marker = document.getElementById("ResolucionReq");
  const resolution = document.getElementById("ResolucionTxt");
  if (state && marker && resolution) {
    const sync = () => { const closing = state.value === "Cerrado"; marker.hidden = !closing; resolution.required = closing; };
    state.addEventListener("change", sync); sync();
  }
  document.querySelectorAll(".djj-service-warranty-form").forEach(form => {
    const select = form.querySelector('[name="estado"]');
    const text = form.querySelector('[name="resolucion"]');
    if (!select || !text) return;
    const sync = () => { text.required = select.value === "Aprobada" || select.value === "Rechazada"; };
    select.addEventListener("change", sync); sync();
  });
  const client = document.getElementById("UsuarioId");
  const invoices = document.getElementById("FacturaId");
  const invoiceForm = document.querySelector("[data-djj-invoices-url]");
  const help = document.getElementById("invoice-help");
  if (!client || !invoices || !invoiceForm) return;
  let requestVersion = 0;
  client.addEventListener("change", async () => {
    const version = ++requestVersion;
    const id = client.value;
    invoices.replaceChildren(new Option("— Sin factura asociada —", ""));
    if (help) help.textContent = "Opcional: factura del cliente seleccionado.";
    if (!id) return;
    if (help) help.textContent = "Consultando facturas del cliente…";
    try {
      const response = await fetch(invoiceForm.dataset.djjInvoicesUrl + "?usuarioId=" + encodeURIComponent(id));
      if (!response.ok) throw new Error("Invoice lookup failed");
      const data = await response.json();
      if (version !== requestVersion) return;
      data.forEach(item => invoices.add(new Option(item.texto, item.facturaId)));
      if (help) help.textContent = data.length ? "Opcional: seleccioná una factura del cliente." : "El cliente no tiene facturas disponibles; la asociación es opcional.";
    } catch {
      if (version === requestVersion && help) help.textContent = "No se pudieron consultar las facturas. Cambiá de cliente para reintentar; la asociación es opcional.";
    }
  });
})();
