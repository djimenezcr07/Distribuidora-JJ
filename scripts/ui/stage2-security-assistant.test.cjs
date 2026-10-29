const {test}=require('node:test');
const assert=require('node:assert/strict');
const vm=require('node:vm');
const fs=require('node:fs');
const path=require('node:path');
const source=fs.readFileSync(path.join(__dirname,'../../Proyecto_Final/wwwroot/js/stage2/assistant.js'),'utf8');
class Node {
 constructor(tag='div'){this.tagName=tag.toUpperCase();this.children=[];this.dataset={};this.handlers={};this.value='';this.attrs={};this.disabled=false;this._text='';}
 set textContent(v){this._text=String(v);this.children=[];} get textContent(){return this._text+this.children.map(x=>x.textContent).join('');}
 set innerHTML(v){throw new Error('Unsafe HTML sink');} set outerHTML(v){throw new Error('Unsafe HTML sink');}
 insertAdjacentHTML(){throw new Error('Unsafe HTML sink');}
 append(...nodes){for(const n of nodes){if(n.tagName==='#FRAGMENT')this.children.push(...n.children);else this.children.push(n);}}
 setAttribute(k,v){this.attrs[k]=v;} addEventListener(k,fn){this.handlers[k]=fn;} focus(){this.focused=true;}
 closest(){return this.className?.includes('assistant-chip')?this:null;}
 requestSubmit(){this.submission=this.handlers.submit({preventDefault(){}});}
}
function setup(fetchImpl){const ids=Object.fromEntries(['assistantWindow','assistantForm','assistantInput','assistantSubmit','assistantStatus'].map(x=>[x,new Node()]));const root=new Node();root.dataset.askUrl='/Assistant/Ask';const calls=[],errors=[];
 const document={querySelector:s=>s.includes('data-djj')?root:{value:'test-token'},getElementById:id=>ids[id],createElement:t=>new Node(t),createDocumentFragment:()=>new Node('#fragment'),createTextNode:t=>{const n=new Node('#text');n.textContent=t;return n;}};
 vm.runInNewContext(source,{document,URLSearchParams,console:{error:(...a)=>errors.push(a)},fetch:async(u,o)=>{calls.push([u,o]);return fetchImpl(u,o);}});
 return {ids,calls,errors,async ask(text){ids.assistantInput.value=text;return ids.assistantForm.handlers.submit({preventDefault(){}});}};
}
function nodes(n){return [n,...n.children.flatMap(nodes)];}
test('initial greeting is local: no POST or invented metrics',()=>{const h=setup(()=>{throw Error('must not fetch');});assert.equal(h.calls.length,0);assert.match(h.ids.assistantWindow.textContent,/Hola/);assert.equal(nodes(h.ids.assistantWindow).filter(x=>x.tagName==='BUTTON').length,5);});
test('POST endpoint, token, names and metric context preserved',async()=>{const h=setup(async()=>({ok:true,json:async()=>({ok:true,tipo:'metrica',intent:'ventas',titulo:'Ventas',respuesta:'<strong>₡10</strong>',sugerencias:[]})}));await h.ask(' ventas ');await h.ask('amplía');assert.equal(h.calls[0][0],'/Assistant/Ask');const o=h.calls[0][1];assert.equal(o.method,'POST');assert.equal(o.headers['Content-Type'],'application/x-www-form-urlencoded');assert.equal(o.body.get('pregunta'),'ventas');assert.equal(o.body.get('__RequestVerificationToken'),'test-token');assert.equal(h.calls[1][1].body.get('contexto'),'ventas');});
test('user payload remains text without executing or parsing tags',async()=>{const payload='<script>alert(1)</script><img onerror="x"> & " ñ';const h=setup(async()=>({ok:true,json:async()=>({ok:true,respuesta:'Bien'})}));await h.ask(payload);const msg=h.ids.assistantWindow.children[1];assert.equal(msg.textContent,payload);assert.equal(nodes(msg).filter(x=>['SCRIPT','IMG'].includes(x.tagName)).length,0);});
test('server title/body/chips reject executable markup and attributes',async()=>{const payload='<img src=x onerror=alert(1)><script>x</script> " & ñ';const h=setup(async()=>({ok:true,json:async()=>({ok:true,titulo:payload,respuesta:payload+'<strong>Seguro &amp; &lt;img&gt;</strong>',sugerencias:[payload]})}));await h.ask('x');const msg=h.ids.assistantWindow.children[2];assert.equal(nodes(msg).filter(x=>['IMG','SCRIPT'].includes(x.tagName)).length,0);assert.match(msg.textContent,/Seguro & <img>/);assert.equal(nodes(msg).find(x=>x.tagName==='BUTTON').dataset.question,payload);assert.equal(nodes(msg).find(x=>x.tagName==='STRONG').attrs.onclick,undefined);});
test('existing strong/em/list/break formatting survives safely',async()=>{const h=setup(async()=>({ok:true,json:async()=>({ok:true,respuesta:'<ul><li><strong>A</strong><br/><em>B</em></li></ul>'})}));await h.ask('x');const types=nodes(h.ids.assistantWindow.children[2]).map(x=>x.tagName);for(const tag of ['UL','LI','STRONG','BR','EM'])assert.ok(types.includes(tag));});
test('loading blocks duplicate submits and restores input/focus',async()=>{let release;const h=setup(()=>new Promise(r=>release=r));const pending=h.ask('x');assert.equal(h.ids.assistantSubmit.disabled,true);assert.equal(h.ids.assistantWindow.attrs['aria-busy'],'true');await h.ask('repeat');assert.equal(h.calls.length,1);release({ok:true,json:async()=>({ok:true,respuesta:'ok'})});await pending;assert.equal(h.ids.assistantInput.disabled,false);assert.equal(h.ids.assistantInput.focused,true);assert.equal(h.ids.assistantSubmit.textContent,'Enviar');});
test('empty question never contacts server',async()=>{const h=setup(()=>{throw Error();});await h.ask(' ');assert.equal(h.calls.length,0);});
test('business error is encoded and does not update metric context',async()=>{let n=0;const h=setup(async()=>({ok:true,json:async()=>++n===1?{ok:false,message:'<script>x</script>'}:{ok:true,respuesta:'ok'}}));await h.ask('x');assert.match(h.ids.assistantWindow.children[2].textContent,/<script>/);await h.ask('x');assert.equal(h.calls[1][1].body.get('contexto'),'');});
test('network/HTTP error retains logging, recovers controls and shows message',async()=>{const h=setup(async()=>({ok:false,status:429}));await h.ask('x');assert.equal(h.errors.length,1);assert.match(h.ids.assistantWindow.textContent,/Sin conexión/);assert.equal(h.ids.assistantSubmit.disabled,false);});
test('suggestion submits its original value and preserves context',async()=>{const h=setup(async()=>({ok:true,json:async()=>({ok:true,respuesta:'ok'})}));const chip=nodes(h.ids.assistantWindow).find(x=>x.tagName==='BUTTON');h.ids.assistantWindow.handlers.click({target:chip});await h.ids.assistantForm.submission;assert.equal(h.calls[0][1].body.get('pregunta'),'¿Qué puedo preguntar?');});
test('numeric entities decode only into inert text',async()=>{const h=setup(async()=>({ok:true,json:async()=>({ok:true,respuesta:'&#60;script&#62; &#x1f600; &amp;lt;img&amp;gt;'})}));await h.ask('x');const msg=h.ids.assistantWindow.children[2];assert.match(msg.textContent,/<script> 😀 &lt;img&gt;/);assert.equal(nodes(msg).some(x=>x.tagName==='SCRIPT'),false);});
