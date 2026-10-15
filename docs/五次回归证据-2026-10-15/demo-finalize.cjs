const fs = require("node:fs");
const path = require("node:path");
const crypto = require("node:crypto");
const assert = require("node:assert/strict");
const root = "/Users/jobs/Desktop/啄木鸟维修平台-V3.8";
const read = (name) => JSON.parse(fs.readFileSync(path.join(__dirname, name), "utf8"));
const first = read("demo-results-valid.json"), repeat = read("demo-results-repeat.json");
assert.deepEqual(first.rows.map((r) => [r.id, r.passed]), repeat.rows.map((r) => [r.id, r.passed]));
assert.deepEqual(first.source, repeat.source);
for (const [file, expected] of Object.entries(first.source)) {
  assert.equal(crypto.createHash("sha256").update(fs.readFileSync(path.join(root, file))).digest("hex"), expected, file);
}
const at = (file, start, end, why) => ({ file, start, end, why });
const findings = [
  {
    id: "R5-D01", title: "仓库角色可在独立演示自行完成须管理员批准的借用品耗用、处置和转独立跟踪", tests: ["Q01-consume", "Q01-dispose", "Q01-transfer"],
    reproduce: ["打开独立演示并切仓库角色，进入库存台账。", "对种子尚欠1件借用分别打开转耗用、处置、独立跟踪表单，填写数量1及原因；独立跟踪另选工程师和期限。"],
    expected: "仓库可以归还，但这三类批准动作应由admin办理；拒绝保持库存、借用、关联工单不变。",
    actual: "三个表单均直接保存，warehouse角色分别增加consumed/disposed，或加入transfers并解除对应工单阻塞，没有管理员批准身份。",
    source: [at("Workspace/app.js", 1334, 1347, "仓库与admin同时获得三个批准动作按钮"), at("Workspace/app.js", 3672, 3708, "合成localApply只检查数量，不检查批准角色")],
    contract: [at("Server/internal/workbench/inventory.go", 113, 135, "consume/dispose/transfer明确要求admin"), at("需求/物业设备维修服务平台 PRD V3.8（Jobs规范版）.md", 304, 309, "尚欠处置须批准，独立转出须有批准依据")],
  },
  {
    id: "R5-D02", title: "已完结演示工单不经受控重开，仍能新增关联借用或未结异议并保持completed", tests: ["Q02", "Q14"],
    reproduce: ["将demo-003按实际完结表单完成。", "管理员借用登记选择该已完结单并借出1件；独立另例由客户打开该单登记异议。"],
    expected: "新增会改变完结条件的义务须先按授权重开；不能在已完结状态追加未清事项。",
    actual: "借用会真实改变合成可用库存并生成尚欠，或客户新增未结异议；summary已有缺项，status仍completed。",
    source: [at("Workspace/app.js", 3540, 3578, "关联选项含已完结单且localApply不检查已完结"), at("Workspace/app.js", 650, 660, "已完结仍保留issue入口"), at("Workspace/data.js", 1028, 1030, "issue直接追加"), at("Workspace/data.js", 422, 429, "派生保留completed，不自动重开")],
    contract: [at("Server/internal/workbench/inventory.go", 44, 51, "已完结关联借用返回reopen_required"), at("Server/internal/workbench/actions.go", 250, 255, "已完结动作白名单排除issue"), at("需求/物业设备维修服务平台 PRD V3.8（Jobs规范版）.md", 1901, 1901, "A41完结后改变条件应受控重开")],
  },
  {
    id: "R5-D03", title: "独立演示允许未关联工单的借用品直接转维修耗用", tests: ["Q03"],
    reproduce: ["管理员实际借用表单选独立借用、不关联工单，借出1件。", "对该借用打开转维修耗用并填数量1及原因。"],
    expected: "维修耗用须能归属工单及本单成本依据；没有关联时拒绝，保留尚欠。",
    actual: "orderId为空仍增加consumed并减少outstanding，缺少维修工单成本归属。",
    source: [at("Workspace/app.js", 3685, 3686, "耗用直接增加累计，不检查关联工单")],
    contract: [at("Server/internal/workbench/inventory.go", 120, 124, "无关联返回order_required"), at("需求/物业设备维修服务平台 PRD V3.8（Jobs规范版）.md", 304, 309, "借还去向和维修耗用需要业务依据")],
  },
  {
    id: "R5-D04", title: "借用表单提供财务等不符合现行借用API合同的责任人，演示仍扣库借出", tests: ["Q04"],
    reproduce: ["管理员打开实际借出表单，借用责任人列表选择财务，数量1、独立借用、有效期限和说明后提交。"],
    expected: "当前借用API只接受有效内部engineer账号，客户端选项和演示校验应匹配；无效责任人不扣库。",
    actual: "select包含finance选项，演示接受borrowerId=finance并直接减可用库；真API会invalid_loan。",
    source: [at("Workspace/app.js", 3555, 3561, "仅排除customer/supplier，仍包含finance/dispatcher/qc/outsource等"), at("Workspace/app.js", 3565, 3578, "借出localApply未校验借用人类型")],
    contract: [at("Server/internal/workbench/inventory.go", 33, 38, "当前实现显式accountExists(..., engineer)")],
    limit: "这是相对现行API人员合同的可见选项/演示一致性问题；未主张所有内部角色都不得在未来业务规则获批借用。",
  },
  {
    id: "R5-D05", title: "财务核实超额退款未被演示拒绝，净实收可直接变负", tests: ["Q05"],
    reproduce: ["财务打开已有净核实收款50000分的demo-003，实际现金表单登记50100分退款。", "对新增退款点击财务核实并提交。"],
    expected: "退款不得超过当前已核实净收款，核实失败时不改原现金台账或版本。",
    actual: "退款verified变true，collectedCents=-100；没有拒绝信息，已形成不可能的核实资金事实。",
    source: [at("Workspace/data.js", 950, 955, "核实仅检查存在/未核实，缺退款净收上限")],
    contract: [at("Server/internal/workbench/actions.go", 570, 576, "超退返回refund_exceeds_receipts"), at("需求/物业设备维修服务平台 PRD V3.8（Jobs规范版）.md", 369, 369, "退款关联原收款并冲减实收")],
  },
  {
    id: "R5-D06", title: "演示完结清单漏掉已核实退款的内部交接，handedOver=false仍可整单完结", tests: ["Q06"],
    reproduce: ["财务在demo-003实际登记退款10000分并核实，保持handedOver=false。", "按真实应收调整表单将有效应收改成退款后净收40000分，再切调度核对完结。"],
    expected: "退款内部交接未处理应列缺项，不能因净收等于应收而完结。",
    actual: "派生missing为空、阶段pending_completion；调度点击完结后completed，退款仍verified=true/handedOver=false。",
    source: [at("Workspace/data.js", 367, 368, "内部交接缺项明确排除了refund")],
    contract: [at("Server/internal/workbench/service.go", 418, 429, "真服务检查所有已核实现金的未交接"), at("需求/物业设备维修服务平台 PRD V3.8（Jobs规范版）.md", 1897, 1897, "A37必须交接未完成不能整单完结")],
  },
  {
    id: "R5-D07", title: "演示发票登记只检查非空引用，可重复有效票号、违反无需开票约定或引用普通文字", tests: ["Q07", "Q08", "Q09"],
    reproduce: ["财务对demo-002用现有有效票号和同一文件再登记。", "另例将其开票要求改成none后仍从通用发票入口登记新票。", "另例实际归档文字证据，再在发票多选控件选它作为票据原件。"],
    expected: "拒绝有效票号重复；需先确认required；电子发票原件只接受对应有效PDF/图片。",
    actual: "三例都新增invoice记录；文字证据被当作有效票据引用，重复号码增加票额，none约定下继续登记成功。",
    source: [at("Workspace/data.js", 964, 966, "仅must(payload.files.length)后追加"), at("Workspace/app.js", 2646, 2655, "附件select对所有未删除证据可选，依赖业务提交校验")],
    contract: [at("Server/internal/workbench/actions.go", 590, 605, "开票要求、有效原件和有效票号去重"), at("Server/internal/workbench/service.go", 398, 412, "invoiceFiles检查原件类型"), at("需求/物业设备维修服务平台 PRD V3.8（Jobs规范版）.md", 356, 356, "电子发票PDF/图片留存")],
  },
  {
    id: "R5-D08", title: "付款资料发送未填写接收对象，演示仍形成已发送事实", tests: ["Q10"],
    reproduce: ["财务将demo-002当前有效付款资料先实际保存为已制作/未发送。", "再选择已发送，但接收对象字段留空，保留有效文件引用后提交。"],
    expected: "已发送须记录真实接收对象，输入缺失时保留未发送事实。",
    actual: "资料sent=true、recipient为空，summary.documentStatus=sent。原控件为optional，可正常提交。",
    source: [at("Workspace/app.js", 2945, 2951, "recipient表单明确可留空"), at("Workspace/data.js", 931, 938, "sent只要求prepared，不检查recipient")],
    contract: [at("Server/internal/workbench/actions.go", 536, 543, "发送必须有非空recipient，否则document_recipient_required"), at("docs/workbench-contract.md", 78, 78, "资料合同包含recipient")],
  },
  {
    id: "R5-D09", title: "停止履约表单可覆盖演示原有效验收或已确认停止结果", tests: ["Q11", "Q12"],
    reproduce: ["管理员在accepted的demo-001打开仍可见的停止履约，选择取消。", "另例对demo-004先按不能修停止，再第二次按取消停止。"],
    expected: "已有履约结果不得直接覆盖，原验收/停止原因和历史事实保留。",
    actual: "accepted直接变cancelled且旧质保仍在；已确认不能修结果也被第二次取消覆盖。",
    source: [at("Workspace/app.js", 74, 88, "failure是结算阶段通用入口"), at("Workspace/data.js", 1039, 1044, "直接赋outcome=payload.reason，不检查已有结果")],
    contract: [at("Server/internal/workbench/actions.go", 764, 766, "已有Outcome直接返回outcome_exists"), at("需求/物业设备维修服务平台 PRD V3.8（Jobs规范版）.md", 1899, 1903, "A39/A41/A43原验收历史与实际终局事实保留")],
  },
  {
    id: "R5-D10", title: "未约定先款开修时演示漏掉预付不得超过报价的通用金额约束", tests: ["Q13"],
    reproduce: ["实际将demo-006受理、开始检测进入合法报价阶段。", "报价100元，预付款200元，明确选择未约定先款开修，其他字段合法后提交。"],
    expected: "未约定先款只解除开修门槛，不代表允许prepayCents大于amountCents；非法报价应原子拒绝。",
    actual: "报价保存为amountCents=10000、prepayCents=20000、startRequiresPrepayment=false，形成新版本。",
    source: [at("Workspace/data.js", 814, 828, "预付上限校验仅在startRequiresPrepayment=true时触发")],
    contract: [at("Server/internal/workbench/actions.go", 327, 331, "所有报价都要求prepay<=amount，另对true要求正数"), at("docs/workbench-contract.md", 109, 116, "无先款约定不会取消报价本身的金额合法性")],
    limit: "不恢复已废弃的cash维修全款开修断言；无约定仍允许零款开修。",
  },
];
for (const f of findings) {
  f.priority = "P2"; f.status = "confirmed-repeated-unfixed"; f.mode = "independent-synthetic-demo";
  assert.ok(f.tests.every((id) => first.rows.some((r) => r.id === id && !r.passed)), f.id);
}
const assigned = findings.flatMap((f) => f.tests).sort();
assert.deepEqual(assigned, first.rows.filter((r) => !r.passed).map((r) => r.id).sort());
const summary = {
  date: "2026-10-15", findings: findings.length, priorityCounts: { P2: findings.length }, tests: first.tests, pass: first.pass, fail: first.fail, skip: first.skip,
  repeated: true, repeatCounts: { tests: repeat.tests, pass: repeat.pass, fail: repeat.fail, skip: repeat.skip }, exitCodes: { initialExploratory: 1, valid: 1, repeat: 1 }, source: first.source,
  filesUnchangedAgainstBothValidRuns: true,
  methodology: "Current actual app.js in VM using existing formal harness prefix. Read-only in-memory getDemo/available test export. Native FormData.getAll added only to the lightweight VM harness, enabling actual selected-file callbacks; integer/amount controls converted as actual UI. All 16 failed assertions use normal available forms/actions and legitimate synthetic sequence setup. No product or formal test files changed.",
  exploratoryRun: { log: "demo-sequences.log", results: "demo-results.json", tests: 22, pass: 11, fail: 11, usedForFindings: false, explanation: "Initial diagnostic run exposed missing getAll in the lightweight harness and Q13 started from a non-quote stage. Corrected diagnostic environment/setup without changing expectations, retained initial outputs, then ran the same substantive assertions plus two positive controls twice. Current valid counts are24/8/16." },
  positiveCoverage: first.rows.filter((r) => r.passed),
  evidence: ["demo-sequences.cjs", "demo-sequences-valid.log", "demo-results-valid.json", "demo-sequences-repeat.log", "demo-results-repeat.json", "demo-sequences.log", "demo-results.json"],
  findingsDetail: findings,
  cleanup: "No listeners, browsers, containers, temporary directories, credentials or real data created; Node processes exited1 as expected for discovered failures. Only current docs/五次回归证据-2026-10-15/demo-* diagnostic outputs written; no services or .runtime read/modified.",
  limitations: ["Findings concern independent synthetic fallback; they are not evidence of backend authorization, real money or production bypass.", "API rules were inspected in authoritative current Go source, not re-tested by this subtask. Root/backend agent owns final real-service verification.", "No fixes, report/map/memory edits, index sync, commits or pushes performed."],
};
fs.writeFileSync(path.join(__dirname, "demo-findings.json"), JSON.stringify(summary, null, 2) + "\n");
console.log(JSON.stringify({ findings: summary.findings, tests: summary.tests, pass: summary.pass, fail: summary.fail, repeatMatched: true, sourceUnchanged: true }));
