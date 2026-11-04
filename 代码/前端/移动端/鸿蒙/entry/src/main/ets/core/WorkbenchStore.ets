import {
  Actor, ClientError, Loan, LoginResponse, Order, OrderResult, Purchase, Snapshot,
  integer, newKey, normalizeBase, sameActor, validateActor, validateLoan,
  validateOrder, validatePurchase, validateSnapshot
} from './Models';
import type { ActionRequest, LoginInput, Payload } from './Models';
import { DemoLedger } from './DemoLedger';

export interface Transport {
  send(base: string, path: string, method: string, body: string, token: string, key: string, timeout: number): Promise<string>;
}

export class WorkbenchStore {
  base: string = 'http://127.0.0.1:8098';
  timeout: number = 2500;
  actor: Actor = new Actor();
  snapshot: Snapshot = new Snapshot();
  source: string = '请登录或选择演示账号';
  demo: boolean = true;
  authenticated: boolean = false;
  private transport: Transport;
  private token: string = '';
  private anchor: Actor = new Actor();
  private generation: number = 0;
  private listRevision: number = 0;
  private ledger: DemoLedger = new DemoLedger();
  private pendingBody: string = '';
  private pendingPath: string = '';
  private pendingKey: string = '';

  constructor(transport: Transport) {
    this.transport = transport;
  }

  configure(base: string, timeout: number): void {
    const normalized = normalizeBase(base);
    if (!integer(timeout, 500) || timeout > 10000) {
      throw new ClientError('超时须为500～10000毫秒。');
    }
    this.clear();
    this.base = normalized;
    this.timeout = timeout;
  }

  private clear(): void {
    this.generation += 1;
    this.listRevision += 1;
    this.token = '';
    this.authenticated = false;
    this.actor = new Actor();
    this.anchor = new Actor();
    this.snapshot = new Snapshot();
    this.pendingBody = '';
    this.pendingKey = '';
    this.pendingPath = '';
    this.demo = true;
    this.source = '请登录或选择演示账号';
  }

  private fallback(role: string): void {
    const demoRole = ['customer', 'engineer', 'admin'].indexOf(role) >= 0 ? role : 'admin';
    this.ledger = new DemoLedger(demoRole);
    this.snapshot = this.ledger.snapshot;
    this.actor = this.snapshot.actor;
    this.demo = true;
    this.source = '独立本地演示 · 不含服务器资料';
  }

  async enterDemo(role: string): Promise<void> {
    this.clear();
    const generation = this.generation;
    // 即使仅预览，仍探测当前服务器；不把演示身份提升为真实授权。
    try {
      await this.transport.send(this.base, '/healthz', 'GET', '', '', '', this.timeout);
    } catch (_) {}
    if (generation !== this.generation) {
      throw new ClientError('身份已变化，旧演示入口已取消。', -1);
    }
    this.fallback(role);
    this.authenticated = true;
  }

  private async request(path: string, method: string = 'GET', body: string = '', key: string = ''): Promise<string> {
    const generation = this.generation;
    try {
      const result = await this.transport.send(this.base, path, method, body, this.token, key, this.timeout);
      if (generation !== this.generation) {
        throw new ClientError('连接或身份已变化，旧响应已丢弃。', -1);
      }
      return result;
    } catch (reason) {
      const error = reason as ClientError;
      if (generation !== this.generation) {
        throw new ClientError('连接或身份已变化，旧响应已丢弃。', -1);
      }
      if (error.code === 401 && this.token.length > 0) {
        this.clear();
        this.source = '会话已失效，请重新登录';
      }
      throw error;
    }
  }

  async login(username: string, password: string): Promise<void> {
    this.clear();
    const input: LoginInput = { username: username, password: password };
    const response = JSON.parse(await this.request('/login', 'POST', JSON.stringify(input))) as LoginResponse;
    validateActor(response.actor);
    if (!response.token || typeof response.token !== 'string') {
      throw new ClientError('登录响应缺少有效会话。');
    }
    this.token = response.token;
    this.anchor = response.actor;
    this.actor = response.actor;
    this.authenticated = true;
    await this.refresh();
  }

  async logout(): Promise<void> {
    try {
      if (this.token) {
        await this.request('/logout', 'POST', '{}');
      }
    } finally {
      this.clear();
    }
  }

  async refresh(): Promise<void> {
    if (!this.token) {
      try {
        await this.request('/bootstrap');
      } catch (reason) {
        const error = reason as ClientError;
        if (error.code === -1) {
          throw error;
        }
      }
      this.snapshot = this.ledger.snapshot;
      return;
    }
    try {
      const snapshot = JSON.parse(await this.request('/bootstrap')) as Snapshot;
      validateSnapshot(snapshot, this.anchor);
      this.snapshot = snapshot;
      this.actor = snapshot.actor;
      this.demo = false;
      this.source = '服务端资料 · ' + this.base;
    } catch (reason) {
      const error = reason as ClientError;
      if (error.code === 401 || error.code === 403 || error.code === -1) {
        throw error;
      }
      if (!this.demo || this.snapshot.actor.id.indexOf('demo-') !== 0) {
        this.fallback(this.anchor.role);
      }
      this.source = '连接暂不可用 · 独立本地演示 · 重载将自动重连';
    }
  }

  async list(q: string, status: string, page: number): Promise<OrderResult> {
    const revision = ++this.listRevision;
    if (this.demo) {
      await this.refresh();
    }
    if (this.demo) {
      return this.demoList(q, status);
    }
    try {
      const result = JSON.parse(await this.request('/orders?page=' + page + '&pageSize=30&q=' + encodeURIComponent(q) + '&status=' + encodeURIComponent(status))) as OrderResult;
      if (revision !== this.listRevision) {
        throw new ClientError('筛选条件已变化，旧列表已丢弃。', -1);
      }
      if (!Array.isArray(result.items) || !integer(result.total) || !integer(result.page, 1) || !integer(result.totalPages)) {
        throw new ClientError('工单分页响应不完整。');
      }
      result.items.forEach((order: Order) => validateOrder(order));
      return result;
    } catch (reason) {
      const error = reason as ClientError;
      if (error.code === 401 || error.code === 403 || error.code === -1) {
        throw error;
      }
      this.fallback(this.anchor.role);
      return this.demoList(q, status);
    }
  }

  private demoList(q: string, status: string): OrderResult {
    const result = new OrderResult();
    result.items = this.snapshot.orders.filter((order: Order) => (!status || order.status === status) &&
      (!q || (order.number + order.device + order.customer + order.description).indexOf(q) >= 0));
    result.total = result.items.length;
    return result;
  }

  async detail(id: string): Promise<Order> {
    if (this.demo) {
      // 演示详情也尝试恢复连接；恢复后必须重新从真实列表选择。
      await this.refresh();
      if (!this.demo) {
        throw new ClientError('服务已恢复，请返回列表选择真实工单。');
      }
      return this.ledger.get(id);
    }
    try {
      const order = JSON.parse(await this.request('/orders/' + encodeURIComponent(id))) as Order;
      validateOrder(order, true);
      if (order.id !== id) {
        throw new ClientError('详情响应与所选工单不匹配。');
      }
      return order;
    } catch (reason) {
      const error = reason as ClientError;
      if (error.code === 401 || error.code === 403 || error.code === 404 || error.code === -1) {
        throw error;
      }
      this.fallback(this.anchor.role);
      throw new ClientError('详情暂不可用，已回到独立演示。请从工单列表重新选择。');
    }
  }

  private async write(path: string, body: string): Promise<string> {
    if (this.pendingBody && (this.pendingBody !== body || this.pendingPath !== path)) {
      throw new ClientError('上次提交结果未知。请保留原内容重试，或先重载核对结果；不能改成另一次记账。');
    }
    if (!this.pendingKey) {
      this.pendingKey = newKey();
      this.pendingBody = body;
      this.pendingPath = path;
    }
    try {
      return await this.request(path, 'POST', body, this.pendingKey);
    } catch (reason) {
      const error = reason as ClientError;
      if (error.code >= 400 && error.code < 500 && error.code !== 408) {
        this.finishWrite();
      }
      throw new ClientError(error.message + (error.code === 0 || error.code >= 500 || error.uncertain ? ' 提交结果未知，请重载核对；同内容重试沿用原请求键。' : ''), error.code, true);
    }
  }

  private finishWrite(): void {
    this.pendingKey = '';
    this.pendingBody = '';
    this.pendingPath = '';
  }

  async create(payload: Payload): Promise<Order> {
    if (this.demo) {
      await this.refresh();
      if (!this.demo) {
        throw new ClientError('服务器已恢复，请从真实列表重新新增。');
      }
      return this.ledger.create(payload);
    }
    const order = JSON.parse(await this.write('/orders', JSON.stringify(payload))) as Order;
    validateOrder(order, true);
    this.finishWrite();
    return order;
  }

  async perform(order: Order, action: string, payload: Payload): Promise<Order> {
    if (order.isSummary || order.allowedActions.indexOf(action) < 0) {
      throw new ClientError('请先加载完整详情，并核对当前办理权限。');
    }
    if (this.demo) {
      await this.refresh();
      if (!this.demo) {
        throw new ClientError('服务器已恢复，请重新打开真实单据核对。');
      }
      return this.ledger.apply(order.id, action, order.version, payload);
    }
    const input: ActionRequest = { type: action, version: order.version, payload: payload };
    const body = JSON.stringify(input);
    const updated = JSON.parse(await this.write('/orders/' + encodeURIComponent(order.id) + '/actions', body)) as Order;
    validateOrder(updated, true);
    if (action === 'rework' ? updated.id === order.id || updated.originalOrderId !== order.id : updated.id !== order.id || updated.version <= order.version) {
      throw new ClientError('提交响应与工单上下文不匹配，结果待核对。', 0, true);
    }
    this.finishWrite();
    return updated;
  }

  async inventoryWrite(path: string, body: string, loan: boolean): Promise<void> {
    if (this.demo) {
      await this.refresh();
      throw new ClientError(this.demo ? '库存数量变化须连接服务端办理；本地演示不生成库存凭证。' : '服务器已恢复，请重新打开库存办理。');
    }
    const text = await this.write(path, body);
    if (loan) {
      validateLoan(JSON.parse(text) as Loan);
    } else {
      validatePurchase(JSON.parse(text) as Purchase);
    }
    this.finishWrite();
    await this.refresh();
  }
}
