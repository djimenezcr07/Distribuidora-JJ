(() => {
 'use strict';
 const root=document.querySelector('[data-djj-chat-v2]');if(!root||!window.ChatContinuity)return;
 const status=root.querySelector('#chat-v2-status'),domain=root.querySelector('#chat-v2-domain'),resource=root.querySelector('#chat-v2-resource');
 const messages=root.querySelector('#chat-v2-messages'),empty=root.querySelector('#chat-v2-empty'),input=root.querySelector('#chat-v2-content');
 const send=root.querySelector('#chat-v2-send'),retry=root.querySelector('#chat-v2-retry'),refresh=root.querySelector('#chat-v2-refresh');
 const paths={context:'Context',own:'Own',membership:'Membership',history:'History',prepare:'Prepare',send:'Send',receipt:'Receipt'};
 const labels={Checking:'Comprobando acceso…',Ready:'Sesión y acceso comprobados.',Sending:'Enviando…',Persisted:'Mensaje guardado.',PendingConfirmation:'Resultado pendiente. Comprobá el recibo antes de reenviar.',SessionExpired:'Tu sesión terminó. Iniciá sesión de nuevo.',AccessChanged:'El contexto o la autorización cambiaron. Se limpió la conversación.',ValidationError:'Revisá el mensaje: debe contener texto y no superar 1000 caracteres.'};
 const api=async(name,body,signal)=>{
  if(!Object.hasOwn(paths,name))throw new Error('Invalid operation');
  const mutation=['prepare','send','receipt'].includes(name);const url=new URL(paths[name],new URL(root.dataset.apiRoot,location.origin));
  if(!mutation&&body)for(const [key,value]of Object.entries(body))if(value!==null&&value!==undefined)url.searchParams.set(key,String(value));
  const options={method:mutation?'POST':'GET',credentials:'same-origin',cache:'no-store',signal,headers:{Accept:'application/json'}};
  if(mutation){options.headers['Content-Type']='application/json';options.headers['X-CSRF-TOKEN']=root.querySelector('input[name="__RequestVerificationToken"]').value;options.body=JSON.stringify(body);}
  const response=await fetch(url,options);if(!response.ok||response.redirected){const e=new Error('Operation unavailable');e.status=response.redirected?401:response.status;throw e;}
  return response.json();
 };
 let controller,busy=false,closed=false;
 function updateControls(){const available=!!controller?.context&&!!controller?.resource&&controller.canSend&&!controller.pending&&!controller.refreshTask&&!controller.sendTask&&!busy&&!closed;input.disabled=!available;send.disabled=!available;retry.hidden=!controller?.pending;retry.disabled=!controller?.pending||busy;}
 function purge(){input.value='';messages.replaceChildren();empty.hidden=false;}
 controller=new ChatContinuity.Controller(api,{
  clear(){messages.replaceChildren();empty.hidden=false;},purge,
  state(code){status.textContent=code==='Ready'&&controller.resource&&!controller.canSend?'Conversación de solo lectura.':labels[code]||'Servicio no disponible.';updateControls();},
  render(rows){const nodes=rows.map(row=>{if(typeof row.content!=='string')throw new Error('Invalid message');const p=document.createElement('p');p.className='djj-chat-v2-message';p.textContent=row.content;return p;});messages.replaceChildren(...nodes);empty.hidden=rows.length>0;},
  persisted(){input.value='';}
 });
 async function conversations(){
  if(!controller.context)return;
  const data=await controller.call('own',{contextHandle:controller.context.contextHandle,domain:domain.value},controller.generation);
  const nodes=[new Option('Seleccioná una conversación','')];for(const row of data){if(!Number.isInteger(row.resourceId)||row.resourceId<=0)throw new Error('Invalid conversation');nodes.push(new Option(`Conversación #${row.resourceId}`,String(row.resourceId)));}
  const previous=controller.resource?.domain===domain.value?controller.resource.id:null;
  resource.replaceChildren(...nodes);resource.disabled=data.length===0;
  if(previous&&data.some(row=>row.resourceId===previous)){resource.value=String(previous);}
  else if(previous){controller.pending=null;controller.resource=null;controller.bump();}
 }
 async function run(action){if(busy||closed)return;busy=true;refresh.disabled=true;updateControls();try{await action();}catch(error){controller.fail(error,controller.generation);}finally{busy=false;refresh.disabled=false;updateControls();}}
 async function availability(){await controller.refresh();if(!controller.context){status.textContent='Chat V2 no está disponible: faltan infraestructura o autorización acreditadas. No se enviaron mensajes.';return;}
  const c=controller.context;for(const option of domain.options)option.disabled=option.value==='C'?!c.attention:!c.internalChat;
  const allowed=[...domain.options].filter(o=>!o.disabled);domain.disabled=!allowed.length;if(!allowed.length){status.textContent='No hay modalidades autorizadas para esta sesión.';return;}
  if(domain.selectedOptions[0]?.disabled)domain.value=allowed[0].value;await conversations();
 }
 refresh.addEventListener('click',()=>run(availability));
 domain.addEventListener('change',()=>run(async()=>{controller.pending=null;controller.resource=null;controller.bump();await availability();}));
 resource.addEventListener('change',()=>run(async()=>{if(resource.value)await controller.select(domain.value,Number(resource.value));else{controller.pending=null;controller.resource=null;controller.bump();}}));
 root.querySelector('#chat-v2-compose').addEventListener('submit',event=>{event.preventDefault();void run(()=>controller.send(input.value));});
 retry.addEventListener('click',()=>run(()=>controller.retry()));
 const stop=()=>{closed=true;controller.logout();purge();updateControls();};
 const channel=typeof BroadcastChannel==='function'?new BroadcastChannel('djj-chat-v2-session'):null;
 channel?.addEventListener('message',event=>{if(event.data==='logout')stop();});
 document.addEventListener('submit',event=>{const form=event.target;if(form instanceof HTMLFormElement&&new URL(form.action,location.origin).pathname==='/Account/Logout'){channel?.postMessage('logout');stop();}},true);
 window.addEventListener('pagehide',()=>{stop();channel?.close();});
 document.addEventListener('djj:chat-v2-invalidate',()=>run(()=>controller.invalidate()));
 const timer=setInterval(()=>{if(!busy&&controller.context&&controller.resource&&!document.hidden&&!closed)void run(()=>controller.poll());},4000);
 window.addEventListener('pagehide',()=>clearInterval(timer),{once:true});
 void run(availability);
})();
