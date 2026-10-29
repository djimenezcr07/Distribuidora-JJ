const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const source = name => fs.readFileSync(path.resolve(__dirname, '../../Proyecto_Final/wwwroot/js/stage2/' + name + '.js'), 'utf8');
class Node {
  constructor(tag='div') { this.tagName=tag; this.children=[]; this.dataset={}; this.events={}; this.hidden=false; this.className=''; this.value=''; this._text=''; this.attributes={}; }
  set textContent(value) { this._text=String(value); this.children=[]; }
  get textContent() { return this._text + this.children.map(c=>c.textContent).join(''); }
  append(...nodes) { for (const n of nodes) { if(n.tagName==='fragment') this.append(...n.children); else { this.children.push(n); n.parent=this; } } }
  replaceChildren(...nodes) { this._text=''; this.children=[]; this.append(...nodes); }
  addEventListener(event, fn) { this.events[event]=fn; }
  setAttribute(key,value) { this.attributes[key]=value; }
  contains(node) { return this.children.some(c=>c===node || c.contains(node)); }
  remove() { if(this.parent) this.parent.children=this.parent.children.filter(c=>c!==this); }
  all() { return this.children.flatMap(c=>[c,...c.all()]); }
  querySelectorAll(selector) { return this.all().filter(n=>selector==='[data-board-row]' ? 'boardRow' in n.dataset : selector==='[data-board-empty]' ? 'boardEmpty' in n.dataset : selector==='.djj-badge' ? n.className.includes('djj-badge ') : false); }
  querySelector(selector) { return this.querySelectorAll(selector)[0] || null; }
}
const route = { rutaId:7,codigo:'R-7',zona:'Zona',chofer:'Chofer',vehiculoPlaca:'ABC',estado:'Planificada',totalPedidos:3,entregados:1,fallidos:1,pendientes:1,fechaDespacho:null };
const data = () => ({ rutasActivas:1,entregasPendientes:1,entregasCompletadas:1,entregasFallidas:1,generadoUtc:'2026-10-09T06:00:00Z',rutas:[{...route}] });
function board({canRoutes=true,payload=data(),fail=false}={}) {
  const ids={}; for(const id of ['delivery-board-body','board-status','board-pause','board-search','board-state','board-filter','board-updated','board-attention','active-routes','pending-deliveries','completed-deliveries','failed-deliveries']) ids[id]=new Node();
  ids['active-routes'].textContent='Previous';
  const root=new Node(); root.dataset={snapshotUrl:'/DeliveryBoard/Snapshot',routeDetailBase:'/RoutesAdmin/Detail',canViewRoutes:String(canRoutes)};
  const document={hidden:false,activeElement:null,querySelector:()=>root,getElementById:id=>ids[id],createElement:tag=>new Node(tag),createDocumentFragment:()=>new Node('fragment')};
  let tick, requests=0, timer;
  const window={setInterval(fn,delay){assert.equal(delay,15000);tick=fn;},setTimeout(fn){timer=fn;return 1;},clearTimeout(){}};
  vm.runInNewContext(source('delivery-board'), {document,window,AbortController,fetch:async(url,options)=>{requests++;assert.equal(url,'/DeliveryBoard/Snapshot');assert.equal(options.credentials,'same-origin');assert.equal(options.cache,'no-store');return {ok:!fail,redirected:false,headers:{get:()=> 'application/json'},json:async()=>payload};}});
  return {ids,document,tick:()=>tick(),requests:()=>requests,pause:()=>ids['board-pause'].events.click(),timer:()=>timer()};
}
test('snapshot renders server metrics, totals and named detail link',async()=>{const b=board();await b.tick();assert.equal(b.ids['active-routes'].textContent,'1');const row=b.ids['delivery-board-body'].children[0];assert.match(row.textContent,/3 pedidos/);assert.match(row.textContent,/1 entregadas/);assert.equal(row.children[5].children[0].href,'/RoutesAdmin/Detail/7');});
test('unprivileged board never produces a route detail link',async()=>{const b=board({canRoutes:false});await b.tick();assert.equal(b.ids['delivery-board-body'].children[0].children.length,5);assert.equal(b.ids['delivery-board-body'].all().filter(n=>n.tagName==='a').length,0);});
test('untrusted strings remain text nodes instead of injected HTML',async()=>{const p=data();p.rutas[0].codigo='<img src=x onerror=alert(1)>';p.rutas[0].estado='Estado futuro';const b=board({payload:p});await b.tick();assert.match(b.ids['delivery-board-body'].textContent,/<img src=x/);assert.equal(b.ids['delivery-board-body'].all().filter(n=>n.tagName==='img').length,0);assert.match(b.ids['delivery-board-body'].querySelector('.djj-badge').className,/neutral/);});
for(const value of [null,-1,'7',1.5,'7/../../Admin']) test('invalid route identity preserves previous snapshot: '+String(value),async()=>{const p=data();p.rutas[0].rutaId=value;const b=board({payload:p});await b.tick();assert.equal(b.ids['active-routes'].textContent,'Previous');assert.match(b.ids['board-status'].textContent,/últimos datos/);});
test('invalid metrics are rejected without partial updates',async()=>{const p=data();p.entregasFallidas=-1;const b=board({payload:p});await b.tick();assert.equal(b.ids['active-routes'].textContent,'Previous');});
test('HTTP failure retains displayed data and gives useful feedback',async()=>{const b=board({fail:true});await b.tick();assert.equal(b.ids['active-routes'].textContent,'Previous');assert.match(b.ids['board-status'].textContent,/reintentará/);});
test('hidden tab does not poll',async()=>{const b=board();b.document.hidden=true;await b.tick();assert.equal(b.requests(),0);});
test('paused board does not poll and announces state',async()=>{const b=board();b.pause();await b.tick();assert.equal(b.requests(),0);assert.equal(b.ids['board-pause'].attributes['aria-pressed'],'true');assert.match(b.ids['board-status'].textContent,/pausada/);});
test('refresh does not remove the focused table control',async()=>{const b=board();const focused=new Node('a');b.ids['delivery-board-body'].append(focused);b.document.activeElement=focused;await b.tick();assert.equal(b.requests(),0);});
test('local search filters table without changing server metrics',async()=>{const b=board();await b.tick();b.ids['board-search'].value='no-match';b.ids['board-search'].events.input();assert.equal(b.ids['delivery-board-body'].children[0].hidden,true);assert.match(b.ids['delivery-board-body'].textContent,/No hay rutas que coincidan/);assert.equal(b.ids['active-routes'].textContent,'1');});
test('empty snapshot retains explicit empty state',async()=>{const p=data();p.rutas=[];const b=board({payload:p});await b.tick();assert.match(b.ids['delivery-board-body'].textContent,/No hay rutas para mostrar/);});
test('Leaflet unavailable leaves a useful textual fallback',()=>{const element=new Node(),status=new Node();vm.runInNewContext(source('route-admin-map'),{document:{getElementById:id=>id==='routePickerMap'?element:status}});assert.equal(element.hidden,true);assert.match(status.textContent,/coordenadas en la tabla/);});
test('map initialization failure has the same usable fallback',()=>{const element=new Node(),status=new Node();vm.runInNewContext(source('route-admin-map'),{document:{getElementById:id=>id==='routePickerMap'?element:status,querySelectorAll:()=>[]},L:{map(){throw Error('unavailable')}}});assert.equal(element.hidden,true);assert.match(status.textContent,/datos siguen accesibles/);});
test('evidence image failure reveals fallback without changing authorized URL',()=>{const image=new Node('img'),caption=new Node();image.src='/DeliveryEvidence/View/7';image.complete=false;caption.hidden=true;const figure={querySelector:s=>s==='img'?image:caption};vm.runInNewContext(source('logistics-ui'),{document:{querySelectorAll:s=>s==='[data-djj-evidence]'?[figure]:[]}});image.events.error();assert.equal(image.hidden,true);assert.equal(caption.hidden,false);assert.equal(image.src,'/DeliveryEvidence/View/7');});
test('local disclosure keeps keyboard focus and aria state without requests',()=>{const button=new Node('button');button.dataset.djjToggle='cancelBox';const input={focus(){this.focused=true;}};const panel={hidden:true,querySelector:s=>{assert.match(s,/input:not\(\[type=hidden\]\)/);return input;}};vm.runInNewContext(source('logistics-ui'),{document:{querySelectorAll:s=>s==='[data-djj-toggle]'?[button]:[],getElementById:()=>panel}});button.events.click();assert.equal(panel.hidden,false);assert.equal(button.attributes['aria-expanded'],'true');assert.equal(input.focused,true);button.events.click();assert.equal(panel.hidden,true);});

function mapFixture(lat='9.93',lng='-84.08') {
 const mapElement=new Node(),status=new Node();const inputs={'.lat-input':new Node(),'.lng-input':new Node(),'.seq-input':new Node(),'.btn-locate':new Node()};
 inputs['.lat-input'].value=lat;inputs['.lng-input'].value=lng;inputs['.seq-input'].value='<img onerror=alert(1)>';
 const row={dataset:{rutapedidoid:'7',label:'<script>alert(1)</script>'},classList:{toggle(){}},querySelector:s=>inputs[s],querySelectorAll:()=>[inputs['.lat-input'],inputs['.lng-input'],inputs['.seq-input']]};
 let icon,tooltip,markers=0;const map={setView(){return this;},fitBounds(){},on(){},removeLayer(){},invalidateSize(){}};
 const L={map:()=>map,tileLayer:()=>({addTo(){return this;},on(){}}),divIcon:args=>{icon=args;return args;},marker:()=>{markers++;return {addTo(){return this;},bindTooltip(node){tooltip=node;return this;},on(){}};},latLngBounds:()=>({pad(){return this;}})};
 const document={getElementById:id=>id==='routePickerMap'?mapElement:status,querySelectorAll:()=>[row],createElement:tag=>new Node(tag)};
 vm.runInNewContext(source('route-admin-map'),{document,L,window:{setTimeout(){}}});return {icon,tooltip,markers};
}
test('map pins and tooltips use DOM text even with hostile sequence and label',()=>{const m=mapFixture();assert.equal(m.markers,1);assert.equal(m.icon.html.tagName,'div');assert.equal(m.icon.html.textContent,'<img onerror=alert(1)>');assert.equal(m.tooltip.tagName,'span');assert.equal(m.tooltip.textContent,'<script>alert(1)</script>');});
for(const [lat,lng] of [['91','0'],['0','181'],['','0'],['Infinity','-84']]) test('map rejects invalid coordinate pair '+lat+','+lng,()=>assert.equal(mapFixture(lat,lng).markers,0));

test("prototype-named unknown state remains neutral",async()=>{const p=data();p.rutas[0].estado="__proto__";const b=board({payload:p});await b.tick();assert.match(b.ids["delivery-board-body"].querySelector(".djj-badge").className,/neutral/);});
