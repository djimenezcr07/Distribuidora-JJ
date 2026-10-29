const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const read = p => fs.readFileSync(path.join(__dirname, '../../Proyecto_Final', p), 'utf8');

test('failure surfaces remain script-free, local and independent of workspace initialization', () => {
  const shell = read('Views/Shared/_StatusLayout.cshtml');
  assert.doesNotMatch(shell, /<script|@inject|Session|TempData|fonts.googleapis|SignalR|chatHub/);
  assert.match(shell, /djj-skip-link/);
  assert.match(shell, /public-surfaces.css/);
});
test('public form uses native constraints and preserves server binding and validation scripts', () => {
  const contact = read('Views/Home/Contact.cshtml');
  for (const [field, length] of [['Nombre', 100], ['Asunto', 120], ['Mensaje', 1000]]) {
    assert.match(contact, new RegExp(`(?:input|textarea) asp-for="${field}"[^>]*maxlength="${length}"`));
  }
  assert.match(contact, /asp-for="Correo" type="email"/);
  assert.match(contact, /_ValidationScriptsPartial/);
  assert.match(contact, /AntiForgeryToken/);
});
test('trace and dynamic content use Razor encoding, never an HTML execution sink', () => {
  for (const view of ['Home/Contact', 'Shared/Error', 'Shared/ServiceUnavailable', 'FinancialReportAdmin/Index']) {
    assert.doesNotMatch(read(`Views/${view}.cshtml`), /Html.Raw|innerHTML|<script|onclick=/);
  }
  assert.match(read('Views/Shared/Error.cshtml'), /@requestId/);
  assert.match(read('Views/Shared/ServiceUnavailable.cshtml'), /@requestId/);
});
test('responsive layouts allow wrapping, local table scroll and safe trace reflow', () => {
  const css = read('wwwroot/css/stage2/public-surfaces.css');
  assert.match(css, /minmax\(min\(100%, 17rem\), 1fr\)/);
  assert.match(css, /overflow-wrap: anywhere/);
  assert.match(css, /\.djj-kpi-card__value \{ white-space: normal/);
  assert.match(read('Views/FinancialReportAdmin/Index.cshtml'), /djj-table-shell/);
  assert.match(read('wwwroot/css/stage2/base.css'), /prefers-reduced-motion/);
});
