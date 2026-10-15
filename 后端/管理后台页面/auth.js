(() => {
  const $ = selector => document.querySelector(selector);
  let mode = "Login";
  let workspaceTab = "Business";
  let revision = 0;
  let accountRevision = 0;
  let lastSessionRevision = -1;
  let recovery = "";
  let accounts = [];
  let cursor = "";
  const roleName = role => ({ admin: "管理员", operator: "普通账号", customer: "App 用户", worker: "维修师傅" })[role] || role;
  function feedback(text) { $("#authFeedback").textContent = text; }
  function showMode(next) {
    revision += 1;
    mode = next;
    recovery = "";
    feedback("");
    for (const name of ["Login", "Register", "Forgot"]) {
      $("#tab" + name).setAttribute("aria-pressed", String(name === next));
      $("#admin" + name).hidden = name !== next;
    }
    $("#authTitle").textContent = ({ Login: "登录运营工作台", Register: "开通平台账号", Forgot: "找回账号访问权" })[next];
    $("#authDescription").textContent = ({ Login: "使用平台账号登录，开始处理业务。", Register: "账号与权限由管理员统一管理。", Forgot: "使用已保存的恢复码验证身份；没有恢复码请联系管理员。" })[next];
  }
  function download(code) {
    if (!code) return;
    const url = URL.createObjectURL(new Blob(["啄木鸟维修平台 · 账号恢复码\n" + code + "\n请妥善保存，不要发送给他人。"], { type: "text/plain;charset=utf-8" }));
    const link = document.createElement("a"); link.href = url; link.download = "啄木鸟-账号恢复码.txt"; link.click();
    window.setTimeout(() => URL.revokeObjectURL(url), 1000);
  }
  function sync() {
    const session = AdminSession.current();
    const admin = session?.user.role === "admin";
    $("#authGate").hidden = !!session;
    $("#adminWorkspace").hidden = !session;
    $("#administratorManagement").hidden = !admin;
    $("#identityReviewPanel").hidden = !admin;
    $("#workspaceBusiness").hidden = workspaceTab !== "Business";
    $("#workspaceSettings").hidden = workspaceTab !== "Settings";
    $("#authBase").value = activeAPIBase();
    if (lastSessionRevision !== AdminSession.revision) {
      lastSessionRevision = AdminSession.revision;
      revision += 1;
      accountRevision += 1;
      workspaceTab = "Business";
      $("#workspaceBusiness").hidden = false; $("#workspaceSettings").hidden = true;
      accounts = []; cursor = "";
      recovery = "";
      $("#workspaceRecoveryCode").textContent = "";
      $("#workspaceRecovery").hidden = true;
      $("#accountsFeedback").textContent = "";
      renderAccounts();
      if (admin) loadAccounts();
    }
  }
  function renderAccounts() {
    $("#accountsMore").hidden = !cursor;
    $("#administratorAccounts").innerHTML = accounts.length ? accounts.map(user =>
      '<div class="account-row"><div><strong>' + safe(user.displayName) + '</strong><p>' + safe(user.username) + ' · ' + safe(roleName(user.role)) + ' · ' + (user.status === "disabled" ? "已封停" : "正常") + '</p></div>' +
      (user.id === AdminSession.current()?.user.id ? '<span class="muted">当前账号</span>' : '<button class="button secondary" data-account="' + safe(user.username) + '" data-account-status="' + (user.status === "disabled" ? "active" : "disabled") + '">' + (user.status === "disabled" ? "解除封停" : "封停账号") + '</button>') + '</div>').join("") :
      '<div class="empty-state"><strong>暂无账号记录</strong><p>重新加载服务端账号列表。</p><button class="button secondary" id="accountsEmptyReload" type="button">重新加载</button></div>';
    $("#accountsEmptyReload")?.addEventListener("click", () => loadAccounts());
  }
  async function loadAccounts(more = false) {
    if (AdminSession.current()?.user.role !== "admin") return;
    const expected = ++accountRevision;
    const sessionRevision = AdminSession.revision;
    try {
      let next = "";
      const rows = await request("/api/v1/admin/accounts" + (more && cursor ? "?cursor=" + encodeURIComponent(cursor) : ""), {
        onResponse: response => { next = response.headers?.get("X-Next-Cursor") || ""; }
      });
      if (expected !== accountRevision || sessionRevision !== AdminSession.revision) return;
      if (!Array.isArray(rows) || rows.some(user => !user || typeof user.username !== "string" || !["admin", "operator", "customer", "worker"].includes(user.role))) throw Error("账号列表响应无效");
      accounts = more ? [...accounts, ...rows] : rows;
      cursor = next; renderAccounts();
      $("#accountsFeedback").textContent = "服务端账号列表已加载。";
    } catch (error) {
      if (expected !== accountRevision || sessionRevision !== AdminSession.revision) return;
      if (!more) { accounts = []; cursor = ""; renderAccounts(); }
      $("#accountsFeedback").textContent = "账号列表未加载：" + error.message;
    }
  }
  for (const name of ["Business", "Settings"]) $("#nav" + name).addEventListener("click", () => { workspaceTab = name; sync(); });
  for (const name of ["Login", "Register", "Forgot"]) $("#tab" + name).addEventListener("click", () => showMode(name));
  $("#authSaveBase").addEventListener("click", () => {
    try { saveAPIEnvironment("test", $("#authBase").value); syncEnvironmentFields(); sync(); feedback("服务地址已保存。"); }
    catch (error) { feedback("地址未保存：" + error.message); }
  });
  $("#adminForgot").addEventListener("submit", async event => {
    event.preventDefault();
    const expected = revision;
    const password = $("#forgotPassword").value;
    if (password !== $("#forgotConfirm").value) { feedback("两次输入的密码不一致。"); return; }
    const body = { username: $("#forgotUsername").value.trim(), recoveryCode: $("#forgotCode").value.trim(), password };
    $("#forgotPassword").value = ""; $("#forgotConfirm").value = ""; $("#forgotCode").value = "";
    $("#forgotButton").disabled = true;
    try {
      await request("/api/v1/auth/password-reset", { method: "POST", body: JSON.stringify(body) });
      if (expected !== revision) return;
      showMode("Login"); $("#adminUsername").value = body.username;
      feedback("密码已重置，旧会话和恢复码已失效。请使用新密码登录，再生成新的恢复码。");
    } catch (error) { if (expected === revision) feedback("重置未确认：" + error.message + "。未模拟成功，请核对后重新操作。"); }
    finally { $("#forgotButton").disabled = false; }
  });
  $("#changeOwnPassword").addEventListener("submit", async event => {
    event.preventDefault();
    const expected = AdminSession.revision;
    const body = { currentPassword: $("#ownCurrentPassword").value, password: $("#ownNewPassword").value };
    $("#ownCurrentPassword").value = ""; $("#ownNewPassword").value = "";
    $("#ownPasswordButton").disabled = true;
    try {
      await request("/api/v1/auth/password", { method: "POST", body: JSON.stringify(body) });
      if (expected !== AdminSession.revision) return;
      AdminSession.clear(expected); feedback("密码已修改，所有旧会话已撤销，请重新登录。");
    } catch (error) { if (expected === AdminSession.revision) { $("#operationsState").hidden = false; $("#operationsState").textContent = "修改密码未确认：" + error.message; } }
    finally { $("#ownPasswordButton").disabled = false; }
  });
  $("#generateRecovery").addEventListener("click", async () => {
    const expected = AdminSession.revision;
    $("#generateRecovery").disabled = true;
    try {
      const result = await request("/api/v1/auth/recovery-code", { method: "POST", body: "{}" });
      if (expected !== AdminSession.revision) return;
      if (typeof result?.recoveryCode !== "string" || result.recoveryCode.length !== 43) throw Error("恢复码响应无效");
      recovery = result.recoveryCode;
      $("#workspaceRecoveryCode").textContent = recovery; $("#workspaceRecovery").hidden = false;
    } catch (error) { if (expected === AdminSession.revision) { $("#operationsState").hidden = false; $("#operationsState").textContent = "恢复码生成未确认：" + error.message; } }
    finally { $("#generateRecovery").disabled = false; }
  });
  $("#downloadWorkspaceRecovery").addEventListener("click", () => download(recovery));
  $("#accountsReload").addEventListener("click", () => loadAccounts());
  $("#accountsMore").addEventListener("click", () => loadAccounts(true));
  $("#addAdministrator").addEventListener("submit", async event => {
    event.preventDefault();
    const expected = AdminSession.revision;
    const body = { username: $("#newAdminUsername").value.trim(), displayName: $("#newAdminName").value.trim(), password: $("#newAdminPassword").value, role: $("#newAdminRole").value };
    $("#newAdminPassword").value = ""; $("#newAdminButton").disabled = true;
    try {
      const result = await request("/api/v1/admin/accounts", { method: "POST", body: JSON.stringify(body) });
      if (expected !== AdminSession.revision) return;
      if (!result?.user || result.user.username !== body.username.toLowerCase() || result.user.role !== body.role) throw Error("新增账号响应无效");
      await loadAccounts();
      if (expected === AdminSession.revision) $("#accountsFeedback").textContent = "账号已创建：" + result.user.username + "（" + roleName(result.user.role) + "）。";
    } catch (error) { if (expected === AdminSession.revision) $("#accountsFeedback").textContent = "新增账号未确认：" + error.message + "。请先重新加载核对，未创建本地账号。"; }
    finally { $("#newAdminButton").disabled = false; }
  });
  $("#resetAdministrator").addEventListener("submit", async event => {
    event.preventDefault();
    const expected = AdminSession.revision;
    const username = $("#resetAdminUsername").value.trim().toLowerCase();
    const password = $("#resetAdminPassword").value; $("#resetAdminPassword").value = "";
    $("#resetAdminButton").disabled = true;
    try {
      await request("/api/v1/admin/accounts/" + encodeURIComponent(username) + "/password", { method: "POST", body: JSON.stringify({ password }) });
      if (expected !== AdminSession.revision) return;
      if (username === AdminSession.current()?.user.username) { AdminSession.clear(expected); feedback("密码已重置，请重新登录。"); }
      else $("#accountsFeedback").textContent = "密码已重置，该账号旧会话和恢复码已撤销。";
    } catch (error) { if (expected === AdminSession.revision) $("#accountsFeedback").textContent = "重置未确认：" + error.message; }
    finally { $("#resetAdminButton").disabled = false; }
  });
  document.addEventListener("click", async event => {
    const button = event.target.closest("button[data-account-status]");
    if (!button || button.disabled) return;
    const expected = AdminSession.revision;
    const username = button.dataset.account;
    if (!window.confirm((button.dataset.accountStatus === "disabled" ? "封停" : "解除封停") + "账号 " + username + "？封停会撤销该账号全部会话。")) return;
    button.disabled = true;
    try {
      await request("/api/v1/admin/accounts/" + encodeURIComponent(username) + "/status", { method: "POST", body: JSON.stringify({ status: button.dataset.accountStatus }) });
      if (expected === AdminSession.revision) await loadAccounts();
    } catch (error) { if (expected === AdminSession.revision) $("#accountsFeedback").textContent = "账号状态未确认：" + error.message; }
    finally { button.disabled = false; }
  });
  window.AuthGate = { sync, loadAccounts };
  showMode("Login"); sync();
})();
