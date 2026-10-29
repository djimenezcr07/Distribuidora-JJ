const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const code = fs.readFileSync(path.resolve(__dirname, '../../Proyecto_Final/wwwroot/js/stage2/documents.js'), 'utf8');
function run({ history = null, forms = [], jquery = false } = {}) {
  const handlers = []; const frame = [];
  const document = { querySelector: () => history, querySelectorAll: () => forms };
  const window = { requestAnimationFrame: fn => frame.push(fn) };
  if (jquery) window.jQuery = form => ({ on(name, fn) { assert.equal(name, 'invalid-form.validate'); handlers.push({ form, fn }); } });
  vm.runInNewContext(code, { document, window, fetch() { throw Error('No network allowed'); } });
  return { handlers, frame };
}
test('history route focuses the existing history without a request', () => { const history = { focus() { this.focused = true; } }; run({ history }); assert.equal(history.focused, true); });
test('ordinary document pages do not manufacture a history focus target', () => assert.doesNotThrow(() => run()));
test('unobtrusive failed validation focuses its own summary after updates', () => { const summary = { focus() { this.focused = true; } }; const form = { querySelector: () => summary }; const r = run({ forms: [form], jquery: true }); r.handlers[0].fn(); assert.equal(summary.focused, undefined); r.frame[0](); assert.equal(summary.focused, true); });
test('a replacement form without a summary is harmless', () => { const r = run({ forms: [{ querySelector: () => null }], jquery: true }); assert.doesNotThrow(() => r.handlers[0].fn()); assert.equal(r.frame.length, 0); });
test('validation script absence does not prevent native form validation', () => assert.doesNotThrow(() => run({ forms: [{ querySelector() { throw Error('Not expected'); } }] })));
