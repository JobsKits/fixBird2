const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '../..');
const summary = JSON.parse(fs.readFileSync(path.join(__dirname, 'test-summary.json'), 'utf8'));
if (!summary.completed || summary.web.fail || summary.http.exitCode || !summary.browser.passed) throw Error('最终验证未完成');
const metrics = `网页 ${summary.web.pass} 项、HTTP 6 组、语法检查及实际页面回归通过`;
function paragraph(file, prefix, value) {
  const location = path.join(root, file);
  const lines = fs.readFileSync(location, 'utf8').split('\n');
  const index = lines.findIndex(line => line.startsWith(prefix));
  if (index < 0) throw Error(`${file}: 找不到最新状态`);
  lines[index] = value;
  fs.writeFileSync(location, lines.join('\n'));
}
function replace(file, before, after) {
  const location = path.join(root, file);
  const source = fs.readFileSync(location, 'utf8');
  if (!source.includes(before)) throw Error(`${file}: 找不到替换目标`);
  fs.writeFileSync(location, source.replace(before, after));
}
paragraph('README.md','**最新验证：2026-10-15 第三轮回归',`**最新修复：2026-10-15 第三轮发现的两项问题已修复。** ${metrics}，身份切换旧快照隔离及演示备注更新已纳入正式保护测试，详见 [三次修复说明](./docs/三次修复说明-2026-10-15.md)。[第三轮回归报告](./docs/三次回归报告-2026-10-15.md) 保留修复前失败；后端未修改，既有 Go／数据库结果保留为历史基线。`);
paragraph('部署文档.md','**最新第三轮回归未全部通过。**',`**第三轮两项问题已修复。** ${metrics}，详见 [三次修复说明](./docs/三次修复说明-2026-10-15.md)。身份切换立即废弃旧授权快照，新响应按当前会话校验；演示备注按字段更新。原 [第三轮失败报告](./docs/三次回归报告-2026-10-15.md) 保留历史，后端源码一致性与历史数据库验证分别记录。`);
replace('部署文档.md','核对日期：2026-10-14。','核对日期：2026-10-15。');
paragraph('docs/实现范围.md','最新第三轮回归 **未全部通过**',`最新第三轮的两项前端问题 **已修复并验证**：${metrics}。身份切换、迟到 metadata、失败与重连、备注省略／清空／权限均有正式保护测试；结果见 [三次修复说明](./三次修复说明-2026-10-15.md)，[原回归报告](./三次回归报告-2026-10-15.md) 保留历史。后端未改，本轮未重复整套数据库测试，下方既有 Go／数据库结果仍为历史基线。`);
paragraph('AGENTS.md','最新独立回归先读', '最新修复与验证先读 [三次修复说明](./docs/三次修复说明-2026-10-15.md)，再按地图定位；[第三轮回归报告](./docs/三次回归报告-2026-10-15.md) 保留两项修复前失败，历史测试不能替代当前变更验证。');
replace('AGENTS.md','修复验证看 [二次修复说明](./docs/二次修复说明-2026-10-14.md)。','修复验证看 [三次修复说明](./docs/三次修复说明-2026-10-15.md)。');
replace('README.md','[二次修复与证据](./docs/二次修复说明-2026-10-14.md)','[三次修复与证据](./docs/三次修复说明-2026-10-15.md)');
replace('代码地图.md','最新独立检查见 [三次回归报告](./docs/三次回归报告-2026-10-15.md)，新增身份快照隔离和演示备注问题尚未修复；先查 `login`、`currentOrders`、`applySnapshotMetadata` 与 `data.js` 的 `apply`。已完成的 9 项修复与保护测试见 [二次修复说明](./docs/二次修复说明-2026-10-14.md)。','身份快照隔离、演示备注字段更新与新增正式保护见 [三次修复说明](./docs/三次修复说明-2026-10-15.md)；原 [第三轮回归报告](./docs/三次回归报告-2026-10-15.md) 保留历史失败。');
replace('docs/三次回归报告-2026-10-15.md','## 🔥 <span id="前言">前言</span>','## 🔥 <span id="前言">前言</span>\n\n**后续状态：本报告两项问题已修复并完成本轮网页、HTTP 与实际页面验证。** 最新结果见 [三次修复说明](./三次修复说明-2026-10-15.md)；以下数字和未修状态保留为修复前历史，不改写失败证据。');
replace('docs/三次修复说明-2026-10-15.md','<!-- FINAL_OUTCOME -->',`**第三轮两项问题已修复，${metrics}，0 失败、0 跳过。** 本轮完成身份数据隔离与合成备注字段更新，并将第三轮交叉诊断纳入正式测试。`);
const table = `| 检查 | 本轮执行结果 | 证据 |\n| --- | --- | --- |\n| 全部网页正式测试 | ${summary.web.pass} 项通过，0 失败、0 跳过，退出 0；旧 26＋Workspace ${summary.web.pass-26} | [日志](./三次修复验证-2026-10-15/web-tests.log) |\n| 第三轮原外部交叉保护诊断 | ${summary.externalFrontend.pass}／${summary.externalFrontend.tests} 通过，0 失败 | [日志](./三次修复验证-2026-10-15/external-frontend-tests.log) |\n| 独立 HTTP 合同 | 6 组通过，退出 0，包含原子写入与权限流程 | [日志](./三次修复验证-2026-10-15/http-smoke.log) |\n| 网页与正式测试语法 | node --check 退出 0 | [汇总](./三次修复验证-2026-10-15/test-summary.json) |\n| 本机后端构建与运行 | [**MacOS**](https://www.apple.com.cn/macos) ARM64 构建通过，专用合成后端与实际网页连通 | [构建](./三次修复验证-2026-10-15/native-build.log) |\n| 独立代码审查 | 身份切换与回退／重连边界复核完成，无未处理阻断项 | [记录](./三次修复验证-2026-10-15/review.json) |\n| 源码范围 | 119 个基线文件中 4 个网页／测试变更，115 个保持一致，后端未变 | [核验](./三次修复验证-2026-10-15/source-verification.json) |`;
replace('docs/三次修复说明-2026-10-15.md','<!-- FINAL_RESULTS -->',table);
const current = '/Users/jobs/Documents/Github/啄木鸟维修平台/需求';
for (const [name, destination] of [
  ['三次回归报告-2026-10-15.md','三次回归分析与测试报告-V3.8-2026-10-15.md'],
  ['三次修复说明-2026-10-15.md','三次修复与回归报告-V3.8-2026-10-15.md'],
]) {
  const source = fs.readFileSync(path.join(root,'docs',name),'utf8');
  const adjusted = source.replace(/\]\((\.\.?\/)([^)]*)\)/g,(_,base,target)=>']('+'../../../../Desktop/啄木鸟维修平台-V3.8'+(base==='./'?'/docs/':'/')+target+')');
  fs.writeFileSync(path.join(current,destination),adjusted);
}
console.log('最终说明、历史后续入口及当前文件夹副本已更新');
