// Jobs · 微信端实际 Store 的故障、恢复、会话和请求顺序回归。
const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const vm=require('node:vm');
const {createRequire}=require('node:module');
const root=path.resolve(__dirname,'../../../../代码/前端/微信小程序');
const {Store,endpoint}=require('../../../../代码/前端/微信小程序/utils/store');
const F=require('../../../../代码/前端/微信小程序/utils/form');
const D=require('../../../../代码/前端/微信小程序/utils/demo');
const C=require('../../../../代码/前端/微信小程序/assets/contract.json');
const copy=x=>JSON.parse(JSON.stringify(x));
const actor={id:'customer',role:'customer',companyId:'company-a',status:'active',authVersion:1};
function snapshot(){const s=D.seed();s.actor=copy(actor);s.metrics={openCount:6,remainingCents:12345};s.orders.forEach(o=>{o.allowedActions=['remark'];});return s;}
function reply(route,s=snapshot()){
  if(route==='/login')return {token:'synthetic-token',actor:copy(actor)};
  if(route==='/bootstrap')return s;
  if(route.startsWith('/orders?'))return {items:s.orders,total:s.orders.length,page:1,pageSize:30,totalPages:1};
  if(route.startsWith('/orders/'))return s.orders.find(o=>o.id===route.split('/')[2]);
  if(route==='/logout')return {ok:true};
}
const route=o=>o.url.split('/api/v38')[1];
const ok=data=>({statusCode:200,data});
const deferred=()=>{let resolve,reject;const promise=new Promise((a,b)=>{resolve=a;reject=b;});return {resolve,reject,promise};};
function liveStore(transport){const s=new Store(transport||(async(o)=>ok(reply(route(o)))));return s;}

test('表单按十进制分提交，拒绝科学计数/超过两位小数',()=>{
  assert.equal(F.payload([{key:'amountCents',type:'money',value:'123.45',label:'金额'}]).amountCents,12345);
  for(const value of ['1e5','0.001','-1','NaN'])assert.throws(()=>F.payload([{key:'amountCents',type:'money',value,label:'金额'}]));
  assert.throws(()=>endpoint('https://user:password@example.com'));
  assert.throws(()=>endpoint('http://example.com'));
  assert.throws(()=>endpoint('https://example.com/api'));
});
test('登录成功读取授权分页；读取故障只回退独立样例，恢复成功覆盖',async()=>{
  let offline=false;const store=liveStore(async o=>{if(offline)throw Error('网络断开');return ok(reply(route(o)));});
  await store.login('customer','x');assert.equal(store.source,'server');assert.equal(store.snapshot.metrics.remainingCents,12345);
  offline=true;await store.refresh();assert.equal(store.source,'demo');assert.equal(store.writable,false);assert.equal(store.detail,null);
  offline=false;await store.refresh();assert.equal(store.source,'server');assert.equal(store.snapshot.metrics.remainingCents,12345);
});
test('离线演示写入仍请求API；服务恢复后自动重建合成账号会话并覆盖',async()=>{
  let offline=true,calls=[];const store=liveStore(async o=>{calls.push(route(o));if(offline)throw Error('离线');return ok(reply(route(o)));});
  await store.login('customer','Demo-Repair-2026!');assert.equal(store.source,'demo');
  const order=await store.write('/orders',{customer:'合成客户',customerId:'customer',companyId:'company-demo',project:'合成机房',device:'合成设备',type:'mail',description:'合成故障'});
  assert.ok(order.id.startsWith('demo-'));assert.ok(calls.includes('/orders'));
  offline=false;await store.refresh();assert.equal(store.source,'server');assert.equal(store.actor.id,'customer');assert.equal(store.demoActor,null);
});
test('未知写入不转换为演示成功，原请求键同内容重试后才释放',async()=>{
  let fail=true,keys=[];const record=snapshot().orders[0];
  const store=liveStore(async o=>{if(o.method==='POST'&&route(o)==='/orders'){keys.push(o.header['Idempotency-Key']);if(fail)throw Error('回包丢失');return ok(record);}return ok(reply(route(o)));});
  await store.login('customer','x');const body={device:'合成设备'};
  await assert.rejects(()=>store.write('/orders',body),/结果暂不确定/);assert.equal(store.intents.size,1);
  fail=false;await store.write('/orders',body);assert.equal(keys[0],keys[1]);assert.equal(store.intents.size,0);
  await store.write('/orders',body);assert.notEqual(keys[1],keys[2]);
});
test('错误2xx写入保留意图；401清除真实身份和私有视图',async()=>{
  const store=liveStore(async o=>o.method==='POST'&&route(o)==='/orders'?ok({id:'wrong'}):ok(reply(route(o))));
  await store.login('customer','x');await assert.rejects(()=>store.write('/orders',{}),/结果暂不确定/);assert.equal(store.intents.size,1);
  store.transport=async()=>({statusCode:401,data:{message:'会话撤销'}});await store.refresh();assert.equal(store.token,'');assert.equal(store.snapshot,null);assert.equal(store.actor,null);assert.equal(store.intents.size,0);
});
test('同一会话的旧刷新失败不覆盖新成功数据',async()=>{
  const old=deferred();let n=0;const store=liveStore();await store.login('customer','x');
  store.transport=async o=>route(o)==='/bootstrap'&&++n===1?old.promise:ok(reply(route(o)));
  const first=store.refresh();await store.refresh();old.reject(Error('迟到失败'));await first;
  assert.equal(store.source,'server');assert.equal(store.snapshot.metrics.remainingCents,12345);
});
test('较旧详情回包及旧退出回包不能覆盖较新状态',async()=>{
  const old=deferred(),s=snapshot();const store=liveStore();await store.login('customer','x');
  store.transport=async o=>route(o).endsWith(s.orders[0].id)?old.promise:ok(reply(route(o),s));
  const first=store.readDetail(s.orders[0].id);await store.readDetail(s.orders[1].id);old.resolve(ok(s.orders[0]));await first;
  assert.equal(store.detail.id,s.orders[1].id);
  const logout=deferred();store.transport=async o=>route(o)==='/logout'?logout.promise:ok(reply(route(o),s));
  const pending=store.logout();await store.login('customer','x');logout.resolve(ok({ok:true}));await pending;assert.equal(store.actor.id,'customer');assert.ok(store.token);
});
test('WXML动态指令必须绑定表达式，事件处理函数与本地资源可达',()=>{
  const pageFile=path.join(root,'pages/workbench/index.js'),markup=fs.readFileSync(path.join(root,'pages/workbench/index.wxml'),'utf8');
  for(const m of markup.matchAll(/wx:(if|elif|for)\s*=\s*"([^"]*)"/g))assert.ok(/^{{[\s\S]*}}$/.test(m[2]),m[0]);
  let page;vm.runInNewContext(fs.readFileSync(pageFile,'utf8'),{require:createRequire(pageFile),wx:{getStorageSync:()=>null},Page:v=>page=v});
  for(const m of markup.matchAll(/(?:bind|catch)[\w:]*="(\w+)"/g))assert.equal(typeof page[m[1]],'function',m[1]);
  assert.ok(fs.existsSync(path.join(root,'assets/RepairLogo.png')));
  assert.equal(C.actions.length,43);
  for(const action of C.actions)assert.equal(typeof F.action(action.type).label,'string');
  const sourceContract=path.resolve(root,'../后台管理端/共享契约/admin-ui.json');
  assert.deepEqual(C,JSON.parse(fs.readFileSync(sourceContract,'utf8')));
});
test('HTTP500结果未知，改变正文不能绕过原提交意图',async()=>{
  let writes=0;const store=liveStore(async o=>{if(route(o)==='/orders'&&o.method==='POST'){writes++;return {statusCode:500,data:{message:'internal error'}};}return ok(reply(route(o)));});
  await store.login('customer','x');await assert.rejects(()=>store.write('/orders',{device:'A'}),e=>e.uncertain===true);
  assert.ok(store.pendingWrite);await assert.rejects(()=>store.write('/orders',{device:'B'}),/未确认/);assert.equal(writes,1);
});
test('1MB附件base64只留逻辑层，不经setData传入视图',()=>{
  const pageFile=path.join(root,'pages/workbench/index.js');let page;const updates=[];const blob='A'.repeat(1400000);
  const wx={getStorageSync:()=>null,chooseMessageFile:options=>options.success({tempFiles:[{name:'synthetic.pdf',path:'/synthetic',size:1048576}]}),getFileSystemManager:()=>({readFile:options=>options.success({data:blob})})};
  vm.runInNewContext(fs.readFileSync(pageFile,'utf8'),{require:createRequire(pageFile),wx,Page:v=>page=v});
  page.data={screen:'form',fields:[{key:'data',type:'file',value:''},{key:'name',type:'text',value:''}]};page.formSerial=1;page.setData=update=>{updates.push(JSON.stringify(update));Object.assign(page.data,update);};
  page.chooseFile();assert.equal(page.fileData.length,blob.length);assert.ok(updates.every(v=>v.length<1024));assert.equal(page.data.fields[0].value,'');
  page.invalidateForm();assert.equal(page.fileData,null);
});
test('真实隔离Go服务：登录、分页、创建、详情及版本动作', {skip:!process.env.REPAIR_TEST_BASE},async()=>{
  const base=new URL(process.env.REPAIR_TEST_BASE);
  assert.equal(base.hostname,'127.0.0.1');assert.ok(!['8098','8099',''].includes(base.port));
  const store=new Store(async options=>{const response=await fetch(options.url,{method:options.method,headers:options.header,body:options.data===undefined?undefined:JSON.stringify(options.data),signal:AbortSignal.timeout(options.timeout)});return {statusCode:response.status,data:await response.text()};},{base:base.origin,timeout:10000});
  await store.login('admin','Demo-Repair-2026!');assert.equal(store.source,'server');
  const order=await store.write('/orders',{type:'mail',customer:'微信回归合成客户',customerId:'customer',companyId:'company-a',project:'独立回归',device:'微信合成主板',description:'小程序真实API回归',customerNote:''});
  await store.refresh({q:order.number});assert.equal(store.snapshot.orders.length,1);assert.equal(store.snapshot.orders[0].id,order.id);
  const detail=await store.readDetail(order.id);assert.notEqual(detail.isSummary,true);
  const result=await store.write('/orders/'+order.id+'/actions',{type:'remark',version:detail.version,payload:{customerNote:'微信端合成回归备注'}},order.id);
  assert.equal(result.customerNote,'微信端合成回归备注');await store.logout();assert.equal(store.token,'');
});
