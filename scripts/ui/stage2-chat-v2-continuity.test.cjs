'use strict';
const {test}=require('node:test');const assert=require('node:assert/strict');const {Controller,decimal}=require('../../Proyecto_Final/wwwroot/js/stage2/chat-v2-continuity.js');
function fixture(){let context='opaque-A',allow=true,writable=true,rows=[],sent=[],lost=false,active=0,max=0,hold=null;const rendered=[];const calls=[];
 const api=async(name,body,signal)=>{calls.push(name);active++;max=Math.max(max,active);try{
  if(hold&&name===hold.name){const current=hold;hold=null;await current.promise;}
  if(name==='context')return {contextHandle:context};if(!allow){const e=new Error();e.status=403;throw e;}
  if(name==='membership')return {authorized:true,canSend:writable};if(name==='prepare')return {intentBinding:'binding-original'};
  if(name==='history')return {messages:rows,nextCursor:null};
  if(name==='receipt'){const row=rows.find(x=>x.requestId===body.requestId);if(row)return row;const e=new Error();e.status=404;throw e;}
  if(name==='send'){sent.push(body);let row=rows.find(x=>x.requestId===body.requestId);if(!row){row={requestId:body.requestId,domain:body.domain,resourceId:body.resource,messageId:'9007199254740993',streamSequence:'9007199254740995',content:body.content,persistedState:'PERSISTED'};rows.push(row);}if(lost){lost=false;throw new Error('lost');}return row;}
  throw new Error('Unexpected');
 }finally{active--;}};
 const c=new Controller(api,{clear(){rendered.splice(0);},render(value){rendered.splice(0,rendered.length,...value);}}, {uuid:()=> 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'});
 return {c,calls,sent,rendered,get max(){return max;},set lost(v){lost=v;},set context(v){context=v;},set allow(v){allow=v;},set writable(v){writable=v;},add(row){rows.push(row);},hold(name){let release;const promise=new Promise(r=>release=r);hold={name,promise};return release;}};
}
test('lost HTTP + refresh preserves exact UUID/content and recovers receipt without another send',async()=>{const f=fixture();await f.c.select('P',1);f.lost=true;await f.c.send(' exact <script>ñ</script> ');const pending=f.c.pending;assert.ok(pending);await f.c.refresh();assert.equal(f.sent.length,1);assert.equal(f.sent[0].requestId,pending.requestId);assert.equal(f.sent[0].content,pending.content);assert.equal(f.c.pending,null);assert.equal(f.rendered.length,1);assert.ok(f.calls.lastIndexOf('receipt')>f.calls.lastIndexOf('send'));});
test('Invalidate receipt-first uses same original intent',async()=>{const f=fixture();await f.c.select('P',1);f.lost=true;await f.c.send('fixed');await f.c.invalidate();assert.equal(f.sent.length,1);assert.equal(f.rendered.length,1);});
test('HTTP absent receipt retries exact UUID with immutable body and binding',async()=>{const f=fixture();await f.c.select('P',1);const release=f.hold('send');const task=f.c.send('fixed');await new Promise(setImmediate);const pending=f.c.pending;const refresh=f.c.refresh();release();await Promise.all([task,refresh]);assert.equal(new Set(f.sent.map(x=>x.requestId)).size,1);assert.ok(f.sent.every(x=>x.content===pending.content&&x.intentBinding==='binding-original'));assert.equal(f.rendered.length,1);});
test('cookie/account change purges attempt and never transfers to new context',async()=>{const f=fixture();await f.c.select('P',1);f.lost=true;await f.c.send('private');f.context='opaque-B';await f.c.refresh();assert.equal(f.c.pending,null);assert.equal(f.sent.length,1);});
test('logout discards late successful send and leaves no visible bodies',async()=>{const f=fixture();await f.c.select('P',1);const release=f.hold('send');const task=f.c.send('private');await new Promise(setImmediate);f.c.logout();release();await task;assert.equal(f.c.pending,null);assert.equal(f.rendered.length,0);});
test('revoked authorization purges pending and visible content',async()=>{const f=fixture();await f.c.select('P',1);f.lost=true;await f.c.send('private');f.allow=false;await f.c.refresh();assert.equal(f.c.pending,null);assert.equal(f.rendered.length,0);});
test('poll/invalidate coalesce history and recover other participant HTTP without duplication',async()=>{const f=fixture();await f.c.select('P',1);f.add({messageId:'9007199254740997',streamSequence:'9007199254740999',content:'other participant'});await Promise.all([f.c.poll(),f.c.poll(),f.c.invalidate(),f.c.invalidate()]);assert.equal(f.max,1);assert.equal(f.rendered.length,1);await f.c.poll();assert.equal(f.rendered.length,1);});
test('resource switch and F5 new instance cannot recover another context attempt',async()=>{const f=fixture();await f.c.select('P',1);f.lost=true;await f.c.send('private');await f.c.select('C',1);assert.equal(f.c.pending,null);assert.equal(fixture().c.pending,null);});
test('BIGINT decimal string validation and exact order',()=>{assert.equal(decimal('9007199254740993'),'9007199254740993');assert.throws(()=>decimal(9007199254740993));assert.throws(()=>decimal('9223372036854775808'));});

test('cookie change after committed response prevents rendering under a different account',async()=>{
 let context='A',rows=[],rendered=[];
 const api=async(name,body)=>{
  if(name==='context')return {contextHandle:context};
  if(name==='membership')return {authorized:true,canSend:true};
  if(name==='history')return {messages:rows,nextCursor:null};
  if(name==='prepare')return {intentBinding:'binding'};
  if(name==='send'){context='B';return {requestId:body.requestId,domain:body.domain,resourceId:body.resource,messageId:'1',streamSequence:'1',content:body.content,persistedState:'PERSISTED'};}
 };
 const c=new Controller(api,{clear(){rendered=[];},render(v){rendered=v;}},{uuid:()=> 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'});
 await c.select('P',1);await c.send('private');assert.equal(rendered.length,0);assert.equal(c.pending,null);assert.equal(c.lastState,'AccessChanged');
});
test('private browser persistence APIs are not part of the continuity implementation',()=>{
 const fs=require('node:fs');const source=fs.readFileSync(require.resolve('../../Proyecto_Final/wwwroot/js/stage2/chat-v2-continuity.js'),'utf8');
 assert.doesNotMatch(source,/localStorage|sessionStorage|indexedDB/);
});

test('read-only membership leaves history available but cannot initiate send',async()=>{const f=fixture();f.writable=false;await f.c.select('D',1);assert.equal(f.c.canSend,false);await f.c.send('not allowed');assert.equal(f.sent.length,0);assert.equal(f.c.pending,null);});

// Offline integration of the actual scripts with a minimal DOM/fetch boundary.
// This does not certify a browser, HTTP server, SQL authorization or CSS layout.
async function pageFixture({unavailable=false,writable=false}={}){
 const vm=require('node:vm'),fs=require('node:fs');const calls=[];
 class Element{
  constructor(){this.disabled=true;this.hidden=false;this.value='';this.textContent='';this.children=[];this.listeners={};this.options=[];}
  addEventListener(name,listener){this.listeners[name]=listener;}
  replaceChildren(...nodes){this.children=nodes;if(this.isSelect)this.options=nodes;}
  get selectedOptions(){return this.options.filter(o=>o.value===this.value);}
  set innerHTML(_){throw new Error('Private content must never be rendered as HTML');}
 }
 class Option extends Element{constructor(text,value){super();this.textContent=text;this.value=value;this.disabled=false;}}
 const ids=['status','domain','resource','messages','empty','content','send','retry','refresh','compose'];
 const elements=Object.fromEntries(ids.map(id=>['#chat-v2-'+id,new Element()]));
 elements['#chat-v2-domain'].isSelect=true;elements['#chat-v2-domain'].options=['P','D','C'].map(v=>new Option(v,v));elements['#chat-v2-domain'].value='P';
 elements['#chat-v2-resource'].isSelect=true;elements['#chat-v2-refresh'].disabled=false;
 const root={dataset:{apiRoot:'/ChatV2/'},querySelector(selector){return selector.startsWith('input[')?{value:'synthetic-antiforgery'}:elements[selector];}};
 const document={hidden:false,querySelector(){return root;},createElement(){return new Element();},addEventListener(){}};
 const window={ChatContinuity:{Controller},addEventListener(){}};
 const fetch=async(url,options)=>{const name=url.pathname.split('/').pop();calls.push({name,method:options.method});
  if(unavailable)return {ok:false,status:503,redirected:false};
  const data=name==='Context'?{contextHandle:'page-context',internalChat:true,attention:false,management:false}:
   name==='Own'?[{domain:'P',resourceId:1}]:name==='Membership'?{authorized:true,canSend:writable}:
   name==='History'?{messages:[{messageId:'1',streamSequence:'1',content:'<img src=x onerror=alert(1)>'}],nextCursor:null}:null;
  if(data===null)throw new Error('Unexpected request');return {ok:true,redirected:false,json:async()=>data};
 };
 vm.runInNewContext(fs.readFileSync(require.resolve('../../Proyecto_Final/wwwroot/js/stage2/chat-v2.js'),'utf8'),
  {window,document,ChatContinuity:window.ChatContinuity,location:{origin:'https://synthetic.invalid'},URL,Option,fetch,
   setInterval(){return 1;},clearInterval(){},HTMLFormElement:class{}});
 await new Promise(setImmediate);
 return {elements,calls,async select(){elements['#chat-v2-resource'].value='1';elements['#chat-v2-resource'].listeners.change();await new Promise(setImmediate);}};
}
test('page with unavailable persistence keeps composer disabled and never attempts a mutation',async()=>{
 const p=await pageFixture({unavailable:true});assert.equal(p.elements['#chat-v2-content'].disabled,true);
 assert.equal(p.elements['#chat-v2-send'].disabled,true);assert.equal(p.elements['#chat-v2-domain'].disabled,true);
 assert.match(p.elements['#chat-v2-status'].textContent,/no está disponible/);assert.deepEqual(p.calls,[{name:'Context',method:'GET'}]);
});
test('page renders hostile message as text and keeps read-only composer disabled',async()=>{
 const p=await pageFixture();await p.select();assert.equal(p.elements['#chat-v2-messages'].children[0].textContent,'<img src=x onerror=alert(1)>');
 assert.equal(p.elements['#chat-v2-send'].disabled,true);assert.equal(p.elements['#chat-v2-content'].disabled,true);
 assert.equal(p.elements['#chat-v2-status'].textContent,'Conversación de solo lectura.');assert.ok(p.calls.every(c=>c.method==='GET'));
});
test('page enables composer only after authorized writable membership',async()=>{
 const p=await pageFixture({writable:true});assert.equal(p.elements['#chat-v2-send'].disabled,true);await p.select();
 assert.equal(p.elements['#chat-v2-content'].disabled,false);assert.equal(p.elements['#chat-v2-send'].disabled,false);
});
