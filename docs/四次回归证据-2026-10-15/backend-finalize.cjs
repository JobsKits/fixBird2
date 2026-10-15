const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const project = '/Users/jobs/Desktop/啄木鸟维修平台-V3.8';
const evidence = path.join(project,'docs/四次回归证据-2026-10-15');
const runtime = JSON.parse(fs.readFileSync(path.join(evidence,'backend-runtime.json')));
const digest = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
function summarize(file) {
  const events = fs.readFileSync(path.join(evidence,file),'utf8').trim().split('\n').filter(line=>line.startsWith('{')).map(line=>JSON.parse(line));
  const tests = events.filter(e=>e.Test && ['pass','fail','skip'].includes(e.Action));
  const roots = tests.filter(e=>!e.Test.includes('/'));
  const leaves = tests.filter(e=>!tests.some(other=>other.Test.startsWith(e.Test+'/')));
  const count = values => ({tests:values.length,pass:values.filter(e=>e.Action==='pass').length,fail:values.filter(e=>e.Action==='fail').length,skip:values.filter(e=>e.Action==='skip').length});
  return {exitCode:events.some(e=>!e.Test && e.Action==='fail')?1:0,...count(tests),roots:count(roots),children:count(tests.filter(e=>e.Test.includes('/'))),leaves:count(leaves),failedTests:tests.filter(e=>e.Action==='fail').map(e=>e.Test),raceDetected:events.some(e=>(e.Output||'').includes('WARNING: DATA RACE'))};
}
const unchanged = runtime.copied.every(item => digest(fs.readFileSync(path.join(project,'Server',item.path))) === item.sha256);
const isolatedCopyMatched = runtime.copied.every(item => digest(fs.readFileSync(path.join(runtime.server,item.path))) === item.sha256);
if (!unchanged || !isolatedCopyMatched) throw new Error('Source verification failed');
const findings = [
 {id:'R4-B01',priority:'P2',title:'真实端质保日历月计算溢出且未按中国日期截月末',status:'confirmed',file:'Server/internal/workbench/actions.go',line:970,requirement:{file:'需求/物业设备维修服务平台 PRD V3.8（Jobs规范版）.md',line:1832},impact:'人工和自动验收持久化错误质保截止日，可能延长数日；与独立演示及已约定截止日期不一致。',examples:[{acceptedAt:'2026-01-31T10:00:00+08:00',months:3,actual:'2026-05-01T02:00:00Z',expected:'2026-04-30T02:00:00Z'},{acceptedAt:'2024-01-31T10:00:00+08:00',months:1,actual:'2024-03-02T02:00:00Z',expected:'2024-02-29T02:00:00Z'},{acceptedAt:'2026-01-31T02:00:00+08:00',months:1,actual:'2026-03-02T18:00:00Z',expected:'2026-02-27T18:00:00Z'}],tests:['TestR4BackendManualWarrantyCalendar','TestR4BackendAutoWarrantyCalendar'],reproduction:'控制墙钟后，对 wo_quote 依次 quote（新报价时长）、approve_quote、sign_quote、start、finish、qc、deliver、accept；实际 Service.transact 保存后检查响应与持久快照。自动验收改为 deliver 后跨过自然日截止再 SweepAutoAcceptance。'},
 {id:'R4-B02',priority:'P2',title:'截止日当天在原验收时刻即提前显示质保到期',status:'confirmed',file:'Server/internal/workbench/service.go',line:533,related:[{file:'Workspace/data.js',line:374}],requirement:{file:'需求/物业设备维修服务平台 PRD V3.8（Jobs规范版）.md',line:1832},impact:'截止日尚未结束时客户查询已显示到期；可能造成售后处理依据错误。演示同因由另一路独立测试确认。',example:{acceptedAt:'2026-10-06T10:00:00+08:00',months:3,now:'2027-01-06T23:59:59+08:00',actual:'质保到期',expected:'质保中',expiration:'2027-01-07T00:00:00+08:00'},tests:['TestR4BackendWarrantyInclusiveFinalDay'],reproduction:'实际交易链完成普通3个月验收，单独控制墙钟检查截止日09:59:59、10:00:00、23:59:59和次日00:00；中间两项错误，前后正对照正确。'},
 {id:'R4-B03',priority:'P2',title:'不通过的验收提交接受签名后未保留签署原件',status:'confirmed',file:'Server/internal/workbench/actions.go',line:475,requirement:{file:'需求/物业设备维修服务平台 PRD V3.8（Jobs规范版）.md',lines:[401,409,1219,1229]},impact:'API 接受 passed=false 的有效客户签名并成功保存异议，却丢弃签名原件；重启后无法还原客户此次签署依据。',limits:'普通页面的当前手写入口固定 passed=true；确认的是已公开合同支持的 API passed=false 路径。此缺陷不会自动转为验收通过，也不属于绕过权限。',tests:['TestR4BackendRejectedAcceptanceRetainsSubmittedSignature/submitted_signature_is_durably_retained'],reproduction:'完整动作链达到待验收；客户发送 accept passed=false、唯一有效PNG签名和文字异议；确认事务成功、异议保留且未起保，检查持久快照不存在该签名，再重启核验拒绝仍保留。'},
];
const result = {date:'2026-10-15',mode:'read_only_product_diagnostics',completed:true,command:'Tools/go/bin/go test -race -count=1 -run ^TestR4Backend -json ./internal/workbench（独立 Server 副本）',tests:summarize('backend-deep.log'),repeat:summarize('backend-reproduction-repeat.log'),findings,suspicions:[],sourceVerification:{copied:runtime.copied.length,goFiles:runtime.copied.filter(item=>item.path.endsWith('.go')).length,allProductSourceUnchanged:unchanged,allIsolatedBaselineMatches:isolatedCopyMatched},artifacts:['backend-deep-fourth_test.go','backend-deep.log','backend-reproduction-repeat.log','backend-runtime.json'],hashes:runtime.copied.filter(item=>['internal/workbench/actions.go','internal/workbench/service.go','internal/workbench/models.go','internal/workbench/inventory.go'].includes(item.path))};
if (!runtime.temporary.startsWith(require('node:os').tmpdir()+path.sep+'jobs-v38-r4-backend-')) throw new Error('Unexpected temporary path');
fs.rmSync(runtime.temporary,{recursive:true,force:false});
result.cleanup={temporaryPath:runtime.temporary,removed:!fs.existsSync(runtime.temporary),createdListeners:false,createdContainers:false,touchedExistingRuntime:false};
result.artifacts.forEach(file=>result.hashes.push({path:file,sha256:digest(fs.readFileSync(path.join(evidence,file)))}));
fs.writeFileSync(path.join(evidence,'backend-findings.json'),JSON.stringify(result,null,2)+'\n');
process.stdout.write(JSON.stringify({tests:result.tests,repeat:result.repeat,findings:findings.map(f=>f.id),sourceVerification:result.sourceVerification,cleanup:result.cleanup},null,2)+'\n');
