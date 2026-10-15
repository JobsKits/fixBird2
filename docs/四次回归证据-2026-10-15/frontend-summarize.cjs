/* Jobs · 把第四轮外部失败断言归并为可复查的问题，不把失败改写为通过。 */
const fs=require('node:fs');
const path=require('node:path');
const assert=require('node:assert/strict');
const crypto=require('node:crypto');
const first=JSON.parse(fs.readFileSync(path.join(__dirname,'frontend-results.json'),'utf8'));
const repeat=JSON.parse(fs.readFileSync(path.join(__dirname,'frontend-repeat.json'),'utf8'));
assert.deepEqual(first.results.map(({id,status})=>({id,status})),repeat.results.map(({id,status})=>({id,status})));
assert.deepEqual(first.sourceHashes,repeat.sourceHashes);
const root=path.resolve(__dirname,'../..');
const file=path.join(root,'Workspace/app.js');
const refs=(...entries)=>entries.map(([line,symbol])=>({file,line,symbol}));
const observations=ids=>first.results.filter(r=>ids.includes(r.id)).map(({id,status,observed})=>({case:id,status,observed}));
const findings=[
  {
    id:'R4-F01',severity:'P2',status:'reproduced',category:'client-session-revocation',
    title:'非列表路径401和被导航取代的bootstrap401未撤销旧会话，真实缓存继续显示',
    source:refs([369,'request'],[747,'enterFallback'],[1593,'refresh catch'],[1754,'openDetail catch'],[1345,'settingsMetadata catch'],[3138,'mutateOrder catch'],[3464,'previewFile'],[3713,'exportOrders catch']),
    cases:['R4-C01','R4-C02','R4-C03','R4-C04','R4-C05','R4-C06','R4-C07'],
    expected:'当前认证会话的任意明确401应撤销本地token、旧授权缓存及其DOM，并显示重新认证入口；旧身份迟到401不得影响新会话。',
    actual:'详情、附件原件、导出、业务动作、账号与审计401均只显示局部错误，token和真实快照仍在，connected仍true；同epoch bootstrap401若被导航先到也因sequence不符直接忽略。列表401对照组正确清理。',
    reproduction:['加载合成管理员服务端快照，确认列表与经营指标已显示。','对当前身份详情、导出或写接口返回401，或挂起bootstrap后导航财务列表成功、再返回bootstrap401。','检查账号仍标示服务端已认证、旧真实列表/指标/详情缓存仍可读；只有再刷新订单或完整refresh才走原清理路径。'],
    impact:'已知会话撤销后客户端继续暴露先前真实缓存，并错误显示已连接。未证明后端鉴权绕过、未证明撤销后可读取新资料或成功写入。',
    verification:'外部22用例中的7条当前会话保护断言失败；C14列表401清理和C12旧身份401不撤销新会话的对照均通过。',
    suggestedRepair:'将当前epoch的401统一收口到会话撤销，保留epoch隔离；原件下载须保留HTTP状态；导航listRevision只能丢弃旧列表结果，不能丢弃同会话401。',
    observations:observations(['R4-C01','R4-C02','R4-C03','R4-C04','R4-C05','R4-C06','R4-C07'])
  },
  {
    id:'R4-F02',severity:'P2',status:'reproduced',category:'bootstrap-navigation-error',
    title:'新身份bootstrap失败被导航吞掉，部分真实列表与零概览长期并存',
    source:refs([1592,'refresh catch'],[1593,'sequence !== listRevision'],[1654,'emptyServerSnapshot'],[1658,'login success toast']),
    cases:['R4-C08','R4-C21','R4-C22'],
    expected:'导航可以取代工单页结果，但新身份bootstrap的失败必须明确回退、显示待加载，或完成有界补读；未得到的经营指标不能作为已连接的0显示。',
    actual:'客户登录成功后挂起bootstrap，导航财务使/orders先成功；随后bootstrap网络异常/503/null均被listRevision守卫忽略。保留客户真实列表且connected=true，但remainingCents仍0（有效夹具为123），toast提示已登录；snapshotReady不能完成，等待本身不触发补读。',
    reproduction:['管理员已有真实快照后登录合成客户。','只挂起本次GET bootstrap，在其返回前导航现金与票据，允许客户订单列表成功。','再令bootstrap抛网络错误、返回503或200/null。','不手动刷新，检查真实订单存在但顶部经营指标仍为0；显式刷新可恢复。'],
    impact:'真实业务列表与未加载的零经营指标混合显示，可能误导待收款/待办判断；管理员同类流程还会持续禁止保存未加载的公司配置。未复现上一轮跨身份旧数据重新出现。',
    verification:'网络、503、空2xx三种故障各从零执行2次，均失败；C15无导航的网络故障正常回退作为对照。',
    suggestedRepair:'把同身份bootstrap元数据的加载/失败状态与列表序号独立管理；被导航取代的bootstrap失败仍处理元数据，并避免以真实0代表未加载。',
    observations:observations(['R4-C08','R4-C21','R4-C22'])
  },
  {
    id:'R4-F03',severity:'P2',status:'fault-injection-reproduced',category:'nested-response-validation',
    title:'嵌套坏2xx通过浅校验，渲染抛错并留下半套服务端状态或永久加载详情',
    source:refs([198,'validOrder'],[232,'validBootstrap'],[1100,'renderInventory'],[1596,'refresh finally render'],[1767,'openDetail renderDetail'],[1850,'summary.missing.length']),
    cases:['R4-C09','R4-C10'],
    expected:'解析成功但缺必填字段或含非法嵌套记录的响应应在应用前拒绝；首屏回退独立演示，详情显示完整可重载错误。',
    actual:'parts=[null]仍通过validBootstrap数组检查，data被标记server后在renderInventory读取available抛TypeError；详情summary缺missing仍通过validOrder，在renderDetail读取length抛TypeError，界面停留正在读取完整工单且坏详情已进cache。',
    reproduction:['登录合成管理员。','故障注入：只将一份有效bootstrap的parts改为[null]后refresh；或只删除有效完整详情的summary.missing后打开详情。','捕获未处理TypeError并核对数据来源仍server、详情仍是加载空态。'],
    impact:'异常/漂移响应可中断工作台渲染，且data已先采用坏快照。当前真实后端正常响应未观察到这些非法结构，此发现属于防错/兼容性边界，不是正常API必然崩溃。',
    verification:'两个仅改一个嵌套字段的故障夹具各2次重现；C17有效空列表不受影响，C16坏JSON写仍安全拒绝。',
    suggestedRepair:'在提交快照/详情缓存前验证实际渲染消费的嵌套类型，至少覆盖summary.missing和库存/借还/采购条目；渲染异常也应恢复可重试状态。',
    observations:observations(['R4-C09','R4-C10'])
  },
  {
    id:'R4-F04',severity:'P2',status:'reproduced',category:'idempotency-scope',
    title:'无关业务弹窗清空全局请求键，破坏公司配置未知提交的相同意图重试',
    source:refs([132,'formKey'],[2437,'modal resets formKeys'],[3664,'companyForm request'],[3669,'releaseFormKey after confirmed success']),
    cases:['R4-C18'],
    expected:'公司配置请求结果未知时，相同输入的明确重试继续使用原Idempotency-Key；打开无关动作表单不能结束这一未知意图。',
    actual:'第一次/settings抛未知网络错误后，createForm调用modal重置整个formKeys Map。关闭无关新建弹窗、原样重试公司配置，第二次/settings的请求键已变化。',
    reproduction:['管理员提交公司配置A；使响应未知，例如服务已处理后连接中断。','打开新建工单或其它动作弹窗后关闭，不提交该弹窗。','原样重试公司配置A，比对两次/settings头Idempotency-Key，观察为不同值。'],
    impact:'已实际提交但响应未知的配置可能被再次视为新业务，而不是核对原结果。若期间有其它配置变更，旧输入可能重新覆盖；本轮只直接证明请求键变化，没有把后续覆盖推断计为已发生。',
    verification:'C18从零2次均观察sameIdempotencyKey=false；既有正式B10仅覆盖回退/重连，未覆盖无关modal。',
    suggestedRepair:'请求键按表单/提交意图作用域隔离，不由新modal清空其它未知意图；保留成功后释放公司配置键的新意图区分。',
    observations:observations(['R4-C18'])
  }
];
for(const finding of findings)assert.ok(finding.cases.every(id=>first.results.find(r=>r.id===id)?.status==='failed'));
const reported=new Set(findings.flatMap(f=>f.cases));
assert.deepEqual([...reported].sort(),first.results.filter(r=>r.status==='failed').map(r=>r.id).sort());
const result={date:'2026-10-15',owner:'r4_frontend_adversarial',mode:'read-only-external',businessSourceModified:false,formalTestsModified:false,
  completed:true,tests:first.tests,pass:first.pass,fail:first.fail,uniqueFindings:findings.length,severityCounts:{P2:4},repeatCount:2,repeatConsistent:true,
  sourceHashes:first.sourceHashes,evidence:['frontend-adversarial.cjs','frontend-adversarial.log','frontend-results.json','frontend-repeat.log','frontend-repeat.json'],
  limitations:['使用真实app.js与正式VM夹具，只对合成HTTP响应故障注入；未启动浏览器或业务服务。','失败数是保护断言失败数，按根因归并为4组，不能当作13个独立问题。','后端生产鉴权、真实资金/业务数据未访问；真实浏览器由主任务另行佐证。'],
  cleanup:{openedPorts:[],spawnedServices:[],externalTempFiles:[],remainingArtifacts:'仅本证据目录frontend-*'},findings};
fs.writeFileSync(path.join(__dirname,'frontend-findings.json'),JSON.stringify(result,null,2)+'\n');
console.log(JSON.stringify({tests:result.tests,pass:result.pass,fail:result.fail,findings:findings.length,repeatConsistent:true,sourceUnchanged:true}));
