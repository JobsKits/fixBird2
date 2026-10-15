(() => {
  const $ = selector => document.querySelector(selector);
  const demoApplicationSeed = [{ id: "demo-application-1", workerId: "demo-worker-review",
    displayName: "本地演示申请", contactPhone: "未填写真实手机号", serviceAreas: ["演示服务区域"],
    skills: ["家电维修"], bio: "用于预览人工审核流程，未提交至服务端。", assetIds: [],
    status: "pending", revision: 1, reviewNote: "", createdAt: "2026-10-05T00:00:00Z" }];
  let demoApplications = structuredClone(demoApplicationSeed);
  let applications = { data: demoApplications, isOnline: false, nextCursor: "" };
  let ledger = { data: [], isOnline: false, nextCursor: "" };
  let summary = OperationsData.emptySummary();
  let applicationRevision = 0;
  let ledgerRevision = 0;
  let ledgerQuery = "";
  let previewRevision = 0;
  let loginRevision = 0;
  let imageURL = "";
  const pendingReviews = new Set();
  const statusLabel = value => ({ pending: "待审核", approved: "已通过", rejected: "已驳回",
    posted: "已记账", reversed: "已冲正" })[value] || value;
  const kindLabel = value => ({ collection: "订单收款", manual_payout: "结算核销", reversal: "冲正" })[value] || value;
  const channelLabel = value => ({ demo: "模拟收款", manual: "人工核销", wechat: "微信",
    alipay: "支付宝", aggregate: "聚合支付" })[value] || value;
  const accountLabel = value => ({ platform_funds: "平台资金", worker_payable: "师傅待结算",
    platform_revenue: "平台收入" })[value] || value;

  function notice(message) {
    $("#operationsState").hidden = false;
    $("#operationsState").textContent = message;
    if (!AdminSession.current()) $("#authFeedback").textContent = message;
  }
  function renderSession() {
    const value = AdminSession.current();
    if (window.AuthGate) window.AuthGate.sync();
    $("#adminLogout").hidden = !value;
    $("#adminSessionState").textContent = value
      ? "已登录" + (value.user.role === "admin" ? "管理员：" : "普通账号：") + (value.user.displayName || value.user.username) + "；凭据仅保留在当前页面。"
      : "未登录；敏感接口需要管理员账号。失败时仅展示独立本地演示数据。";
  }
  function closePreview() {
    previewRevision += 1;
    if (imageURL) URL.revokeObjectURL(imageURL);
    imageURL = "";
    $("#assetImage").removeAttribute("src");
    $("#assetImage").hidden = true;
    $("#assetPreview").close();
  }
  function renderApplications() {
    $("#applicationsSource").textContent = applications.isOnline ? "服务端资料" :
      "独立本地演示资料" + (applications.reason ? "（" + applications.reason + "）" : "");
    $("#applications").innerHTML = applications.data.length ? applications.data.map(item =>
      '<article class="record"><strong>' + safe(item.displayName) + " · " + safe(statusLabel(item.status)) +
      '</strong><small>申请 ' + safe(item.id) + " / 师傅 " + safe(item.workerId) +
      '<br>联系电话：' + safe(item.contactPhone) + '<br>技能：' + safe(item.skills.join("、")) +
      '<br>服务区域：' + safe(item.serviceAreas.join("、")) + '<br>说明：' + safe(item.bio) +
      '<br>审核意见：' + safe(item.reviewNote || "暂无") + '</small><div class="asset-buttons">' +
      item.assetIds.map((id, index) => '<button class="button secondary" data-operation="asset" data-id="' +
        safe(id) + '">查看资料图片 ' + (index + 1) + '</button>').join("") + '</div>' +
      (item.status === "pending" ? '<label>审核意见（驳回必填）<textarea maxlength="500" id="note-' + safe(item.id) +
        '"></textarea></label><div class="review-actions"><button class="button primary" data-operation="approved" data-id="' +
        safe(item.id) + '">审核通过</button><button class="button warn" data-operation="rejected" data-id="' +
        safe(item.id) + '">驳回申请</button></div>' : "") + '</article>'
    ).join("") : emptyState("暂无对应状态的申请", "师傅提交资料后会显示在这里。");
    $("#applicationsMore").hidden = !applications.isOnline || !applications.nextCursor;
    $("#applicationsMore").disabled = false;
    loadIconfontImages();
  }
  function filters() {
    const params = new URLSearchParams({ mode: $("#ledgerMode").value || "simulated", limit: "100" });
    for (const [field, id] of Object.entries({ kind: "Kind", channel: "Channel", status: "Status",
      orderId: "Order", customerId: "Customer", workerId: "Worker" })) {
      const value = $("#ledger" + id).value.trim();
      if (value) params.set(field, value);
    }
    for (const [field, id] of [["from", "From"], ["to", "To"]]) {
      const value = $("#ledger" + id).value;
      if (value) {
        const date = new Date(value);
        if (!Number.isFinite(date.getTime())) throw new Error("时间格式无效");
        params.set(field, date.toISOString());
      }
    }
    if (params.has("from") && params.has("to") && params.get("from") >= params.get("to")) {
      throw new Error("开始时间必须早于结束时间");
    }
    return params;
  }
  function demoLedger(params) {
    const rows = [];
    for (const item of DEMO_DATA.settlements) {
      const order = DEMO_DATA.orders.find(value => value.id === item.orderId);
      if (!order) continue;
      const common = { orderId: item.orderId, customerId: order.customerId, workerId: item.workerId,
        settlementId: item.id, mode: "simulated", simulated: true, status: "posted", actorId: "local-demo",
        workerShareCents: item.workerShareCents, platformFeeCents: item.platformFeeCents,
        occurredAt: item.createdAt || new Date().toISOString(), reason: "独立本地演示，未写入服务端" };
      rows.push({ ...common, id: "local-collection-" + item.id, kind: "collection", channel: "demo",
        amountCents: item.grossAmountCents, entries: [
          { account: "platform_funds", direction: "debit", amountCents: item.grossAmountCents },
          { account: "worker_payable", direction: "credit", amountCents: item.workerShareCents },
          { account: "platform_revenue", direction: "credit", amountCents: item.platformFeeCents }] });
      if (item.status === "manually_paid") rows.push({ ...common, id: "local-payout-" + item.id,
        kind: "manual_payout", channel: "manual", amountCents: item.workerShareCents, platformFeeCents: 0, entries: [
          { account: "worker_payable", direction: "debit", amountCents: item.workerShareCents },
          { account: "platform_funds", direction: "credit", amountCents: item.workerShareCents }] });
    }
    const selected = rows.filter(row => [...params].every(([key, value]) => {
      if (key === "limit") return true;
      if (key === "from") return Date.parse(row.occurredAt) >= Date.parse(value);
      if (key === "to") return Date.parse(row.occurredAt) < Date.parse(value);
      return row[key] === value;
    }));
    const totals = OperationsData.emptySummary(params.get("mode") || "simulated");
    for (const row of selected) {
      totals.journalCount += 1;
      if (row.kind === "collection") {
        totals.collectedCents += row.amountCents;
        totals.platformRevenueCents += row.platformFeeCents;
        totals.workerAccruedCents += row.workerShareCents;
      } else totals.payoutCents += row.amountCents;
      for (const entry of row.entries) {
        const net = entry.amountCents * (entry.direction === "debit" ? 1 : -1);
        if (entry.account === "platform_funds") totals.platformFundsCents += net;
        if (entry.account === "worker_payable") totals.workerPayableCents -= net;
      }
    }
    return { rows: selected, totals };
  }
  function renderLedger() {
    $("#ledgerSource").textContent = ledger.isOnline ? "服务端账本；汇总涵盖全部筛选结果，列表分批加载。" :
      "独立本地预览，查询结果未获服务端确认" + (ledger.reason ? "（" + ledger.reason + "）" : "");
    $("#ledgerSummary").innerHTML = [["收款发生额", "collectedCents"], ["平台收入发生额", "platformRevenueCents"],
      ["结算核销发生额", "payoutCents"], ["待结算净发生额", "workerPayableCents"]].map(([title, key]) =>
      '<article class="metric"><span>' + title + '</span><strong>' + money(summary[key]) + '</strong></article>').join("");
    $("#ledgerBody").innerHTML = ledger.data.length ? ledger.data.map(item => '<tr><td>' + safe(item.occurredAt) +
      '<small>' + safe(item.id) + '</small></td><td>' + safe(item.orderId) + '<small>用户 ' + safe(item.customerId) +
      '<br>师傅 ' + safe(item.workerId) + '</small></td><td>' + safe(kindLabel(item.kind)) + '<small>' +
      safe(channelLabel(item.channel)) + '</small></td><td>' + (item.simulated ? "模拟账" : "真实账") +
      '<small>' + safe(statusLabel(item.status)) + '</small></td><td class="numeric">' + money(item.amountCents) +
      '</td><td class="numeric">' + money(item.platformFeeCents) + '<small>' + money(item.workerShareCents) +
      '</small></td><td>' + item.entries.map(entry => safe(accountLabel(entry.account)) + " / " +
        (entry.direction === "debit" ? "借" : "贷") + " " + money(entry.amountCents)).join("<br>") + '</td></tr>'
    ).join("") : '<tr><td colspan="7">' + emptyState("暂无对应账务流水", "目前真实支付尚未接入；模拟收款后可查询模拟账。").replace('data-action="refresh"', 'data-operation="reload-ledger"') + '</td></tr>';
    $("#ledgerMore").hidden = !ledger.isOnline || !ledger.nextCursor;
    $("#ledgerMore").disabled = false;
    $("#ledgerExport").disabled = !ledger.isOnline || !AdminSession.current();
    loadIconfontImages();
  }
  async function list(path, validate) {
    let nextCursor = "";
    const data = await request(path, { onResponse: response => { nextCursor = response.headers.get("X-Next-Cursor") || ""; } });
    if (!validate(data)) throw new Error("响应数据结构不正确");
    return { data, isOnline: true, nextCursor };
  }
  async function refreshApplications(more = false) {
    if (AdminSession.current()?.user.role === "operator") return;
    const revision = ++applicationRevision;
    const environment = environmentRevision;
    const previous = applications;
    const params = new URLSearchParams({ limit: "100" });
    if ($("#applicationStatus").value) params.set("status", $("#applicationStatus").value);
    if (more && previous.nextCursor) params.set("cursor", previous.nextCursor);
    $("#applicationsMore").disabled = true;
    let result;
    try {
      result = await list("/api/v1/admin/worker-applications?" + params, OperationsData.applications);
      if (more) result.data = [...new Map([...previous.data, ...result.data].map(item => [item.id, item])).values()];
      if (more && result.nextCursor === previous.nextCursor) result.nextCursor = "";
    } catch (error) {
      result = { data: structuredClone(demoApplications.filter(item => !params.get("status") || item.status === params.get("status"))),
        isOnline: false, reason: error.message, nextCursor: "" };
    }
    if (environment !== environmentRevision || revision !== applicationRevision) return;
    applications = result;
    renderApplications();
  }
  async function refreshLedger(more = false) {
    const revision = ++ledgerRevision;
    const environment = environmentRevision;
    const previous = ledger;
    let params;
    try { params = filters(); } catch (error) { notice(error.message); return; }
    const query = params.toString();
    if (more && query !== ledgerQuery) more = false;
    if (more && previous.nextCursor) params.set("cursor", previous.nextCursor);
    $("#ledgerMore").disabled = true;
    let result, totals;
    try {
      [result, totals] = await Promise.all([
        list("/api/v1/admin/ledger/journals?" + params, OperationsData.journals),
        request("/api/v1/admin/ledger/summary?" + query)
      ]);
      if (!OperationsData.summary(totals)) throw new Error("汇总响应数据结构不正确");
      if (totals.mode !== params.get("mode") || !result.data.every(item => item.mode === params.get("mode"))) {
        throw new Error("账本响应与当前查询范围不一致");
      }
      if (more) result.data = [...new Map([...previous.data, ...result.data].map(item => [item.id, item])).values()];
      if (more && result.nextCursor === previous.nextCursor) result.nextCursor = "";
    } catch (error) {
      const local = demoLedger(new URLSearchParams(query));
      result = { data: local.rows, isOnline: false, reason: error.message, nextCursor: "" };
      totals = local.totals;
    }
    if (environment !== environmentRevision || revision !== ledgerRevision) return;
    ledger = result;
    ledgerQuery = query;
    summary = totals;
    renderLedger();
  }
  async function review(id, decision, button) {
    if (!["approved", "rejected"].includes(decision)) return;
    const item = applications.data.find(value => value.id === id);
    if (!item || item.status !== "pending" || pendingReviews.has(id)) return;
    const note = $("#note-" + id).value.trim();
    if (decision === "rejected" && !note) { notice("驳回申请需要填写审核意见。"); return; }
    if (!window.confirm("确认" + statusLabel(decision) + "此申请？")) return;
    const environment = environmentRevision;
    pendingReviews.add(id);
    button.disabled = true;
    try {
      const data = await request("/api/v1/admin/worker-applications/" + encodeURIComponent(id) + "/review", {
        method: "POST", body: JSON.stringify({ decision, note, expectedRevision: item.revision })
      });
      if (!OperationsData.applications([data]) || data.status !== decision) throw new Error("审核响应无效");
      if (environment !== environmentRevision) return;
      notice("服务端已确认审核结果。");
      await refreshApplications();
      refresh();
    } catch (error) {
      if (environment !== environmentRevision) return;
      const local = { ...structuredClone(item), id: "demo-copy-" + id, status: decision,
        revision: item.revision + 1, reviewNote: note, assetIds: [] };
      demoApplications = demoApplications.filter(value => value.id !== local.id);
      demoApplications.push(local);
      applications = { data: [local], isOnline: false, reason: error.message, nextCursor: "" };
      renderApplications();
      notice("审核未获服务端确认（" + error.message + "）。仅在独立本地副本演示此结果，不代表真实审核通过，也不会自动补发。");
    } finally { pendingReviews.delete(id); button.disabled = false; }
  }
  async function preview(id) {
    closePreview();
    const revision = previewRevision;
    const environment = environmentRevision;
    $("#assetPreview").showModal();
    $("#assetState").textContent = "正在读取私有图片…";
    try {
      const blob = await request("/api/v1/worker-assets/" + encodeURIComponent(id), { responseType: "blob" });
      if (!["image/jpeg", "image/png"].includes(blob.type)) throw new Error("图片响应类型无效");
      if (revision !== previewRevision || environment !== environmentRevision) return;
      imageURL = URL.createObjectURL(blob);
      $("#assetImage").src = imageURL;
      $("#assetImage").hidden = false;
      $("#assetState").textContent = "私有资料图片；关闭窗口后释放预览。";
    } catch (error) {
      if (revision === previewRevision && environment === environmentRevision) $("#assetState").textContent = "无法查看：" + error.message;
    }
  }
  async function exportCSV() {
    const environment = environmentRevision;
    $("#ledgerExport").disabled = true;
    try {
      const blob = await request("/api/v1/admin/ledger/export.csv?" + filters(), { responseType: "blob" });
      if (!blob.type.startsWith("text/csv")) throw new Error("导出响应类型无效");
      if (environment !== environmentRevision) return;
      const url = URL.createObjectURL(blob);
      const link = document.createElement("a");
      link.href = url;
      link.download = "账务流水-" + ($("#ledgerMode").value || "simulated") + ".csv";
      link.click();
      window.setTimeout(() => URL.revokeObjectURL(url), 1000);
      notice("已导出当前筛选范围的服务端账务流水。");
    } catch (error) {
      if (environment === environmentRevision) notice("导出未完成：" + error.message + "。本地演示数据未冒充服务端账本。");
    } finally { $("#ledgerExport").disabled = !ledger.isOnline || !AdminSession.current(); }
  }
  function reset() {
    applicationRevision += 1;
    ledgerRevision += 1;
    ledgerQuery = "";
    loginRevision += 1;
    demoApplications = structuredClone(demoApplicationSeed);
    applications = { data: demoApplications, isOnline: false, nextCursor: "" };
    ledger = { data: [], isOnline: false, nextCursor: "" };
    summary = OperationsData.emptySummary();
    closePreview();
    renderSession();
    renderApplications();
    renderLedger();
  }
  $("#adminLogin").addEventListener("submit", async event => {
    event.preventDefault();
    const revision = ++loginRevision;
    const environment = environmentRevision;
    const password = $("#adminPassword").value;
    $("#adminPassword").value = "";
    $("#adminLoginButton").disabled = true;
    try {
      const value = await request("/api/v1/auth/login", { method: "POST",
        body: JSON.stringify({ username: $("#adminUsername").value.trim(), password }) });
      if (environment !== environmentRevision || revision !== loginRevision) return;
      AdminSession.set(value);
      notice(value.user.role === "admin" ? "管理员登录成功。" : "普通账号登录成功。");
    } catch (error) {
      if (environment === environmentRevision && revision === loginRevision) notice("登录失败：" + error.message + "。未创建本地管理员身份。");
    } finally { $("#adminLoginButton").disabled = false; }
  });
  $("#adminLogout").addEventListener("click", async () => {
    const revision = AdminSession.revision;
    const operation = request("/api/v1/auth/logout", { method: "POST" });
    AdminSession.clear(revision);
    const environment = environmentRevision;
    try { await operation; if (environment === environmentRevision) notice("已退出登录，会话已撤销。"); }
    catch (error) { if (environment === environmentRevision) notice("已清除本页登录凭据；服务端撤销未确认：" + error.message); }
  });
  AdminSession.onChange(() => {
    environmentRevision += 1;
    reset();
    DEMO_DATA = structuredClone(DEMO_SEED);
    renderDemoPreview();
    refresh();
  });
  $("#applicationStatus").addEventListener("change", () => refreshApplications());
  $("#applicationsReload").addEventListener("click", () => refreshApplications());
  $("#applicationsMore").addEventListener("click", () => refreshApplications(true));
  $("#ledgerFilters").addEventListener("submit", event => { event.preventDefault(); refreshLedger(); });
  $("#ledgerMore").addEventListener("click", () => refreshLedger(true));
  $("#ledgerExport").addEventListener("click", exportCSV);
  $("#assetClose").addEventListener("click", closePreview);
  $("#assetPreview").addEventListener("cancel", event => { event.preventDefault(); closePreview(); });
  document.addEventListener("click", event => {
    const button = event.target.closest("button[data-operation]");
    if (!button) return;
    if (button.dataset.operation === "asset") preview(button.dataset.id);
    else if (button.dataset.operation === "reload-ledger") refreshLedger();
    else review(button.dataset.id, button.dataset.operation, button);
  });
  window.AdminOperations = { refresh: () => Promise.all([refreshApplications(), refreshLedger()]), reset };
  reset();
  window.AdminOperations.refresh();
})();
