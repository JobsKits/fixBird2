import { Actor, Cash, ClientError, Evidence, Order, Part, Snapshot, Task, newKey } from './Models';
import type { Payload } from './Models';

// 合成台账始终独立，真实资料和未知写入绝不复制到演示中。
export class DemoLedger {
  snapshot: Snapshot = new Snapshot();

  constructor(role: string = 'customer') {
    const actor = new Actor();
    actor.id = 'demo-' + role;
    actor.name = role === 'engineer' ? '演示工程师' : role === 'customer' ? '演示客户' : '演示管理员';
    actor.role = 'admin';
    actor.companyId = 'demo-company';
    this.snapshot.actor = actor;
    const part = new Part();
    part.id = 'demo-part';
    part.name = '维修电源模块';
    part.sku = 'DEMO-POWER';
    part.available = 12;
    this.snapshot.parts = [part];
    const first = this.create({ type: 'mail', customer: '演示物业公司', project: '一号楼机房', device: '门禁电源', description: '设备断电，需检测维修。' });
    actor.role = role;
    if (role === 'engineer') {
      first.status = 'pending_arrangement';
      first.assigneeId = actor.id;
    }
    this.refresh(first);
    this.snapshot.orderPage.total = this.snapshot.orders.length;
  }

  create(input: Payload): Order {
    if (['customer', 'admin', 'dispatcher'].indexOf(this.snapshot.actor.role) < 0) {
      throw new ClientError('当前角色不能新建工单。');
    }
    if (!input['device'] || !input['description'] || !input['customer']) {
      throw new ClientError('客户、设备与故障说明不能为空。');
    }
    const order = new Order();
    order.id = 'demo-' + newKey();
    order.number = '演示-' + String(this.snapshot.orders.length + 1).padStart(4, '0');
    order.type = input['type'] as string;
    order.customer = input['customer'] as string;
    order.customerId = 'demo-customer';
    order.companyId = 'demo-company';
    order.project = input['project'] as string || '';
    order.device = input['device'] as string;
    order.description = input['description'] as string;
    order.customerNote = input['customerNote'] as string || '';
    order.ownerId = 'demo-admin';
    order.assigneeId = 'demo-engineer';
    order.createdAt = new Date().toISOString();
    order.updatedAt = order.createdAt;
    this.snapshot.orders.unshift(order);
    this.refresh(order);
    this.snapshot.orderPage.total = this.snapshot.orders.length;
    return order;
  }

  get(id: string): Order {
    const order = this.snapshot.orders.find((item: Order) => item.id === id);
    if (!order) {
      throw new ClientError('演示工单不存在。');
    }
    return order;
  }

  actions(order: Order): string[] {
    const role = this.snapshot.actor.role;
    const actions: string[] = ['evidence', 'issue'];
    if (role === 'customer') {
      if (order.status === 'pending_customer_confirmation') {
        actions.push('sign_quote');
      }
      if (order.status === 'pending_acceptance') {
        actions.push('accept');
      }
    } else {
      actions.push('remark');
      if (role === 'admin') {
        const next: Record<string, string> = { pending_intake: 'intake', diagnosis_quotation: 'approve_quote', pending_quality_check: 'qc', pending_delivery: 'deliver' };
        if (next[order.status]) {
          actions.push(next[order.status]);
        }
      }
      if (['engineer', 'admin'].indexOf(role) >= 0) {
        const next: Record<string, string> = { pending_arrangement: 'diagnose', diagnosis_quotation: 'quote', pending_execution: 'start', repairing: 'finish' };
        if (next[order.status]) {
          actions.push(next[order.status]);
        }
      }
    }
    if (order.status === 'completed') {
      return ['evidence', 'remark'].filter((value: string) => value !== 'remark' || role !== 'customer');
    }
    return actions;
  }

  refresh(order: Order): void {
    order.allowedActions = this.actions(order);
    order.summary.nextTask = '按当前阶段核对并办理实际事项';
    order.summary.receivableCents = order.quote.amountCents;
    order.summary.collectedCents = order.cash.reduce((total: number, item: Cash) => total + (item.verified ? item.amountCents * (item.kind === 'refund' ? -1 : 1) : 0), 0);
    order.summary.remainingCents = Math.max(0, order.summary.receivableCents - order.summary.collectedCents);
    order.summary.missing = order.issues.filter((item: Task) => !item.resolved).map((item: Task) => item.note);
  }

  apply(id: string, action: string, version: number, payload: Payload): Order {
    const before = this.get(id);
    if (before.version !== version || this.actions(before).indexOf(action) < 0) {
      throw new ClientError('演示身份、阶段或版本已变化，请重新加载。');
    }
    const order = JSON.parse(JSON.stringify(before)) as Order;
    const unresolved = order.issues.some((item: Task) => !item.resolved);
    switch (action) {
      case 'intake':
        order.ownerId = payload['ownerId'] as string;
        order.assigneeId = payload['assigneeId'] as string;
        order.status = 'pending_arrangement';
        break;
      case 'diagnose': order.status = 'diagnosis_quotation'; break;
      case 'quote':
        if ((payload['prepayCents'] as number) > (payload['amountCents'] as number)) {
          throw new ClientError('预付款不得超过报价总额。');
        }
        order.quote.amountCents = payload['amountCents'] as number;
        order.quote.description = payload['description'] as string;
        order.quote.prepayCents = payload['prepayCents'] as number;
        order.quote.startRequiresPrepayment = payload['startRequiresPrepayment'] as boolean;
        order.quote.warrantyMonths = payload['warrantyMonths'] as number;
        order.quote.paymentTerms = payload['paymentTerms'] as string;
        order.quote.validUntil = payload['validUntil'] as string;
        order.quote.autoAccept = payload['autoAccept'] as boolean;
        order.quote.version += 1;
        order.quote.approved = false;
        order.quote.signed = false;
        break;
      case 'approve_quote':
        if (order.quote.version < 1) {
          throw new ClientError('请先制定完整报价。');
        }
        order.quote.approved = true;
        order.status = 'pending_customer_confirmation';
        break;
      case 'sign_quote':
      case 'accept':
        // 演示不伪造签署历史或正式验收事实。
        throw new ClientError('手写签署须连接服务端办理；当前仅演示查看流程。');
      case 'start':
        if (!order.quote.approved || !order.quote.signed || unresolved ||
          (order.quote.startRequiresPrepayment && order.summary.collectedCents < order.quote.prepayCents)) {
          throw new ClientError('当前报价未有效签署、有异议或约定预付款未核实。');
        }
        order.status = 'repairing';
        break;
      case 'finish': order.status = 'pending_quality_check'; break;
      case 'qc': order.status = payload['passed'] === true ? 'pending_delivery' : 'repairing'; break;
      case 'deliver':
        if (Date.parse(payload['deliveredAt'] as string) < Date.parse(order.createdAt)) {
          throw new ClientError('交付时间不得早于本单创建。');
        }
        order.status = 'pending_acceptance';
        break;
      case 'remark':
        order.remark = payload['remark'] as string;
        order.customerNote = payload['customerNote'] as string;
        break;
      case 'evidence': {
        const item = new Evidence();
        item.id = 'demo-' + newKey();
        item.name = payload['name'] as string;
        item.text = payload['text'] as string;
        item.uploaderId = this.snapshot.actor.id;
        order.evidence.push(item);
        break;
      }
      case 'issue': {
        const issue = new Task();
        issue.id = 'demo-' + newKey();
        issue.note = payload['note'] as string;
        issue.ownerId = payload['ownerId'] as string;
        issue.dueAt = payload['dueAt'] as string;
        order.issues.push(issue);
        break;
      }
      default: throw new ClientError('该事项须连接服务端办理，演示不产生财务或复杂库存事实。');
    }
    order.version += 1;
    order.updatedAt = new Date().toISOString();
    this.refresh(order);
    this.snapshot.orders = this.snapshot.orders.map((item: Order) => item.id === id ? order : item);
    return order;
  }
}
