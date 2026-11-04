/* Jobs · V3.8 工作台的合成样例与离线演示计算。金额始终使用整数分。 */
(function (root) {
  "use strict";
  const states = {
    pending_intake: "待受理",
    pending_arrangement: "待安排",
    diagnosis_quotation: "检测 / 报价中",
    pending_customer_confirmation: "待客户确认",
    pending_execution: "待执行",
    repairing: "维修中",
    pending_quality_check: "待质检",
    pending_delivery: "待交付",
    pending_acceptance: "待验收",
    settling: "结算中",
    pending_completion: "待完结确认",
    completed: "已完结",
  };
  const roles = {
    admin: "系统管理员",
    dispatcher: "客服 / 调度",
    engineer: "自有工程师",
    outsource: "一手外包",
    warehouse: "仓库管理员",
    qc: "质检员",
    finance: "财务",
    customer: "客户经办人",
    supplier: "供应商",
  };
  const actionNames = {
    handover_contact: "交接客户经办人",
    review_acceptance: "核实停机期间线下异议",
    intake: "确认受理",
    receive: "确认公司收件",
    assign: "安排 / 改派",
    diagnose: "开始检测 / 询价",
    report: "提交检测 / 询价报告",
    quote: "拟定报价",
    approve_quote: "审核并发送报价",
    sign_quote: "签署报价与维修确认",
    start: "确认开始维修",
    finish: "提交维修完工",
    qc: "确认公司质检",
    stock_ready: "销售备货 / 出库",
    dispatch: "登记实际发货",
    deliver: "确认客户签收 / 交接",
    accept: "独立签署最终验收",
    requirements: "确认资料与开票约定",
    documents: "制作 / 发送付款资料",
    cash: "登记现金收款 / 退款",
    verify_cash: "财务核实现金",
    handover_cash: "确认内部现金交接",
    invoice: "登记真实发票",
    void_invoice: "红冲 / 作废原票",
    adjust_receivable: "批准调整应收",
    remark: "编辑工单备注",
    evidence: "归档证据",
    delete_evidence: "删除本人证据",
    issue: "登记异议 / 协商",
    resolve_issue: "记录协商处理结果",
    failure: "批准停止履约",
    obligation: "新增内部余项",
    resolve_obligation: "办理内部余项",
    visit: "安排上门行程",
    start_visit: "确认实际到场",
    outsource: "登记外包 / 后续流向",
    cost: "登记内部成本",
    approve_cost: "审核成本",
    commission: "登记提成",
    settle_commission: "核实提成结算",
    complete: "核对并整单完结",
    reopen: "批准重开办理",
    rework: "创建关联返修单",
  };
  const permissions = {
    admin: [
      "handover_contact",
      "review_acceptance",
      "intake",
      "receive",
      "assign",
      "diagnose",
      "report",
      "quote",
      "approve_quote",
      "start",
      "finish",
      "qc",
      "stock_ready",
      "dispatch",
      "deliver",
      "requirements",
      "documents",
      "cash",
      "verify_cash",
      "handover_cash",
      "invoice",
      "void_invoice",
      "adjust_receivable",
      "remark",
      "evidence",
      "delete_evidence",
      "issue",
      "resolve_issue",
      "failure",
      "obligation",
      "resolve_obligation",
      "visit",
      "start_visit",
      "outsource",
      "cost",
      "approve_cost",
      "commission",
      "settle_commission",
      "complete",
      "reopen",
      "rework",
    ],
    dispatcher: [
      "handover_contact",
      "review_acceptance",
      "intake",
      "assign",
      "quote",
      "approve_quote",
      "requirements",
      "documents",
      "cash",
      "remark",
      "evidence",
      "delete_evidence",
      "issue",
      "resolve_issue",
      "failure",
      "obligation",
      "resolve_obligation",
      "visit",
      "outsource",
      "commission",
      "complete",
      "rework",
    ],
    engineer: [
      "diagnose",
      "report",
      "quote",
      "start",
      "finish",
      "cash",
      "remark",
      "evidence",
      "delete_evidence",
      "issue",
      "visit",
      "start_visit",
      "cost",
    ],
    outsource: [
      "diagnose",
      "report",
      "quote",
      "start",
      "finish",
      "dispatch",
      "evidence",
      "delete_evidence",
      "issue",
      "outsource",
    ],
    warehouse: [
      "receive",
      "stock_ready",
      "dispatch",
      "deliver",
      "remark",
      "evidence",
      "delete_evidence",
      "obligation",
      "resolve_obligation",
    ],
    qc: ["qc", "remark", "evidence", "delete_evidence", "issue"],
    finance: [
      "requirements",
      "documents",
      "cash",
      "verify_cash",
      "handover_cash",
      "invoice",
      "void_invoice",
      "adjust_receivable",
      "remark",
      "evidence",
      "delete_evidence",
      "issue",
      "resolve_issue",
      "cost",
      "approve_cost",
      "commission",
      "settle_commission",
    ],
    customer: [
      "sign_quote",
      "accept",
      "evidence",
      "delete_evidence",
      "issue",
      "rework",
    ],
    supplier: [],
  };
  function cents(value, allowZero = true) {
    const input = String(value ?? "").trim();
    if (!/^\d{1,9}(?:\.\d{1,2})?$/.test(input))
      throw new Error("金额请使用最多两位小数的十进制数字。");
    const [whole, fraction = ""] = input.split(".");
    const amount = Number(whole) * 100 + Number(fraction.padEnd(2, "0"));
    if (
      !Number.isSafeInteger(amount) ||
      amount > 100000000000 ||
      (!allowZero && amount <= 0)
    )
      throw new Error("金额超出允许范围。");
    return amount;
  }
  function integer(value) {
    if (!/^[1-9]\d{0,6}$/.test(String(value)))
      throw new Error("数量必须是正整数。");
    return Number(value);
  }
  function uid(prefix) {
    return (
      "demo-" +
      prefix +
      "-" +
      Date.now().toString(36) +
      "-" +
      Math.random().toString(36).slice(2, 7)
    );
  }
  function addMonths(value, months) {
    const original = new Date(Date.parse(value) + 8 * 3600000),
      year = original.getUTCFullYear(),
      month = original.getUTCMonth(),
      day = original.getUTCDate();
    const lastDay = new Date(
      Date.UTC(year, month + months + 1, 0),
    ).getUTCDate();
    original.setUTCDate(1);
    original.setUTCMonth(month + months);
    original.setUTCDate(Math.min(day, lastDay));
    return new Date(original.getTime() - 8 * 3600000).toISOString();
  }
  function chinaDay(value) {
    const instant = typeof value === "number" ? value : Date.parse(value);
    return Number.isFinite(instant)
      ? new Date(instant + 8 * 3600000).toISOString().slice(0, 10)
      : "";
  }
  function quoteDeadline(value) {
    return Date.parse(
      /^\d{4}-\d{2}-\d{2}$/.test(value)
        ? value + "T23:59:59.999+08:00"
        : value,
    );
  }
  function loanBlockingQuantity(loan) {
    const outstanding = Number.isSafeInteger(loan.outstanding)
      ? loan.outstanding
      : loan.quantity -
        loan.returnedGood -
        loan.returnedQuarantine -
        loan.consumed -
        loan.disposed;
    const transfers = Array.isArray(loan.transfers)
      ? loan.transfers
      : loan.transfer
        ? [loan.transfer]
        : loan.transferred
          ? [{ quantity: outstanding }]
          : [];
    const transferred = transfers
      .filter(
        (item) =>
          !item.resolved &&
          Number.isSafeInteger(item.quantity) &&
          item.quantity > 0,
      )
      .reduce((sum, item) => sum + item.quantity, 0);
    return Math.max(0, outstanding - transferred);
  }
  function derive(order, loans = []) {
    const quote = order.quote || {};
    const cash = order.cash || [];
    const receivableCents = Number.isSafeInteger(order.receivableCents)
      ? order.receivableCents
      : quote.amountCents || 0;
    const collectedCents = cash
      .filter((c) => c.verified && !c.voided)
      .reduce(
        (n, c) => n + (c.kind === "refund" ? -c.amountCents : c.amountCents),
        0,
      );
    const pendingCashCents = cash
      .filter((c) => !c.verified && !c.voided)
      .reduce((n, c) => n + c.amountCents, 0);
    const validInvoices = (order.invoices || []).filter((i) => !i.voided);
    const invoiceCents = validInvoices.reduce((n, i) => n + i.amountCents, 0);
    const documents = order.documents || {};
    const deleted = (id) =>
      !(order.evidence || []).some((e) => e.id === id && !e.deleted);
    const documentStatus =
      documents.requirement === "none"
        ? "not_required"
        : documents.requirement !== "required"
          ? "unknown"
          : documents.sent &&
              documents.prepared &&
              (documents.files || []).length &&
              !(documents.files || []).some(deleted)
            ? "sent"
            : documents.sent
              ? "supplement"
              : documents.prepared
                ? "prepared"
                : "required";
    const invoiceFilesValid =
      validInvoices.length &&
      validInvoices.every(
        (i) => (i.files || []).length && !i.files.some(deleted),
      );
    const invoiceStatus =
      order.invoiceRequirement === "none"
        ? "not_required"
        : order.invoiceRequirement !== "required"
          ? "unknown"
          : invoiceCents > (order.invoiceDueCents || 0)
            ? "over"
            : invoiceCents === (order.invoiceDueCents || 0) && invoiceFilesValid
              ? "complete"
              : invoiceCents
                ? "partial"
                : "pending";
    const missing = [];
    if (!order.outcome) missing.push("有效履约结果尚未明确");
    if (!["not_required", "sent"].includes(documentStatus))
      missing.push(
        "付款资料" +
          (documentStatus === "prepared"
            ? "已做未送"
            : documentStatus === "unknown"
              ? "要求待确认"
              : "待齐备"),
      );
    if (!["not_required", "complete"].includes(invoiceStatus))
      missing.push(
        "票据" +
          (invoiceStatus === "unknown"
            ? "要求待确认"
            : invoiceStatus === "over"
              ? "超开待核实"
              : "待办理"),
      );
    const remainingCents = Math.max(0, receivableCents - collectedCents),
      overpaidCents = Math.max(0, collectedCents - receivableCents);
    if (remainingCents) missing.push("仍有客户待收款");
    if (overpaidCents) missing.push("超收款尚未处理");
    if (pendingCashCents) missing.push("现金待财务核实");
    if (cash.some((c) => c.verified && !c.handedOver && c.kind !== "refund"))
      missing.push("内部现金交接待完成");
    (order.issues || [])
      .filter((i) => !i.resolved)
      .forEach(() => missing.push("协商事项未解决"));
    (order.obligations || [])
      .filter((i) => !i.resolved)
      .forEach((i) => missing.push(i.title));
    (order.costs || [])
      .filter((i) => !i.approved)
      .forEach(() => missing.push("成本待审核"));
    (order.commissions || [])
      .filter((i) => !i.settled)
      .forEach(() => missing.push("提成待结算"));
    loans
      .filter(
        (l) => l.orderId === order.id && loanBlockingQuantity(l) > 0,
      )
      .forEach(() => missing.push("关联借用配件未清"));
    const stageTask = {
      pending_intake: "客服确认受理并安排负责人",
      pending_arrangement: "安排收件 / 派单 / 到访",
      diagnosis_quotation: quote.amountCents
        ? "公司审核并发送报价"
        : "检测 / 询价并拟定报价",
      pending_customer_confirmation: "客户签署当前版本合并确认单",
      pending_execution:
        order.type === "sale" ? "仓库备货并核对出库条件" : "工程师确认实际开修",
      repairing: "提交维修完工报告",
      pending_quality_check: "公司测试 / 质检，核实回寄",
      pending_delivery: "实际发货并确认客户签收",
      pending_acceptance: "客户独立签署最终验收",
      completed: "有效质保继续，按需登记售后",
    };
    const warrantyEnd = order.warranty?.endsAt || order.warranty?.endAt;
    return {
      documentStatus,
      invoiceStatus,
      collectedCents,
      receivableCents,
      remainingCents,
      overpaidCents,
      pendingCashCents,
      invoiceCents,
      missing: [...new Set(missing)],
      nextTask:
        stageTask[order.status] ||
        (missing.length ? missing[0] : "负责人核对整单完结"),
      warrantyLabel: warrantyEnd
        ? chinaDay(warrantyEnd) >= chinaDay(Date.now())
          ? "质保中"
          : "质保已到期"
        : "质保未起算",
    };
  }
  function refreshOrder(order, loans = []) {
    order.summary = derive(order, loans);
    if (order.outcome && order.status !== "completed") {
      order.status = order.summary.missing.length
        ? "settling"
        : "pending_completion";
      order.summary = derive(order, loans);
    }
    return order;
  }
  function baseOrder(
    id,
    number,
    customer,
    device,
    status,
    amount,
    type = "mail",
  ) {
    return {
      id,
      number,
      version: 1,
      type,
      customer,
      customerId: "customer",
      companyId: "company-demo",
      project: "锦绣物业 · 设备维保",
      device,
      description: "合成业务样例，请勿输入真实客户资料。",
      status,
      outcome: ["settling", "pending_completion", "completed"].includes(status)
        ? "accepted"
        : "",
      ownerId: "dispatcher",
      assigneeId: "engineer",
      createdAt: "2026-10-10T02:30:00Z",
      updatedAt: "2026-10-13T01:30:00Z",
      remark: "合成演示记录，不代表真实业务",
      customerNote: "",
      quote: {
        version: 1,
        amountCents: amount,
        description: "检测、配件更换与维修服务",
        warrantyMonths: 3,
        paymentTerms: "credit",
        prepayCents: 0,
        approved: !["pending_intake", "diagnosis_quotation"].includes(status),
        signed: ![
          "pending_intake",
          "pending_arrangement",
          "diagnosis_quotation",
          "pending_customer_confirmation",
        ].includes(status),
        validUntil: "2026-11-01",
        autoAccept: false,
      },
      documents: {
        requirement: "required",
        reason: "物业项目付款约定",
        version: 1,
        prepared: false,
        sent: false,
        files: [],
      },
      invoiceRequirement: "required",
      invoiceReason: "企业开票约定",
      invoiceDueCents: amount,
      invoices: [],
      cash: [],
      evidence: [],
      events: [
        {
          id: "demo-event-" + id,
          type: "created",
          note: "客服登记合成演示工单",
          actorId: "dispatcher",
          createdAt: "2026-10-10T02:30:00Z",
        },
      ],
      visits: [],
      outsource: [],
      costs: [],
      commissions: [],
      issues: [],
      obligations: [],
      warranty: {},
      originalOrderId: "",
    };
  }
  function seed() {
    const a = baseOrder(
      "demo-001",
      "WX-202610-001",
      "锦绣花园物业",
      "地下泵房 · 变频控制柜",
      "settling",
      1000000,
    );
    a.description = "地下泵房变频控制柜异常报警，检查更换控制模块并完成联调。";
    a.documents.prepared = true;
    a.documents.files = ["demo-report-1"];
    a.cash = [
      {
        id: "demo-cash-1",
        amountCents: 300000,
        kind: "receipt",
        purpose: "部分维修款",
        receipt: "合成现金收据 #001",
        collector: "dispatcher",
        occurredAt: "2026-10-12T03:00:00Z",
        verified: true,
        handedOver: true,
      },
    ];
    a.evidence = [
      {
        id: "demo-report-1",
        name: "维修检测报告（样例文本）",
        kind: "text",
        text: "已完成控制模块更换、联调测试及公司质检。本条为合成样例。",
        stage: "repair",
        uploaderId: "engineer",
        createdAt: "2026-10-11T03:30:00Z",
        deleted: false,
      },
    ];
    a.warranty = { startAt: "2026-10-12", endAt: "2027-01-12" };
    const b = baseOrder(
      "demo-002",
      "WX-202610-002",
      "新城国际物业",
      "消防系统 · 电源模块",
      "settling",
      100000,
    );
    b.documents.prepared = true;
    b.documents.sent = true;
    b.documents.recipient = "物业授权经办人";
    b.documents.files = ["demo-package-2"];
    b.evidence = [
      {
        id: "demo-package-2",
        name: "付款资料包（样例说明）",
        kind: "text",
        text: "资料包内含确认单、维修报告和独立验收记录。合成演示。",
        stage: "finance",
        uploaderId: "dispatcher",
        createdAt: "2026-10-12T01:00:00Z",
        deleted: false,
      },
    ];
    b.cash = [
      {
        id: "demo-cash-2",
        amountCents: 100000,
        kind: "receipt",
        collector: "dispatcher",
        verified: true,
        handedOver: true,
        purpose: "维修尾款",
        receipt: "合成收据",
        occurredAt: "2026-10-12T03:00:00Z",
      },
    ];
    b.invoices = [
      {
        id: "demo-invoice-2",
        number: "DEMO-INVOICE-600",
        amountCents: 60000,
        files: ["demo-package-2"],
        voided: false,
      },
    ];
    const c = baseOrder(
      "demo-003",
      "WX-202610-003",
      "个人客户 · 陈先生（虚构）",
      "家用空调 · 控制主板",
      "pending_completion",
      50000,
      "onsite",
    );
    c.project = "个人散客";
    c.documents = {
      requirement: "none",
      reason: "客户无需企业报销资料",
      version: 1,
      prepared: false,
      sent: false,
      files: [],
    };
    c.invoiceRequirement = "none";
    c.invoiceReason = "已确认无需开票";
    c.cash = [
      {
        id: "demo-cash-3",
        amountCents: 50000,
        kind: "receipt",
        collector: "engineer",
        verified: true,
        handedOver: true,
        purpose: "维修款",
        receipt: "合成收据",
        occurredAt: "2026-10-12T03:00:00Z",
      },
    ];
    c.warranty = { startAt: "2026-10-12", endAt: "2027-01-12" };
    const d = baseOrder(
      "demo-004",
      "WX-202610-004",
      "春申景城物业",
      "电梯机房 · 散热风扇",
      "repairing",
      260000,
      "onsite",
    );
    d.visits = [
      {
        id: "demo-visit-4",
        plannedAt: "2026-10-14T06:00:00Z",
        note: "现场复检并安装新配件",
        feeMemo: "交通费与工时实报待审核",
        started: false,
      },
    ];
    const e = baseOrder(
      "demo-005",
      "XS-202610-005",
      "江南商务中心",
      "销售 · 消防备用电源 × 4",
      "pending_customer_confirmation",
      380000,
      "sale",
    );
    e.quote.description =
      "消防备用电源 4 套，含税单价 950 元，公司审核通过，等待客户一次签署销售报价确认单。";
    const f = baseOrder(
      "demo-006",
      "WX-202610-006",
      "云庭公馆物业",
      "监控主机 · 存储模块",
      "pending_intake",
      0,
    );
    const orders = [a, b, c, d, e, f];
    const parts = [
      {
        id: "demo-part-1",
        name: "消防备用电源",
        sku: "PS-24V-20A",
        available: 18,
        quarantine: 1,
      },
      {
        id: "demo-part-2",
        name: "变频控制模块",
        sku: "VFD-CTRL-A",
        available: 8,
        quarantine: 0,
      },
      {
        id: "demo-part-3",
        name: "机房散热风扇",
        sku: "FAN-120-24V",
        available: 25,
        quarantine: 2,
      },
    ];
    const loans = [
      {
        id: "demo-loan-1",
        version: 1,
        orderId: d.id,
        partId: "demo-part-3",
        partName: "机房散热风扇",
        quantity: 5,
        returnedGood: 2,
        returnedQuarantine: 1,
        consumed: 1,
        disposed: 0,
        outstanding: 1,
        borrowerId: "engineer",
        dueAt: "2026-10-15",
        note: "合成：测试临时替换",
      },
    ];
    orders.forEach((o) => (o.summary = derive(o, loans)));
    return {
      actor: {
        id: "dispatcher",
        role: "dispatcher",
        name: "演示客服",
        displayName: "演示客服",
      },
      states,
      orders,
      parts,
      loans,
      purchases: [],
      settings: {
        companyAddress: "公司寄送地址待配置",
        requestTimeoutMs: 2500,
      },
    };
  }
  function createOrder(payload) {
    const order = baseOrder(
      uid("order"),
      "DEMO-" + Date.now().toString().slice(-8),
      payload.customer,
      payload.device,
      "pending_intake",
      0,
      payload.type,
    );
    Object.assign(order, payload, {
      id: order.id,
      number: order.number,
      status: "pending_intake",
      version: 1,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
      outcome: "",
      receivableCents: 0,
      invoiceDueCents: 0,
      quote: {
        version: 0,
        amountCents: 0,
        warrantyMonths: 3,
        paymentTerms: "cash",
        prepayCents: 0,
        startRequiresPrepayment: false,
        approved: false,
        signed: false,
      },
      documents: {
        requirement: "unknown",
        reason: "",
        version: 1,
        prepared: false,
        sent: false,
        files: [],
      },
      invoiceRequirement: "unknown",
    });
    return refreshOrder(order);
  }
  function apply(order, type, payload, actor, data) {
    if (!(permissions[actor.role] || []).includes(type))
      throw new Error("当前演示角色无权办理该动作。");
    const o = structuredClone(order),
      now = new Date().toISOString();
    function must(condition, message) {
      if (!condition) throw new Error(message);
    }
    function requireStatus(...s) {
      must(s.includes(o.status), "该阶段不能办理此动作，请重新核对工单。");
    }
    function noIssues() {
      must(
        !(o.issues || []).some((issue) => !issue.resolved),
        "存在未解决异议，请先办理协商结果。",
      );
    }
    function currentQuote() {
      must(
        quoteDeadline(o.quote.validUntil) > Date.now(),
        "报价接受期限已过或无效，请重新制作并审核。",
      );
    }
    switch (type) {
      case "intake":
        requireStatus("pending_intake");
        o.ownerId = payload.ownerId;
        o.assigneeId = payload.assigneeId;
        o.status = "pending_arrangement";
        break;
      case "receive":
        requireStatus("pending_arrangement");
        break;
      case "handover_contact":
        must(payload.reason, "交接须授权核实依据。");
        o.customerId = payload.customerId;
        break;
      case "assign":
        o.assigneeId = payload.assigneeId;
        break;
      case "diagnose":
        requireStatus("pending_arrangement", "diagnosis_quotation");
        o.status = "diagnosis_quotation";
        break;
      case "quote":
        requireStatus("diagnosis_quotation", "pending_customer_confirmation");
        must(
          payload.startRequiresPrepayment == null ||
            typeof payload.startRequiresPrepayment === "boolean",
          "请选择是否明确约定先款开修。",
        );
        must(
          o.type === "sale" ||
            !payload.startRequiresPrepayment ||
            (Number.isSafeInteger(payload.prepayCents) &&
              payload.prepayCents > 0 &&
              payload.prepayCents <= payload.amountCents),
          "明确约定先款开修须填写不超过报价的正数预付款。",
        );
        o.quote = {
          ...payload,
          startRequiresPrepayment: payload.startRequiresPrepayment === true,
          version: (o.quote?.version || 0) + 1,
          approved: false,
          signed: false,
        };
        o.invoiceDueCents = payload.amountCents;
        o.receivableCents = payload.amountCents;
        o.status = "diagnosis_quotation";
        break;
      case "approve_quote":
        requireStatus("diagnosis_quotation");
        must(o.quote.amountCents > 0, "请先拟定报价。");
        currentQuote();
        o.quote.approved = true;
        o.status = "pending_customer_confirmation";
        break;
      case "sign_quote":
        requireStatus("pending_customer_confirmation");
        must(
          o.quote.approved && payload.quoteVersion === o.quote.version,
          "报价版本已变更。",
        );
        currentQuote();
        must(payload.signature, "签名不能为空。");
        o.quote.signed = true;
        o.quote.signer = actor.id;
        o.quote.signedAt = now;
        o.status = "pending_execution";
        break;
      case "start":
        requireStatus("pending_execution");
        must(o.type !== "sale" && o.quote.signed, "需有效维修确认。");
        noIssues();
        must(
          o.quote.startRequiresPrepayment !== true ||
            ((o.quote.prepayCents || 0) > 0 &&
              o.quote.prepayCents <= derive(o, data.loans).collectedCents),
          "约定预付款尚未核实。",
        );
        o.status = "repairing";
        break;
      case "finish":
        requireStatus("repairing");
        o.status = "pending_quality_check";
        break;
      case "qc":
        requireStatus("pending_quality_check");
        o.status = payload.passed ? "pending_delivery" : "pending_execution";
        break;
      case "stock_ready":
        requireStatus("pending_execution");
        noIssues();
        must(
          o.type === "sale" && o.quote.signed,
          "销售出库须客户有效签署报价。",
        );
        must(
          (o.quote.prepayCents || 0) <= derive(o, data.loans).collectedCents,
          "约定预付款尚未核实。",
        );
        must(
          o.quote.paymentTerms !== "cash" ||
            derive(o, data.loans).collectedCents >= o.quote.amountCents,
          "现款销售需先核实现金收齐。",
        );
        {
          const part = data.parts.find((p) => p.id === payload.partId);
          must(part && part.available >= payload.quantity, "可用库存不足。");
          part.available -= payload.quantity;
          o.status = "pending_delivery";
        }
        break;
      case "dispatch":
        requireStatus("pending_delivery");
        break;
      case "deliver":
        requireStatus("pending_delivery");
        noIssues();
        o.status = "pending_acceptance";
        o.deliveredAt = payload.deliveredAt || now;
        break;
      case "accept":
        requireStatus("pending_acceptance");
        noIssues();
        must(payload.signature, "最终验收须独立签名。");
        must(payload.passed, "验收不通过请登记异议。");
        o.outcome = "accepted";
        o.status = "settling";
        o.warranty = {
          startsAt: now,
          endsAt: addMonths(now, o.quote.warrantyMonths || 3),
        };
        break;
      case "requirements":
        o.documents.requirement = payload.documentRequirement;
        o.documents.reason = payload.documentReason;
        o.invoiceRequirement = payload.invoiceRequirement;
        o.invoiceReason = payload.invoiceReason;
        o.invoiceDueCents = payload.invoiceDueCents;
        break;
      case "documents":
        must(o.documents.requirement === "required", "先确认本单需付款资料。");
        must(!payload.sent || payload.prepared, "尚未制作不能发送。");
        must(
          !payload.prepared || payload.files.length,
          "制作完成需要有效文件。",
        );
        Object.assign(o.documents, payload);
        break;
      case "cash":
        must(payload.amountCents > 0, "金额必须大于零。");
        o.cash.push({
          ...payload,
          id: uid("cash"),
          collector: actor.id,
          verified: false,
          handedOver: false,
        });
        break;
      case "verify_cash":
        {
          const cash = o.cash.find((c) => c.id === payload.cashId);
          must(cash && !cash.verified, "现金记录不存在或已核实。");
          cash.verified = true;
        }
        break;
      case "handover_cash":
        {
          const cash = o.cash.find((c) => c.id === payload.cashId);
          must(cash && cash.verified, "须先由财务核实收款。");
          cash.handedOver = true;
        }
        break;
      case "invoice":
        must(payload.files.length, "真实票据须有文件。");
        o.invoices.push({ ...payload, id: uid("invoice"), voided: false });
        break;
      case "void_invoice":
        {
          const invoice = o.invoices.find((i) => i.id === payload.invoiceId);
          must(invoice, "未找到原票。");
          invoice.voided = true;
          invoice.voidReason = payload.reason;
        }
        break;
      case "adjust_receivable":
        must(payload.reason, "调整应收需说明依据。");
        o.receivableCents = payload.amountCents;
        break;
      case "remark": {
        const patch = {};
        for (const [name, value] of Object.entries(payload)) {
          const field = name.toLowerCase();
          if (field !== "remark" && field !== "customernote") continue;
          must(value == null || typeof value === "string", "备注字段格式错误。");
          patch[field] = value;
        }
        if (patch.remark != null) {
          const canEditInternal = [
            "admin",
            "dispatcher",
            "finance",
            "engineer",
          ].includes(actor.role);
          must(
            canEditInternal || patch.remark === "",
            "当前角色不能修改内部备注。",
          );
          // Older forms send a redacted empty value; preserve the hidden record.
          if (canEditInternal) o.remark = patch.remark;
        }
        if (patch.customernote != null) o.customerNote = patch.customernote;
        break;
      }
      case "evidence":
        must(
          payload.kind === "text",
          "离线演示仅留存合成文字；文件请连接服务后上传。",
        );
        o.evidence.push({
          ...payload,
          id: uid("evidence"),
          uploaderId: actor.id,
          createdAt: now,
          deleted: false,
        });
        break;
      case "delete_evidence":
        {
          const ev = o.evidence.find((e) => e.id === payload.evidenceId);
          must(
            ev && (ev.uploaderId === actor.id || actor.role === "admin"),
            "只有发布者或管理员可删除。",
          );
          ev.deleted = true;
        }
        break;
      case "issue":
        o.issues.push({ ...payload, id: uid("issue"), resolved: false });
        break;
      case "resolve_issue":
        {
          const issue = o.issues.find((i) => i.id === payload.issueId);
          must(issue, "协商记录不存在。");
          issue.resolved = true;
          issue.resolution = payload.note;
        }
        break;
      case "failure":
        must(payload.note, "停止履约须依据。");
        o.outcome = payload.reason;
        o.status = "settling";
        o.receivableCents = payload.amountCents;
        if (payload.returnRequired)
          o.obligations.push({
            id: uid("return"),
            title: "退回客户设备",
            ownerId: "warehouse",
            resolved: false,
          });
        break;
      case "obligation":
        o.obligations.push({
          ...payload,
          id: uid("obligation"),
          resolved: false,
        });
        break;
      case "resolve_obligation":
        {
          const item = o.obligations.find((i) => i.id === payload.obligationId);
          must(item, "余项不存在。");
          item.resolved = true;
          item.note = payload.note;
        }
        break;
      case "visit":
        {
          const item = o.visits.find((v) => v.id === payload.id);
          if (item) {
            must(
              !item.started || actor.role === "admin",
              "已发生行程只能管理员留依据更正。",
            );
            Object.assign(item, payload);
          } else
            o.visits.push({ ...payload, id: uid("visit"), started: false });
        }
        break;
      case "start_visit":
        {
          const item = o.visits.find((v) => v.id === payload.visitId);
          must(item, "未找到行程。");
          item.started = true;
          item.startedAt = now;
        }
        break;
      case "outsource":
        o.outsource.push({ ...payload, id: uid("outsource") });
        break;
      case "cost":
        o.costs.push({ ...payload, id: uid("cost"), approved: false });
        break;
      case "approve_cost":
        {
          const item = o.costs.find((i) => i.id === payload.costId);
          must(item, "成本记录不存在。");
          item.approved = true;
        }
        break;
      case "commission":
        o.commissions.push({
          ...payload,
          id: uid("commission"),
          settled: false,
        });
        break;
      case "settle_commission":
        {
          const item = o.commissions.find((i) => i.id === payload.commissionId);
          must(item, "提成记录不存在。");
          item.settled = true;
        }
        break;
      case "complete":
        requireStatus("pending_completion");
        must(!derive(o, data.loans).missing.length, "适用完结条件未齐。");
        o.status = "completed";
        break;
      case "reopen":
        requireStatus("completed");
        must(payload.reason, "重开须原因与依据。");
        o.status = "settling";
        o.obligations.push({
          id: uid("review"),
          title: "重开复核：" + payload.reason,
          ownerId: actor.id,
          dueAt: new Date(Date.parse(now) + 48 * 3600000).toISOString(),
          resolved: false,
        });
        break;
      case "rework": {
        must(o.outcome === "accepted", "返修需要原有效验收。");
        must(payload.note, "返修须填写问题与免费／收费判断依据。");
        const child = createOrder({
          type: o.type,
          customer: o.customer,
          customerId: o.customerId,
          companyId: o.companyId,
          project: o.project,
          device: o.device,
          description: payload.note,
          remark: "返修免费判断：" + (payload.free ? "免费" : "收费，另行报价"),
        });
        child.originalOrderId = o.id;
        child.events = [
          {
            id: uid("event"),
            type,
            note: payload.note,
            actorId: actor.id,
            createdAt: now,
          },
        ];
        return refreshOrder(child, data.loans);
      }
      case "review_acceptance":
        must(payload.note, "需要核实停机期间线下异议依据。");
        break;
      case "report":
        must(payload.note, "报告不能空白。");
        break;
      default:
        throw new Error("该动作尚不支持离线演示。");
    }
    o.version++;
    o.updatedAt = now;
    o.events.push({
      id: uid("event"),
      type,
      note: payload.note || payload.reason || actionNames[type],
      actorId: actor.id,
      createdAt: now,
    });
    return refreshOrder(o, data.loans);
  }
  const api = {
    states,
    roles,
    actionNames,
    permissions,
    cents,
    integer,
    uid,
    addMonths,
    derive,
    loanBlockingQuantity,
    refreshOrder,
    seed,
    createOrder,
    apply,
  };
  if (typeof module !== "undefined" && module.exports) module.exports = api;
  root.WorkbenchData = api;
})(typeof window !== "undefined" ? window : globalThis);
