/* Jobs · 使用实际 app.js 和可控 HTTP 响应回归交互边界。 */
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const test = require("node:test");
const assert = require("node:assert/strict");
const projectRoot = path.resolve(__dirname, "../..");
const D = require(path.join(projectRoot, "Workspace/data.js"));
const source = fs.readFileSync(path.join(projectRoot, "Workspace/app.js"), "utf8");
const flush = async () => {
  for (let i = 0; i < 4; i++) await new Promise(setImmediate);
};
const response = (value, status = 200) => ({
  ok: status < 400,
  status,
  json: async () => structuredClone(value),
});
function fixture() {
  const seed = D.seed();
  const orders = seed.orders.map((order) => ({
    ...order,
    allowedActions: D.permissions.admin,
  }));
  const actor = {
    id: "admin",
    role: "admin",
    name: "合成管理员",
    status: "active",
    authVersion: 1,
  };
  return {
    actor,
    orders,
    parts: seed.parts,
    loans: seed.loans,
    purchases: seed.purchases,
    settings: {
      companyAddress: "合成地址",
      companyReceiver: "样例",
      companyPhone: "测试电话",
      reminderHours: 24,
      remarkLimit: 2000,
    },
    orderPage: { page: 1, pageSize: 30, total: 95, totalPages: 4 },
    metrics: {
      openCount: 89,
      settlingCount: 51,
      remainingCents: 99000000,
      readyCount: 15,
      tasksCount: 135,
      blockedCount: 12,
    },
    capacity: { requestCount: 9001, warning: true, threshold: 10000 },
  };
}
function harness({ url = "http://127.0.0.1:8098/", saved = {}, fetcher } = {}) {
  const nodes = new Map(),
    listeners = new Map(),
    storage = new Map(Object.entries(saved)),
    calls = [];
  let activeFetch =
    fetcher || (async () => response({ message: "未认证" }, 401));
  const controlledFetch = async (url, options) => {
    calls.push({ url, options });
    return activeFetch(url, options);
  };
  function node(key) {
    if (!nodes.has(key)) {
      const events = new Map();
      const el = {
        id: key.replace(/^#/, ""),
        value: "",
        hidden: false,
        disabled: false,
        open: false,
        textContent: "",
        innerHTML: "",
        dataset: {},
        classList: { toggle() {} },
        emit(type) {
          events.get(type)?.();
        },
        addEventListener(type, fn) {
          events.set(type, fn);
        },
        insertAdjacentHTML(_where, value) {
          this.innerHTML += value;
        },
        showModal() {
          this.open = true;
        },
        close() {
          this.open = false;
          events.get("close")?.();
        },
        reset() {
          [
            "#search",
            "#statusFilter",
            "#documentFilter",
            "#paymentFilter",
          ].forEach((name) => (node(name).value = ""));
        },
      };
      nodes.set(key, el);
    }
    return nodes.get(key);
  }
  const downloads = [];
  class BrowserURL extends URL {
    static createObjectURL(blob) { downloads.push(blob); return "blob:synthetic-r5-" + downloads.length; }
    static revokeObjectURL() {}
  }
  const context = vm.createContext({
    URL: BrowserURL,
    URLSearchParams,
    Intl,
    Date,
    Blob,
    structuredClone,
    AbortController,
    AbortSignal,
    WorkbenchData: D,
    location: new URL(url),
    setTimeout(fn, duration) {
      const timer = setTimeout(fn, duration);
      timer.unref();
      return timer;
    },
    clearTimeout,
    FormData: class {
      constructor(form) {
        this.values = new Map(Object.entries(form.fields || {}));
      }
      get(name) {
        return this.values.get(name);
      }
      entries() {
        return this.values.entries();
      }
    },
    localStorage: {
      getItem(name) {
        return storage.get(name) || null;
      },
      setItem(name, value) {
        storage.set(name, value);
      },
    },
    document: {
      querySelector: node,
      querySelectorAll: () => [],
      addEventListener(type, fn) {
        listeners.set(type, fn);
      },
      createElement: () => ({ click() {} }),
    },
    fetch: controlledFetch,
  });
  Object.defineProperty(context, "fetch", {
    get: () => controlledFetch,
    set: (value) => {
      activeFetch = value;
    },
  });
  const instrumented = source.replace(
    /\n\}\)\(\);\s*$/,
    `\n globalThis.__app = { request, mutateOrder, previewFile, showSignature, login, refresh, loadOrders, openDetail, showAction, accountStatusForm, createForm, globalForm, openDemo, normalizeBase, getDemo: () => demo, available, getState: () => ({data, actor, dataKind, connected, page, token, view, cachedDetailIds: [...details.keys()], cachedDetailValues: [...details.values()]}), setPage: (value) => {page = value;} };\n})();`,
  );
  assert.notEqual(instrumented, source);
  vm.runInContext(instrumented, context);
  const click = async (dataset = {}, id = "") => {
    const button = {
      dataset,
      id,
      hasAttribute: (name) =>
        name === "data-reload" && dataset.reload !== undefined,
    };
    button.closest = () => button;
    await listeners.get("click")({ target: button });
    await flush();
  };
  const submit = async (id, fields) => {
    const target = node("#" + id);
    target.fields = fields;
    const event = { target, currentTarget: target, preventDefault() {} };
    if (id === "actionForm") await target.onsubmit(event);
    else await listeners.get("submit")(event);
    await flush();
  };
  return {
    context,
    downloads,
    app: context.__app,
    nodes,
    node,
    calls,
    storage,
    click,
    submit,
  };
}
function reads(value = fixture(), override = {}) {
  return async (url) => {
    const path = url.split("/api/v38")[1];
    if (path === "/login")
      return response({ token: "synthetic-test-token", actor: value.actor });
    if (path === "/bootstrap") return response(value);
    if (path?.startsWith("/orders?")) {
      const query = new URLSearchParams(path.split("?")[1]);
      return response({
        items: value.orders,
        ...value.orderPage,
        page: Number(query.get("page")),
        ...override,
      });
    }
    if (path === "/accounts") return response([value.actor]);
    if (/^\/orders\/[^/]+$/.test(path))
      return response(
        value.orders.find(
          (order) => order.id === decodeURIComponent(path.split("/")[2]),
        ),
      );
    if (url.endsWith("/securityz"))
      return response({ configured: false, storage: "file" });
    return response({ message: "拒绝" }, 403);
  };
}
async function connected() {
  const h = harness();
  await flush();
  h.context.fetch = reads();
  await h.app.login("admin", "synthetic");
  await flush();
  assert.equal(h.app.getState().dataKind, "server");
  return h;
}

const observations = {};
const record = (name, value) => (observations[name] = structuredClone(value));
test.after(() => fs.writeFileSync(path.join(__dirname, `frontend-observations-${process.env.RUN_LABEL || "run"}.json`), JSON.stringify(observations, null, 2) + "\n"));
function deferred() { let resolve; const promise = new Promise(r => resolve = r); return {promise, resolve}; }
async function fresh(value = fixture()) { const h = harness(); await flush(); h.context.fetch = reads(value); await h.app.login(value.actor.id, "synthetic"); await flush(); assert.equal(h.app.getState().dataKind, "server"); return h; }
function settingFields(value) { return {companyAddress:value.companyAddress, companyReceiver:value.companyReceiver, companyPhone:value.companyPhone, reminderHours:String(value.reminderHours)}; }
function counts(h, suffix) { return h.calls.filter(c => c.url.endsWith(suffix) && c.options.method === "POST"); }

for (const delta of [0, -1]) test(`R5-F01/${delta}: 动作2xx返回未推进或倒退版本时不得确认保存`, async () => {
  const value = fixture(), h = await fresh(value), order = structuredClone(value.orders[0]);
  order.version = 8;
  h.context.fetch = async (url, options = {}) => url.endsWith('/actions')
    ? response({...order, version: order.version + delta}) : reads(value)(url, options);
  const keyPath = '/orders/' + encodeURIComponent(order.id) + '/actions';
  const body = JSON.stringify({type:'remark',version:order.version,payload:{remark:'R5合成新备注'}});
  let failure;
  try { await h.app.mutateOrder(order, 'remark', {remark:'R5合成新备注'}); } catch (error) { failure = error.message; }
  record('unchangedOrderVersion'+delta, {submittedVersion:order.version, returnedVersion:order.version+delta, failure, toast:h.node('#toast').textContent, stateKind:h.app.getState().dataKind, cached:h.app.getState().cachedDetailValues.map(o=>({id:o.id,version:o.version,remark:o.remark}))});
  assert.ok(failure, '未推进/倒退版本的2xx被接受并提示保存成功');
  assert.doesNotMatch(h.node('#toast').textContent, /已保存/);
  // 保留原请求键，使用户核对未知结果后明确重试不产生新意图。
  const before = await h.app.request(keyPath,{method:'POST',body}).catch(()=>{});
  assert.equal(before, undefined);
});

test('R5-F02: rework动作返回原工单而不是子单时不得确认创建返修', async () => {
  const value=fixture(),h=await fresh(value),order=value.orders[0];
  h.context.fetch=async(url,options={})=>url.endsWith('/actions') ? response({...order,version:order.version+1}) : reads(value)(url,options);
  let failure; try { await h.app.mutateOrder(order,'rework',{free:true,note:'R5合成返修'}); } catch(error) {failure=error.message;}
  record('reworkOriginalReturned',{failure,toast:h.node('#toast').textContent,createdChild:h.app.getState().data.orders.some(o=>o.originalOrderId===order.id)});
  assert.ok(failure,'原工单被作为返修创建结果接受');
  assert.doesNotMatch(h.node('#toast').textContent,/已保存/);
});

for(const field of ['id','role','companyId','authVersion']) test(`R5-F03/${field}: 导出身份关联错误2xx不得生成文件`, async()=>{
  const value=fixture(),h=await fresh(value),wrong=structuredClone(value);
  if(field==='id') wrong.actor.id='r5-other-account';
  if(field==='role') wrong.actor.role='customer';
  if(field==='companyId') wrong.actor.companyId='r5-other-company';
  if(field==='authVersion') wrong.actor.authVersion++;
  wrong.orders[0].customer='R5另一身份的合成客户';
  h.context.fetch=async()=>response(wrong);
  await h.node('#exportOrders').onclick();
  const content=h.downloads.length ? JSON.parse(await h.downloads[0].text()) : null;
  record('wrongExportActor_'+field,{current:value.actor,returned:wrong.actor,downloadCount:h.downloads.length,downloadCustomer:content?.orders[0].customer,toast:h.node('#toast').textContent});
  assert.equal(h.downloads.length,0,'另一身份/授权版本导出结果仍被保存为授权文件');
  assert.doesNotMatch(h.node('#toast').textContent,/已导出/);
});

for(const [name, mutate] of [
  ['缺收款金额',c=>delete c.amountCents],
  ['空收款金额',c=>c.amountCents=null],
  ['非法现金方向',c=>c.kind='not-a-cash-kind'],
  ['缺现金ID',c=>delete c.id],
]) test(`R5-F04/${name}: 财务坏记录2xx应在展示或办理前拒绝`, async()=>{
  const value=fixture(),h=await fresh(value),bad=structuredClone(value);
  const cash={id:'r5-cash',amountCents:10000,kind:'receipt',purpose:'R5合成款项',collector:'合成人',occurredAt:'2026-10-15T00:00:00Z',verified:false,handedOver:false};
  mutate(cash); bad.orders[0].cash=[cash];
  h.context.fetch=reads(bad);
  await h.click({view:'finance'});
  record('badCash_'+name,{dataKind:h.app.getState().dataKind,acceptedCash:h.app.getState().data.orders[0]?.cash,html:h.node('#financeView').innerHTML,toast:h.node('#toast').textContent});
  assert.equal(h.app.getState().dataKind,'demo','缺少业务必需金额/ID或非法现金方向的真实记录被采用');
});

test('R5-F05: 借用动作只含浅字段的2xx不得确认库存保存并释放未知键', async()=>{
  const value=fixture(),h=await fresh(value),loan=value.loans[0];
  assert.ok(loan);
  h.context.fetch=async(url,options={})=>url.endsWith('/actions') ? response({id:loan.id,version:loan.version+1,quantity:loan.quantity,outstanding:0}) : reads(value)(url,options);
  h.app.globalForm('loanAction',loan.id,'return');
  h.context.document.querySelectorAll=selector=>selector==='#actionForm [data-integer]'?[{name:'quantity',value:'1'}]:[];
  await h.submit('actionForm',{quantity:'1',condition:'good'});
  record('shallowLoanWrite',{formOpen:h.node('#formDialog').open,error:h.node('#formError').textContent,toast:h.node('#toast').textContent});
  assert.equal(h.node('#formDialog').open,true,'缺库存必需字段的响应被确认保存');
  assert.doesNotMatch(h.node('#toast').textContent,/已保存/);
});

test('R5-C01: 当前导出等待时切换身份，迟到2xx不会生成原身份文件',async()=>{
  const value=fixture(),h=await fresh(value),wait=deferred();
  h.context.fetch=()=>wait.promise;
  const pending=h.node('#exportOrders').onclick(); await flush();
  const next=fixture(); next.actor={id:'customer',role:'customer',companyId:'company-a',status:'active',authVersion:1}; next.orders=[];next.orderPage={page:1,pageSize:30,total:0,totalPages:0};
  h.context.fetch=reads(next);await h.app.login('customer','synthetic');
  wait.resolve(response(value));await pending;await flush();
  record('lateExportSwitch',{actor:h.app.getState().actor.id,downloadCount:h.downloads.length,toast:h.node('#toast').textContent});
  assert.equal(h.downloads.length,0);assert.equal(h.app.getState().actor.id,'customer');
});

test('R5-C02: 当前导出等待时导航，合法响应仍能完成当前身份导出',async()=>{
  const value=fixture(),h=await fresh(value),wait=deferred();
  h.context.fetch=async(url,opts)=>url.endsWith('/export')?wait.promise:reads(value)(url,opts);
  const pending=h.node('#exportOrders').onclick();await flush();await h.click({view:'finance'});
  wait.resolve(response(value));await pending;
  assert.equal(h.downloads.length,1);assert.equal(h.app.getState().view,'finance');
});

test('R5-C03: 未知备注经过关闭重开与无关采购表单，明确重试仍使用原请求键',async()=>{
  const value=fixture(),h=await fresh(value),id=value.orders[0].id;
  h.context.fetch=async(url,opts)=>url.endsWith('/actions')?{ok:true,status:200,json:async()=>{throw Error('synthetic broken JSON')}}:reads(value)(url,opts);
  await h.app.showAction('remark',id);await h.submit('actionForm',{remark:'R5合成未知备注',customerNote:'R5对客说明'});
  await h.click({close:'form'});h.app.globalForm('purchase');await h.click({close:'form'});
  await h.app.showAction('remark',id);await h.submit('actionForm',{remark:'R5合成未知备注',customerNote:'R5对客说明'});
  const writes=counts(h,'/actions');assert.equal(writes.length,2);assert.equal(writes[0].options.headers['Idempotency-Key'],writes[1].options.headers['Idempotency-Key']);
  assert.doesNotMatch(h.node('#toast').textContent,/已保存/);
});

test('R5-C04: 明确拒绝与未知结果后的表单均保留，另一动作同内容不共享路径请求键',async()=>{
  const value=fixture(),h=await fresh(value),one=value.orders[0],two=value.orders[1];
  h.context.fetch=async(url,opts)=>url.endsWith('/actions')?response({message:'R5合成冲突'},409):reads(value)(url,opts);
  for(const order of [one,two]) {await h.app.showAction('remark',order.id);await h.submit('actionForm',{remark:'R5同内容',customerNote:'R5对客'});assert.equal(h.node('#formDialog').open,true);}
  const writes=counts(h,'/actions');assert.notEqual(writes[0].options.headers['Idempotency-Key'],writes[1].options.headers['Idempotency-Key']);
});

test('R5-C05: 同一动作提交未返回时重复确认只发送一次，随后明确失败可再试',async()=>{
  const value=fixture(),h=await fresh(value),wait=deferred(),id=value.orders[0].id;
  h.context.fetch=async(url,opts)=>url.endsWith('/actions')?wait.promise:reads(value)(url,opts);
  await h.app.showAction('remark',id);
  const pending=h.submit('actionForm',{remark:'R5防双击',customerNote:'R5对客'});await flush();
  await h.submit('actionForm',{remark:'R5防双击',customerNote:'R5对客'});assert.equal(counts(h,'/actions').length,1);
  wait.resolve(response({message:'R5冲突'},409));await pending;
  assert.equal(h.node('#submitAction').disabled,false);assert.equal(h.node('#formDialog').open,true);
});

test('R5-C06: 同会话附件下载在列表网络回退后才返回，不生成旧原件',async()=>{
  const value=fixture(),h=await fresh(value),wait=deferred(),id=value.orders[0].id;
  await h.app.openDetail(id);
  h.context.fetch=async(url)=>url.includes('/evidence/')?wait.promise:response({message:'R5离线'},503);
  const pending=h.app.previewFile('r5-attachment',id);await flush();await h.app.loadOrders();
  wait.resolve({ok:true,status:200,blob:async()=>new Blob(['R5合成原件'])});await pending;
  assert.equal(h.app.getState().dataKind,'demo');assert.equal(h.downloads.length,0);
});

test('R5-C07: 非401回退保留可信会话，重连失败期间不自动重放先前未知写',async()=>{
  const value=fixture(),h=await fresh(value),id=value.orders[0].id;
  h.context.fetch=async(url,opts)=>opts?.method==='POST'?response(null):response({message:'R5不可用'},503);
  await assert.rejects(h.app.mutateOrder(value.orders[0],'remark',{remark:'R5未知'}));
  const before=counts(h,'/actions').length;await h.app.refresh();assert.equal(h.app.getState().dataKind,'demo');
  await h.app.refresh();assert.equal(counts(h,'/actions').length,before);assert.ok(h.app.getState().token);
  h.context.fetch=reads(value);await h.app.refresh();assert.equal(h.app.getState().dataKind,'server');assert.equal(counts(h,'/actions').length,before);
});

test('R5-C08: 账号状态未知结果跨表单重试保留请求键',async()=>{
  const value=fixture(),h=await fresh(value);
  h.context.fetch=async(url,opts)=>url.endsWith('/status')?response(null):reads(value)(url,opts);
  h.app.accountStatusForm('r5-customer','disabled');await h.submit('actionForm',{reason:'R5合成授权核对'});
  await h.click({close:'form'});h.app.createForm();await h.click({close:'form'});
  h.app.accountStatusForm('r5-customer','disabled');await h.submit('actionForm',{reason:'R5合成授权核对'});
  const writes=counts(h,'/accounts/r5-customer/status');assert.equal(writes.length,2);assert.equal(writes[0].options.headers['Idempotency-Key'],writes[1].options.headers['Idempotency-Key']);
  assert.equal(h.node('#formDialog').open,true);
});

test('R5-C09: 审计嵌套resourceIds非法类型2xx不回填旧成功列表',async()=>{
  const value=fixture(),h=await fresh(value);
  h.context.fetch=async(url,opts)=>url.includes('/audit?')?response({items:[{id:'r5-audit',actorId:'admin',type:'export',result:'success',at:'2026-10-15T00:00:00Z',resourceIds:'wrong'}],total:1,page:1,pageSize:30}):reads(value)(url,opts);
  await h.click({view:'settings'});await flush();assert.match(h.node('#auditList').innerHTML,/安全审计未加载|审计.*未加载|响应格式/);assert.doesNotMatch(h.node('#auditList').innerHTML,/r5-audit/);
});

test('R5-C10: 当前合法签署记录只读原件，不重新发送客户签名',async()=>{
  const value=fixture(),h=await fresh(value),order=value.orders[0];
  order.acceptanceRecords=[{id:'r5-signature',passed:false,signature:'data:image/png;base64,synthetic-r5',signerId:'customer',signerName:'合成经办人',signedAt:'2026-10-15T00:00:00Z',note:'R5合成拒绝',quoteVersion:1,orderVersion:2}];
  h.context.fetch=reads(value);await h.app.openDetail(order.id);const before=h.calls.length;
  await h.click({acceptanceSignature:'r5-signature',order:order.id});
  assert.equal(h.calls.length,before);assert.match(h.node('#formContent').innerHTML,/R5合成拒绝|原件|只读/);assert.doesNotMatch(h.node('#formContent').innerHTML,/id="submitAction"/);
});
