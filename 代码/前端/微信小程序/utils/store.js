// Jobs · 小程序会话、请求意图与服务端 / 合成数据隔离。
const D = require('./demo');
const C = require('../assets/contract.json');
const clone = value => JSON.parse(JSON.stringify(value));
const object = value => value && typeof value === 'object' && !Array.isArray(value);
const strings = value => Array.isArray(value) && value.every(v => typeof v === 'string');
const integer = value => Number.isSafeInteger(value);
class ApiError extends Error {
  constructor(message, status = 0, uncertain = false, uiParts) {
    super(message); this.status = status; this.uncertain = uncertain; this.uiParts = uiParts || [message];
  }
}
function validateActor(actor) {
  return object(actor) && typeof actor.id === 'string' && actor.id && typeof actor.role === 'string'
    && typeof actor.companyId === 'string' && actor.status === 'active' && integer(actor.authVersion) && actor.authVersion > 0;
}
function sameActor(a, b) {
  return ['id','role','companyId','authVersion'].every(k => a && b && a[k] === b[k]);
}
function validateOrder(order, full = false) {
  let valid = object(order) && ['id','number','customer','project','device','description','status','type'].every(k => typeof order[k] === 'string')
    && order.id && integer(order.version) && order.version > 0 && object(order.summary) && strings(order.summary.missing)
    && typeof order.summary.nextTask === 'string';
  for (const key of ['collectedCents','remainingCents','receivableCents']) valid = valid && integer(order.summary[key]);
  if (full) {
    valid = valid && order.isSummary !== true && strings(order.allowedActions) && object(order.quote)
      && ['version','amountCents','prepayCents','warrantyMonths'].every(k => integer(order.quote[k]))
      && ['events','evidence','cash','invoices','issues','obligations'].every(k => Array.isArray(order[k]) && order[k].every(object));
  }
  if (!valid) throw new ApiError('工单响应不完整，请重新加载。', 200, true);
  return order;
}
function endpoint(value) {
  const text = String(value || '').trim().replace(/\/$/, '');
  if (!/^https:\/\/[^\s/@?#]+(?::\d+)?$/.test(text) && !/^http:\/\/(127\.0\.0\.1|localhost)(:\d+)?$/.test(text))
    throw new Error('请填写 HTTPS 服务器根地址；HTTP 仅允许电脑本机调试回环地址。');
  return text;
}
function wxTransport(wxApi) {
  return options => new Promise((resolve, reject) => wxApi.request(Object.assign({}, options, {
    success: resolve, fail: error => reject(new ApiError(error.errMsg && error.errMsg.includes('timeout') ? '连接超时。' : '无法连接服务，请核对地址与合法域名。'))
  })));
}
class Store {
  constructor(transport, config = {}) {
    this.transport = transport; this.base = endpoint(config.base || 'http://127.0.0.1:8098');
    this.timeout = Math.max(500, Math.min(10000, Number(config.timeout) || 2200));
    this.epoch = 0; this.readSequence = 0; this.detailSequence = 0; this.intents = new Map();
    this.token = ''; this.actor = null; this.demoActor = null; this.snapshot = null; this.detail = null;
    this.pendingWrite = null; this.source = 'demo'; this.notice('请登录；服务器不可用时可使用合成示例账号演示。');
  }
  notice(...parts) {
    this.messageParts = parts;
    this.message = parts.join('');
  }
  clear() {
    this.epoch++; this.readSequence++; this.detailSequence++; this.token = ''; this.actor = null; this.demoActor = null;
    this.snapshot = null; this.detail = null; this.intents.clear(); this.pendingWrite=null;
  }
  configure(base, timeout) {
    const next = endpoint(base), delay = Number(timeout);
    if (!Number.isFinite(delay) || delay < 500 || delay > 10000) throw new Error('超时范围为 500—10000 毫秒。');
    this.clear(); this.base = next; this.timeout = delay;
  }
  async request(route, method = 'GET', data, key) {
    const epoch = this.epoch;
    let response;
    try {
      response = await this.transport({url:this.base + '/api/v38' + route, method, data, timeout:this.timeout,
        header:Object.assign({'Content-Type':'application/json'}, this.token ? {Authorization:'Bearer '+this.token} : {}, key ? {'Idempotency-Key':key} : {})});
    } catch (error) { throw new ApiError(error.message || '网络请求失败。', 0, false, error.uiParts); }
    if (epoch !== this.epoch) throw new ApiError('身份已切换，旧请求已忽略。', 409);
    if (response.statusCode === 401 && this.token) {
      this.clear(); this.source = 'demo'; this.notice('会话已失效，请重新登录。');
      throw new ApiError(this.message, 401);
    }
    let result = response.data;
    if (typeof result === 'string') {try {result = JSON.parse(result);} catch (_) {throw new ApiError('服务端响应无法解析。', response.statusCode, method !== 'GET');}}
    if (response.statusCode < 200 || response.statusCode >= 300)
      throw new ApiError((result && (result.message || result.error)) || '请求被拒绝。', response.statusCode);
    return result;
  }
  openDemo(username) {
    const role = username.startsWith('customer') ? 'customer' : username;
    if (!C.roles.some(v => v.id === username)) throw new Error('该账号没有合成演示资料。');
    this.demoActor = {id:username,role,companyId:'company-demo',displayName:'演示'+(D.roles[role] || role)};
    this.demo = D.seed(); this.fallback();
  }
  fallback() {
    this.source = 'demo'; this.detail = null;
    const actor = this.demoActor || {id:'customer',role:'customer',companyId:'company-demo',displayName:'独立合成样例'};
    const demo = this.demo || D.seed();
    const orders = demo.orders.filter(o => actor.role !== 'customer' || o.customerId === actor.id);
    this.snapshot = Object.assign({}, clone(demo), {actor:clone(actor), orders:clone(orders)});
    this.snapshot.metrics = {openCount:orders.filter(o => o.status !== 'completed').length, remainingCents:orders.reduce((s,o)=>s+o.summary.remainingCents,0)};
  }
  async login(username, password) {
    this.clear(); const epoch = this.epoch;
    try {
      const result = await this.request('/login','POST',{username,password});
      if (epoch !== this.epoch) return;
      if (!object(result) || typeof result.token !== 'string' || !result.token || !validateActor(result.actor)) throw new ApiError('登录响应不完整。',200);
      this.token = result.token; this.actor = result.actor; this.source = 'server';
      await this.refresh();
    } catch (error) {
      if (epoch !== this.epoch || error.status) throw error;
      if (password !== 'Demo-Repair-2026!') throw error;
      this.openDemo(username); this.notice('独立合成演示 · 所有修改不进入真实台账。');
      await this.refresh();
    }
  }
  async refresh(query = {}) {
    const epoch = this.epoch, sequence = ++this.readSequence;
    const q = '?page='+Math.max(1,Number(query.page)||1)+'&pageSize=30&q='+encodeURIComponent(query.q||'')+'&status='+encodeURIComponent(query.status||'');
    try {
      if (this.demoActor && !this.token) {
        const session = await this.request('/login','POST',{username:this.demoActor.id,password:'Demo-Repair-2026!'});
        if (epoch !== this.epoch || sequence !== this.readSequence) return;
        if (!object(session) || typeof session.token !== 'string' || !session.token || !validateActor(session.actor)) throw new ApiError('恢复登录响应不完整。',200);
        this.actor=session.actor; this.token=session.token; this.demoActor=null;
      }
      const snapshot = await this.request('/bootstrap');
      const page = await this.request('/orders'+q);
      if (epoch !== this.epoch || sequence !== this.readSequence) return;
      if (!this.token || !validateActor(snapshot.actor) || !sameActor(snapshot.actor,this.actor)
        || !object(snapshot.metrics) || !integer(snapshot.metrics.openCount) || !integer(snapshot.metrics.remainingCents)
        || !['parts','loans','purchases'].every(k => Array.isArray(snapshot[k]) && snapshot[k].every(object))
        || !snapshot.parts.every(p=>typeof p.id==='string' && typeof p.name==='string' && ['available','quarantine'].every(k=>integer(p[k])&&p[k]>=0))
        || !snapshot.loans.every(p=>typeof p.id==='string' && typeof p.borrowerId==='string' && ['version','quantity','outstanding'].every(k=>integer(p[k])&&p[k]>=0))
        || !snapshot.purchases.every(p=>typeof p.id==='string' && typeof p.partId==='string' && ['version','quantity','received'].every(k=>integer(p[k])&&p[k]>=0))
        || !object(page) || !Array.isArray(page.items) || !['page','pageSize','total','totalPages'].every(k => integer(page[k]) && page[k] >= 0))
        throw new ApiError('服务端快照或分页响应不完整。',200);
      page.items.forEach(o=>validateOrder(o));
      snapshot.orders = page.items; snapshot.orderPage = page;
      this.snapshot = snapshot; this.source = 'server'; this.notice('服务端数据 · 当前账号授权范围');
    } catch (error) {
      if (epoch !== this.epoch || sequence !== this.readSequence) return;
      if (error.status === 401 && !this.demoActor) throw error;
      this.fallback();
      const items = this.snapshot.orders.filter(o=>(!query.status || o.status===query.status) && (!query.q || [o.number,o.customer,o.device,o.project].some(v=>String(v).includes(query.q))));
      const page = Math.max(1,Number(query.page)||1);
      this.snapshot.orders = items.slice((page-1)*30,page*30); this.snapshot.orderPage = {page,pageSize:30,total:items.length,totalPages:Math.ceil(items.length/30)};
      this.notice(...(error.uiParts || [error.message]), this.token ? ' 已清除服务端资料；重新加载成功后自动恢复，办理前请恢复服务或切换独立演示。' : ' 独立合成演示；后续刷新继续尝试服务。');
    }
  }
  async readDetail(id) {
    const epoch = this.epoch, sequence = ++this.detailSequence;
    this.detail = null;
    try {
      const order = validateOrder(await this.request('/orders/'+encodeURIComponent(id)),true);
      if (!this.token || order.id !== id) throw new ApiError('详情身份或工单关联不一致。',200);
      if (epoch !== this.epoch || sequence !== this.detailSequence) return null;
      this.detail = order;
    } catch (error) {
      if (epoch !== this.epoch || sequence !== this.detailSequence) return null;
      if (this.token || !this.demoActor || error.status && error.status !== 401) throw error;
      const found = this.demo.orders.find(o=>o.id===id && (this.demoActor.role!=='customer' || o.customerId===this.demoActor.id));
      if (!found) throw new Error('演示工单不存在或无权读取。');
      this.detail = clone(found); this.detail.allowedActions = D.permissions[this.demoActor.role] || [];
    }
    return this.detail;
  }
  get writable() { return this.source === 'server' && !!this.token || !!this.demoActor && !this.token; }
  async write(route, body, expectedId) {
    if (!this.writable) throw new Error('请先恢复服务端连接或退出后使用独立演示账号。');
    const epoch = this.epoch, identity = JSON.stringify([route,body]);
    if(this.pendingWrite && this.pendingWrite.identity!==identity)throw new ApiError('尚有结果未确认的提交，请先原样重试或核对服务端结果。',0,true);
    if (!this.intents.has(identity)) this.intents.set(identity,D.uid('mini'));
    try {
      const value = await this.request(route,'POST',body,this.intents.get(identity));
      if (!this.token) throw new ApiError('未建立服务端身份。',401);
      if (route.startsWith('/orders')) {
        validateOrder(value,true);
        if (expectedId && body.type !== 'rework' && (value.id !== expectedId || value.version !== body.version + 1)) throw new ApiError('返回了其他工单，结果待核对。',200,true);
        if (expectedId && body.type === 'rework' && value.originalOrderId !== expectedId) throw new ApiError('返修关联不正确，结果待核对。',200,true);
      } else if (!object(value) || typeof value.id !== 'string' || !integer(value.version) || value.version < 1) throw new ApiError('写入响应不完整。',200,true);
      this.intents.delete(identity); this.pendingWrite=null; return value;
    } catch (error) {
      if (epoch !== this.epoch) throw error;
      if (this.token || !this.demoActor || error.status && error.status !== 401) {
        if (!error.status || error.status === 200 || error.status >= 500) {
          this.pendingWrite={route,body:clone(body),expectedId,identity};
          throw new ApiError('提交结果暂不确定，请按原内容重试或核对服务端结果。'+error.message,error.status,true,['提交结果暂不确定，请按原内容重试或核对服务端结果。',...(error.uiParts || [error.message])]);
        }
        throw error;
      }
      let value;
      if (route === '/orders') {value=D.createOrder(body);this.demo.orders.unshift(value);}
      else if (/^\/orders\/[^/]+\/actions$/.test(route)) {
        const index=this.demo.orders.findIndex(o=>o.id===expectedId);
        if(index<0 || this.demo.orders[index].version!==body.version)throw new Error('演示记录已变化，请重新加载。');
        value=D.apply(this.demo.orders[index],body.type,body.payload,this.demoActor,this.demo);
        if(body.type==='rework')this.demo.orders.unshift(value); else this.demo.orders[index]=value;
      } else throw new Error('库存写入演示尚未实现；请连接服务端使用。');
      this.intents.delete(identity);this.fallback();return value;
    }
  }
  async logout() {
    const pending = this.request('/logout','POST',{});
    this.clear(); this.notice('已退出，私有资料已清除。');
    try {await pending;} catch (_) {}
  }
}
module.exports = {Store,ApiError,wxTransport,validateOrder,validateActor,endpoint};
