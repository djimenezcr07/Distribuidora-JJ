const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");
const path = require("node:path");
const code = fs.readFileSync(path.resolve(__dirname,"../../Proyecto_Final/wwwroot/js/stage2/customer-service.js"),"utf8");
function element(value = "") { return {value, hidden:false, required:false, children:[], handlers:{}, addEventListener(n,f){this.handlers[n]=f;},replaceChildren(...v){this.children=v;},add(v){this.children.push(v);}}; }
function run({ ids={}, warranty=[], invoiceForm=null, fetchImpl=async()=>{throw Error("No network expected")}, forms=[], jquery=false }={}) {
 const handlers=[],frames=[];
 const document={getElementById:id=>ids[id]||null,querySelector:()=>invoiceForm,querySelectorAll:s=>s===".djj-service-warranty-form"?warranty:forms};
 const window={requestAnimationFrame:f=>frames.push(f)};
 if(jquery) window.jQuery=form=>({on(n,f){assert.equal(n,"invalid-form.validate");handlers.push(f);}});
 vm.runInNewContext(code,{document,window,fetch:fetchImpl,Option:function(text,value){this.text=text;this.value=value;}});
 return {handlers,frames};
}
test("ordinary lists tolerate absent form controls without requests",()=>assert.doesNotThrow(()=>run()));
test("complaint closing toggles native required and marker without mutating data",()=>{
 const state=element("Abierto"),marker=element(),text=element();run({ids:{EstadoSelect:state,ResolucionReq:marker,ResolucionTxt:text}});
 assert.equal(text.required,false);assert.equal(marker.hidden,true);state.value="Cerrado";state.handlers.change();assert.equal(text.required,true);assert.equal(marker.hidden,false);
 state.value="EnProceso";state.handlers.change();assert.equal(text.required,false);
});
test("warranty resolution is required only for existing terminal choices",()=>{
 const state=element("En revisión"),text=element(),form={querySelector:s=>s.includes("estado")?state:text};run({warranty:[form]});assert.equal(text.required,false);
 for(const s of ["Aprobada","Rechazada"]){state.value=s;state.handlers.change();assert.equal(text.required,true);}state.value="En revisión";state.handlers.change();assert.equal(text.required,false);
});
test("empty client clears optional invoice with no request",async()=>{
 const client=element(),invoices=element();run({ids:{UsuarioId:client,FacturaId:invoices},invoiceForm:{dataset:{djjInvoicesUrl:"/Reclamos/InvoicesByClient"}}});await client.handlers.change();assert.equal(invoices.children.length,1);assert.equal(invoices.children[0].value,"");
});
test("invoice GET preserves endpoint, encoded id and camelCase response",async()=>{
 const client=element("7 & 8"),invoices=element(),help=element();let url;
 run({ids:{UsuarioId:client,FacturaId:invoices,"invoice-help":help},invoiceForm:{dataset:{djjInvoicesUrl:"/Reclamos/InvoicesByClient"}},fetchImpl:async u=>{url=u;return {ok:true,json:async()=>[{facturaId:42,texto:"FACT-SINTÉTICA"}]};}});
 await client.handlers.change();assert.equal(url,"/Reclamos/InvoicesByClient?usuarioId=7%20%26%208");assert.equal(invoices.children[1].value,42);assert.equal(invoices.children[1].text,"FACT-SINTÉTICA");
});
test("stale invoice result cannot associate prior client's invoice",async()=>{
 const client=element("1"),invoices=element();let release;
 run({ids:{UsuarioId:client,FacturaId:invoices},invoiceForm:{dataset:{djjInvoicesUrl:"/Reclamos/InvoicesByClient"}},fetchImpl:()=>new Promise(r=>release=r)});
 const first=client.handlers.change();client.value="";await client.handlers.change();release({ok:true,json:async()=>[{facturaId:99,texto:"stale"}]});await first;assert.equal(invoices.children.length,1);
});
test("lookup failure leaves invoice optional and reports failure",async()=>{
 const client=element("1"),invoices=element(),help=element();run({ids:{UsuarioId:client,FacturaId:invoices,"invoice-help":help},invoiceForm:{dataset:{djjInvoicesUrl:"/Reclamos/InvoicesByClient"}},fetchImpl:async()=>({ok:false})});await client.handlers.change();assert.equal(invoices.children.length,1);assert.match(help.textContent,/No se pudieron/);assert.equal(invoices.required,false);
});
test("invalid client validation focuses updated summary without submitting",()=>{
 let focused=false;const form={querySelector:()=>({focus(){focused=true;}})};const result=run({forms:[form],jquery:true});result.handlers[0]();assert.equal(focused,false);result.frames[0]();assert.equal(focused,true);
});
