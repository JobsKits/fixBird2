(() => {
  const $ = selector => document.querySelector(selector);
  const safe = value => String(value ?? "").replace(/[&<>"']/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]);
  const money = value => new Intl.NumberFormat("zh-CN", { style: "currency", currency: "CNY" }).format(value / 100);
  const statuses = { pending_worker: "待接单", accepted: "已接单", arrived: "已到场", quote_pending: "报价待确认",
    in_service: "维修中", awaiting_payment: "待支付", completed: "已完成", cancelled: "已取消" };
  const seed = [{ id: "local-demo-order", customerId: "customer-demo", workerId: "", category: "家电维修",
    equipment: "演示冰箱", issue: "演示故障", address: "本地演示地址", scheduledAt: "", status: "pending_worker",
    paymentStatus: "not_started", quotedAmountCents: 0, platformFeeCents: 0, workerShareCents: 0 }];
  let session = null;
  let epoch = 0;
  let qrRevision = 0;
  let qrTimer = null;
  let ordersRevision = 0;
  let ledgerRevision = 0;
  let demoOrders = structuredClone(seed);
  let orders = { data: demoOrders, online: false, cursor: "" };
  let journals = { data: [], online: false, cursor: "" };
  let createAttempt = null;
  const actions = new Set();
  const storageKey = () => "repairPCSession:" + currentEnvironment + ":" + activeAPIBase();
  function requestKey() {
    if (typeof crypto.randomUUID === "function") return crypto.randomUUID();
    // HTTP 局域网页面也能用 getRandomValues，保持重试标识不依赖 secure-context UUID。
    const bytes = crypto.getRandomValues(new Uint8Array(16));
    return [...bytes].map(byte => byte.toString(16).padStart(2, "0")).join("");
  }
  const device = () => ({ kind: "desktop", label: "PC 浏览器", platform: navigator.userAgentData?.platform || navigator.platform || "Web" });
  function note(message) { $("#feedback").textContent = message; }
  function validSession(value) {
    return value && typeof value.token === "string" && value.token && Number.isFinite(Date.parse(value.expiresAt)) &&
      Date.parse(value.expiresAt) > Date.now() && value.user && typeof value.user.id === "string" &&
      ["customer", "worker"].includes(value.user.role);
  }
  function stopQR() {
    qrRevision += 1;
    if (qrTimer) window.clearTimeout(qrTimer);
    qrTimer = null;
    $("#qrCode").innerHTML = "";
    $("#qrPayload").value = "";
  }
  function renderAccount() {
    $("#loginPanel").hidden = !!session;
    $("#accountPanel").hidden = !session;
    $("#createPanel").hidden = !session || session.user.role !== "customer";
    if (session) {
      $("#accountTitle").textContent = (session.user.displayName || session.user.username) + " · " +
        (session.user.role === "worker" ? "师傅" : "用户");
      $("#sessionState").textContent = "当前 PC 会话独立有效至 " + session.expiresAt + "；手机退出不会使此会话退出。设备授权与撤销请在手机端操作。";
    }
  }
  function persistSession() {
    try {
      if (session) sessionStorage.setItem(storageKey(), JSON.stringify(session));
      else sessionStorage.removeItem(storageKey());
    } catch (_) { note("浏览器禁止会话存储，登录仅保留在当前页面，刷新后需重新扫码。"); }
  }
  function clearSession(expectedEpoch) {
    if (expectedEpoch !== undefined && expectedEpoch !== epoch) return;
    session = null;
    persistSession();
    epoch += 1;
    createAttempt = null;
    demoOrders = structuredClone(seed);
    orders = { data: demoOrders, online: false, cursor: "" };
    journals = { data: [], online: false, cursor: "" };
    renderAccount();
    renderOrders();
    renderLedger();
    stopQR();
  }
  function acceptSession(value) {
    if (!validSession(value)) throw new Error("登录响应无效，或账号不属于用户 / 师傅端");
    epoch += 1;
    session = value;
    createAttempt = null;
    demoOrders = structuredClone(seed);
    orders = { data: demoOrders, online: false, cursor: "" };
    journals = { data: [], online: false, cursor: "" };
    persistSession();
    stopQR();
    renderAccount();
    renderOrders();
    renderLedger();
    refreshOrders();
    refreshLedger();
  }
  async function request(path, { anonymous = false, response, ...options } = {}) {
    const origin = activeAPIBase();
    if (!origin) throw new Error("线上服务地址尚未配置");
    const controller = new AbortController();
    const snapshot = epoch;
    const token = anonymous ? "" : session?.token;
    let timer;
    const deadline = new Promise((_, reject) => {
      timer = window.setTimeout(() => { reject(new Error("请求超时，服务端结果未确认")); controller.abort(); }, API_REQUEST_TIMEOUT_MS);
    });
    try {
      const operation = (async () => {
        const result = await fetch(normalizeAPIBase(origin) + path, { ...options, signal: controller.signal,
          headers: { "Content-Type": "application/json", ...(token ? { Authorization: "Bearer " + token } : {}), ...(options.headers || {}) } });
        if (response) response(result);
        if (!result.ok) {
          const error = await result.json().catch(() => ({}));
          if (result.status === 401 && token && snapshot === epoch) {
            clearSession(snapshot);
            note("此 PC 会话已过期或被撤销，请重新扫码登录。");
          }
          throw new Error("HTTP " + result.status + "：" + (error.message || error.error || "请求失败"));
        }
        if (result.status === 204) return null;
        return await result.json();
      })();
      return await Promise.race([operation, deadline]);
    } finally { window.clearTimeout(timer); }
  }
  const validOrders = value => Array.isArray(value) && value.every(item => item && typeof item.id === "string" &&
    typeof item.customerId === "string" && typeof item.workerId === "string" && typeof item.category === "string" &&
    typeof item.equipment === "string" && typeof item.issue === "string" && typeof item.address === "string" &&
    Object.hasOwn(statuses, item.status) && ["quotedAmountCents", "platformFeeCents", "workerShareCents"].every(key => Number.isSafeInteger(item[key]) && item[key] >= 0));
  const empty = title => '<div class="empty"><img src="./assets/RepairLogo.png" alt="维修平台标志"><strong>' + safe(title) + '</strong><button data-operation="reload">重新加载</button></div>';
  function renderOrders() {
    $("#ordersSource").textContent = orders.online ? (session ? "服务端当前账号订单" : "服务端固定匿名演示订单") :
      "独立本地演示订单" + (orders.reason ? "（" + orders.reason + "）" : "");
    $("#orders").innerHTML = orders.data.length ? orders.data.map(item => {
      const role = session?.user.role || "customer";
      const available = role === "worker" ? ({ pending_worker: ["accept", "接单"], accepted: ["arrive", "登记到场"],
        arrived: ["quote", "提交报价"], in_service: ["complete", "登记完工"] })[item.status]
        : item.status === "quote_pending" ? ["confirm-quote", "确认报价"] : null;
      return '<article class="record"><strong>' + safe(item.category) + " · " + safe(item.equipment) + " · " +
        safe(statuses[item.status]) + '</strong><small>' + safe(item.id) + '<br>' + safe(item.issue) + '<br>' + safe(item.address) +
        '<br>报价 ' + money(item.quotedAmountCents) + '；师傅 ' + money(item.workerShareCents) + '</small>' +
        (available ? '<div class="actions"><button data-operation="' + available[0] + '" data-id="' + safe(item.id) + '">' + available[1] + '</button></div>' : "") + '</article>';
    }).join("") : empty("暂时没有订单");
    $("#ordersMore").hidden = !orders.online || !orders.cursor;
    $("#ordersMore").disabled = false;
  }
  function renderLedger() {
    $("#ledgerSource").textContent = journals.online ? "服务端本人账务 · 模拟账本" :
      "本地空态预览：账务尚未获得服务端确认" + (journals.reason ? "（" + journals.reason + "）" : "");
    $("#ledger").innerHTML = journals.data.length ? journals.data.map(item => '<article class="record"><strong>' +
      (item.kind === "collection" ? "订单收款" : item.kind === "manual_payout" ? "结算核销" : "冲正") + " · " + money(item.amountCents) +
      '</strong><small>模拟账 / ' + safe(item.id) + '<br>订单 ' + safe(item.orderId) + '<br>' + safe(item.occurredAt) + '</small></article>').join("") : empty("暂无账务记录");
    $("#ledgerMore").hidden = !journals.online || !journals.cursor;
    $("#ledgerMore").disabled = false;
  }
  async function refreshOrders(more = false) {
    const snapshot = epoch, revision = ++ordersRevision, previous = orders;
    $("#ordersMore").disabled = true;
    let result;
    try {
      let cursor = "";
      const data = await request("/api/v1/orders?limit=100" + (more ? "&cursor=" + encodeURIComponent(previous.cursor) : ""),
        { response: res => { cursor = res.headers.get("X-Next-Cursor") || ""; } });
      if (!validOrders(data)) throw new Error("订单响应格式无效");
      result = { data: more ? [...new Map([...previous.data, ...data].map(item => [item.id, item])).values()] : data, online: true,
        cursor: cursor === previous.cursor && more ? "" : cursor };
    } catch (error) { result = { data: structuredClone(demoOrders), online: false, cursor: "", reason: error.message }; }
    if (snapshot !== epoch || revision !== ordersRevision) return;
    orders = result;
    renderOrders();
  }
  async function refreshLedger(more = false) {
    const snapshot = epoch, revision = ++ledgerRevision, previous = journals;
    $("#ledgerMore").disabled = true;
    let result;
    try {
      let cursor = "";
      const data = await request("/api/v1/ledger/journals?mode=simulated&limit=100" + (more ? "&cursor=" + encodeURIComponent(previous.cursor) : ""),
        { response: res => { cursor = res.headers.get("X-Next-Cursor") || ""; } });
      if (!Array.isArray(data) || !data.every(item => item && typeof item.id === "string" && typeof item.orderId === "string" &&
          item.mode === "simulated" && item.simulated === true && Number.isSafeInteger(item.amountCents) && item.amountCents >= 0 && typeof item.occurredAt === "string" &&
          ["collection", "manual_payout", "reversal"].includes(item.kind) && ["posted", "reversed"].includes(item.status) &&
          typeof item.customerId === "string" && typeof item.workerId === "string" &&
          ["platformFeeCents", "workerShareCents"].every(key => Number.isSafeInteger(item[key]) && item[key] >= 0))) {
        throw new Error("账务响应格式无效");
      }
      result = { data: more ? [...new Map([...previous.data, ...data].map(item => [item.id, item])).values()] : data, online: true,
        cursor: cursor === previous.cursor && more ? "" : cursor };
    } catch (error) { result = { data: [], online: false, cursor: "", reason: error.message }; }
    if (snapshot !== epoch || revision !== ledgerRevision) return;
    journals = result;
    renderLedger();
  }
  async function createQR() {
    stopQR();
    const revision = qrRevision, snapshot = epoch;
    $("#createQR").disabled = true;
    $("#qrState").textContent = "正在生成授权请求…";
    try {
      const challenge = await request("/api/v1/auth/qr/challenges", { anonymous: true, method: "POST", body: JSON.stringify({ device: device() }) });
      if (!challenge || typeof challenge.id !== "string" || typeof challenge.pollToken !== "string" ||
          typeof challenge.qrPayload !== "string" || !challenge.qrPayload.startsWith("repairmarketplace://login?") ||
          !Number.isFinite(Date.parse(challenge.expiresAt))) throw new Error("扫码请求响应无效");
      if (snapshot !== epoch || revision !== qrRevision) return;
      new QRCode($("#qrCode"), { text: challenge.qrPayload, width: 270, height: 270, correctLevel: QRCode.CorrectLevel.M });
      $("#qrPayload").value = challenge.qrPayload;
      $("#qrState").textContent = "等待手机扫描并确认；有效至 " + challenge.expiresAt;
      poll(challenge, revision, snapshot);
    } catch (error) {
      if (snapshot === epoch && revision === qrRevision) $("#qrState").textContent = "无法生成二维码：" + error.message + "。不会模拟登录成功。";
    } finally { $("#createQR").disabled = false; }
  }
  async function poll(challenge, revision, snapshot) {
    if (snapshot !== epoch || revision !== qrRevision || session) return;
    if (Date.parse(challenge.expiresAt) <= Date.now()) { $("#qrState").textContent = "二维码已过期，请重新生成。"; return; }
    try {
      const result = await request("/api/v1/auth/qr/challenges/" + encodeURIComponent(challenge.id) + "/poll", {
        anonymous: true, method: "POST", body: JSON.stringify({ pollToken: challenge.pollToken })
      });
      if (snapshot !== epoch || revision !== qrRevision) return;
      if (result?.status === "approved") { acceptSession(result.auth); note("手机已授权，此 PC 已独立登录。"); return; }
      if (["rejected", "expired", "consumed"].includes(result?.status)) {
        $("#qrState").textContent = ({ rejected: "手机已拒绝登录请求。", expired: "二维码已过期。", consumed: "登录结果已领取；如未登录成功，请重新扫码。" })[result.status];
        $("#qrPayload").value = "";
        $("#qrCode").innerHTML = "";
        return;
      }
      if (result?.status !== "pending") throw new Error("扫码状态响应无效");
    } catch (error) {
      if (snapshot !== epoch || revision !== qrRevision) return;
      $("#qrState").textContent = "授权状态尚未确认：" + error.message + "；有效期内继续查询。";
    }
    qrTimer = window.setTimeout(() => poll(challenge, revision, snapshot), 2000);
  }
  async function orderAction(action, id, button) {
    if (!["accept", "arrive", "quote", "confirm-quote", "complete"].includes(action) || actions.has(id)) return;
    let body = {};
    if (action === "quote") {
      const value = window.prompt("输入报价（元，最多两位小数）");
      if (value === null) return;
      const match = /^(\d{1,7})(?:\.(\d{1,2}))?$/.exec(value.trim());
      const cents = match ? Number(match[1]) * 100 + Number((match[2] || "").padEnd(2, "0")) : 0;
      if (!Number.isSafeInteger(cents) || cents < 1 || cents > 100000000) { note("请输入 0.01 至 1000000 元的有效报价。"); return; }
      body = { quoteCents: cents };
    }
    const snapshot = epoch;
    actions.add(id); button.disabled = true;
    try {
      const data = await request("/api/v1/orders/" + encodeURIComponent(id) + "/" + action, { method: "POST", body: JSON.stringify(body) });
      if (!validOrders([data])) throw new Error("操作响应格式无效");
      if (snapshot !== epoch) return;
      note("服务端已确认订单操作。");
      await refreshOrders();
    } catch (error) {
      if (snapshot !== epoch) return;
      const item = structuredClone(orders.data.find(value => value.id === id));
      if (item) {
        const states = { accept: ["pending_worker", "accepted"], arrive: ["accepted", "arrived"], quote: ["arrived", "quote_pending"],
          "confirm-quote": ["quote_pending", "in_service"], complete: ["in_service", "awaiting_payment"] };
        if (item.status === states[action][0]) {
          item.id = item.id.startsWith("local-") ? item.id : "local-copy-" + item.id;
          item.status = states[action][1];
          if (action === "accept") item.workerId = "worker-demo";
          if (action === "quote") {
            item.quotedAmountCents = body.quoteCents;
            item.workerShareCents = Math.floor((body.quoteCents * 85 + 50) / 100);
            item.platformFeeCents = body.quoteCents - item.workerShareCents;
          }
          demoOrders = demoOrders.filter(value => value.id !== item.id); demoOrders.push(item);
          orders = { data: structuredClone(demoOrders), online: false, cursor: "", reason: error.message };
          renderOrders();
        }
      }
      note("服务端操作未确认（" + error.message + "）；仅演示本地副本，不代表服务端成功，不自动补发。");
    } finally { actions.delete(id); button.disabled = false; }
  }
  $("#passwordLogin").addEventListener("submit", async event => {
    event.preventDefault(); const snapshot = epoch; const password = $("#password").value; $("#password").value = "";
    $("#passwordButton").disabled = true;
    try {
      const value = await request("/api/v1/auth/login", { anonymous: true, method: "POST", body: JSON.stringify({ username: $("#username").value.trim(), password, device: device() }) });
      if (snapshot !== epoch) return;
      acceptSession(value); note("此 PC 已独立登录，手机退出不会影响此会话。");
    } catch (error) { if (snapshot === epoch) note("登录失败：" + error.message + "。未创建本地账号身份。"); }
    finally { $("#passwordButton").disabled = false; }
  });
  $("#createOrder").addEventListener("submit", async event => {
    event.preventDefault(); const snapshot = epoch;
    const body = { category: $("#category").value, equipment: $("#equipment").value.trim(), issue: $("#issue").value.trim(), address: $("#address").value.trim(), scheduledAt: "" };
    const signature = JSON.stringify(body);
    if (!createAttempt || createAttempt.signature !== signature) createAttempt = { signature, key: requestKey() };
    $("#createButton").disabled = true;
    try {
      const data = await request("/api/v1/orders", { method: "POST", headers: { "Idempotency-Key": createAttempt.key }, body: signature });
      if (!validOrders([data])) throw new Error("创建响应无效");
      if (snapshot !== epoch) return;
      createAttempt = null; $("#createOrder").reset(); note("服务端已确认报修订单：" + data.id); await refreshOrders();
    } catch (error) {
      if (snapshot !== epoch) return;
      const id = "local-create-" + createAttempt.key;
      const item = { ...structuredClone(seed[0]), ...body, id };
      demoOrders = demoOrders.filter(value => value.id !== id); demoOrders.push(item);
      orders = { data: structuredClone(demoOrders), online: false, cursor: "", reason: error.message }; renderOrders();
      note("报修结果未获服务端确认（" + error.message + "）。仅生成本地演示订单；保留表单与原重试标识，不自动补发。");
    } finally { $("#createButton").disabled = false; }
  });
  $("#logout").addEventListener("click", async () => {
    const operation = request("/api/v1/auth/logout", { method: "POST" });
    clearSession();
    const snapshot = epoch;
    try { await operation; if (snapshot === epoch) note("已退出当前 PC，手机及其它设备会话保留。"); }
    catch (error) { if (snapshot === epoch) note("已清除当前 PC 凭据，服务端撤销尚未确认：" + error.message); }
  });
  $("#createQR").addEventListener("click", createQR);
  $("#refreshOrders").addEventListener("click", () => refreshOrders());
  $("#refreshLedger").addEventListener("click", () => refreshLedger());
  $("#ordersMore").addEventListener("click", () => refreshOrders(true));
  $("#ledgerMore").addEventListener("click", () => refreshLedger(true));
  function syncEnvironment() { $("#environment").value = currentEnvironment; $("#baseURL").value = activeAPIBase(); $("#baseURL").disabled = currentEnvironment === "production"; }
  $("#saveEnvironment").addEventListener("click", () => {
    try {
      const previousKey = storageKey();
      saveAPIEnvironment($("#environment").value, $("#baseURL").value);
      try { sessionStorage.removeItem(previousKey); } catch (_) {}
      clearSession(); syncEnvironment(); note("服务环境已切换，请重新登录。"); refreshOrders(); refreshLedger();
    } catch (error) { note(error.message); }
  });
  $("#environment").addEventListener("change", () => { $("#baseURL").value = $("#environment").value === "test" ? testBase : API_ENVIRONMENTS.production.baseURL; });
  document.addEventListener("click", event => {
    const button = event.target.closest("button[data-operation]");
    if (!button) return;
    if (button.dataset.operation === "reload") { refreshOrders(); refreshLedger(); }
    else orderAction(button.dataset.operation, button.dataset.id, button);
  });
  window.addEventListener("pagehide", stopQR);
  syncEnvironment(); renderOrders(); renderLedger();
  try { const saved = JSON.parse(sessionStorage.getItem(storageKey()) || "null"); if (validSession(saved)) session = saved; } catch (_) {}
  renderAccount(); refreshOrders(); refreshLedger();
  if (session) {
    const snapshot = epoch;
    request("/api/v1/auth/me").then(user => {
      if (snapshot !== epoch) return;
      if (!user || user.id !== session.user.id || user.role !== session.user.role) throw new Error("账号响应无效");
      session.user = user; persistSession(); renderAccount(); note("当前 PC 会话已验证，手机下线不影响此设备。");
    }).catch(error => { if (snapshot === epoch) note("会话状态尚未确认：" + error.message + "；刷新可重试。"); });
  } else createQR();
})();
