(() => {
  'use strict';
  const root = document.querySelector('[data-djj-assistant]');
  if (!root) return;
  const askUrl = root.dataset.askUrl;
  const token = document.querySelector('input[name="__RequestVerificationToken"]')?.value || '';
  const windowElement = document.getElementById('assistantWindow');
  const form = document.getElementById('assistantForm');
  const input = document.getElementById('assistantInput');
  const submitButton = document.getElementById('assistantSubmit');
  const status = document.getElementById('assistantStatus');
  let lastMetricIntent = '';
  let loading = false;

  function element(tag, className, text) {
    const node = document.createElement(tag);
    if (className) node.className = className;
    if (text != null) node.textContent = text;
    return node;
  }
  function decodeText(value) {
    const entities = { amp: '&', lt: '<', gt: '>', quot: '"', apos: "'", nbsp: '\u00a0' };
    return value.replace(/&(#x[0-9a-f]+|#\d+|amp|lt|gt|quot|apos|nbsp);/gi, (match, key) => {
      if (key[0] !== '#') return entities[key.toLowerCase()] || match;
      const code = key[1].toLowerCase() === 'x' ? parseInt(key.slice(2), 16) : parseInt(key.slice(1), 10);
      return code > 0 && code <= 0x10ffff && !(code >= 0xd800 && code <= 0xdfff) ? String.fromCodePoint(code) : '\ufffd';
    });
  }
  // Preserve the server's existing formatting vocabulary, never parse arbitrary HTML.
  // Attributes/unknown tags remain plain text. Decoded entities only become text nodes.
  function formattedText(value) {
    const fragment = document.createDocumentFragment();
    const stack = [fragment];
    String(value ?? '').split(/(<\/?(?:strong|em|ul|li)\s*>|<br\s*\/?>)/gi).forEach(part => {
      const tag = part.match(/^<(\/)?(strong|em|ul|li|br)\s*\/?>$/i);
      if (!tag) { stack[stack.length - 1].append(document.createTextNode(decodeText(part))); return; }
      const name = tag[2].toLowerCase();
      if (tag[1]) {
        if (stack.length > 1 && stack[stack.length - 1].tagName.toLowerCase() === name) stack.pop();
        return;
      }
      const node = element(name); stack[stack.length - 1].append(node);
      if (name !== 'br') stack.push(node);
    });
    return fragment;
  }
  function addMessage(user, title, answer, suggestions, plain = false) {
    const message = element('article', 'djj-assistant-message' + (user ? ' djj-assistant-message--user' : ''));
    message.setAttribute('aria-label', user ? 'Tu pregunta' : 'Respuesta del asistente');
    if (title) message.append(element('h3', '', title));
    const content = element('div');
    if (plain) content.textContent = answer ?? ''; else content.append(formattedText(answer));
    message.append(content);
    if (Array.isArray(suggestions) && suggestions.length) {
      const chips = element('div', 'djj-assistant-suggestions');
      suggestions.forEach(suggestion => {
        const chip = element('button', 'djj-button djj-button--secondary assistant-chip', String(suggestion));
        chip.type = 'button'; chip.dataset.question = String(suggestion); chips.append(chip);
      });
      message.append(chips);
    }
    windowElement.append(message); windowElement.scrollTop = windowElement.scrollHeight;
  }
  function setLoading(value) {
    loading = value; input.disabled = value; submitButton.disabled = value;
    submitButton.textContent = value ? 'Procesando' : 'Enviar';
    windowElement.setAttribute('aria-busy', String(value));
    if (status) status.textContent = value ? 'Procesando tu pregunta…' : '';
  }
  async function sendQuestion(text) {
    const body = new URLSearchParams();
    body.append('pregunta', text); body.append('contexto', lastMetricIntent);
    body.append('__RequestVerificationToken', token);
    setLoading(true);
    try {
      const response = await fetch(askUrl, { method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, body });
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      const data = await response.json();
      if (!data.ok) {
        addMessage(false, 'No fue posible responder', data.message || 'Ocurrió un error inesperado.', [], true);
        return;
      }
      addMessage(false, data.titulo, data.respuesta, data.sugerencias);
      if (data.tipo === 'metrica') lastMetricIntent = data.intent;
    } catch (error) {
      console.error('Error consultando el asistente:', error);
      addMessage(false, 'Sin conexión', 'No fue posible comunicarse con el asistente.', [], true);
    } finally { setLoading(false); input.focus(); }
  }
  form.addEventListener('submit', async event => {
    event.preventDefault();
    const text = (input.value || '').trim();
    if (!text || loading) return;
    addMessage(true, '', text, [], true); input.value = '';
    await sendQuestion(text);
  });
  windowElement.addEventListener('click', event => {
    const chip = event.target.closest('.assistant-chip');
    if (!chip || loading) return;
    input.value = chip.dataset.question || ''; form.requestSubmit();
  });
  addMessage(false, '¡Hola! ¿En qué puedo ayudarte?',
    'Puedo consultar métricas del negocio y explicarte cómo utilizar los diferentes módulos del sistema. Selecciona una opción o escribe tu propia pregunta.',
    ['¿Qué puedo preguntar?', 'Dame un resumen', '¿Cuánto vendimos este mes?', '¿Cómo está el inventario?', '¿Cómo uso el módulo de rutas?'], true);
  input.focus();
})();
