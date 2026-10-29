"use strict";
(() => {
  const mapElement = document.getElementById("routePickerMap");
  const status = document.getElementById("route-map-status");
  if (!mapElement) return;
  const fallback = () => { mapElement.hidden = true; status.textContent = "Mapa no disponible. Ingresá el orden y las coordenadas en la tabla; los datos siguen accesibles."; };
  if (typeof L === "undefined") { fallback(); return; }
  const coordinates = row => {
    const latValue = row.querySelector(".lat-input").value.trim();
    const lngValue = row.querySelector(".lng-input").value.trim();
    if (!latValue || !lngValue) return null;
    const lat = Number(latValue), lng = Number(lngValue);
    return Number.isFinite(lat) && Number.isFinite(lng) && Math.abs(lat) <= 90 && Math.abs(lng) <= 180 ? [lat, lng] : null;
  };
  try {
    const rows = Array.from(document.querySelectorAll("#seqForm .seq-row"));
    const markers = new Map();
    let activeRow;
    const map = L.map(mapElement).setView([9.9333, -84.0833], 9);
    const tiles = L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", { maxZoom: 19, attribution: "© OpenStreetMap" }).addTo(map);
    tiles.on("tileerror", () => { status.textContent = "No se pudieron cargar algunas imágenes del mapa. La tabla permite editar coordenadas y orden."; });
    function pin(row) {
      const node = document.createElement("div");
      node.className = "route-pin";
      node.textContent = row.querySelector(".seq-input").value || "?";
      return L.divIcon({ className: "", html: node, iconSize: [28, 28], iconAnchor: [14, 14] });
    }
    function place(row) {
      const id = row.dataset.rutapedidoid, point = coordinates(row);
      if (!point) { if (markers.has(id)) { map.removeLayer(markers.get(id)); markers.delete(id); } return; }
      if (markers.has(id)) { markers.get(id).setLatLng(point).setIcon(pin(row)); return; }
      const tooltip = document.createElement("span");
      tooltip.textContent = row.dataset.label || "Parada";
      const marker = L.marker(point, { icon: pin(row), draggable: true }).addTo(map).bindTooltip(tooltip);
      marker.on("dragend", event => {
        const point = event.target.getLatLng();
        row.querySelector(".lat-input").value = point.lat.toFixed(6);
        row.querySelector(".lng-input").value = point.lng.toFixed(6);
      });
      markers.set(id, marker);
    }
    rows.forEach(row => {
      place(row);
      row.querySelector(".btn-locate").addEventListener("click", () => {
        activeRow = row;
        rows.forEach(item => { item.classList.toggle("active", item === row); item.querySelector(".btn-locate").setAttribute("aria-pressed", String(item === row)); });
        status.textContent = "Parada seleccionada. Hacé clic en el mapa o ingresá coordenadas en la tabla. Guardá para persistir los cambios.";
      });
      row.querySelectorAll(".seq-input,.lat-input,.lng-input").forEach(input => input.addEventListener("change", () => place(row)));
    });
    const bounds = rows.map(coordinates).filter(Boolean);
    if (bounds.length) map.fitBounds(L.latLngBounds(bounds).pad(0.3));
    map.on("click", event => {
      if (!activeRow) { status.textContent = "Seleccioná Ubicar en una parada antes de elegir el punto."; return; }
      activeRow.querySelector(".lat-input").value = event.latlng.lat.toFixed(6);
      activeRow.querySelector(".lng-input").value = event.latlng.lng.toFixed(6);
      place(activeRow);
    });
    window.setTimeout(() => map.invalidateSize(), 200);
  } catch { fallback(); }
})();
