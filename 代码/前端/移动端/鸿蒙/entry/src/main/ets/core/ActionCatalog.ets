import { Cash, ClientError, Evidence, Order, Task, money } from './Models';
import type { Payload } from './Models';

export class Choice {
  value: string;
  label: string;
  constructor(value: string, label: string) {
    this.value = value;
    this.label = label;
  }
}

export class Field {
  key: string;
  label: string;
  kind: string;
  value: string;
  required: boolean;
  choices: Choice[] = [];
  constructor(key: string, label: string, kind: string = 'text', value: string = '', required: boolean = true) {
    this.key = key;
    this.label = label;
    this.kind = kind;
    this.value = value;
    this.required = required;
    if (kind === 'bool') {
      this.choices = [new Choice('false', '否'), new Choice('true', '是')];
    }
  }
}

const TITLES: Record<string, string> = {
  intake: '受理工单', receive: '收件登记', assign: '改派责任人', diagnose: '开始检测', report: '检测结论',
  quote: '制定报价', approve_quote: '审核报价', sign_quote: '签署报价', start: '开始维修', finish: '维修完工',
  qc: '质量检查', stock_ready: '销售备货', dispatch: '发运登记', deliver: '完整交付', accept: '客户验收',
  requirements: '票据资料要求', documents: '制作及发送资料', cash: '登记现金', verify_cash: '核实现金',
  handover_cash: '内部现金交接', invoice: '登记发票', void_invoice: '作废发票', adjust_receivable: '调整应收',
  remark: '备注与客户说明', evidence: '归档文字资料', delete_evidence: '删除资料', issue: '提出异议',
  resolve_issue: '协商处理异议', failure: '停止履约', obligation: '登记内部余项', resolve_obligation: '办理余项',
  visit: '安排上门', start_visit: '到场登记', outsource: '登记外包', cost: '登记成本', approve_cost: '审核成本',
  commission: '登记提成', settle_commission: '结算提成', complete: '整单完结', reopen: '重开工单',
  rework: '关联返修', review_acceptance: '复核验收窗口', handover_contact: '交接客户经办人',
  create: '新增工单', loan: '借出配件', purchase: '新增采购', return: '归还配件', consume: '转维修耗用',
  dispose: '批准处置', transfer: '转独立跟踪', receive_purchase: '分批收货'
};

export function actionTitle(action: string): string {
  return TITLES[action] || action;
}

function choice(key: string, label: string, values: string[], labels: string[], value: string = ''): Field {
  const field = new Field(key, label, 'choice', value || values[0]);
  values.forEach((item: string, index: number) => field.choices.push(new Choice(item, labels[index])));
  return field;
}

function note(): Field {
  return new Field('note', '本次事实说明／办理依据', 'multiline');
}

function future(days: number): string {
  return new Date(Date.now() + days * 86400000).toISOString();
}

export function fieldsFor(action: string, order: Order): Field[] {
  const quote = order.quote;
  switch (action) {
    case 'create':
      return [choice('type', '业务类型', ['mail', 'onsite', 'sale'], ['寄修', '上门维修', '配件销售']),
        new Field('customer', '客户／企业名称'), new Field('customerId', '当前客户账号 ID（客户本人可留空）', 'text', '', false),
        new Field('companyId', '客户企业 ID（客户本人可留空）', 'text', '', false), new Field('project', '项目／安装位置'),
        new Field('device', '设备名称／型号'), new Field('description', '故障说明／购买需求', 'multiline'),
        new Field('customerNote', '对客说明', 'multiline', '', false)];
    case 'intake':
      return [new Field('ownerId', '公司负责人账号 ID', 'text', order.ownerId),
        new Field('assigneeId', '执行责任人账号 ID', 'text', order.assigneeId)];
    case 'assign': return [new Field('assigneeId', '新执行责任人账号 ID', 'text', order.assigneeId)];
    case 'handover_contact': return [new Field('customerId', '同企业新经办人账号 ID'), new Field('reason', '已核实授权与交接依据', 'multiline')];
    case 'quote':
      return [new Field('amountCents', '含税报价总额（元）', 'money', (quote.amountCents / 100).toFixed(2)),
        new Field('description', '型号、数量、维修范围和完整报价条款', 'multiline', quote.description),
        new Field('warrantyMonths', '质保月数（1～60）', 'integer', String(quote.warrantyMonths || 12)),
        choice('paymentTerms', '付款约定', ['cash', 'credit'], ['现金约定', '批准企业账期'], quote.paymentTerms),
        new Field('prepayCents', '约定预付款（元，可为零）', 'money', (quote.prepayCents / 100).toFixed(2)),
        new Field('startRequiresPrepayment', '是否明确约定核实预付款后开修', 'bool', String(quote.startRequiresPrepayment || false)),
        new Field('validUntil', '报价接受截止时间（含时区）', 'date', future(30)),
        new Field('autoAccept', '客户是否接受交付后七日自动验收规则', 'bool', String(quote.autoAccept || false))];
    case 'sign_quote': return [];
    case 'accept': return [new Field('passed', '本次是否验收通过', 'bool', 'true'), note()];
    case 'qc': return [new Field('passed', '实际质检是否合格', 'bool', 'true'), note()];
    case 'stock_ready': return [new Field('partId', '实际出库配件 ID'), new Field('quantity', '实际数量', 'integer', '1')];
    case 'dispatch': return [new Field('carrier', '承运方／自送方式'), new Field('tracking', '运单号／自送凭据', 'text', '', false), note()];
    case 'deliver': return [new Field('deliveredAt', '实际完整交接时间（含时区）', 'date', future(0)), note()];
    case 'requirements':
      return [choice('documentRequirement', '付款资料要求', ['unknown', 'required', 'none'], ['待确认', '需要', '无需，有确认依据']),
        new Field('documentReason', '资料要求来源／无需依据', 'multiline', '', false),
        choice('invoiceRequirement', '发票要求', ['unknown', 'required', 'none'], ['待确认', '需要', '无需，有确认依据']),
        new Field('invoiceReason', '发票要求来源／无需依据', 'multiline', '', false),
        new Field('invoiceDueCents', '应开含税票额（元）', 'money', (quote.amountCents / 100).toFixed(2))];
    case 'documents':
      return [new Field('prepared', '资料已实际制作齐备', 'bool', 'false'), new Field('sent', '资料已实际发送', 'bool', 'false'),
        new Field('recipient', '实际发送对象与方式', 'text', '', false), new Field('files', '已有原件 ID（逗号分隔）', 'files', '', false)];
    case 'invoice':
      return [new Field('number', '真实发票号码'), new Field('amountCents', '含税票额（元）', 'money'),
        new Field('files', '有效 PDF／图片原件 ID（逗号分隔）', 'files')];
    case 'void_invoice': return [new Field('invoiceId', '待作废发票 ID'), new Field('reason', '红冲／作废依据', 'multiline')];
    case 'cash':
      return [choice('kind', '本次实际现金事实', ['receipt', 'refund'], ['收到现金', '实际退款']),
        new Field('amountCents', '本次金额（元）', 'money'), new Field('purpose', '用途（预付／尾款等）'),
        new Field('receipt', '现金凭据／收讫依据', 'multiline'), new Field('occurredAt', '实际发生时间（含时区）', 'date', future(0))];
    case 'verify_cash':
    case 'handover_cash': {
      const field = new Field('cashId', '选择本次现金记录', 'choice');
      order.cash.filter((cash: Cash) => action === 'verify_cash' ? !cash.verified : cash.verified && !cash.handedOver)
        .forEach((cash: Cash) => field.choices.push(new Choice(cash.id, money(cash.amountCents) + ' · ' + cash.purpose)));
      field.value = field.choices.length > 0 ? field.choices[0].value : '';
      return [field];
    }
    case 'adjust_receivable': return [new Field('amountCents', '批准后有效应收总额（元）', 'money', (order.summary.receivableCents / 100).toFixed(2)), new Field('reason', '批准人与调整依据', 'multiline')];
    case 'remark': return [new Field('remark', '内部备注', 'multiline', order.remark, false), new Field('customerNote', '对客说明', 'multiline', order.customerNote, false)];
    case 'evidence': return [new Field('name', '文字资料名称'), new Field('text', '实际事实内容', 'multiline')];
    case 'delete_evidence': {
      const field = new Field('evidenceId', '选择待删除资料', 'choice');
      order.evidence.filter((item: Evidence) => !item.deleted).forEach((item: Evidence) => field.choices.push(new Choice(item.id, item.name)));
      field.value = field.choices.length > 0 ? field.choices[0].value : '';
      return [field, new Field('reason', '删除原因', 'multiline')];
    }
    case 'issue': return [note(), new Field('ownerId', '协商责任人账号 ID', 'text', order.ownerId), new Field('dueAt', '下次处理期限', 'date', future(3))];
    case 'obligation': return [new Field('title', '必须办理事项'), new Field('ownerId', '责任人账号 ID', 'text', order.ownerId), new Field('dueAt', '办理期限', 'date', future(3))];
    case 'resolve_issue':
    case 'resolve_obligation': {
      const field = new Field(action === 'resolve_issue' ? 'issueId' : 'obligationId', '选择本次处理事项', 'choice');
      const records = action === 'resolve_issue' ? order.issues : order.obligations;
      records.filter((item: Task) => !item.resolved).forEach((item: Task) => field.choices.push(new Choice(item.id, item.title || item.note)));
      field.value = field.choices.length > 0 ? field.choices[0].value : '';
      return [field, note()];
    }
    case 'failure':
      return [choice('reason', '真实停止履约结果', ['customer_refused', 'company_refused', 'unrepairable', 'cancelled', 'negotiated'], ['客户拒修', '公司拒修', '确认不能修', '批准取消', '按协商停止']), note(),
        new Field('amountCents', '批准最终应收（元）', 'money', (order.summary.receivableCents / 100).toFixed(2)), new Field('returnRequired', '是否需要退回客户设备', 'bool', 'true')];
    case 'visit': return [new Field('plannedAt', '预计到场时间', 'date', future(1)), new Field('feeMemo', '内部费用备忘', 'multiline', '', false), note()];
    case 'start_visit': return [new Field('visitId', '待到场行程 ID')];
    case 'outsource': return [new Field('provider', '一手外包责任主体'), new Field('contact', '联系人', 'text', '', false), new Field('destination', '设备去向', 'text', '', false), note()];
    case 'cost': return [choice('category', '实际成本类别', ['parts', 'labor', 'transport', 'outsource', 'other'], ['配件', '人工', '交通物流', '一手外包', '其他获批费用']), new Field('amountCents', '成本金额（元）', 'money'), note()];
    case 'approve_cost': return [new Field('costId', '待审核成本 ID'), note()];
    case 'commission': return [new Field('person', '提成归属人'), new Field('amountCents', '提成金额（元）', 'money'), note()];
    case 'settle_commission': return [new Field('commissionId', '待结算提成 ID'), note()];
    case 'reopen': return [new Field('reason', '重开原因与批准依据', 'multiline')];
    case 'rework': return [new Field('free', '已核实为有效质保范围内免费返修', 'bool', 'true'), note()];
    case 'loan': return [new Field('orderId', '关联工单 ID（独立借用可留空）', 'text', '', false), new Field('partId', '配件 ID'), new Field('quantity', '借出数量', 'integer', '1'), new Field('borrowerId', '有效工程师账号 ID'), new Field('dueAt', '归还期限', 'date', future(7)), note()];
    case 'purchase': return [new Field('supplier', '供应商名称'), new Field('partId', '采购配件 ID'), new Field('quantity', '采购数量', 'integer', '1'), new Field('unitCents', '单价（元）', 'money'), note()];
    case 'return': return [new Field('quantity', '本次归还数量', 'integer', '1'), choice('condition', '实物情况', ['good', 'quarantine'], ['良品回库', '隔离待检'])];
    case 'consume':
    case 'dispose': return [new Field('quantity', '批准数量', 'integer', '1'), new Field('reason', '批准人与实际处置依据', 'multiline')];
    case 'transfer': return [new Field('quantity', '转出数量', 'integer', '1'), new Field('ownerId', '独立跟踪责任人 ID'), new Field('dueAt', '后续处理期限', 'date', future(7)), new Field('reason', '批准与转出依据', 'multiline')];
    case 'receive_purchase': return [new Field('quantity', '本次实际收货数量', 'integer', '1'), note()];
    default: return [note()];
  }
}

export function collectPayload(fields: Field[], action: string): Payload {
  const payload: Payload = {};
  fields.forEach((field: Field) => {
    const value = field.value.trim();
    if (!value && field.required) {
      throw new ClientError('请填写：' + field.label);
    }
    if (field.kind === 'money') {
      if (!/^\d+(\.\d{1,2})?$/.test(value)) {
        throw new ClientError(field.label + '须为非负金额，最多两位小数。');
      }
      const parts = value.split('.');
      const cents = Number(parts[0]) * 100 + Number((parts[1] || '').padEnd(2, '0'));
      if (!Number.isSafeInteger(cents) || cents > 100000000000 || (['cash', 'invoice', 'cost', 'commission'].indexOf(action) >= 0 && cents <= 0)) {
        throw new ClientError('金额超出允许范围。');
      }
      payload[field.key] = cents;
    } else if (field.kind === 'integer') {
      if (!/^\d+$/.test(value) || !Number.isSafeInteger(Number(value)) || Number(value) <= 0) {
        throw new ClientError(field.label + '须为正整数。');
      }
      payload[field.key] = Number(value);
    } else if (field.kind === 'bool') {
      payload[field.key] = value === 'true';
    } else if (field.kind === 'files') {
      payload[field.key] = value.split(/[,，]/).map((item: string) => item.trim()).filter((item: string) => item.length > 0);
    } else {
      if (field.kind === 'date' && (!/T.*(Z|[+-]\d{2}:\d{2})$/.test(value) || isNaN(Date.parse(value)))) {
        throw new ClientError('时间必须包含时区，例如 2026-10-30T10:30:00+08:00。');
      }
      payload[field.key] = value;
    }
  });
  if (action === 'quote') {
    const total = payload['amountCents'] as number;
    const prepay = payload['prepayCents'] as number;
    const months = payload['warrantyMonths'] as number;
    if (prepay > total || months > 60 || (payload['startRequiresPrepayment'] === true && prepay <= 0)) {
      throw new ClientError('预付款不得超过总额；先款开修须有正数预付；质保为1～60月。');
    }
  }
  if (action === 'documents' && payload['sent'] === true && (!payload['recipient'] || payload['prepared'] !== true)) {
    throw new ClientError('资料实际发送须已齐备，并填写接收对象。');
  }
  if (action === 'evidence') {
    payload['kind'] = 'text';
  }
  return payload;
}
