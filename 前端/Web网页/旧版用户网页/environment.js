// 仅切换头 URL，业务代码继续拼接 /api/v1/...；保留两套配置供后续部署。
const API_ENVIRONMENTS = Object.freeze({
  test: { title: "本机测试", baseURL: "http://127.0.0.1:8080" },
  production: { title: "线上环境", baseURL: "" } // 线上尚未部署，配置后填入域名。
});
const DEFAULT_API_ENVIRONMENT = "test";
// const DEFAULT_API_ENVIRONMENT = "production"; // 正式部署时切换，保留测试配置。
const API_REQUEST_TIMEOUT_MS = 2000;

function normalizeAPIBase(value) {
  const url = new URL(value.trim());
  if (!["http:", "https:"].includes(url.protocol) || !url.hostname ||
      url.username || url.password || url.search || url.hash || url.pathname !== "/") {
    throw new Error("请输入 http(s)://主机:端口，不包含接口路径、账号或查询参数。");
  }
  return url.origin;
}

function savedSetting(key) {
  try {
    return localStorage.getItem(key);
  } catch (_) {
    return null;
  }
}

const savedEnvironment = savedSetting("repairPortalApiEnvironment");
let currentEnvironment = Object.hasOwn(API_ENVIRONMENTS, savedEnvironment)
  ? savedEnvironment : DEFAULT_API_ENVIRONMENT;
// Go 同源托管的后台复用实际端口，Docker / Kubernetes 不需要分别写死地址。
const localServedBase = ["http:", "https:"].includes(location.protocol) &&
  (location.pathname === "/portal" || location.pathname.startsWith("/portal/"))
  ? location.origin : API_ENVIRONMENTS.test.baseURL;
let testBase = localServedBase;
try {
  const savedBase = savedSetting("repairPortalTestApiBase");
  if (savedBase) testBase = normalizeAPIBase(savedBase);
} catch (_) {
  // 无效的旧地址不阻断首屏演示。
}
let environmentRevision = 0;

function activeAPIBase() {
  return currentEnvironment === "test" ? testBase : API_ENVIRONMENTS.production.baseURL;
}

function saveAPIEnvironment(environment, value) {
  if (!Object.hasOwn(API_ENVIRONMENTS, environment)) throw new Error("未知服务环境");
  const nextTestBase = environment === "test" ? normalizeAPIBase(value) : testBase;
  try {
    localStorage.setItem("repairPortalApiEnvironment", environment);
    localStorage.setItem("repairPortalTestApiBase", nextTestBase);
  } catch (_) {
    // 禁用浏览器存储时仍允许本页切换，刷新后恢复默认值。
  }
  currentEnvironment = environment;
  testBase = nextTestBase;
  environmentRevision += 1;
}
