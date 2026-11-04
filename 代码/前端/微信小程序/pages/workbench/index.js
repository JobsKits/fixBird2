// Jobs · 微信原生维修工作台，所有业务裁决沿用 V3.8 API。
const {Store,wxTransport}=require('../../utils/store');
const F=require('../../utils/form');
const C=require('../../assets/contract.json');
const money=value=>(Number(value||0)/100).toFixed(2);
const text=value=>value === undefined || value === null || value === '' ? '—' : String(value);
const store=new Store(wxTransport(wx),wx.getStorageSync('repair-config')||{});
Page({
  data:{screen:'login',previous:'orders',username:'customer',password:'',busy:false,message:store.message,source:'demo',roles:C.roles,
    states:[{value:'',label:'全部阶段'},...C.states],stateIndex:0,q:'',page:1,orders:[],parts:[],loans:[],purchases:[],fields:[],base:store.base,timeout:store.timeout},
  onLoad(){this.showState();},
  onShow(){if(store.actor||store.demoActor)this.reload();},
  onPullDownRefresh(){this.reload().finally(()=>wx.stopPullDownRefresh());},
  onHide(){this.invalidateForm();},
  onUnload(){this.invalidateForm();},
  invalidateForm(){this.formSerial=(this.formSerial||0)+1;this.fileData=null;},
  async run(job){
    if(this.data.busy)return;
    this.setData({busy:true});
    try {await job();} catch(error){wx.showToast({title:error.message||'操作未完成',icon:'none',duration:4000});this.setData({error:error.message});}
    finally {this.showState();this.setData({busy:false});}
  },
  showState(){
    const snapshot=store.snapshot;
    const update={pending:!!store.pendingWrite,message:store.message,source:store.source,loggedIn:!!(store.actor||store.demoActor),writable:store.writable,actor:store.actor||store.demoActor};
    if(!update.loggedIn){this.order=null;this.detailId=null;this.formRecord=null;}
    if(!update.loggedIn)Object.assign(update,{screen:'login',orders:[],detail:null,sections:[],fields:[],actions:[],evidence:[],parts:[],loans:[],purchases:[]});
    if(snapshot)Object.assign(update,{orders:(snapshot.orders||[]).map(o=>Object.assign({},o,{stateLabel:(C.states.find(s=>s.value===o.status)||{}).label||o.status,remaining:money(o.summary.remainingCents)})),
      parts:snapshot.parts||[],loans:snapshot.loans||[],purchases:snapshot.purchases||[],openCount:snapshot.metrics.openCount,remaining:money(snapshot.metrics.remainingCents),pagination:snapshot.orderPage});
    this.setData(update);
  },
  input(event){this.setData({[event.currentTarget.dataset.key]:event.detail.value});},
  role(event){this.setData({username:C.roles[Number(event.detail.value)].id,password:'',screen:'login'});},
  login(){return this.run(async()=>{
    this.invalidateForm();const username=this.data.username.trim(),password=this.data.password;
    const promise=store.login(username,password);this.showState();await promise;
    this.setData({password:'',screen:store.actor||store.demoActor?'orders':'login',q:'',page:1,error:''});
  });},
  async reload(){
    if(!store.actor&&!store.demoActor)return;
    const old=this.data.screen;
    await this.run(async()=>{await store.refresh({q:this.data.q,page:this.data.page,status:this.data.states[this.data.stateIndex].value});
      if(old==='detail'&&this.data.detail&&store.source==='server')await this.loadDetail(this.data.detail.id);
      else if(old==='detail'){this.invalidateForm();this.setData({detail:null,sections:[],screen:'orders'});}
      if(old==='form'&&store.source!=='server'&&store.token){this.invalidateForm();this.setData({fields:[],screen:'orders'});}
    });
  },
  search(){this.setData({page:1});return this.reload();},
  state(event){this.setData({stateIndex:Number(event.detail.value),page:1});return this.reload();},
  turn(event){const page=this.data.page+Number(event.currentTarget.dataset.step);if(page<1||page>Math.max(1,this.data.pagination.totalPages))return;this.setData({page});return this.reload();},
  nav(event){this.invalidateForm();this.setData({screen:event.currentTarget.dataset.screen,error:'',fields:[],detail:null,sections:[]});store.detailSequence++;store.detail=null;if(this.data.screen==='orders'||this.data.screen==='inventory')this.reload();},
  open(event){return this.run(()=>this.loadDetail(event.currentTarget.dataset.id));},
  async loadDetail(id){
    this.invalidateForm();const serial=this.formSerial;this.detailId=id;this.setData({screen:'detail',detail:null,sections:[],error:''});
    const order=await store.readDetail(id);if(!order||serial!==this.formSerial||this.data.screen!=='detail')return;
    const sections=[['工单资料',[['工单号',order.number],['客户',order.customer],['位置',order.project],['设备',order.device],['描述',order.description],['当前待办',order.summary.nextTask],['待收（元）',money(order.summary.remainingCents)],['未办事项',order.summary.missing.join('；')]]],
      ['当前报价',[['总额（元）',money(order.quote.amountCents)],['范围',order.quote.description],['预付（元）',money(order.quote.prepayCents)],['先款开修',order.quote.startRequiresPrepayment?'是':'否'],['有效期',order.quote.validUntil],['报价版本',order.quote.version]]]];
    const definitions=[['cash','收退款',['id','amountCents','kind','purpose','verified']],['invoices','发票',['id','number','amountCents']],['issues','异议',['id','note','resolved']],['obligations','余项',['id','title','ownerId','done']],['events','办理记录',['type','note','actorId','createdAt']],['acceptanceRecords','验收历史',['passed','signerName','signedAt','note']]];
    for(const [key,label,keys]of definitions)sections.push([label,(order[key]||[]).map(v=>[text(v.id||v.type||v.signedAt),keys.map(k=>text(v[k])).join(' · ')])]);
    const actions=(order.allowedActions||[]).map(t=>F.action(t)).filter(Boolean);
    this.order=order;
    this.setData({detail:{id:order.id,number:order.number,version:order.version},sections:sections.map(([title,rows])=>({title,rows:rows.map(([label,value],index)=>({key:index,label,value:text(value)}))})),actions,evidence:order.evidence||[],screen:'detail',error:''});
  },
  retryDetail(){if(this.detailId)return this.run(()=>this.loadDetail(this.detailId));return this.reload();},
  create(){this.openForm('create','新建工单',C.createOrder,null);},
  action(event){const type=event.currentTarget.dataset.type,definition=F.action(type);if(definition)this.openForm(type,definition.label,definition.fields,this.order);},
  inventoryForm(event){
    const kind=event.currentTarget.dataset.kind,id=event.currentTarget.dataset.id;
    const record=(kind==='receivePurchase'?this.data.purchases:this.data.loans).find(v=>v.id===id);
    if(kind==='loan')return this.openForm('loan','登记借用',C.loan);
    if(kind==='purchase')return this.openForm('purchase','登记采购',C.purchase);
    if(kind==='receivePurchase')return this.openForm(kind,'采购收货',C.receivePurchase,record);
    const def=C.loanActions.find(v=>v.type===kind);if(def)this.openForm('loan:'+kind,def.label,def.fields,record);
  },
  openForm(type,title,definitions,record){
    if(!store.writable)return wx.showToast({title:'请先恢复连接或切换独立演示。',icon:'none'});
    this.invalidateForm();this.formEpoch=store.epoch;this.formRecord=record?JSON.parse(JSON.stringify(record)):null;
    this.returnScreen=this.data.screen;this.signatureDirty=false;this.setData({fileLabel:''});
    this.setData({screen:'form',formType:type,formTitle:title,fields:F.fields(definitions,record,store.actor||store.demoActor),error:''});
    if(definitions.some(f=>f.type==='signature'))wx.nextTick(()=>this.clearSignature());
  },
  field(event){
    const key=event.currentTarget.dataset.key;
    this.setData({fields:this.data.fields.map(f=>{if(f.key!==key)return f;
      let value=event.detail.value,index=f.index;if(f.type==='select'){index=Number(value);value=f.options[index].value;}
      return Object.assign({},f,{value,index});})});
  },
  clearSignature(){this.signatureDirty=false;this.signature=wx.createCanvasContext('signature',this);this.signature.setFillStyle('#fff');this.signature.fillRect(0,0,1000,400);this.signature.draw();},
  signatureStart(e){const p=e.touches[0];this.lastPoint={x:p.x,y:p.y};},
  signatureMove(e){const p=e.touches[0];if(!this.lastPoint)return;const ctx=this.signature;ctx.setStrokeStyle('#172B35');ctx.setLineWidth(3);ctx.setLineCap('round');ctx.moveTo(this.lastPoint.x,this.lastPoint.y);ctx.lineTo(p.x,p.y);ctx.stroke();ctx.draw(true);this.signatureDirty=true;this.lastPoint={x:p.x,y:p.y};},
  signatureEnd(){this.lastPoint=null;},
  captureSignature(){return new Promise((resolve,reject)=>{
    if(!this.signatureDirty)return reject(Error('请在白色区域实际手写签名。'));
    wx.canvasToTempFilePath({canvasId:'signature',fileType:'png',success:result=>wx.getFileSystemManager().readFile({filePath:result.tempFilePath,encoding:'base64',success:r=>resolve('data:image/png;base64,'+r.data),fail:()=>reject(Error('签名读取失败，请重试。'))}),fail:()=>reject(Error('签名生成失败，请重试。'))},this);
  });},
  chooseFile(){
    const serial=this.formSerial,epoch=store.epoch;
    wx.chooseMessageFile({count:1,type:'all',success:result=>{
      const file=result.tempFiles[0];if(file.size>6*1024*1024)return wx.showToast({title:'文件不能超过 6MB。',icon:'none'});
      wx.getFileSystemManager().readFile({filePath:file.path,encoding:'base64',success:read=>{
        if(serial!==this.formSerial||epoch!==store.epoch||this.data.screen!=='form')return;
        const ext=file.name.split('.').pop().toLowerCase();const mime={png:'image/png',jpg:'image/jpeg',jpeg:'image/jpeg',pdf:'application/pdf',txt:'text/plain',mp4:'video/mp4',mp3:'audio/mpeg'}[ext]||'application/octet-stream';
        this.fileData=read.data;
        this.setData({fields:this.data.fields.map(f=>Object.assign({},f,{value:f.type==='file'?'':f.key==='name'?file.name:f.key==='mime'?mime:f.key==='kind'?mime.startsWith('image')?'image':mime.startsWith('video')?'video':mime.startsWith('audio')?'audio':'document':f.value})),fileLabel:file.name});
      },fail:()=>wx.showToast({title:'文件读取失败。',icon:'none'})});
    }});
  },
  submit(){return this.run(async()=>{
    const serial=this.formSerial,epoch=this.formEpoch;if(epoch!==store.epoch)throw Error('身份已切换，请重新打开表单。');
    let values=JSON.parse(JSON.stringify(this.data.fields)).map(f=>f.type==='file'?Object.assign({},f,{value:this.fileData||''}):f);
    if(values.some(f=>f.type==='signature')){const signature=await this.captureSignature();values=values.map(f=>f.type==='signature'?Object.assign({},f,{value:signature}):f);}
    if(serial!==this.formSerial||epoch!==store.epoch)throw Error('表单已关闭，请重新核对。');
    const payload=F.payload(values),kind=this.data.formType,record=this.formRecord;let route,body;
    if(kind==='create'){route='/orders';body=payload;}
    else if(kind==='loan'){route='/loans';body=payload;}
    else if(kind==='purchase'){route='/purchases';body=payload;}
    else if(kind==='receivePurchase'){route='/purchases/'+encodeURIComponent(record.id)+'/receive';body=Object.assign({version:record.version},payload);}
    else if(kind.startsWith('loan:')){route='/loans/'+encodeURIComponent(record.id)+'/actions';body={type:kind.split(':')[1],version:record.version,payload};}
    else {route='/orders/'+encodeURIComponent(record.id)+'/actions';body={type:kind,version:record.version,payload};}
    const value=await store.write(route,body,record&&record.id);
    if(serial!==this.formSerial||epoch!==store.epoch)return;
    this.invalidateForm();this.setData({fields:[],error:'',screen:route.startsWith('/orders')?'orders':'inventory'});
    await store.refresh();if(route.startsWith('/orders'))await this.loadDetail(value.id);
    wx.showToast({title:store.source==='server'?'服务端已保存':'仅合成演示已保存',icon:'none'});
  });},
  cancelForm(){this.invalidateForm();this.setData({screen:this.returnScreen||'orders',fields:[],error:''});},
  download(event){return this.run(async()=>{
    if(!store.token||store.source!=='server')throw Error('原件下载需要服务端连接与当前授权。');
    const epoch=store.epoch;
    const result=await new Promise((resolve,reject)=>wx.downloadFile({url:store.base+'/api/v38/orders/'+encodeURIComponent(this.data.detail.id)+'/evidence/'+encodeURIComponent(event.currentTarget.dataset.id),header:{Authorization:'Bearer '+store.token},timeout:store.timeout,success:resolve,fail:()=>reject(Error('原件下载失败。'))}));
    if(epoch!==store.epoch)throw Error('身份已切换，原件未打开。');
    if(result.statusCode===401){store.clear();store.message='会话已失效，请重新登录。';throw Error(store.message);}
    if(result.statusCode!==200)throw Error('无权读取或原件不可用。');
    wx.openDocument({filePath:result.tempFilePath,showMenu:true,fail:()=>wx.previewImage({urls:[result.tempFilePath]})});
  });},
  retryPending(){return this.run(async()=>{const pending=store.pendingWrite;if(!pending)return;const value=await store.write(pending.route,pending.body,pending.expectedId);this.invalidateForm();this.setData({screen:'orders',fields:[],error:''});await store.refresh();if(pending.route.startsWith('/orders'))await this.loadDetail(value.id);wx.showToast({title:'服务端已确认原提交',icon:'none'});});},
  acknowledgePending(){wx.showModal({title:'确认已核对服务端',content:'请先在工单和业务记录核对原提交是否保存。结束重试后，新的提交会使用新的请求键。',confirmText:'已核对',success:result=>{if(!result.confirm||!store.pendingWrite)return;store.intents.delete(store.pendingWrite.identity);store.pendingWrite=null;this.showState();}});},
  saveConfig(){return this.run(async()=>{this.invalidateForm();store.configure(this.data.base,this.data.timeout);wx.setStorageSync('repair-config',{base:store.base,timeout:store.timeout});this.setData({screen:'login',fields:[],password:''});});},
  logout(){return this.run(async()=>{this.invalidateForm();await store.logout();this.setData({password:'',screen:'login',fields:[],detail:null,sections:[]});});}
});
