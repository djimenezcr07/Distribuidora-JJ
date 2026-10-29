const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const jsRoot = path.resolve(__dirname, '../../Proyecto_Final/wwwroot/js');

class Element {
  constructor(tag = 'div') { this.tagName = tag; this.events = {}; this.attributes = {}; this.children = []; this.hidden = false; this.textContent = ''; this.dataset = {}; }
  addEventListener(name, handler) { (this.events[name] ||= []).push(handler); }
  trigger(name, detail = {}) { const event = { preventDefault() { this.prevented = true; }, ...detail }; (this.events[name] || []).forEach(handler => handler(event)); return event; }
  setAttribute(name, value) { this.attributes[name] = String(value); }
  removeAttribute(name) { delete this.attributes[name]; }
  toggleAttribute(name, enabled) { if (enabled) this.setAttribute(name, ''); else this.removeAttribute(name); return enabled; }
  getAttribute(name) { return this.attributes[name]; }
  append(...children) { this.children.push(...children); }
  focus() { this.focused = true; }
  set innerHTML(value) { throw new Error('User data must not pass through HTML parsing'); }
}

function runtime({ user = 11, online = false, denied = false } = {}) {
  const entries = new Map();
  const body = new Element('body');
  body.setAttribute('data-authenticated-user-id', user);
  const logout = new Element('form');
  const elements = new Map();
  for (const id of ['connectionBadge', 'pendingSyncBadge', 'driverToast', 'refreshRouteBtn', 'noCoordsBanner', 'mapOfflineBanner']) elements.set(id, new Element());
  elements.get('pendingSyncBadge').parentElement = new Element();
  const localStorage = {
    get length() { if (denied) throw new Error('denied'); return entries.size; },
    key(index) { return [...entries.keys()][index] || null; },
    getItem(key) { if (denied) throw new Error('denied'); return entries.get(key) || null; },
    setItem(key, value) { if (denied) throw new Error('denied'); entries.set(key, value); },
    removeItem(key) { if (denied) throw new Error('denied'); entries.delete(key); }
  };
  const window = new Element();
  let guidCount = 0;
  window.crypto = { randomUUID: () => 'same-guid-' + ++guidCount };
  window.location = { reload() { window.reloads = (window.reloads || 0) + 1; } };
  const card = new Element('article');
  card.setAttribute('data-rutapedidoid', 7);
  card.setAttribute('data-estado', 'Pendiente');
  const label = new Element('span');
  const button = new Element('button');
  button.setAttribute('data-action', 'Entregado');
  card.querySelector = selector => selector === '.delivery-status-label' ? label : null;
  card.querySelectorAll = () => [button];
  const document = {
    body, documentElement: new Element('html'), readyState: 'complete',
    createElement: tag => new Element(tag),
    getElementById: id => elements.get(id),
    querySelector: selector => selector === '.delivery-card[data-rutapedidoid="7"]' ? card : null,
    querySelectorAll: selector => selector.startsWith('form[data-clear') ? [logout] : selector === '.delivery-card' ? [card] : [],
  };
  let now = 1000;
  const context = vm.createContext({ window, document, localStorage, navigator: { onLine: online }, URLSearchParams,
    Date: class extends Date { static now() { return now; } },
    setTimeout() {}, alert() {}, getComputedStyle: () => ({ getPropertyValue: () => '#8b0e16' }) });
  function run(file) { vm.runInContext(fs.readFileSync(path.join(jsRoot, file), 'utf8'), context, { filename: file }); }
  run('secure-offline-storage.js');
  return { context, window, document, elements, entries, logout, body, card, label, button, run,
    storage: window.DistribuidoraJJOfflineStorage, advance: ms => { now += ms; } };
}

const settle = async () => { for (let i = 0; i < 8; i++) await new Promise(resolve => setImmediate(resolve)); };

test('private cache isolates users, rejects anonymous writes and expires', () => {
  const r = runtime();
  r.storage.write('route', { client: 'private' }, 100);
  r.body.setAttribute('data-authenticated-user-id', 12);
  assert.equal(r.storage.read('route'), null);
  r.body.setAttribute('data-authenticated-user-id', 11);
  assert.equal(r.storage.read('route').client, 'private');
  r.advance(101);
  assert.equal(r.storage.read('route'), null);
  r.body.setAttribute('data-authenticated-user-id', 0);
  assert.throws(() => r.storage.write('route', {}, 100));
});

test('logout clears current user data while preserving another user', () => {
  const r = runtime();
  r.storage.write('queue', [1], 100);
  r.body.setAttribute('data-authenticated-user-id', 12);
  r.storage.write('queue', [2], 100);
  r.body.setAttribute('data-authenticated-user-id', 11);
  r.logout.trigger('submit');
  assert.equal(r.storage.read('queue'), null);
  r.body.setAttribute('data-authenticated-user-id', 12);
  assert.equal(r.storage.read('queue')[0], 2);
});

test('tampered ownership and invalid JSON never leak cached data', () => {
  const r = runtime();
  r.entries.set('distribuidorajj:user:11:route', JSON.stringify({ ownerUserId: 12, expiresAt: 2000, value: 'other user' }));
  assert.equal(r.storage.read('route'), null);
  r.entries.set('distribuidorajj:user:11:route', '{broken');
  assert.equal(r.storage.read('route'), null);
});

test('offline change retries the same SyncGuid after network failure', async () => {
  const r = runtime();
  const requests = [];
  let fail = true;
  r.context.fetch = async (_, request) => { requests.push(new URLSearchParams(request.body)); if (fail) throw new Error('offline'); return { ok: true, status: 200, json: async () => ({ ok: true, duplicado: true }) }; };
  r.window.driverDeliveriesConfig = { updateUrl: '/status', token: '<ANTIFORGERY_TEST>' };
  r.run('driver-deliveries.js');
  r.button.trigger('click');
  const saved = r.storage.read('driver-delivery-queue-v2')[0];
  assert.match(r.label.textContent, /pendiente de sincronizar/);
  r.context.navigator.onLine = true;
  r.window.trigger('online');
  await settle();
  assert.equal(r.storage.read('driver-delivery-queue-v2').length, 1);
  fail = false;
  r.window.trigger('online');
  await settle();
  assert.equal(requests.length, 2);
  assert.equal(requests[0].get('syncGuid'), saved.syncGuid);
  assert.equal(requests[1].get('syncGuid'), saved.syncGuid);
  assert.equal(requests[1].get('__RequestVerificationToken'), '<ANTIFORGERY_TEST>');
  assert.equal(r.storage.read('driver-delivery-queue-v2'), null);
  assert.equal(r.window.reloads, 1);
});

test('expired session preserves pending changes and explains retry requirement', async () => {
  const r = runtime();
  r.context.fetch = async () => ({ ok: false, status: 401 });
  r.run('driver-deliveries.js');
  r.button.trigger('click');
  r.context.navigator.onLine = true;
  r.window.trigger('online');
  await settle();
  assert.equal(r.storage.read('driver-delivery-queue-v2').length, 1);
  assert.match(r.elements.get('driverToast').textContent, /sesión/);
  assert.equal(r.window.reloads, undefined);
});

test('denied storage cannot report a change as saved or change delivery state', () => {
  const r = runtime({ denied: true });
  r.run('driver-deliveries.js');
  r.button.trigger('click');
  assert.equal(r.card.getAttribute('data-estado'), 'Pendiente');
  assert.match(r.elements.get('driverToast').textContent, /No se pudo guardar/);
  assert.doesNotThrow(() => r.logout.trigger('submit'));
});

test('business rejection restores the card and does not retry a rejected change', async () => {
  const r = runtime({ online: true });
  r.context.fetch = async () => ({ ok: true, status: 200, json: async () => ({ ok: false, message: 'Cambio rechazado' }) });
  r.run('driver-deliveries.js');
  r.button.trigger('click');
  await settle();
  assert.equal(r.storage.read('driver-delivery-queue-v2'), null);
  assert.equal(r.card.getAttribute('data-estado'), 'Pendiente');
  assert.equal(r.button.disabled, false);
  assert.equal(r.elements.get('driverToast').textContent, 'Cambio rechazado');
});

test('map labels treat malicious domain values as text without parsing HTML', () => {
  const r = runtime({ online: true });
  const popups = [], pins = [];
  const map = { fitBounds() {} };
  const L = {
    map: () => map, tileLayer: () => ({ addTo() {} }),
    divIcon: options => { pins.push(options.html); return {}; },
    marker: () => ({ addTo() { return this; }, bindPopup(node) { popups.push(node); } }),
    latLngBounds: () => ({ pad() { return this; } }),
  };
  r.context.L = L;
  r.window.L = L;
  const attack = '<img src=x onerror=alert(1)>';
  r.window.driverRouteConfig = { routeId: 1, stops: [{ seq: attack, cliente: attack, dir: attack, estado: attack, lat: 9.9, lng: -84 }] };
  r.run('driver-route-map.js');
  assert.equal(popups[0].children[0].textContent, '#' + attack + ' · ' + attack);
  assert.equal(popups[0].children[2].textContent, attack);
  assert.equal(pins[0].textContent, attack);
  assert.deepEqual(popups[0].children.map(child => child.tagName), ['strong', 'br', 'span', 'br', 'em']);
  assert.equal(r.window.events.online, undefined);
});

test('signature is encoded on submit and clearing prevents empty evidence submission', () => {
  const r = runtime();
  const form = new Element('form'), canvas = new Element('canvas'), data = new Element('input'), clear = new Element('button');
  Object.assign(canvas, { width: 320, height: 140, getBoundingClientRect: () => ({ left: 0, top: 0, width: 320, height: 140 }),
    getContext: () => ({ beginPath() {}, moveTo() {}, lineTo() {}, stroke() {}, clearRect() {} }), toDataURL: () => 'data:image/png;base64,real-signature' });
  form.querySelector = selector => ({ '.sig-canvas': canvas, '.sig-data': data, '.sig-clear': clear }[selector]);
  r.document.querySelectorAll = selector => selector === '.sig-form' ? [form] : [];
  r.run('driver-signature.js');
  assert.equal(form.trigger('submit').prevented, true);
  canvas.trigger('pointerdown', { button: 0, clientX: 20, clientY: 20, pointerId: 1 });
  canvas.trigger('pointermove', { clientX: 50, clientY: 40 });
  canvas.trigger('pointerup');
  assert.equal(form.trigger('submit').prevented, undefined);
  assert.equal(data.value, 'data:image/png;base64,real-signature');
  clear.trigger('click');
  assert.equal(data.value, '');
  assert.equal(form.trigger('submit').prevented, true);
});

test('mobile drawer isolates background, traps focus and restores it on close', () => {
  const r = runtime();
  const drawer = new Element('aside'), open = new Element('button'), close = new Element('button'), last = new Element('a');
  const header = new Element('header'), main = new Element('main'), footer = new Element('footer'), scrim = new Element('button');
  drawer.id = 'drawer';
  drawer.querySelectorAll = () => [close, last];
  [close, last].forEach(control => {
    control.getClientRects = () => [{}];
    control.closest = () => drawer.inert ? drawer : null;
    control.focus = () => { r.document.activeElement = control; };
  });
  open.focus = () => { r.document.activeElement = open; };
  r.document.activeElement = open;
  r.document.body.children = [header, main, footer, drawer, scrim];
  r.document.querySelectorAll = selector => selector === '[data-djj-drawer]' ? [drawer] : [];
  r.document.querySelector = selector => selector.startsWith('[data-djj-drawer-open]') ? open : selector.startsWith('[data-djj-drawer-scrim]') ? scrim : null;
  const controls = drawer.querySelectorAll;
  drawer.querySelectorAll = selector => selector === '[data-djj-drawer-close]' ? [close] : controls();
  r.document.addEventListener = () => {};
  r.window.matchMedia = () => ({ matches: true, addEventListener() {} });
  r.run('stage2/layouts.js');
  open.trigger('click');
  assert.equal(drawer.inert, false);
  assert.equal(main.inert, true);
  assert.equal(r.document.activeElement, close);
  assert.equal(drawer.trigger('keydown', { key: 'Tab', shiftKey: true }).prevented, true);
  assert.equal(r.document.activeElement, last);
  assert.equal(drawer.trigger('keydown', { key: 'Tab', shiftKey: false }).prevented, true);
  assert.equal(r.document.activeElement, close);
  close.trigger('click');
  assert.equal(drawer.inert, true);
  assert.equal(Boolean(main.inert), false);
  assert.equal(r.document.activeElement, open);
});

test('workspace collapse toggles both ways and resets safely at mobile breakpoint', () => {
  const r = runtime();
  const shell = new Element(), sidebar = new Element(), open = new Element('button'), collapse = new Element('button'), main = new Element();
  const media = { matches: false, addEventListener(name, handler) { this.change = handler; } };
  const elements = { '[data-djj-workspace-shell]': shell, '[data-djj-workspace-sidebar]': sidebar,
    '[data-djj-workspace-open]': open, '[data-djj-workspace-collapse]': collapse, '.djj-workspace-main': main };
  sidebar.contains = () => false;
  r.document.querySelector = selector => elements[selector] || null;
  r.document.querySelectorAll = () => [];
  r.document.addEventListener = () => {};
  r.window.matchMedia = () => media;
  r.run('stage2/layouts.js');
  collapse.trigger('click');
  assert.equal(shell.getAttribute('data-sidebar-collapsed'), 'true');
  collapse.trigger('click');
  assert.equal(shell.getAttribute('data-sidebar-collapsed'), 'false');
  collapse.trigger('click');
  media.matches = true;
  media.change();
  assert.equal(shell.getAttribute('data-sidebar-collapsed'), 'false');
  assert.equal(sidebar.inert, true);
  assert.equal(sidebar.getAttribute('aria-hidden'), 'true');
});
