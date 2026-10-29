const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const source = fs.readFileSync(path.resolve(__dirname, '../../Proyecto_Final/wwwroot/js/stage2/promotions.js'), 'utf8');
function setup(value) {
  let change;
  const type = { value, addEventListener(event, handler) { assert.equal(event, 'change'); change = handler; } };
  const discount = { hidden: false, value: '15' };
  const gift = { hidden: false, value: '2' };
  const document = { getElementById(id) { assert.equal(id, 'promoTipo'); return type; }, querySelectorAll(selector) { return selector === '.promo-descuento' ? [discount] : [gift]; } };
  vm.runInNewContext(source, { document });
  return { type, discount, gift, change: () => change() };
}
test('discount form hides gifts without discarding values', () => {
  const form = setup('DescuentoPorcentual');
  assert.equal(form.discount.hidden, false); assert.equal(form.gift.hidden, true);
  assert.equal(form.gift.value, '2'); assert.equal(form.gift.disabled, undefined);
});
test('gift form shows gift fields and preserves discount values', () => {
  const form = setup('RegaliaPorVolumen');
  assert.equal(form.discount.hidden, true); assert.equal(form.gift.hidden, false);
  assert.equal(form.discount.value, '15');
});
test('keyboard and pointer change event restores correct field visibility', () => {
  const form = setup('DescuentoPorcentual');
  form.type.value = 'RegaliaPorVolumen'; form.change();
  assert.equal(form.gift.hidden, false);
  form.type.value = 'DescuentoPorcentual'; form.change();
  assert.equal(form.discount.hidden, false); assert.equal(form.gift.hidden, true);
});
test('script is harmless outside promotion forms', () => {
  assert.doesNotThrow(() => vm.runInNewContext(source, { document: { getElementById() { return null; } } }));
});
// Exercise the actual shared confirmation implementation without a browser or database.
for (const action of ['ToggleStatus', 'Inactivate', 'SetSegment']) {
  test(`${action} cancellation prevents form submission`, () => {
    let submit;
    let prompted;
    const form = { dataset: { djjConfirm: `Cancel ${action}` }, addEventListener(name, handler) { assert.equal(name, 'submit'); submit = handler; } };
    const document = {
      documentElement: { toggleAttribute() {} },
      querySelector() { return null; },
      querySelectorAll(selector) { return selector === 'form[data-djj-confirm]' ? [form] : []; },
      addEventListener() {}
    };
    const window = { matchMedia() { return { matches: false, addEventListener() {} }; }, addEventListener() {}, confirm(message) { prompted = message; return false; } };
    const layout = fs.readFileSync(path.resolve(__dirname, '../../Proyecto_Final/wwwroot/js/stage2/layouts.js'), 'utf8');
    vm.runInNewContext(layout, { document, window });
    const event = { cancelled: false, preventDefault() { this.cancelled = true; } };
    submit(event);
    assert.equal(prompted, `Cancel ${action}`);
    assert.equal(event.cancelled, true);
  });
}
