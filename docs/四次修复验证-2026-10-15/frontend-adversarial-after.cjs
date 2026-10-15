/* Jobs · 第四轮只读外部诊断；不修改业务或正式测试。 */
const fs = require('node:fs');
const path = require('node:path');
const Module = require('node:module');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname, '../..');
const formalPath = path.join(root, 'Workspace/tests/app.test.cjs');
const formal = fs.readFileSync(formalPath, 'utf8');
const sourcePaths=['Workspace/app.js','Workspace/data.js','Workspace/tests/app.test.cjs','Workspace/tests/data.test.cjs'];
const sourceHashes=Object.fromEntries(sourcePaths.map(p=>[p,crypto.createHash('sha256').update(fs.readFileSync(path.join(root,p))).digest('hex')]));
const helperSource = formal.slice(0, formal.indexOf('\ntest('));
assert.ok(helperSource.includes('function harness('), '必须复用实际 app.js 的正式隔离环境');
const loaded = new Module(path.join(root, 'Workspace/tests/__r4_readonly_helpers.cjs'), module);
loaded.filename = path.join(root, 'Workspace/tests/__r4_readonly_helpers.cjs');
loaded.paths = module.paths;
loaded._compile(helperSource + '\nmodule.exports={harness,fixture,reads,response,flush,connected};', loaded.filename);
const {harness,fixture,reads,response,flush,connected} = loaded.exports;
const results = [];
let active = null;
function observe(value) { active.observed = structuredClone(value); }
function privateFixture() {
  const data = fixture();
  data.orders.forEach((o,i) => {o.id='private-'+i;o.number='PRIVATE-'+i;o.remark='PRIVATE-INTERNAL-NOTE';});
  data.settings.companyAddress='PRIVATE-COMPANY-ADDRESS';
  return data;
}
async function privateSession() {
  const h=harness(); await flush();
  const data=privateFixture(); h.context.fetch=reads(data); await h.app.login('admin','synthetic');
  return {h,data};
}
function current(h) {
  const s=h.app.getState();
  return {hasToken:!!s.token,dataKind:s.dataKind,connected:s.connected,actor:s.actor.id,dataActor:s.data.actor.id,
    orders:s.data.orders.length,remainingCents:s.data.metrics?.remainingCents,cache:s.cachedDetailIds,
    privateDOM:[...h.nodes.values()].some(n=>/PRIVATE-/.test(n.innerHTML)),
    detailOpen:h.node('#detailDialog').open,formOpen:h.node('#formDialog').open,
    toast:h.node('#toast').textContent,error:h.node('#formError').textContent};
}
function expectRevoked(h) {
  observe(current(h));
  assert.equal(h.app.getState().token,'','当前会话收到明确401后必须撤销本地服务端会话');
  assert.equal(h.app.getState().dataKind,'demo','401后只保留独立合成资料');
  assert.doesNotMatch(JSON.stringify(h.app.getState().data),/PRIVATE-/,'401后真实缓存必须清除');
}
async function run(id,title,fn) {
  active={id,title,status:'running'};
  try {await fn();active.status='passed';}
  catch(e) {active.status='failed';active.error={name:e.name,message:e.message,stack:e.stack};}
  results.push(active); console.log(JSON.stringify(active));active=null;
}
async function main() {
  await run('R4-C01','完整详情401后撤销会话和旧真实资料',async()=>{
    const {h,data}=await privateSession();
    h.context.fetch=async()=>response({message:'synthetic revoked'},401);
    await h.app.openDetail(data.orders[0].id); expectRevoked(h);
  });
  await run('R4-C02','附件原件401后撤销会话和旧真实资料',async()=>{
    const {h,data}=await privateSession();await h.app.openDetail(data.orders[0].id);
    h.context.fetch=async()=>response({message:'synthetic revoked'},401);
    await h.app.previewFile('synthetic-evidence',data.orders[0].id);expectRevoked(h);
  });
  await run('R4-C03','授权导出401后撤销会话和旧真实资料',async()=>{
    const {h}=await privateSession();h.context.fetch=async()=>response({message:'synthetic revoked'},401);
    await h.node('#exportOrders').onclick();expectRevoked(h);
  });
  await run('R4-C04','业务写401后撤销会话和旧真实资料，不能显示旧账号仍已连接',async()=>{
    const {h,data}=await privateSession();await h.app.showAction('remark',data.orders[0].id);
    h.context.fetch=async()=>response({message:'synthetic revoked'},401);
    await h.submit('actionForm',{remark:'新的合成备注',customerNote:'合成对客说明'});expectRevoked(h);
  });
  await run('R4-C05','账号元数据401后撤销会话和旧真实资料',async()=>{
    const {h,data}=await privateSession();
    h.context.fetch=(url,options)=>url.endsWith('/accounts')?Promise.resolve(response({message:'synthetic revoked'},401)):reads(data)(url,options);
    await h.click({view:'settings'});await flush();expectRevoked(h);
  });
  await run('R4-C06','管理员审计401后撤销会话和旧真实资料',async()=>{
    const {h,data}=await privateSession();
    h.context.fetch=(url,options)=>url.includes('/audit?')?Promise.resolve(response({message:'synthetic revoked'},401)):reads(data)(url,options);
    await h.click({view:'settings'});await flush();expectRevoked(h);
  });
  await run('R4-C07','同一身份bootstrap401即使被导航列表先到也必须撤销会话',async()=>{
    const {h,data}=await privateSession();let finish;
    h.context.fetch=(url,options)=>url.endsWith('/bootstrap')?new Promise(r=>{finish=()=>r(response({message:'synthetic revoked'},401));}):reads(data)(url,options);
    const refreshing=h.app.refresh();await flush();await h.click({view:'finance'});finish();await refreshing;expectRevoked(h);
  });
  await run('R4-C08','新身份bootstrap失败被导航抢先时应明确回退或重试，不能保持已连接且概览永久为零',async()=>{
    const {h}=await privateSession(),data=fixture();
    data.actor={...data.actor,id:'customer',role:'customer',companyId:'company-a'};
    data.orders=[{...data.orders[0],id:'customer-current',number:'CUSTOMER-CURRENT'}];
    data.parts=[];data.loans=[];data.purchases=[];data.metrics.remainingCents=123;
    let fail;
    h.context.fetch=(url,options)=>url.endsWith('/bootstrap')?new Promise((_r,reject)=>{fail=()=>reject(Error('synthetic network failure'));}):reads(data)(url,options);
    const loggingIn=h.app.login('customer','synthetic');await flush();await h.click({view:'finance'});fail();await loggingIn;
    observe(current(h));
    assert.ok(h.app.getState().dataKind==='demo'||h.app.getState().data.metrics.remainingCents===123,
      'bootstrap失败后应回退独立演示或成功补读当前身份概览，不能停留部分真数据+零概览');
  });
  await run('R4-C09','服务返回部分坏库存2xx时可控回退，不使render抛错并留下半套真资料',async()=>{
    const h=await connected(),bad=fixture();bad.parts=[null];h.context.fetch=reads(bad);
    let thrown;try{await h.app.refresh();}catch(e){thrown=e;}
    observe({...current(h),thrown:thrown?.message});
    assert.equal(thrown,undefined,'坏响应应拒绝并回退，不应逃出render造成页面未完成');
    assert.equal(h.app.getState().dataKind,'demo','坏库存响应不能采用为真数据');
  });
  await run('R4-C10','服务返回缺missing的详情2xx时显示可重试错误，不使详情直接抛错',async()=>{
    const {h,data}=await privateSession(),bad=structuredClone(data.orders[0]);delete bad.summary.missing;
    h.context.fetch=async()=>response(bad);let thrown;try{await h.app.openDetail(bad.id);}catch(e){thrown=e;}
    observe({...current(h),thrown:thrown?.message,detailHTML:h.node('#detailContent').innerHTML.slice(0,500)});
    assert.equal(thrown,undefined,'详情缺必填派生字段应拒绝并显示完整空态，不应向事件循环抛错');
    assert.match(h.node('#detailContent').innerHTML,/工单详情未加载/);
  });
  await run('R4-C11','403业务拒绝保留真实事实和表单，无模拟成功',async()=>{
    const {h,data}=await privateSession(),before=JSON.stringify(h.app.getState().data);await h.app.showAction('remark',data.orders[0].id);
    h.context.fetch=async()=>response({message:'synthetic forbidden'},403);await h.submit('actionForm',{remark:'不得落入演示'});
    observe(current(h));assert.equal(h.app.getState().dataKind,'server');assert.equal(JSON.stringify(h.app.getState().data),before);
    assert.equal(h.node('#formDialog').open,true);assert.match(h.node('#formError').textContent,/synthetic forbidden/);
  });
  await run('R4-C12','旧身份详情401迟到不能撤销新身份成功会话',async()=>{
    const {h,data}=await privateSession();let finish;
    h.context.fetch=()=>new Promise(r=>{finish=()=>r(response({message:'old synthetic revoked'},401));});
    const detail=h.app.openDetail(data.orders[0].id);await flush();
    const next=fixture();next.actor={...next.actor,id:'finance',role:'finance'};h.context.fetch=reads(next);await h.app.login('finance','synthetic');
    finish();await detail;observe(current(h));assert.equal(h.app.getState().actor.id,'finance');assert.ok(h.app.getState().token);assert.equal(h.app.getState().dataKind,'server');
  });
  await run('R4-C13','附件读取失败时保留当前真实表单且不发送动作',async()=>{
    const {h,data}=await privateSession();let reader;h.context.FileReader=class{constructor(){reader=this;}readAsDataURL(){}};
    await h.app.showAction('evidence',data.orders[0].id);const submitted=h.submit('actionForm',{name:'合成附件',kind:'image',stage:'settling',file:{size:10,type:'image/png'}});
    const before=h.calls.filter(c=>c.url.endsWith('/actions')).length;reader.onerror();await submitted;observe(current(h));
    assert.equal(h.calls.filter(c=>c.url.endsWith('/actions')).length,before);assert.equal(h.node('#formDialog').open,true);assert.match(h.node('#formError').textContent,/无法读取文件/);
  });
  await run('R4-C14','当前列表401按既有路径撤销会话，作为401对照组',async()=>{
    const {h}=await privateSession();h.context.fetch=async()=>response({message:'synthetic revoked'},401);await h.app.loadOrders();expectRevoked(h);
  });
  await run('R4-C15','当前bootstrap网络失败无导航抢先时进入独立回退，作为并发失败对照组',async()=>{
    const {h}=await privateSession();h.context.fetch=async()=>{throw Error('synthetic offline');};await h.app.refresh();observe(current(h));
    assert.equal(h.app.getState().dataKind,'demo');assert.ok(h.app.getState().token,'非401保留可信身份用于恢复');
    assert.doesNotMatch(JSON.stringify(h.app.getState().data),/PRIVATE-/);
  });
  await run('R4-C16','坏JSON写响应不能提示成功或迁入演示',async()=>{
    const {h,data}=await privateSession();await h.app.showAction('remark',data.orders[0].id);
    const before=JSON.stringify(h.app.getState().data);h.context.fetch=async()=>({ok:true,status:200,json:async()=>{throw SyntaxError('synthetic json');}});
    await h.submit('actionForm',{remark:'合成未知提交'});observe(current(h));
    assert.equal(h.app.getState().dataKind,'server');assert.equal(JSON.stringify(h.app.getState().data),before);
    assert.equal(h.node('#formDialog').open,true);assert.match(h.node('#formError').textContent,/无法解析/);
  });
  await run('R4-C17','当前有效空bootstrap和空列表正常显示空态',async()=>{
    const h=await connected(),data=fixture();data.orders=[];data.orderPage={page:1,pageSize:30,total:0,totalPages:0};
    for(const key of Object.keys(data.metrics))data.metrics[key]=0;data.parts=[];data.loans=[];data.purchases=[];
    h.context.fetch=reads(data);await h.app.refresh();observe(current(h));assert.equal(h.app.getState().dataKind,'server');
    assert.match(h.node('#ordersEmpty').innerHTML,/暂无符合条件的工单/);assert.match(h.node('#ordersEmpty').innerHTML,/重新加载/);
  });
  await run('R4-C18','打开无关动作表单不应丢失公司配置未知提交的请求键',async()=>{
    const h=await connected(),fields={companyAddress:'合成未知提交地址',companyReceiver:'合成收件',companyPhone:'合成电话',reminderHours:'24'};
    h.context.fetch=async()=>{throw Error('synthetic unknown commit');};await h.submit('companyForm',fields);
    const original=h.calls.findLast(c=>c.url.endsWith('/settings')).options.headers['Idempotency-Key'];
    h.app.createForm();await h.click({close:'form'});await h.submit('companyForm',fields);
    const retry=h.calls.findLast(c=>c.url.endsWith('/settings')).options.headers['Idempotency-Key'];
    observe({...current(h),sameIdempotencyKey:original===retry,settingsWrites:h.calls.filter(c=>c.url.endsWith('/settings')).length});
    assert.equal(retry,original,'公司配置未知结果的相同输入重试必须保留原键，不能被无关弹窗重置');
  });
  await run('R4-C19','超限附件在读取前本地拒绝，不发送文件和动作',async()=>{
    const {h,data}=await privateSession();let readerCount=0;h.context.FileReader=class{constructor(){readerCount++;}readAsDataURL(){}};
    await h.app.showAction('evidence',data.orders[0].id);const before=h.calls.length;
    await h.submit('actionForm',{name:'合成大附件',kind:'image',stage:'settling',file:{size:8*1024*1024+1,type:'image/png'}});
    observe({...current(h),readerCount,newCalls:h.calls.length-before});assert.equal(readerCount,0);assert.equal(h.calls.length,before);assert.match(h.node('#formError').textContent,/8 MB/);
  });
  await run('R4-C20','错误授权资料被导航抢先后不被合入，随后显式刷新可恢复',async()=>{
    const h=await connected(),wrong=fixture();wrong.actor={...wrong.actor,id:'wrong'};wrong.settings.companyAddress='WRONG-SNAPSHOT';let finish;
    h.context.fetch=(url,options)=>url.endsWith('/bootstrap')?new Promise(r=>{finish=()=>r(response(wrong));}):reads()(url,options);
    const refreshing=h.app.refresh();await flush();await h.click({view:'finance'});finish();await refreshing;
    assert.doesNotMatch(JSON.stringify(h.app.getState().data),/WRONG-SNAPSHOT/);h.context.fetch=reads();await h.app.refresh();observe(current(h));
    assert.equal(h.app.getState().actor.id,'admin');assert.equal(h.app.getState().dataKind,'server');
  });
  await run('R4-C21','新身份bootstrap503被导航抢先后不应留在零概览的真实身份',async()=>{
    const {h}=await privateSession(),data=fixture();data.actor={...data.actor,id:'customer',role:'customer',companyId:'company-a'};
    data.orders=[{...data.orders[0],id:'customer-current',number:'CUSTOMER-CURRENT'}];data.parts=[];data.loans=[];data.purchases=[];data.metrics.remainingCents=123;
    let finish;h.context.fetch=(url,options)=>url.endsWith('/bootstrap')?new Promise(r=>{finish=()=>r(response({error:'synthetic outage',message:'合成503'},503));}):reads(data)(url,options);
    const login=h.app.login('customer','synthetic');await flush();await h.click({view:'finance'});finish();await login;observe(current(h));
    assert.ok(h.app.getState().dataKind==='demo'||h.app.getState().data.metrics.remainingCents===123,'503应明确降级或补读，不能把未取得的概览当作0');
  });
  await run('R4-C22','新身份bootstrap空2xx被导航抢先后不应留在零概览的真实身份',async()=>{
    const {h}=await privateSession(),data=fixture();data.actor={...data.actor,id:'customer',role:'customer',companyId:'company-a'};
    data.orders=[{...data.orders[0],id:'customer-current',number:'CUSTOMER-CURRENT'}];data.parts=[];data.loans=[];data.purchases=[];data.metrics.remainingCents=123;
    let finish;h.context.fetch=(url,options)=>url.endsWith('/bootstrap')?new Promise(r=>{finish=()=>r(response(null));}):reads(data)(url,options);
    const login=h.app.login('customer','synthetic');await flush();await h.click({view:'finance'});finish();await login;observe(current(h));
    assert.ok(h.app.getState().dataKind==='demo'||h.app.getState().data.metrics.remainingCents===123,'空2xx应明确降级或补读，不能把未取得的概览当作0');
  });
  const afterHashes=Object.fromEntries(sourcePaths.map(p=>[p,crypto.createHash('sha256').update(fs.readFileSync(path.join(root,p))).digest('hex')]));
  assert.deepEqual(afterHashes,sourceHashes,'只读诊断不能改动业务或正式测试');
  const summary={date:'2026-10-15',mode:'read-only-external',script:__filename,actualSource:path.join(root,'Workspace/app.js'),
    tests:results.length,pass:results.filter(r=>r.status==='passed').length,fail:results.filter(r=>r.status==='failed').length,sourceUnchanged:true,sourceHashes,results};
  const outputName=process.argv[2]||'frontend-results.json';assert.ok(/^frontend-[a-z-]+\.json$/.test(outputName));
  fs.writeFileSync(path.join(__dirname,outputName),JSON.stringify(summary,null,2)+'\n');
  console.log(JSON.stringify({summary:{tests:summary.tests,pass:summary.pass,fail:summary.fail}}));
  process.exitCode=summary.fail?1:0;
}
main().catch(e=>{console.error(e.stack);process.exitCode=2;});
