const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const root = path.resolve(__dirname, '../..');
const view = fs.readFileSync(path.join(root, 'Proyecto_Final/Views/SellerOrders/Index.cshtml'), 'utf8');
const sellerScript = view.match(/<script>([\s\S]*?)<\/script>/)[1].replace('@Url.Action("SyncOffline", "SellerOrders")', '/mock-sync');
const layouts = fs.readFileSync(path.join(root, 'Proyecto_Final/wwwroot/js/stage2/layouts.js'), 'utf8');
const clone = value => JSON.parse(JSON.stringify(value));

function setup({ online = true, orders = [], response = { ok: true, success: true, pedidoId: 42, redirectUrl: '/SellerOrders/Confirmation/42' } } = {}) {
  const elements = new Map();
  const windowHandlers = {};
  const writes = []; const requests = [];
  let stored = clone(orders);
  function element(id) {
    const classes = new Set();
    const el = { id, value: '', textContent: '', innerHTML: '', hidden: false, dataset: {}, handlers: {}, attrs: {},
      addEventListener(name, handler) { this.handlers[name] = handler; },
      setAttribute(name, value) { this.attrs[name] = value; },
      classList: { toggle(name, force) { if (force ?? !classes.has(name)) classes.add(name); else classes.delete(name); }, add(name) { classes.add(name); }, remove(name) { classes.delete(name); } }
    };
    elements.set(id, el); return el;
  }
  for (const id of ['productSearch', 'selectedItems', 'selectedUnits', 'selectedTotal', 'ClienteUsuarioId', 'DireccionEntrega', 'TipoEntrega', 'IdentificacionCliente', 'Observaciones', 'sellerOrderForm', 'saveOfflineOrder', 'connectionStatus', 'connectionStatusText', 'pendingOrdersCount', 'togglePendingOrders', 'syncPendingOrders', 'clearSyncedOrders', 'pendingOrdersPanel', 'pendingOrdersList', 'sellerOfflineMessage']) element(id);
  const item = element('item'); item.dataset = { productId: '8', name: 'agua', category: 'bebidas', displayName: 'Agua', stock: '5' }; item.style = {};
  const quantity = element('quantity'); quantity.value = '0'; quantity.dataset = { price: '650', stock: '5' }; quantity.closest = () => item;
  const client = elements.get('ClienteUsuarioId'); client.value = '3'; client.selectedIndex = 0; client.options = [{ getAttribute: () => 'Dirección conocida' }];
  elements.get('TipoEntrega').value = 'Entrega por vendedor'; elements.get('DireccionEntrega').value = 'Dirección del pedido';
  const form = elements.get('sellerOrderForm'); form.querySelector = () => ({ value: 'fake-antiforgery' }); form.reset = () => { form.resetCount = (form.resetCount || 0) + 1; };
  const document = { getElementById: id => elements.get(id), querySelectorAll: selector => selector === '.seller-product-item' ? [item] : [quantity] };
  const navigator = { onLine: online };
  const window = { crypto: { randomUUID: () => '11111111-1111-4111-8111-111111111111' }, addEventListener(name, handler) { windowHandlers[name] = handler; }, DistribuidoraJJOfflineStorage: {
    read(scope) { assert.equal(scope, 'seller-offline-orders-v2'); return clone(stored); },
    write(scope, value, ttl) { writes.push({ scope, value: clone(value), ttl }); stored = clone(value); }
  } };
  const fetch = async (url, options) => { requests.push({ url, ...options }); return { ok: response.ok, json: async () => clone(response) }; };
  vm.runInNewContext(sellerScript, { document, window, navigator, fetch });
  return { elements, item, quantity, navigator, writes, requests, windowHandlers, stored: () => clone(stored) };
}
function pending() { return { pedidoOfflineGuid: 'existing-guid', clienteUsuarioId: 3, tipoEntrega: 'Entrega por vendedor', direccionEntrega: 'Dirección', identificacionCliente: '', observaciones: '', productos: [{ productoId: 8, cantidad: 2 }], totalItems: 2, estadoOffline: 'Pendiente', creadoEn: '2026-10-08T12:00:00Z' }; }

test('GET initialization renders existing queue without sync, submit or storage writes', () => {
  const app = setup({ orders: [pending()] });
  assert.equal(app.requests.length, 0); assert.equal(app.writes.length, 0);
  assert.equal(app.elements.get('pendingOrdersCount').textContent, 1);
  assert.match(app.elements.get('pendingOrdersList').innerHTML, /Pendiente/);
});
test('selection estimate preserves quantity, units and es-CR money', () => {
  const app = setup(); app.quantity.value = '2'; app.quantity.handlers.input();
  assert.equal(app.elements.get('selectedItems').textContent, 1);
  assert.equal(app.elements.get('selectedUnits').textContent, 2);
  assert.match(app.elements.get('selectedTotal').textContent, /^₡1\s?300,00$/);
  assert.equal(app.requests.length, 0);
});
test('catalog filter and customer address do not discard quantity or existing address', () => {
  const app = setup(); app.quantity.value = '2';
  const search = app.elements.get('productSearch'); search.value = 'otro'; search.handlers.input(); assert.equal(app.item.style.display, 'none');
  search.value = 'bebidas'; search.handlers.input(); assert.equal(app.item.style.display, ''); assert.equal(app.quantity.value, '2');
  const address = app.elements.get('DireccionEntrega'); app.elements.get('ClienteUsuarioId').handlers.change(); assert.equal(address.value, 'Dirección del pedido');
  address.value = ''; app.elements.get('ClienteUsuarioId').handlers.change(); assert.equal(address.value, 'Dirección conocida');
});
test('offline validation rejects missing client and excessive quantity without writing queue', () => {
  const app = setup({ online: false }); app.quantity.value = '6'; app.elements.get('ClienteUsuarioId').value = '0';
  app.elements.get('saveOfflineOrder').handlers.click();
  assert.equal(app.writes.length, 0); assert.equal(app.requests.length, 0);
  assert.equal(app.elements.get('sellerOfflineMessage').hidden, false);
});
test('offline submit prevents POST and retains GUID, 24-hour TTL and minimal product payload', () => {
  const app = setup({ online: false }); app.quantity.value = '2'; let prevented = false;
  app.elements.get('sellerOrderForm').handlers.submit({ preventDefault() { prevented = true; } });
  assert.equal(prevented, true); assert.equal(app.requests.length, 0); assert.equal(app.writes.length, 1);
  assert.equal(app.writes[0].ttl, 24 * 60 * 60 * 1000);
  const order = app.stored()[0]; assert.equal(order.pedidoOfflineGuid, '11111111-1111-4111-8111-111111111111');
  assert.deepEqual(order.productos, [{ productoId: 8, cantidad: 2 }]);
  assert.equal(order.estadoOffline, 'Pendiente'); assert.equal(order.totalItems, 2);
  assert.equal(order.clienteNombre, undefined); assert.equal(order.productos[0].precio, undefined);
  assert.equal(app.elements.get('pendingOrdersPanel').hidden, false); assert.equal(app.elements.get('togglePendingOrders').attrs['aria-expanded'], 'true');
});
test('sync mock preserves antiforgery, idempotency GUID and server response destination', async () => {
  const app = setup({ orders: [pending()] }); await app.elements.get('syncPendingOrders').handlers.click();
  assert.equal(app.requests.length, 1); const request = app.requests[0]; assert.equal(request.url, '/mock-sync'); assert.equal(request.method, 'POST');
  assert.equal(request.headers.RequestVerificationToken, 'fake-antiforgery');
  const body = JSON.parse(request.body); assert.equal(body.pedidoOfflineGuid, 'existing-guid'); assert.deepEqual(body.productos, [{ productoId: 8, cantidad: 2 }]);
  assert.equal(body.total, undefined); assert.equal(app.stored()[0].estadoOffline, 'Sincronizado'); assert.equal(app.stored()[0].pedidoId, 42);
  assert.equal(app.stored()[0].redirectUrl, '/SellerOrders/Confirmation/42'); assert.equal(app.elements.get('syncPendingOrders').disabled, false);
});
test('failed sync remains retryable with original GUID and visible server error', async () => {
  const app = setup({ orders: [pending()], response: { ok: true, success: false, message: 'Disponibilidad insuficiente' } });
  await app.elements.get('syncPendingOrders').handlers.click(); await app.elements.get('syncPendingOrders').handlers.click();
  assert.equal(app.stored()[0].estadoOffline, 'Error'); assert.equal(app.stored()[0].mensajeError, 'Disponibilidad insuficiente');
  assert.equal(app.requests.length, 2); assert.ok(app.requests.every(r => JSON.parse(r.body).pedidoOfflineGuid === 'existing-guid'));
});
test('offline sync never invokes transport and online event uses the existing retry path', async () => {
  const app = setup({ online: false, orders: [pending()] }); await app.elements.get('syncPendingOrders').handlers.click(); assert.equal(app.requests.length, 0);
  app.navigator.onLine = true; app.windowHandlers.online();
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(app.requests.length, 1); assert.equal(app.stored()[0].estadoOffline, 'Sincronizado');
});
test('queue disclosure reports expanded state and untrusted queue strings are escaped', () => {
  const order = pending(); order.estadoOffline = '<script>bad</script>'; order.mensajeError = '<img onerror=bad>';
  const app = setup({ orders: [order] }); const panel = app.elements.get('pendingOrdersPanel'); panel.hidden = true;
  const toggle = app.elements.get('togglePendingOrders'); toggle.handlers.click(); assert.equal(toggle.attrs['aria-expanded'], 'true'); toggle.handlers.click(); assert.equal(toggle.attrs['aria-expanded'], 'false');
  const html = app.elements.get('pendingOrdersList').innerHTML; assert.doesNotMatch(html, /<script>|<img/); assert.match(html, /&lt;script&gt;/);
});
for (const action of ['Approve', 'Reject']) {
  for (const confirmed of [false, true]) {
    test(`${action} ${confirmed ? 'acceptance only allows mock submission' : 'cancellation prevents submission'}`, () => {
      let submit; let prompted = 0; let simulatedPosts = 0;
      const form = { dataset: { djjConfirm: action }, addEventListener(name, handler) { assert.equal(name, 'submit'); submit = handler; } };
      const document = { documentElement: { toggleAttribute() {} }, querySelector() { return null; }, querySelectorAll(s) { return s === 'form[data-djj-confirm]' ? [form] : []; }, addEventListener() {} };
      const window = { matchMedia() { return { matches: false, addEventListener() {} }; }, addEventListener() {}, confirm(message) { assert.equal(message, action); prompted++; return confirmed; } };
      vm.runInNewContext(layouts, { document, window });
      let cancelled = false; submit({ preventDefault() { cancelled = true; } }); if (!cancelled) simulatedPosts++;
      assert.equal(prompted, 1); assert.equal(cancelled, !confirmed); assert.equal(simulatedPosts, confirmed ? 1 : 0);
    });
  }
}
