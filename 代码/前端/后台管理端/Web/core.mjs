// Created by Jobs on 2026年10月30日，星期五.
export const clone = value => structuredClone(value);
export const money = value => `¥${(Number(value || 0) / 100).toFixed(2)}`;
export const sameActor = (a, b) => !!a && !!b && b.status === 'active' && ['id', 'role', 'companyId', 'authVersion'].every(k => a[k] === b[k]);
export function fieldValue(field, raw) {
  if (field.type === 'bool') return !!raw;
  if (field.required && (raw === '' || raw == null)) throw Error(`请填写${field.label}`);
  if (field.type === 'int' || field.type === 'money') {
    const n = field.type === 'money' ? Math.round(Number(raw) * 100) : Number(raw);
    if (!Number.isSafeInteger(n) || n < 0) throw Error(`${field.label}须为有效非负数`);
    return n;
  }
  if (field.type === 'datetime') {
    if (!raw) return '';
    const date = new Date(raw);
    if (!Number.isFinite(date.getTime())) throw Error(`${field.label}时间无效`);
    return date.toISOString();
  }
  if (field.type === 'list') return String(raw || '').split(',').map(x => x.trim()).filter(Boolean);
  return raw == null ? '' : String(raw).trim();
}
const count = value => Number.isSafeInteger(value) && value >= 0;
const identity = value => !!value && typeof value.id === 'string' && !!value.id;
export function validLoan(value) {
  return identity(value) && count(value.version) && value.version > 0 && ['quantity','returnedGood','returnedQuarantine','consumed','disposed','outstanding'].every(k => count(value[k])) && value.quantity > 0 && value.quantity === value.returnedGood + value.returnedQuarantine + value.consumed + value.disposed + value.outstanding && typeof value.partId === 'string' && typeof value.borrowerId === 'string' && Array.isArray(value.transfers);
}
export function validPurchase(value) {
  return identity(value) && count(value.version) && value.version > 0 && ['quantity','received','unitCents'].every(k => count(value[k])) && value.quantity > 0 && value.received <= value.quantity && typeof value.partId === 'string' && typeof value.supplier === 'string';
}
export function validOrder(o) {
  if (!identity(o) || !Number.isSafeInteger(o.version) || o.version < 1 || typeof o.status !== 'string' || typeof o.device !== 'string') return false;
  if (o.cash !== undefined && (!Array.isArray(o.cash) || !o.cash.every(c => identity(c) && count(c.amountCents) && c.amountCents > 0 && ['receipt','refund'].includes(c.kind) && typeof c.verified === 'boolean' && typeof c.handedOver === 'boolean'))) return false;
  if (o.summary && Object.entries(o.summary).some(([k,v]) => k.endsWith('Cents') && !Number.isSafeInteger(v))) return false;
  for (const k of ['invoices','evidence','issues','obligations','costs','commissions','events']) if (o[k] !== undefined && !Array.isArray(o[k])) return false;
  return true;
}
export class ApiError extends Error {
  constructor(message, status = 0) { super(message); this.status = status; }
}
export class AdminStore {
  constructor(spec, fetcher = globalThis.fetch.bind(globalThis)) {
    this.spec = spec; this.fetcher = fetcher; this.base = ''; this.token = ''; this.actor = null;
    this.demo = true; this.epoch = 0; this.readRevision = 0; this.timeout = 2500; this.pending = new Map();
    this.resetDemo();
  }
  resetDemo() {
    this.local = clone(this.spec.seed);
    for (const o of this.local.orders) {
      Object.assign(o, { cash: [], invoices: [], evidence: [], events: [], issues: [], obligations: [], costs: [], commissions: [], ...o });
    }
    this.local.settings = { companyAddress: '演示地址', companyReceiver: '调度', companyPhone: '000-0000', reminderHours: 24, remarkLimit: 2000 };
    this.snapshot = this.local;
  }
  async request(path, body, key) {
    const requestEpoch = this.epoch, requestToken = this.token;
    const revokeCurrent = () => {
      if (responseIsCurrent()) this.logout();
    };
    const responseIsCurrent = () => requestEpoch === this.epoch && requestToken === this.token;
    const controller = new AbortController(), timer = setTimeout(() => controller.abort(), this.timeout);
    try {
      const response = await this.fetcher(`${this.base}/api/v38${path}`, {
        method: body === undefined ? 'GET' : 'POST', signal: controller.signal,
        headers: { 'Content-Type': 'application/json', ...(this.token ? { Authorization: `Bearer ${this.token}` } : {}), ...(key ? { 'Idempotency-Key': key } : {}) },
        ...(body === undefined ? {} : { body: JSON.stringify(body) })
      });
      let data;
      try { data = await response.json(); }
      catch {
        if (response.status === 401 && path !== '/login') revokeCurrent();
        throw new ApiError(response.ok ? '服务响应无法解析' : `请求被拒绝（${response.status}）`, response.ok ? 502 : response.status);
      }
      if (response.status === 401 && path !== '/login') revokeCurrent();
      if (!response.ok) throw new ApiError(data.message || '请求被拒绝', response.status);
      return data;
    } catch (e) {
      if (e instanceof ApiError) throw e;
      throw new ApiError(e.name === 'AbortError' ? '连接超时' : '服务不可用或响应无法解析');
    } finally { clearTimeout(timer); }
  }
  logout() { this.epoch++; this.readRevision++; this.actor = null; this.token = ''; this.pending.clear(); this.resetDemo(); }
  async login(username, password) {
    this.logout(); const epoch = this.epoch;
    try {
      const result = await this.request('/login', { username, password });
      if (epoch !== this.epoch) return;
      if (!result.token || !result.actor || result.actor.status !== 'active') throw new ApiError('登录响应无效', 502);
      this.actor = result.actor; this.token = result.token; this.demo = false;
    } catch (e) {
      if (epoch !== this.epoch) return;
      if ((e.status && e.status < 500) || !this.spec.roles.some(r => r.id === username) || password !== 'Demo-Repair-2026!') throw e;
      this.actor = { id: username, role: username === 'customer-b' ? 'customer' : username, companyId: username === 'customer-b' ? 'company-b' : 'company-a', authVersion: 1, status: 'active', name: this.spec.roles.find(r => r.id === username).label };
      this.demo = true;
    }
    await this.refresh();
  }
  localSnapshot() {
    for (const order of this.local.orders) {
      if (['settling','pending_completion'].includes(order.status)) order.status = this.completionMissing(order).length ? 'settling' : 'pending_completion';
    }
    const value = clone(this.local), a = this.actor;
    value.orders = value.orders.filter(o => a.role !== 'customer' || o.companyId === a.companyId && o.customerId === a.id);
    if (!['admin','dispatcher','engineer','warehouse','qc','finance'].includes(a.role)) value.parts = [];
    value.loans = value.loans.filter(l=>['admin','warehouse','dispatcher'].includes(a.role)||a.role==='engineer'&&l.borrowerId===a.id);
    value.purchases = value.purchases.filter(p=>['admin','warehouse','finance','dispatcher'].includes(a.role)||a.role==='supplier'&&[a.id,a.name].includes(p.supplier));
    value.orders.forEach(o => { o.allowedActions = this.actions(o); });
    value.actor = a; value.metrics = this.metrics(value.orders); return value;
  }
  metrics(orders) {
    return { openCount: orders.filter(o => o.status !== 'completed').length, settlingCount: orders.filter(o => o.status === 'settling').length,
      remainingCents: orders.reduce((s, o) => s + Math.max(0, (o.receivableCents ?? o.quote?.amountCents ?? 0) - (o.cash || []).filter(c => c.verified).reduce((n,c) => n + (c.kind === 'refund' ? -c.amountCents : c.amountCents),0)),0), readyCount: orders.filter(o => o.status === 'pending_completion').length,
      tasksCount: orders.reduce((s,o) => s + (o.obligations || []).filter(x => !x.resolved).length,0), blockedCount: orders.filter(o => (o.issues || []).some(x => !x.resolved)).length };
  }
  completionMissing(o) {
    const missing = [];
    if (!o.outcome) missing.push('等待履约验收');
    if (this.metrics([o]).remainingCents > 0) missing.push('应收未清');
    if (o.cash.some(x=>!x.verified)) missing.push('存在待核实款项');
    if (o.cash.some(x=>x.verified&&!x.handedOver)) missing.push('内部交接未清');
    if (o.issues.some(x=>!x.resolved)) missing.push('存在未解决异议');
    if (o.obligations.some(x=>!x.resolved)) missing.push('存在未办余项');
    if (!o.documents?.requirement || o.documents.requirement==='unknown' || o.documents.requirement==='required'&&!o.documents.sent) missing.push('付款资料未清');
    if (!o.invoiceRequirement || o.invoiceRequirement==='unknown' || o.invoiceRequirement==='required'&&!o.invoices.length) missing.push('发票未清');
    if (this.local.loans.some(l=>l.orderId===o.id&&l.outstanding-(l.transfers||[]).reduce((n,x)=>n+x.quantity,0)>0)) missing.push('工单借用未清');
    if (o.commissions.some(c=>!c.settled)) missing.push('提成未结算');
    return missing;
  }
  async refresh(query = '') {
    const epoch = this.epoch, revision = ++this.readRevision;
    if (!this.actor) return;
    try {
      if (!this.token) await this.request('/session');
      const value = await this.request('/bootstrap');
      if (!sameActor(this.actor, value.actor) || !Array.isArray(value.orders) || !value.orders.every(validOrder) || !Array.isArray(value.parts) || !value.parts.every(p => identity(p) && count(p.available) && count(p.quarantine)) || !Array.isArray(value.loans) || !value.loans.every(validLoan) || !Array.isArray(value.purchases) || !value.purchases.every(validPurchase)) throw new ApiError('工作台响应不完整');
      const list = await this.request(`/orders?pageSize=30&${query}`);
      if (!Array.isArray(list.items) || !list.items.every(validOrder) || !Number.isInteger(list.total)) throw new ApiError('工单分页响应无效');
      if (epoch !== this.epoch || revision !== this.readRevision) return;
      this.snapshot = { ...value, orders: list.items, orderPage: list }; this.demo = false;
    } catch (e) {
      if (epoch !== this.epoch || revision !== this.readRevision) return;
      if (e.status === 401 || e.status === 403) { this.logout(); throw e; }
      this.demo = true; this.snapshot = this.localSnapshot();
    }
  }
  async detail(id) {
    const epoch = this.epoch;
    if (!this.demo) {
      const o = await this.request(`/orders/${encodeURIComponent(id)}`);
      if (epoch !== this.epoch) throw Error('身份已改变');
      if (!validOrder(o) || o.id !== id || o.isSummary) throw Error('详情响应无效');
      return o;
    }
    return clone(this.localSnapshot().orders.find(o => o.id === id));
  }
  actions(o) {
    const roles = [
      [['sign_quote','accept'],['customer']],
      [['intake','assign','approve_quote','failure','complete','reopen','rework','requirements','outsource','obligation','resolve_issue','review_acceptance','handover_contact'],['admin','dispatcher']],
      [['quote','diagnose','report'],['admin','dispatcher','engineer','outsource']],
      [['start','finish','start_visit'],['admin','engineer','outsource']],
      [['receive','stock_ready','dispatch'],['admin','warehouse']], [['qc'],['admin','qc']],
      [['deliver'],['admin','warehouse','engineer','dispatcher']],
      [['verify_cash','handover_cash','invoice','void_invoice','adjust_receivable','approve_cost','commission','settle_commission'],['admin','finance']],
      [['documents'],['admin','dispatcher','finance']], [['cash','cost'],['admin','dispatcher','finance','engineer','warehouse']],
      [['visit'],['admin','dispatcher','engineer']], [['remark','resolve_obligation'],['admin','dispatcher','engineer','warehouse','qc','finance']],
      [['issue','evidence','delete_evidence'],['admin','dispatcher','engineer','warehouse','qc','finance','customer','outsource']]
    ];
    const stages = {intake:['pending_intake'],receive:['pending_arrangement','pending_quality_check'],diagnose:['pending_arrangement'],report:['diagnosis_quotation'],quote:['diagnosis_quotation','pending_customer_confirmation','pending_execution'],approve_quote:['diagnosis_quotation'],sign_quote:['pending_customer_confirmation'],start:['pending_execution'],finish:['repairing'],qc:['pending_quality_check'],stock_ready:['pending_execution'],dispatch:['pending_delivery'],deliver:['pending_delivery'],accept:['pending_acceptance'],complete:['pending_completion'],reopen:['completed']};
    return this.spec.actions.map(a=>a.type).filter(type=>{
      if (!roles.some(([actions,allowed])=>actions.includes(type)&&allowed.includes(this.actor.role))) return false;
      if (stages[type]&&!stages[type].includes(o.status)) return false;
      if (o.status==='completed'&&!['reopen','rework','remark','evidence','delete_evidence','handover_contact'].includes(type)) return false;
      if (type==='start'&&o.type==='sale'||type==='stock_ready'&&o.type!=='sale'||['visit','start_visit'].includes(type)&&o.type!=='onsite'||type==='rework'&&!o.acceptedAt||type==='failure'&&o.outcome) return false;
      if (type==='review_acceptance'&&!o.restartReview) return false;
      if (type==='resolve_obligation'&&!o.obligations.some(t=>!t.resolved&&(['admin','dispatcher'].includes(this.actor.role)||t.ownerId===this.actor.id))) return false;
      return true;
    });
  }
  async write(path, body, localAction, check) {
    const epoch = this.epoch, signature = path + JSON.stringify(body);
    const key = this.pending.get(signature) || crypto.randomUUID(); this.pending.set(signature,key);
    try {
      const value = await this.request(path,body,key);
      if (epoch !== this.epoch) throw Error('身份已改变');
      const validator = check || (path.startsWith('/loans') ? validLoan : path.startsWith('/purchases') ? validPurchase : null);
      if (validator && !validator(value)) throw new ApiError('响应与提交上下文不匹配',502);
      this.pending.delete(signature); await this.refresh(); return value;
    } catch (e) {
      if (epoch !== this.epoch) throw e;
      if (e.status === 401) { this.logout(); throw e; }
      if (e.status && !(this.demo && !this.token && e.status >= 500)) {
        if (e.status >= 400 && e.status < 500 && ![408, 429].includes(e.status)) this.pending.delete(signature);
        throw e;
      }
      if (!this.demo || this.token) throw new ApiError('提交结果尚未确认，请保留表单并重新提交核对；不会写入本地副本');
      const role = this.actor?.role;
      let allowed;
      if (path === '/orders') allowed = ['admin','dispatcher','customer'];
      else if (path.startsWith('/loans')) allowed = ['admin','warehouse'];
      else if (/^\/purchases\/[^/]+\/receive$/.test(path)) allowed = ['admin','warehouse'];
      else if (path === '/purchases') allowed = ['admin','warehouse','dispatcher'];
      else if (path === '/settings') allowed = ['admin'];
      if (allowed && !allowed.includes(role)) throw new ApiError('当前岗位不能办理此动作',403);
      const value = localAction(); this.pending.delete(signature); this.snapshot = this.localSnapshot(); return clone(value);
    }
  }
  create(payload) {
    return this.write('/orders', payload, () => {
      if (this.actor.role === 'customer') {
        if (payload.companyId && payload.companyId !== this.actor.companyId) throw Error('不能为其他企业创建工单');
        payload = {...payload,customerId:this.actor.id,companyId:this.actor.companyId,customer:payload.customer||this.actor.name};
      }
      const id = `demo-${crypto.randomUUID()}`, o = { ...payload, id, number: `DEMO-${this.local.orders.length+1}`, version:1,status:'pending_intake',cash:[],invoices:[],evidence:[],events:[],issues:[],obligations:[],costs:[],commissions:[] };
      this.local.orders.unshift(o); return o;
    }, validOrder);
  }
  act(order, type, payload) {
    return this.write(`/orders/${encodeURIComponent(order.id)}/actions`,{type,version:order.version,payload}, () => {
      const original = this.local.orders.find(o => o.id === order.id);
      if (!original || original.version !== order.version || !this.actions(original).includes(type)) throw Error('当前状态或身份不允许此操作');
      const o = clone(original); this.applyDemo(o,type,payload);
      o.version++; o.events.unshift({title:this.spec.actions.find(a => a.type===type)?.label,note:payload.note || '',at:new Date().toISOString()});
      Object.assign(original,o); return original;
    }, value => validOrder(value) && (type === 'rework' ? value.id !== order.id && value.originalOrderId === order.id : value.id === order.id && value.version > order.version));
  }
  applyDemo(o,type,p) {
    const transitions = { intake:'pending_arrangement',diagnose:'diagnosis_quotation',start:'repairing',finish:'pending_quality_check',deliver:'pending_acceptance' };
    if (type in transitions) {
      if (type === 'start' && (!o.quote?.approved || !o.quote?.signed || o.issues.some(x=>!x.resolved))) throw Error('报价须签署且异议须解决');
      if (type === 'start' && o.quote.startRequiresPrepayment) { const net=o.cash.filter(c=>c.verified).reduce((n,c)=>n+(c.kind==='refund'?-c.amountCents:c.amountCents),0);if(net<o.quote.prepayCents)throw Error('须先核实约定预付款'); }
      o.status = transitions[type]; Object.assign(o, type === 'intake' ? p : {}); return;
    }
    if (type === 'quote') {
      if (p.prepayCents < 0 || p.prepayCents > p.amountCents || p.startRequiresPrepayment && p.prepayCents <= 0 || !p.description || new Date(p.validUntil) <= new Date()) throw Error('请核对报价范围、预付款和有效期');
      o.quote = {...p,version:(o.quote?.version||0)+1,approved:false,signed:false}; o.receivableCents=p.amountCents;
    } else if (type === 'approve_quote') { if(!o.quote)throw Error('请先报价');o.quote.approved=true;o.status='pending_customer_confirmation';
    } else if (type === 'sign_quote') { if(!p.signature || p.quoteVersion!==o.quote.version)throw Error('签名或报价版本无效');o.quote.signed=true;o.status='pending_execution';
    } else if (type === 'qc') { o.status=p.passed?'pending_delivery':'repairing';
    } else if (type === 'accept') { if(!p.signature)throw Error('请手写签名');if(p.passed){o.outcome='accepted';o.status='settling';}else o.issues.push({id:crypto.randomUUID(),title:p.note||'验收未通过',resolved:false});
    } else if (type === 'remark') Object.assign(o,p);
    else if (type === 'requirements') {o.documents={...o.documents,requirement:p.documentRequirement};o.invoiceRequirement=p.invoiceRequirement;o.invoiceDueCents=p.invoiceDueCents;}
    else if (type === 'documents') {if(p.sent && (!p.recipient || !p.prepared || !p.files.length))throw Error('发送资料需接收人、制作状态与原件');o.documents={...o.documents,...p};}
    else if (type === 'cash') {if(p.amountCents<=0)throw Error('金额须大于零');o.cash.push({...p,id:crypto.randomUUID(),verified:false,handedOver:false});}
    else if (type === 'verify_cash' || type === 'handover_cash') {const c=o.cash.find(x=>x.id===p.cashId);if(!c)throw Error('现金记录不存在');if(type==='verify_cash'){const net=o.cash.filter(x=>x.verified).reduce((n,x)=>n+(x.kind==='refund'?-x.amountCents:x.amountCents),0);if(c.kind==='refund'&&c.amountCents>net)throw Error('退款不能超过净实收');c.verified=true;}else{if(!c.verified)throw Error('请先核实');c.handedOver=true;}}
    else if (type === 'adjust_receivable') o.receivableCents=p.amountCents;
    else if (type === 'evidence') o.evidence.push({...p,id:crypto.randomUUID()});
    else if (type === 'delete_evidence') {const e=o.evidence.find(x=>x.id===p.evidenceId&&!x.deleted);if(!e||!p.reason)throw Error('原件或删除原因缺失');e.deleted=true;}
    else if (type === 'issue') o.issues.push({id:crypto.randomUUID(),title:p.note,...p,resolved:false});
    else if (type === 'resolve_issue') {const x=o.issues.find(x=>x.id===p.issueId);if(!x)throw Error('异议不存在');x.resolved=true;}
    else if (type === 'obligation') o.obligations.push({...p,id:crypto.randomUUID(),resolved:false});
    else if (type === 'resolve_obligation') {const x=o.obligations.find(x=>x.id===p.obligationId&&!x.resolved);if(!x||!['admin','dispatcher'].includes(this.actor.role)&&x.ownerId!==this.actor.id)throw Error('无权办理此余项');x.resolved=true;}
    else if (type === 'failure') {if(o.outcome)throw Error('不能覆盖已有履约结果');o.outcome='failed';o.status='settling';o.receivableCents=p.amountCents;}
    else if (type === 'reopen') {o.status='settling';}
    else if (type === 'complete') {const missing=this.completionMissing(o);if(missing.length)throw Error(missing.join('、'));o.status='completed';}
    else if (['receive','report','dispatch','assign'].includes(type)) {if(type==='assign')o.assigneeId=p.assigneeId;}
    else throw Error('此动作请连接服务端办理；演示不伪造结果');
  }
}
