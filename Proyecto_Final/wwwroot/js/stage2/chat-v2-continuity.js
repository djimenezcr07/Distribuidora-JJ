'use strict';
(function(root,factory){if(typeof module==='object'&&module.exports)module.exports=factory();else root.ChatContinuity=factory();})(globalThis,()=>{
 class Stale extends Error {}
 const decimal=value=>{if(typeof value!=='string'||! /^(0|[1-9]\d*)$/.test(value)||BigInt(value)>9223372036854775807n)throw new Error('Invalid BIGINT');return value;};
 class Controller {
  constructor(api,view,{uuid=()=>crypto.randomUUID()}={}){this.api=api;this.view=view;this.uuid=uuid;this.generation=0;this.context=null;this.resource=null;this.canSend=false;this.pending=null;this.rows=new Map();this.requests=new Set();this.refreshTask=null;this.refreshAgain=false;this.sendTask=null;this.closed=false;}
  emit(code){this.lastState=code;this.view.state?.(code);}
  clear(){this.rows.clear();this.view.clear();}
  bump(){this.generation++;for(const c of this.requests)c.abort();this.requests.clear();this.canSend=false;this.clear();}
  valid(g){if(g!==this.generation||this.closed)throw new Stale();}
  async call(name,body,g){this.valid(g);const c=new AbortController();this.requests.add(c);let abort;
   const cancelled=new Promise((_,reject)=>{abort=()=>reject(new Stale());c.signal.addEventListener('abort',abort,{once:true});});
   try{const task=Promise.resolve().then(()=>{this.valid(g);return this.api(name,body,c.signal);});const result=await Promise.race([task,cancelled]);this.valid(g);
    // The cookie may have changed while this response was in flight. No private response is rendered before continuity is checked again.
    if(name!=='context'){
     const current=await Promise.race([Promise.resolve().then(()=>this.api('context',undefined,c.signal)),cancelled]);this.valid(g);
     const expected=body?.contextHandle??this.context?.contextHandle;
     if(!expected||current.contextHandle!==expected){const error=new Error('Context changed');error.status=409;throw error;}
    }
    return result;}
   finally{c.signal.removeEventListener('abort',abort);this.requests.delete(c);}
  }
  sameResource(a,b){return a?.domain===b?.domain&&a?.id===b?.id;}
  async select(domain,id){if(!['P','D','C'].includes(domain)||!Number.isInteger(id)||id<=0||id>2147483647)throw new Error('Invalid resource');
   const next={domain,id};if(!this.sameResource(this.resource,next))this.pending=null;this.resource=next;return this.refresh();}
  refresh(){if(this.closed)return Promise.resolve();if(this.refreshTask){this.refreshAgain=true;return this.refreshTask;}
   this.refreshTask=(async()=>{do{this.refreshAgain=false;this.bump();const g=this.generation;this.emit('Checking');
    try{const context=await this.call('context',undefined,g);
     if(!context.contextHandle)throw new Error('Missing session contract');
     if(this.context&&context.contextHandle!==this.context.contextHandle){this.pending=null;this.view.purge?.();}
     this.context=context;
     if(this.resource){const selected={...this.resource};const access=await this.call('membership',{contextHandle:context.contextHandle,domain:selected.domain,resource:selected.id},g);this.canSend=access.canSend===true;
      if(this.pending&&!this.sameResource(this.pending,selected))this.pending=null;
      await this.history(g);if(this.pending)await this.recover(g);}
     this.emit(this.pending?'PendingConfirmation':'Ready');
    }catch(error){this.fail(error,g);} }while(this.refreshAgain&&!this.closed);})().finally(()=>{this.refreshTask=null;});return this.refreshTask;
  }
  invalidate(){return this.refresh();}
  poll(){if(this.closed||this.refreshTask||this.sendTask)return this.refreshTask??this.sendTask??Promise.resolve();return this.refresh();}
  input(p=this.pending){return {contextHandle:p.contextHandle,domain:p.domain,resource:p.id,requestId:p.requestId,intentBinding:p.intentBinding};}
  async prepare(g){const p=this.pending;if(!p)return;if(p.intentBinding)return;
   const binding=await this.call('prepare',{...this.input(p),content:p.content},g);this.valid(g);
   if(this.pending!==p)throw new Stale();this.pending=Object.freeze({...p,intentBinding:binding.intentBinding});}
  async send(content){if(this.closed||this.pending||this.sendTask||this.refreshTask||!this.context||!this.resource||!this.canSend)return;
   if(typeof content!=='string'||!content.trim()||content.length>1000){this.emit('ValidationError');return;}
   const g=this.generation;this.pending=Object.freeze({...this.resource,requestId:this.uuid(),content,contextHandle:this.context.contextHandle,intentBinding:null});
   this.sendTask=(async()=>{this.emit('Sending');try{await this.prepare(g);await this.transmit(g);}catch(error){this.fail(error,g);}})().finally(()=>{this.sendTask=null;});return this.sendTask;
  }
  async transmit(g){const p=this.pending;if(!p)return;const result=await this.call('send',{...this.input(p),content:p.content},g);this.persist(result,p,g);}
  async recover(g){await this.prepare(g);const p=this.pending;if(!p)return;
   try{const result=await this.call('receipt',this.input(p),g);this.persist(result,p,g);}
   catch(error){if(error.status===404){await this.transmit(g);}else throw error;}}
  retry(){if(this.refreshTask||this.sendTask||!this.pending)return this.refreshTask??this.sendTask??Promise.resolve();return this.refresh();}
  persist(row,p,g){this.valid(g);if(this.pending!==p||row.requestId!==p.requestId||row.domain!==p.domain||row.resourceId!==p.id||row.content!==p.content||row.persistedState!=='PERSISTED')throw new Error('Receipt conflict');
   this.merge([row]);this.pending=null;this.view.persisted?.();this.emit('Persisted');}
  merge(rows){for(const row of rows){decimal(row.messageId);decimal(row.streamSequence);this.rows.set(row.messageId,Object.freeze({...row}));}
   this.view.render([...this.rows.values()].sort((a,b)=>BigInt(a.streamSequence)<BigInt(b.streamSequence)?-1:BigInt(a.streamSequence)>BigInt(b.streamSequence)?1:0));}
  async history(g){let cursor=null;do{const data=await this.call('history',{contextHandle:this.context.contextHandle,domain:this.resource.domain,resource:this.resource.id,cursor},g);this.merge(data.messages);cursor=data.nextCursor;}while(cursor);}
  fail(error,g){if(error instanceof Stale||g!==this.generation||this.closed)return;
   if([401,403,409].includes(error.status)){this.pending=null;this.context=null;this.bump();this.view.purge?.();this.emit(error.status===401?'SessionExpired':'AccessChanged');}
   else{this.clear();this.emit('PendingConfirmation');}}
  logout(){this.closed=true;this.pending=null;this.context=null;this.resource=null;this.bump();this.view.purge?.();this.emit('SessionExpired');}
 }
 return {Controller,decimal};
});
