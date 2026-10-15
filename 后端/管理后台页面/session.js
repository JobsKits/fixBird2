// 管理员凭据只保留在当前页面内存，切换服务、退出或刷新页面后重新登录。
const AdminSession = (() => {
  let session = null;
  let revision = 0;
  let listener = () => {};
  const scope = () => currentEnvironment + ":" + activeAPIBase();
  function clear(expectedRevision) {
    if (expectedRevision !== undefined && expectedRevision !== revision) return;
    if (!session) return;
    session = null;
    revision += 1;
    listener();
  }
  function current() {
    if (session && (session.scope !== scope() || Date.parse(session.expiresAt) <= Date.now())) clear();
    return session;
  }
  function set(value) {
    if (!value || typeof value.token !== "string" || !value.token ||
        !Number.isFinite(Date.parse(value.expiresAt)) || Date.parse(value.expiresAt) <= Date.now() ||
        !value.user || !["admin", "operator"].includes(value.user.role) || typeof value.user.id !== "string") {
      throw new Error("登录响应无效，或此账号没有后台访问权限");
    }
    session = { ...value, scope: scope() };
    revision += 1;
    listener();
  }
  return {
    set, clear, current,
    headers: () => { const value = current(); return value ? { Authorization: "Bearer " + value.token } : {}; },
    get revision() { return revision; },
    onChange(fn) { listener = fn; }
  };
})();
