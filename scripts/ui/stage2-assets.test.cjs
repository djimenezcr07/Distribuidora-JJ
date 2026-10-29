const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const read = name => fs.readFileSync(path.resolve(__dirname, '../../Proyecto_Final/wwwroot/js/stage2/' + name + '.js'), 'utf8');
function disclosure() {
  const field = { value:'Inventario', focus(){this.focused=true;} };
  const button = { dataset:{djjReturnToggle:'ret-9'}, events:{}, attributes:{}, addEventListener(name,handler){this.events[name]=handler;}, setAttribute(name,value){this.attributes[name]=value;}, focus(){this.focused=true;} };
  const panel = { hidden:true, events:{}, addEventListener(name,handler){this.events[name]=handler;}, querySelector(selector){assert.match(selector,/input:not\(\[type=hidden\]\)/);return field;} };
  const document = { querySelectorAll:()=>[button],getElementById:id=>{assert.equal(id,'ret-9');return panel;} };
  vm.runInNewContext(read('assets-ui'),{document,fetch(){throw Error('No requests allowed');}});
  return {button,panel,field};
}
test('opening a return panel announces state and focuses a visible field',()=>{const d=disclosure();d.button.events.click();assert.equal(d.panel.hidden,false);assert.equal(d.button.attributes['aria-expanded'],'true');assert.equal(d.field.focused,true);});
test('closing a return panel preserves destination without submitting',()=>{const d=disclosure();d.button.events.click();d.button.events.click();assert.equal(d.panel.hidden,true);assert.equal(d.button.attributes['aria-expanded'],'false');assert.equal(d.field.value,'Inventario');});
test('Escape closes the panel and restores the triggering button focus',()=>{const d=disclosure();d.button.events.click();let prevented=false;d.panel.events.keydown({key:'Escape',preventDefault(){prevented=true;}});assert.equal(prevented,true);assert.equal(d.panel.hidden,true);assert.equal(d.button.focused,true);});
test('ordinary typing does not close or discard the return form',()=>{const d=disclosure();d.button.events.click();d.panel.events.keydown({key:'a',preventDefault(){throw Error('Not expected');}});assert.equal(d.panel.hidden,false);});
test('a stale panel identifier does not install a broken click handler',()=>{const button={dataset:{djjReturnToggle:'missing'},addEventListener(){throw Error('Not expected');}};assert.doesNotThrow(()=>vm.runInNewContext(read('assets-ui'),{document:{querySelectorAll:()=>[button],getElementById:()=>null}}));});
test('the script is harmless outside comodato lists',()=>assert.doesNotThrow(()=>vm.runInNewContext(read('assets-ui'),{document:{querySelectorAll:()=>[]}})));
for(const action of ['Delete','Return']) test(action+' cancellation uses the real shared confirmation and prevents submission',()=>{
 let submit,prompted;
 const form={dataset:{djjConfirm:'Cancel '+action},addEventListener(name,handler){assert.equal(name,'submit');submit=handler;}};
 const document={documentElement:{toggleAttribute(){}},querySelector:()=>null,querySelectorAll:s=>s==='form[data-djj-confirm]'?[form]:[],addEventListener(){}};
 const window={matchMedia:()=>({matches:false,addEventListener(){}}),addEventListener(){},confirm(message){prompted=message;return false;}};
 vm.runInNewContext(read('layouts'),{document,window});
 const event={prevented:false,preventDefault(){this.prevented=true;}};submit(event);assert.equal(event.prevented,true);assert.equal(prompted,'Cancel '+action);
});
