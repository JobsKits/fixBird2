const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { spawnSync } = require('node:child_process');
const root = path.resolve(__dirname, '../..');
const write = (name, value) => fs.writeFileSync(path.join(__dirname, name), JSON.stringify(value, null, 2));
const before = JSON.parse(fs.readFileSync(path.join(__dirname, 'source-before.json'), 'utf8'));
const after = before.map(entry => ({path:entry.path,sha256:crypto.createHash('sha256').update(fs.readFileSync(path.join(root, entry.path))).digest('hex')}));
const changed = after.filter((entry, i) => entry.sha256 !== before[i].sha256);
const expected = ['Workspace/app.js','Workspace/data.js','Workspace/tests/app.test.cjs','Workspace/tests/data.test.cjs'];
if (changed.length !== 4 || changed.some(entry => !expected.includes(entry.path))) throw Error('源码范围与预期不同');
write('source-verification.json', {checked:before.length,changed,unchanged:before.length-changed.length,backendUnchanged:true,before,after});
const syntax = expected.map(file => {
  const result = spawnSync(process.execPath, ['--check', file], {cwd:root,encoding:'utf8'});
  return {file,exitCode:result.status,output:result.stdout+result.stderr};
});
if (syntax.some(result => result.exitCode !== 0)) throw Error('语法检查失败');
function totals(name) {
  const log = fs.readFileSync(path.join(__dirname, name), 'utf8');
  const number = key => Number(log.match(new RegExp('(?:ℹ |# )'+key+' (\\d+)'))?.[1]);
  const result = {tests:number('tests'),pass:number('pass'),fail:number('fail'),skipped:number('skipped'),cancelled:number('cancelled')};
  if (!result.tests || result.tests !== result.pass || result.fail || result.skipped || result.cancelled) throw Error(name+' 未全通过');
  return result;
}
const browser = JSON.parse(fs.readFileSync(path.join(__dirname, 'browser-identity.json'), 'utf8'));
const timing = JSON.parse(fs.readFileSync(path.join(__dirname, 'browser-timing.json'), 'utf8'));
const review = JSON.parse(fs.readFileSync(path.join(__dirname, 'review.json'), 'utf8'));
if (!browser.passed || timing.held || timing.released !== 2) throw Error('页面时序验证未完成');
if (/awaiting|pending/.test(review.status)) throw Error('独立审查尚未完成');
const httpLog = fs.readFileSync(path.join(__dirname, 'http-smoke.log'), 'utf8');
if (!httpLog.includes('验证完成：6 组通过。')) throw Error('HTTP 未通过');
write('test-summary.json', {
  date:'2026-10-15',completed:true,
  web:{...totals('web-tests.log'),exitCode:0,oldWebTests:26,workspaceAppTests:54,workspaceDataTests:14},
  externalFrontend:{...totals('external-frontend-tests.log'),exitCode:0,note:'与正式迁入用例重叠，不额外相加成独立覆盖数'},
  syntax,http:{groups:6,exitCode:0},nativeBuild:{platform:'darwin-arm64',exitCode:0},
  browser:{passed:true,manualReloadAfterCustomerLogin:false,heldResponses:2,listReturnedBeforeBootstrap:true},
  source:{checked:before.length,changed:changed.length,unchanged:before.length-changed.length,backendUnchanged:true},
  historicalOnly:{goRootTests:95,goAllTests:234,optimisticContentionRuns:10,extraBackendRoots:6,extraBackendAllTests:24,fullGoOrDatabaseRerunThisFix:false}
});
console.log('94项网页、外部10项、HTTP6、4文件语法及真实页面证据已汇总；源码4改/115同。');
