// Created by Jobs on 2026年10月30日，星期五.
// 所有金额是整数分；服务端摘要与完整详情分别验证。
export type Payload = Record<string, string | number | boolean | string[]>;

export interface LoginInput {
  username: string;
  password: string;
}

export interface ActionRequest {
  type: string;
  version: number;
  payload: Payload;
}

export class Actor {
  id: string = '';
  name: string = '';
  role: string = '';
  companyId: string = '';
  status: string = 'active';
  authVersion: number = 1;
}

export class LoginResponse {
  token: string = '';
  actor: Actor = new Actor();
}

export class Summary {
  nextTask: string = '';
  missing: string[] = [];
  remainingCents: number = 0;
  collectedCents: number = 0;
  receivableCents: number = 0;
  pendingCashCents: number = 0;
  invoiceCents: number = 0;
  documentStatus: string = '';
  invoiceStatus: string = '';
  warrantyLabel: string = '';
}

export class Quote {
  version: number = 0;
  amountCents: number = 0;
  prepayCents: number = 0;
  warrantyMonths: number = 12;
  paymentTerms: string = 'cash';
  startRequiresPrepayment: boolean = false;
  validUntil: string = '';
  description: string = '';
  approved: boolean = false;
  signed: boolean = false;
  autoAccept: boolean = false;
}

export class Evidence {
  id: string = '';
  name: string = '';
  kind: string = 'text';
  mime: string = '';
  text: string = '';
  deleted: boolean = false;
  uploaderId: string = '';
}

export class Cash {
  id: string = '';
  amountCents: number = 0;
  kind: string = 'receipt';
  purpose: string = '';
  receipt: string = '';
  occurredAt: string = '';
  verified: boolean = false;
  handedOver: boolean = false;
}

export class Task {
  id: string = '';
  title: string = '';
  note: string = '';
  ownerId: string = '';
  dueAt: string = '';
  resolved: boolean = false;
}

export class Order {
  id: string = '';
  number: string = '';
  version: number = 1;
  type: string = 'mail';
  customer: string = '';
  customerId: string = '';
  companyId: string = '';
  project: string = '';
  device: string = '';
  description: string = '';
  status: string = 'pending_intake';
  outcome: string = '';
  ownerId: string = '';
  assigneeId: string = '';
  createdAt: string = '';
  updatedAt: string = '';
  remark: string = '';
  customerNote: string = '';
  originalOrderId: string = '';
  isSummary: boolean = false;
  allowedActions: string[] = [];
  quote: Quote = new Quote();
  summary: Summary = new Summary();
  cash: Cash[] = [];
  evidence: Evidence[] = [];
  issues: Task[] = [];
  obligations: Task[] = [];
}

export class Part {
  id: string = '';
  name: string = '';
  sku: string = '';
  available: number = 0;
  quarantine: number = 0;
}

export class Loan {
  id: string = '';
  version: number = 1;
  orderId: string = '';
  partId: string = '';
  partName: string = '';
  quantity: number = 0;
  returnedGood: number = 0;
  returnedQuarantine: number = 0;
  consumed: number = 0;
  disposed: number = 0;
  outstanding: number = 0;
  borrowerId: string = '';
  dueAt: string = '';
  note: string = '';
}

export class Purchase {
  id: string = '';
  version: number = 1;
  supplier: string = '';
  partId: string = '';
  quantity: number = 0;
  received: number = 0;
  unitCents: number = 0;
  note: string = '';
}

export class OrderPage {
  page: number = 1;
  pageSize: number = 30;
  total: number = 0;
  totalPages: number = 1;
}

export class OrderResult extends OrderPage {
  items: Order[] = [];
}

export class Snapshot {
  actor: Actor = new Actor();
  orders: Order[] = [];
  orderPage: OrderPage = new OrderPage();
  parts: Part[] = [];
  loans: Loan[] = [];
  purchases: Purchase[] = [];
}

export class ClientError extends Error {
  code: number;
  uncertain: boolean;
  constructor(message: string, code: number = 0, uncertain: boolean = false) {
    super(message);
    this.code = code;
    this.uncertain = uncertain;
  }
}

export const STATES: string[] = [
  'pending_intake', 'pending_arrangement', 'diagnosis_quotation',
  'pending_customer_confirmation', 'pending_execution', 'repairing',
  'pending_quality_check', 'pending_delivery', 'pending_acceptance',
  'settling', 'pending_completion', 'completed'
];
export const STATE_TITLES: string[] = [
  '待受理', '待安排', '检测／报价', '待客户确认', '待执行', '维修中',
  '待质检', '待交付', '待验收', '结算中', '待完结', '已完结'
];

export function stateTitle(status: string): string {
  const index = STATES.indexOf(status);
  return index >= 0 ? STATE_TITLES[index] : status;
}

export function money(cents: number): string {
  return '¥' + (cents / 100).toFixed(2);
}

export function integer(value: number, minimum: number = 0): boolean {
  return Number.isSafeInteger(value) && value >= minimum;
}

export function sameActor(a: Actor, b: Actor): boolean {
  return !!a && !!b && a.id === b.id && a.role === b.role &&
    a.companyId === b.companyId && a.authVersion === b.authVersion && b.status === 'active';
}

export function validateActor(actor: Actor): void {
  if (!actor || !actor.id || !actor.name || !actor.role ||
    actor.status !== 'active' || !integer(actor.authVersion, 1)) {
    throw new ClientError('账号资料不完整，请重新登录。');
  }
}

export function validateOrder(order: Order, full: boolean = false): void {
  if (!order || !order.id || !order.number || !integer(order.version, 1) ||
    STATES.indexOf(order.status) < 0 || !order.device || !order.customer ||
    !order.summary || !Array.isArray(order.summary.missing) ||
    !integer(order.summary.remainingCents) || !integer(order.summary.receivableCents) ||
    !integer(order.summary.collectedCents) || !order.quote ||
    !integer(order.quote.version) || !integer(order.quote.amountCents) ||
    !Array.isArray(order.allowedActions) || (full && order.isSummary === true)) {
    throw new ClientError('工单响应不完整，已保留当前页面，请重新加载。');
  }
  if (full) {
    if (!Array.isArray(order.cash) || !Array.isArray(order.evidence) ||
      !Array.isArray(order.issues) || !Array.isArray(order.obligations)) {
      throw new ClientError('工单明细缺失，请重新加载。');
    }
    order.cash.forEach((cash: Cash) => {
      if (!cash || !cash.id || !integer(cash.amountCents, 1) ||
        (cash.kind !== 'receipt' && cash.kind !== 'refund') ||
        typeof cash.verified !== 'boolean' || typeof cash.handedOver !== 'boolean') {
        throw new ClientError('现金明细不完整，不能采用此响应。');
      }
    });
  }
}

export function validateSnapshot(snapshot: Snapshot, actor: Actor): void {
  if (!snapshot || !sameActor(actor, snapshot.actor) || !Array.isArray(snapshot.orders) ||
    !Array.isArray(snapshot.parts) || !Array.isArray(snapshot.loans) || !Array.isArray(snapshot.purchases) ||
    !snapshot.orderPage || !integer(snapshot.orderPage.total)) {
    throw new ClientError('概览响应与当前身份不匹配。');
  }
  snapshot.orders.forEach((order: Order) => validateOrder(order));
  snapshot.parts.forEach((part: Part) => {
    if (!part || !part.id || !part.name || !integer(part.available) || !integer(part.quarantine)) {
      throw new ClientError('库存响应不完整。');
    }
  });
  snapshot.loans.forEach((loan: Loan) => validateLoan(loan));
  snapshot.purchases.forEach((purchase: Purchase) => validatePurchase(purchase));
}

export function validateLoan(loan: Loan): void {
  if (!loan || !loan.id || !loan.partId || !loan.borrowerId || !integer(loan.version, 1) ||
    !integer(loan.quantity, 1) || !integer(loan.returnedGood) || !integer(loan.returnedQuarantine) ||
    !integer(loan.consumed) || !integer(loan.disposed) || !integer(loan.outstanding) ||
    loan.returnedGood + loan.returnedQuarantine + loan.consumed + loan.disposed + loan.outstanding !== loan.quantity) {
    throw new ClientError('借还响应数量不守恒或缺少明细。');
  }
}

export function validatePurchase(purchase: Purchase): void {
  if (!purchase || !purchase.id || !purchase.partId || !integer(purchase.version, 1) ||
    !integer(purchase.quantity, 1) || !integer(purchase.received) ||
    purchase.received > purchase.quantity || !integer(purchase.unitCents)) {
    throw new ClientError('采购响应不完整。');
  }
}

export function newKey(): string {
  return 'harmony-' + Date.now().toString(36) + '-' + Math.random().toString(36).slice(2) + Math.random().toString(36).slice(2);
}

export function validateSignaturePNG(bytes: Uint8Array): void {
  const header: number[] = [137, 80, 78, 71, 13, 10, 26, 10];
  if (bytes.length < 24 || header.some((value: number, index: number) => bytes[index] !== value) ||
    bytes[12] !== 73 || bytes[13] !== 72 || bytes[14] !== 68 || bytes[15] !== 82) {
    throw new ClientError('签署画布未生成有效 PNG，请重写后再试。');
  }
  const width = bytes[16] * 16777216 + bytes[17] * 65536 + bytes[18] * 256 + bytes[19];
  const height = bytes[20] * 16777216 + bytes[21] * 65536 + bytes[22] * 256 + bytes[23];
  if (width < 8 || width > 1600 || height < 8 || height > 800) {
    throw new ClientError('签名图像须为8～1600像素宽、8～800像素高，请在标准签署区域重写。');
  }
}

export function normalizeBase(value: string): string {
  const base = value.trim().replace(/\/+$/, '').replace(/\/api\/v38$/, '');
  if (!/^https?:\/\/(?:[a-z0-9._-]+|\[[a-f0-9:]+\])(?::\d{1,5})?$/i.test(base)) {
    throw new ClientError('服务地址填写 http(s)://主机:端口，不含账号、路径或查询。');
  }
  return base;
}
