import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { AdminStore, fieldValue, sameActor, validOrder } from '../../../../../代码/前端/后台管理端/Web/core.mjs';
const spec=JSON.parse(await readFile(new URL('../../../../../代码/前端/后台管理端/共享契约/admin-ui.json',import.meta.url)));
const offline=async()=>new Response(JSON.stringify({message:'未连接服务'}),{status:503});
const login=async(fetcher=offline)=>{const s=new AdminStore(spec,fetcher);await s.login('admin','Demo-Repair-2026!');return s;};
test('字段按整数分、整数、时间和列表规范化',()=>{
 assert.equal(fieldValue({type:'money',label:'金额'},'12.34'),1234);
 assert.throws(()=>fieldValue({type:'int',label:'数量'},'1.5'));
 assert.throws(()=>fieldValue({type:'money',label:'金额'},'abc'));
 assert.throws(()=>fieldValue({type:'text',required:true,label:'说明'},''));
 assert.deepEqual(fieldValue({type:'list'},'a, b,,'),['a','b']);
 assert.match(fieldValue({type:'datetime'},'2026-10-30T12:00:00+08:00'),/Z$/);
});
test('401明确拒绝不能进入演示',async()=>{
 const s=new AdminStore(spec,async()=>new Response('{"message":"密码错误"}',{status:401}));
 await assert.rejects(s.login('admin','Demo-Repair-2026!'));assert.equal(s.actor,null);
});
test('503和离线使用独立种子，创建操作不污染原种子',async()=>{
 const s=await login();assert.equal(s.demo,true);assert.equal(s.snapshot.orders.length,3);
 const o=await s.create({device:'新设备',type:'onsite',customer:'客户',customerId:'customer',companyId:'company-a',description:'故障'});
 assert.equal(o.version,1);assert.equal(spec.seed.orders.length,3);assert.equal(s.snapshot.orders.length,4);
 const accepted=await s.act(o,'intake',{ownerId:'dispatcher',assigneeId:'engineer'});
 assert.equal(accepted.status,'pending_arrangement');assert.equal(accepted.version,2);
});
test('未知真实写保留同一请求键，不制造本地成功',async()=>{
 const keys=[];let fail=true;
 const s=await login();s.token='real-session';s.demo=false;
 s.fetcher=async(url,options)=>{keys.push(options.headers['Idempotency-Key']);if(fail)throw Error('网络中断');return new Response(JSON.stringify({id:'x',device:'d',version:2,status:'repairing'}));};
 const body={type:'remark',version:1,payload:{remark:'x'}};
 await assert.rejects(s.write('/orders/x/actions',body,()=>assert.fail('不应本地写')));
 await assert.rejects(s.write('/orders/x/actions',body,()=>assert.fail('不应本地写')));
 assert.equal(keys[0],keys[1]);assert.equal(s.pending.size,1);
});
test('迟到登录不能覆盖退出状态',async()=>{
 let resume;const pending=new Promise(resolve=>resume=resolve);
 const s=new AdminStore(spec,()=>pending);const work=s.login('admin','Demo-Repair-2026!');s.logout();
 resume(new Response(JSON.stringify({token:'old',actor:{id:'admin',role:'admin',status:'active'}})));await work;
 assert.equal(s.actor,null);assert.equal(s.token,'');
});
test('坏工单与身份快照拒绝',()=>{
 assert.equal(validOrder({id:'x',device:'d',version:0,status:'s'}),false);
 const a={id:'x',role:'customer',companyId:'a',authVersion:1,status:'active'};
 assert.equal(sameActor(a,{...a,companyId:'b'}),false);assert.equal(sameActor(a,{...a}),true);
});
test('无权限角色不能办理工单内部动作',async()=>{
 const s=await login();s.actor={...s.actor,id:'customer',role:'customer'};
 const o=s.local.orders[0];await assert.rejects(s.act(o,'intake',{}));assert.equal(o.version,1);
});
test('预付超过总额拒绝并保持原版本',async()=>{
 const s=await login();const o=s.local.orders[1];o.status='diagnosis_quotation';
 await assert.rejects(s.act(o,'quote',{amountCents:100,prepayCents:200,validUntil:'2099-01-01',description:'范围'}));await assert.rejects(s.act(o,'quote',{amountCents:100,prepayCents:0,startRequiresPrepayment:true,validUntil:'2099-01-01',description:'范围'}));assert.equal(o.version,1);
});
test('已完结单不能新增异议；退款不能超过核实实收',async()=>{
 const s=await login(),o=s.local.orders[0];o.status='completed';await assert.rejects(s.act(o,'issue',{note:'x'}));
 o.status='settling';o.cash=[{id:'r',kind:'receipt',amountCents:100,verified:true},{id:'f',kind:'refund',amountCents:101,verified:false}];
 await assert.rejects(s.act(o,'verify_cash',{cashId:'f'}));assert.equal(o.cash[1].verified,false);
});
test('非JSON认证拒绝保持401，受保护详情401清理会话',async()=>{
 const s=await login();s.fetcher=async()=>new Response('<h1>Unauthorized</h1>',{status:401});
 await assert.rejects(s.login('admin','Demo-Repair-2026!'),e=>e.status===401);assert.equal(s.actor,null);
 s.actor={id:'admin',role:'admin',status:'active'};s.token='session';s.demo=false;
 await assert.rejects(s.detail('x'),e=>e.status===401);assert.equal(s.actor,null);assert.equal(s.token,'');
});
test('真实5xx、408、429和坏2xx均保留原提交意图键',async()=>{
 for(const status of [500,503,408,429,200]) {
  const s=await login();s.token='real';s.demo=false;const keys=[];
  s.fetcher=async(url,options)=>{keys.push(options.headers['Idempotency-Key']);return new Response('invalid-json',{status});};
  for(let i=0;i<2;i++)await assert.rejects(s.write('/orders/x/actions',{type:'remark'},()=>assert.fail('禁止本地成功')));
  assert.equal(keys[0],keys[1]);assert.equal(s.pending.size,1);
 }
});
test('演示岗位与明确先款约定和Go保持一致',async()=>{
 const s=await login(),o=s.local.orders[1];o.status='diagnosis_quotation';s.actor={...s.actor,role:'engineer'};
 assert.ok(!s.actions(o).includes('approve_quote'));s.actor={...s.actor,role:'warehouse'};assert.ok(!s.actions(o).includes('quote'));
 s.actor={...s.actor,role:'engineer'};o.status='pending_execution';o.quote={approved:true,signed:true,startRequiresPrepayment:true,prepayCents:100};
 await assert.rejects(s.act(o,'start',{}));assert.equal(o.status,'pending_execution');
 o.cash=[{id:'r',amountCents:100,kind:'receipt',verified:true,handedOver:false}];
 const result=await s.act(o,'start',{});assert.equal(result.status,'repairing');
});
test('现金缺金额、非法方向和坏库存写不能当作成功',async()=>{
 const s=await login();const base={id:'x',version:1,device:'设备',status:'settling'};
 for(const cash of [{id:'r',kind:'receipt',verified:true,handedOver:false},{id:'r',amountCents:null,kind:'receipt',verified:true,handedOver:false},{id:'r',amountCents:1,kind:'other',verified:true,handedOver:false}])assert.equal(validOrder({...base,cash:[cash]}),false);
 s.token='real';s.demo=false;s.fetcher=async()=>new Response('{"id":"loan","version":1}');
 await assert.rejects(s.write('/loans',{quantity:1},()=>assert.fail('不应本地成功')),e=>e.status===502);assert.equal(s.pending.size,1);
});
test('旧请求迟到401不能撤销新会话',async()=>{
 let resume;const pending=new Promise(resolve=>resume=resolve);const s=await login();s.fetcher=()=>pending;s.token='old';
 const work=s.request('/accounts');s.logout();s.actor={id:'new',role:'admin',status:'active'};s.token='new';
 resume(new Response('Unauthorized',{status:401}));await assert.rejects(work,e=>e.status===401);
 assert.equal(s.token,'new');assert.equal(s.actor.id,'new');
});
test('演示完结须履约、票款资料、余项、借用与提成均清理',async()=>{
 const s=await login(),o=s.local.orders[0];o.status='settling';o.outcome='accepted';o.receivableCents=0;o.documents={requirement:'none'};o.invoiceRequirement='none';
 assert.deepEqual(s.completionMissing(o),[]);
 o.obligations=[{id:'t',resolved:false}];assert.ok(s.completionMissing(o).includes('存在未办余项'));o.obligations=[];
 s.local.loans=[{orderId:o.id,outstanding:1,transfers:[]}];assert.ok(s.completionMissing(o).includes('工单借用未清'));
 s.local.loans[0].transfers=[{quantity:1}];assert.deepEqual(s.completionMissing(o),[]);
 o.commissions=[{settled:false}];assert.ok(s.completionMissing(o).includes('提成未结算'));
});
test('离线全局动作也按Go岗位拒绝，不通过UI隐藏来替代授权',async()=>{
 const s=await login();s.actor={...s.actor,role:'engineer'};
 for(const path of ['/orders','/loans','/purchases','/settings','/purchases/x/receive'])await assert.rejects(s.write(path,{},()=>assert.fail('不能进入本地变更')),e=>e.status===403);
});
test('离线库存只读范围与余项上下文对齐服务端',async()=>{
 const s=await login();s.local.loans=[{id:'l',borrowerId:'engineer'}];s.actor={...s.actor,id:'customer',role:'customer'};
 assert.equal(s.localSnapshot().parts.length,0);assert.equal(s.localSnapshot().loans.length,0);assert.equal(s.localSnapshot().purchases.length,0);
 s.actor={...s.actor,id:'engineer',role:'engineer'};assert.equal(s.localSnapshot().loans.length,1);assert.equal(s.localSnapshot().purchases.length,0);
 const o=s.local.orders[0];o.obligations=[{id:'t',ownerId:'finance',resolved:false}];assert.ok(!s.actions(o).includes('resolve_obligation'));
 s.actor={...s.actor,id:'dispatcher',role:'dispatcher'};assert.ok(s.actions(o).includes('resolve_obligation'));
});
