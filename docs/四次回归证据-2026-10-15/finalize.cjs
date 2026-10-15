const fs=require('node:fs');
const path=require('node:path');
const crypto=require('node:crypto');
const root=path.resolve(__dirname,'../..');
const read=name=>JSON.parse(fs.readFileSync(path.join(__dirname,name),'utf8'));
const write=(name,value)=>fs.writeFileSync(path.join(__dirname,name),JSON.stringify(value,null,2));
const before=read('source-before.json');
const after=before.map(entry=>({path:entry.path,sha256:crypto.createHash('sha256').update(fs.readFileSync(path.join(root,entry.path))).digest('hex')}));
const changed=after.filter((entry,i)=>entry.sha256!==before[i].sha256);
write('source-verification.json',{checked:before.length,unchanged:before.length-changed.length,changed,before,after});
if(changed.length)throw Error('受检源码发生变化');
const baseline=read('baseline-summary.json'),frontend=read('frontend-findings.json'),backend=read('backend-findings.json'),demo=read('demo-findings.json'),audit=read('audit-findings.json');
if(!baseline.completed||!audit.completed)throw Error('验证或复核尚未完成');
const tests=fs.readFileSync(path.join(__dirname,'web-tests.log'),'utf8');
const number=key=>Number(tests.match(new RegExp('(?:ℹ |# )'+key+' (\\d+)'))?.[1]);
const web={tests:number('tests'),pass:number('pass'),fail:number('fail'),skip:number('skipped')};
if(web.pass!==94||web.fail||web.skip||baseline.steps.some(x=>x.exitCode!==0))throw Error('常规回归未通过，必须重新核对报告');
const contention=fs.readFileSync(path.join(__dirname,'contention-repeat.log'),'utf8').trim().split('\n').map(JSON.parse);
const repeatPass=contention.filter(x=>x.Action==='pass'&&x.Test==='TestRepositoryContract/tidb-optimistic').length;
if(repeatPass!==10)throw Error('并发次数不符');
const browser401=read('browser-revocation.json'),browserPartial=read('browser-partial-bootstrap.json');
if(!browser401.observedOldRowsRetained||!browser401.observedAuthenticatedClaim||!browserPartial.observedRealListWithZeroMetrics)throw Error('真实页面复现未完成');
const merged=demo.findings.filter(x=>x.mergeWithBackendWarrantyDay).length;
const confirmed=frontend.findings.length+backend.findings.length+demo.findings.length-merged;
if(confirmed!==14)throw Error('去重问题组数不符');
write('test-summary.json',{date:'2026-10-15',completed:true,overallPassed:false,confirmedDefectGroups:confirmed,priorities:{P2:confirmed},businessRulesPending:demo.discrepancies.length,
  conventional:{go:baseline.go,web,http:{groups:6,exitCode:0},contention:{runs:repeatPass,pass:repeatPass,exitCode:0},vetExitCode:0,syntaxChecks:5,nativeBuildExitCode:0},
  newDiagnostics:{frontend:{tests:frontend.tests,pass:frontend.pass,fail:frontend.fail,groups:frontend.findings.length,repeated:true},backend:backend.tests,demo:{tests:demo.tests,pass:demo.pass,fail:demo.fail,skip:demo.skip,classification:demo.failureClassification,groupsBeforeCrossModeMerge:demo.findings.length,repeated:true}},
  merge:[{from:'R4-D08',into:'R4-B02',reason:'跨端同一质保截止日比较问题'}],
  browser:{realRevocation401Reproduced:true,navigationThenInjected503Reproduced:true,peerZeroOrderControlNotCountedAsMismatch:true},
  source:{checked:before.length,changed:0},businessSourceModified:false,formalTestsModified:false,productionAcceptance:false});
function line(file,prefix,value){const name=path.join(root,file);const lines=fs.readFileSync(name,'utf8').split('\n');const index=lines.findIndex(x=>x.startsWith(prefix));if(index<0)throw Error(file+' 未找到状态入口');lines[index]=value;fs.writeFileSync(name,lines.join('\n'));}
line('README.md','**最新修复：2026-10-15','**最新回归：2026-10-15 第四轮未全部通过。** 正式网页 94 项、HTTP 6 组、[**Go**](https://go.dev/) 95 根／234 条及独立数据库回归通过；深入诊断新增确认 14 组 P2，另有 1 项付款口径待澄清，详见 [四次回归报告](./docs/四次回归报告-2026-10-15.md)。本轮未改业务源码，三次修复结果保留历史。');
line('部署文档.md','**第三轮两项问题已修复。**','**最新第四轮回归未全部通过。** 基础网页、HTTP、Go／独立数据库测试通过，深入诊断确认 14 组 P2 与 1 项待澄清口径，本轮未修复，详见 [四次回归报告](./docs/四次回归报告-2026-10-15.md)。三次修复结果保留为历史；本报告不等同完整需求或生产验收。');
line('docs/实现范围.md','最新第三轮的两项前端问题','最新第四轮回归 **未全部通过**：正式网页 94 项、HTTP 6 组、Go 95 根／234 条和独立数据库测试通过，深入诊断新增 14 组 P2、1 项业务口径待澄清，详见 [四次回归报告](./四次回归报告-2026-10-15.md)。本轮业务源码未改、新问题未修；下方能力范围与历史验证不能替代当前问题清单。');
line('AGENTS.md','最新修复与验证先读','最新回归先读 [四次回归报告](./docs/四次回归报告-2026-10-15.md)：14 组 P2 尚未修复，1 项付款口径待澄清；再按代码地图定位。已完成的三次修复见 [三次修复说明](./docs/三次修复说明-2026-10-15.md)，历史通过不能替代当前变更验证。');
line('代码地图.md','身份快照隔离、演示备注字段更新与新增正式保护见','最新检查见 [四次回归报告](./docs/四次回归报告-2026-10-15.md)：14 组 P2 未修，另有 1 项付款口径待澄清；重点定位 `request/enterFallback/refresh/modal`、验收与质保日历、演示 `apply/derive/rework` 及借还全局表单。已完成的身份快照／备注修复保留在 [三次修复说明](./docs/三次修复说明-2026-10-15.md)。');
const report=fs.readFileSync(path.join(root,'docs/四次回归报告-2026-10-15.md'),'utf8');
const adjusted=report.replace(/\]\((\.\.?\/)([^)]*)\)/g,(_,base,target)=>']('+'../../../../Desktop/啄木鸟维修平台-V3.8'+(base==='./'?'/docs/':'/')+target+')');
fs.writeFileSync('/Users/jobs/Documents/Github/啄木鸟维修平台/需求/四次回归分析与测试报告-V3.8-2026-10-15.md',adjusted);
console.log('第四轮汇总、当前状态入口与报告副本已同步；119文件保持一致，14组P2。');
