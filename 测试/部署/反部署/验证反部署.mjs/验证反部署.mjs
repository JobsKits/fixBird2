import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { fileURLToPath } from 'node:url';
import { spawnSync, spawn } from 'node:child_process';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../../..');
if(process.argv[2]!=='--run'||process.argv.length>4||(process.argv[3]&&process.argv[3]!=='--macos-only')){console.log('用途：以临时目录与假工具验证配对反部署；不操作真实服务、SDK或数据库。显式执行：node 验证反部署.mjs --run [--macos-only]');process.exit(0);}
const temp=fs.mkdtempSync(path.join(fs.realpathSync(os.tmpdir()),'repair-undeploy-check-'));
let passed=0;let failed=0;
const systems=process.argv[3]==='--macos-only'?['MacOS']:['MacOS','Ubuntu','Debian','RockyLinux','AlibabaCloudLinux'];
const setup=`source "$DEPLOY_SOURCE"
PROJECT_DIR="$CASE_ROOT/中文 空格工程"
RUNTIME_ROOT="$CASE_ROOT/Runtime"
ENV_ROOT="$CASE_ROOT/Environments"
RUN_DIR="$RUNTIME_ROOT/deploy-session.fixture"
LOG_FILE="$CASE_ROOT/deploy.log"
mkdir -p "$PROJECT_DIR" "$RUN_DIR"
: > "$LOG_FILE"
if [ "$PRIOR" = 1 ]; then
  printf original > "$RUNTIME_ROOT/workbench"
  id="$(printf '%s' "$PROJECT_DIR" | cksum | awk '{print $1}')"
  mkdir -p "$ENV_ROOT/Projects/RepairWorkbench/$id"
  printf prior-cache > "$ENV_ROOT/Projects/RepairWorkbench/$id/prior"
fi
deploy_state_initialize existing
mkdir -p "$PROJECT_ENV_DIR/Tools" "$RUNTIME_ROOT/data" "$RUNTIME_ROOT/keys"
printf new-sdk > "$PROJECT_ENV_DIR/Tools/sdk"
cat > "$RUNTIME_ROOT/workbench" <<'BACKEND'
#!/bin/sh
[ "$FAIL_DECRYPT" != 1 ] || exit 13
if [ "$1" = -clear-storage ]; then printf '%s\n' "$@" > "$CASE_ROOT/clear-arguments"; exit 0; fi
[ "$1" = -backup ] || exit 0
printf verified-encrypted-aggregate > "$2"
digest="$(shasum -a 256 "$2" | awk '{print $1}')"
printf '{"sha256": "%s"}\n' "$digest" > "$2.manifest.json"
BACKEND
chmod u+x "$RUNTIME_ROOT/workbench"
printf encrypted-snapshot > "$RUNTIME_ROOT/data/snapshot.enc"
printf 12345678901234567890123456789012 > "$RUNTIME_ROOT/keys/storage.key"
mkdir -p "$ENV_ROOT/SharedSDK"
printf shared > "$ENV_ROOT/SharedSDK/original"
deploy_state_seal "$RUNTIME_ROOT/workbench"
deploy_state_finish
`;
const undo=`source "$UNDEPLOY_SOURCE"
PROJECT_DIR="$CASE_ROOT/中文 空格工程"
RUNTIME_ROOT="$CASE_ROOT/Runtime"
ENV_ROOT="$CASE_ROOT/Environments"
DEPLOY_STATE_DIR="$RUNTIME_ROOT/deploy-state"
DEPLOY_OPERATION_LOCK="$RUNTIME_ROOT/.deployment-operation.lock"
DATA_ACTION="$ACTION"
validate_state
stop_recorded_processes
acquire_operation_lock
trap release_operation_lock EXIT
preflight_artifacts
prepare_operation_directory
if [ "$FAIL_BACKUP" = 1 ]; then cp() { return 1; }; fi
if [ "$FAIL_SOURCE_CHANGE" = 1 ]; then
  cp() { command cp "$@" || return; case "$*" in *"$OPERATION_DIR/Data"*) printf concurrent-change >> "$RUNTIME_ROOT/data/snapshot.enc";; esac; }
fi
backup_business_data
clear_business_data
if [ "$FAIL_RESTORE" = 1 ]; then
  cp() { case "$*" in *previous/1*) return 1;; *) command cp "$@";; esac; }
fi
restore_artifacts
`;
function run(shell,script,env,input){
  const isolated={...process.env};
  for(const key of Object.keys(isolated))if(key.startsWith('WB_'))delete isolated[key];
  return spawnSync(shell,['-c',script],{cwd:root,env:{...isolated,...env,NO_COLOR:'1',PATH:'/usr/bin:/bin:/usr/sbin:/sbin'},input,encoding:'utf8',timeout:60000});
}
function check(ok,name,detail=''){if(ok){passed++;console.log('PASS '+name);}else{failed++;console.log('FAIL '+name+' '+detail.slice(-1000));}}
for(const sys of systems){const mac=sys==='MacOS',shell=mac?'/bin/zsh':'/bin/bash';const deploy=mac?'【MacOS】启动维修工作台.command':'【Linux】部署维修工作台.sh';const remove=mac?'【MacOS】反部署维修工作台.command':'【Linux】反部署维修工作台.sh';const ds=path.join(root,'部署',sys,'Deployment',deploy,deploy);const us=path.join(root,'部署',sys,'Undeployment',remove,remove);const dmod=path.join(temp,sys+'-deploy.sh'),umod=path.join(temp,sys+'-undeploy.sh');for(const [src,dst] of [[ds,dmod],[us,umod]]){const text=fs.readFileSync(src,'utf8');if(!text.endsWith('main "$@"\n'))throw Error('入口结构异常');fs.writeFileSync(dst,text.slice(0,-'main "$@"\n'.length));check(spawnSync(shell,['-n',src]).status===0,sys+'语法 '+path.basename(src));}
 if(mac){
  // 只运行真实选择与读取分支，使用替身菜单；确认前不调用停机或数据处理。
  const confirmation=`source "$UNDEPLOY_SOURCE"
choose() {
  case "$1" in
    '数据处理 > ') [ "$MENU_FAILURE" != 1 ] || return 130; printf '%s' "$MENU_ACTION";;
    *) printf '%s' "$EXECUTE_ACTION";;
  esac
}
state_value() { printf fixture; }
select_data_action
printf '\\nconfirmation-accepted\\n'
`;
  for(const [name,input,action,execute,menuFailure,accepted] of [
    ['清零回车确认','\n','clear','execute','0',true],
    ['清零空格取消',' \n','clear','execute','0',false],
    ['清零文字取消','YES\n','clear','execute','0',false],
    ['清零EOF取消','','clear','execute','0',false],
    ['备份无需额外输入','','backup','execute','0',true],
    ['数据菜单取消','\n','cancel','execute','0',false],
    ['执行菜单取消','\n','clear','cancel','0',false],
    ['选择器失败取消','\n','clear','execute','1',false]
  ]){
    const result=run(shell,confirmation,{UNDEPLOY_SOURCE:umod,MENU_ACTION:action,EXECUTE_ACTION:execute,MENU_FAILURE:menuFailure},input);
    check(result.status===0&&result.stdout.includes('confirmation-accepted')===accepted,'MacOS '+name,result.stdout+result.stderr);
  }
 }
 for(const scenario of ['backup-prior','clear-new','artifact-conflict','backup-failure','pid-reused','state-symlink','cancel','concurrent','decrypt-failure','source-change','session-change','restore-retry','external-backup-nested','external-backup-parent','tidb-backup-reference']){
  const dir=path.join(temp,sys+'-'+scenario);fs.mkdirSync(dir);const env={CASE_ROOT:dir,DEPLOY_SOURCE:dmod,UNDEPLOY_SOURCE:umod,PRIOR:['backup-prior','restore-retry'].includes(scenario)?'1':'0',ACTION:scenario==='clear-new'?'clear':'backup',WB_UNDEPLOY_BACKUP_DIR:path.join(dir,'Backups')};const created=run(shell,setup,env);check(created.status===0,sys+'准备 '+scenario,created.stderr);if(created.status!==0)continue;
  let data=path.join(dir,'Runtime/data/snapshot.enc');
  const binary=path.join(dir,'Runtime/workbench');
  if(scenario==='tidb-backup-reference'){
    const settings=path.join(dir,'Runtime/deploy-state/settings.tsv');
    fs.writeFileSync(settings,fs.readFileSync(settings,'utf8').replace('storage\tfile\n','storage\ttidb\n').replace('db_dsn\t\n','db_dsn\tfixture-only\n'));
  }
  if(scenario.startsWith('external-backup-')){
    const external=path.join(dir,'External');fs.mkdirSync(external);
    fs.renameSync(path.join(dir,'Runtime/data'),path.join(external,'Data'));
    fs.renameSync(path.join(dir,'Runtime/keys'),path.join(external,'Keys'));
    const settings=path.join(dir,'Runtime/deploy-state/settings.tsv');
    fs.writeFileSync(settings,fs.readFileSync(settings,'utf8').replaceAll(path.join(dir,'Runtime/data'),path.join(external,'Data')).replaceAll(path.join(dir,'Runtime/keys'),path.join(external,'Keys')));
    env.WB_UNDEPLOY_BACKUP_DIR=scenario.endsWith('nested')?path.join(external,'Data/Backup'):external;
    data=path.join(external,'Data/snapshot.enc');
  }
  if(scenario==='artifact-conflict')fs.appendFileSync(binary,'user-change');
  if(scenario==='session-change')fs.writeFileSync(path.join(dir,'Runtime/deploy-session.fixture/unknown'),'not-created-by-deployment');
  if(scenario==='state-symlink'){fs.renameSync(path.join(dir,'Runtime/data'),path.join(dir,'OtherData'));fs.symlinkSync(path.join(dir,'OtherData'),path.join(dir,'Runtime/data'));}
  if(scenario==='pid-reused')fs.writeFileSync(path.join(dir,'Runtime/deploy-state/processes.tsv'),'backend\t'+process.pid+'\twrong-start\twrong-command\n');
  let work=undo;
  if(scenario==='backup-failure')env.FAIL_BACKUP='1';
  if(scenario==='decrypt-failure')env.FAIL_DECRYPT='1';
  if(scenario==='source-change')env.FAIL_SOURCE_CHANGE='1';
  if(scenario==='restore-retry')env.FAIL_RESTORE='1';
  if(scenario==='cancel'){
    const fake=path.join(dir,'fake-fzf');fs.writeFileSync(fake,'#!/bin/sh\nprintf "cancel\\t取消\\n"\n',{mode:0o755});env.FAKE_FZF=fake;
    work=undo.slice(0,undo.indexOf('validate_state'))+'FZF_EXECUTABLE="$FAKE_FZF"\nselect_data_action\nprintf should-not-execute\n';
  }
  if(scenario==='concurrent'){fs.mkdirSync(path.join(dir,'Runtime/.deployment-operation.lock'));work=undo.slice(0,undo.indexOf('stop_recorded_processes'))+'acquire_operation_lock\n';}
  let result=run(shell,work,env);
  if(scenario==='restore-retry'){
    check(result.status!==0&&!fs.existsSync(binary)&&fs.existsSync(path.join(dir,'Runtime/deploy-state/restoring.tsv')),sys+'第二项恢复失败保留检查点','status='+result.status+' error='+(result.error?.code??'')+' '+result.stdout+result.stderr);
    delete env.FAIL_RESTORE;
    result=run(shell,undo,env);
    check(result.status===0&&fs.existsSync(binary)&&fs.readFileSync(binary,'utf8')==='original',sys+'已恢复首项后原点续跑',result.stdout+result.stderr);
    continue;
  }
  if(scenario==='backup-prior'){
    check(result.status===0&&fs.readFileSync(binary,'utf8')==='original',sys+'原程序恢复',result.stdout+result.stderr);
    const id=spawnSync('/bin/sh',['-c','printf %s "$CASE_ROOT/中文 空格工程" | cksum'],{env:{...process.env,CASE_ROOT:dir},encoding:'utf8'}).stdout.split(' ')[0];
    check(fs.existsSync(path.join(dir,'Environments/Projects/RepairWorkbench',id,'prior'))&&!fs.existsSync(path.join(dir,'Environments/Projects/RepairWorkbench',id,'Tools/sdk'))&&!fs.existsSync(data),sys+'原依赖恢复并清理数据');
    const backupDirs=fs.existsSync(path.join(dir,'Backups'))?fs.readdirSync(path.join(dir,'Backups')):[];
    check(backupDirs.length===1&&fs.readFileSync(path.join(dir,'Backups',backupDirs[0],'storage.key'),'utf8').length===32&&fs.existsSync(path.join(dir,'Backups',backupDirs[0],'BACKUP_VERIFIED')),sys+'数据密钥备份验证');
  }else if(scenario==='tidb-backup-reference')check(result.status===0&&fs.readFileSync(path.join(dir,'clear-arguments'),'utf8').includes('-clear-storage-backup\n')&&!fs.existsSync(data),sys+'TiDB备份清零绑定已验证备份',result.stdout+result.stderr);
  else if(scenario==='clear-new')check(result.status===0&&!fs.existsSync(binary)&&!fs.existsSync(data),sys+'清零与新增资源撤回',result.stdout+result.stderr);
  else if(scenario==='cancel')check(result.status===0&&!result.stdout.includes('should-not-execute')&&fs.existsSync(data),sys+'取消零删除',result.stdout+result.stderr);
  else check(result.status!==0&&fs.existsSync(data)&&fs.existsSync(binary),sys+'拒绝危险边界 '+scenario,result.stdout+result.stderr);
  check(fs.readFileSync(path.join(dir,'Environments/SharedSDK/original'),'utf8')==='shared',sys+'保留共享SDK '+scenario);
 }
}
// 真实子进程夹具只使用临时目录和随机回环端口。
async function waitFor(predicate, timeout=30000) {
  const until=Date.now()+timeout;
  while(Date.now()<until){if(predicate())return true;await new Promise(resolve=>setTimeout(resolve,60));}
  return false;
}
async function lifecycleChecks() {
  if(process.platform!=='darwin')return;
  const dir=path.join(temp,'MacOS-lifecycle');fs.mkdirSync(dir);
  const project=path.join(dir,'中文 空格工程'),runtime=path.join(dir,'Runtime');
  fs.mkdirSync(project);fs.mkdirSync(runtime);fs.writeFileSync(path.join(runtime,'business-preserved'),'unchanged');
  const backend=path.join(dir,'backend.mjs');
  fs.writeFileSync(backend,"import net from 'node:net';import fs from 'node:fs';const server=net.createServer();server.listen(Number(process.env.FIXTURE_PORT)||0,'127.0.0.1',()=>fs.writeFileSync(process.env.PORT_FILE,String(server.address().port)));");
  const supervisor=path.join(project,'supervisor.command');
  fs.writeFileSync(supervisor,[
    'source "$DEPLOY_SOURCE"',
    'PROJECT_DIR="$CASE_ROOT/中文 空格工程"',
    'RUNTIME_ROOT="$CASE_ROOT/Runtime"',
    'ENV_ROOT="$CASE_ROOT/Environments"',
    'LOG_FILE="$CASE_ROOT/$SESSION.log"',
    'RUN_DIR="$(mktemp -d "$RUNTIME_ROOT/deploy-session.XXXXXXXX")"',
    'DEPLOY_STATE_DIR="$RUNTIME_ROOT/deploy-state"',
    'DEPLOY_OPERATION_LOCK="$RUNTIME_ROOT/.deployment-operation.lock"',
    'DEPLOY_OWNER_PID="$$"',
    ': > "$LOG_FILE"',
    "trap 'exit 129' HUP",
    "trap 'exit 130' INT",
    "trap 'exit 143' TERM",
    'if [ "$CANCEL_ONLY" = 1 ]; then exit 0; fi',
    'deploy_state_begin_selected',
    'run_session_child backend "$NODE_BIN" "$CASE_ROOT/backend.mjs" &',
    'API_PID=$!',
    'wait_session_child_ready backend "$API_PID"',
    'count=0',
    'while [ ! -s "$PORT_FILE" ] && [ "$count" -lt 100 ]; do sleep 0.05; count=$((count + 1)); done',
    '[ -s "$PORT_FILE" ] || exit 3',
    'printf %s "$API_PID" > "$CASE_ROOT/$SESSION.ready"',
    'deploy_state_release_handoff',
    'while kill -0 "$API_PID" 2>/dev/null; do sleep 0.2; done',
    ''
  ].join('\n'));
  const env={...process.env,NO_COLOR:'1',PATH:'/usr/bin:/bin:/usr/sbin:/sbin',CASE_ROOT:dir,DEPLOY_SOURCE:path.join(temp,'MacOS-deploy.sh'),NODE_BIN:process.execPath};
  for(const key of Object.keys(env))if(key.startsWith('WB_'))delete env[key];
  const children=[];
  function start(name,extra={},wrapper=false){
    const options={cwd:'/',env:{...env,SESSION:name,PORT_FILE:path.join(dir,name+'.port'),...extra},stdio:['ignore','pipe','pipe']};
    options.env.FIXTURE_SUPERVISOR=supervisor;
    const launch=wrapper?['-c','/bin/zsh "$FIXTURE_SUPERVISOR" &\nprintf %s $! > "$CASE_ROOT/$SESSION.supervisor"\nwait']:[supervisor];
    const child=spawn('/bin/zsh',launch,options);child.output='';
    child.stdout.on('data',data=>child.output+=data);child.stderr.on('data',data=>child.output+=data);
    children.push(child);return child;
  }
  const ready=name=>fs.existsSync(path.join(dir,name+'.ready'));
  const lock=path.join(runtime,'.deployment-operation.lock');
  const gone=pid=>{const result=spawnSync('/bin/ps',['-p',String(pid),'-o','stat='],{encoding:'utf8'});return result.status!==0||result.stdout.includes('Z');};
  const backendPid=name=>Number(fs.readFileSync(path.join(dir,name+'.ready'),'utf8'));
  try {
    let first=start('first');check(await waitFor(()=>ready('first')),'MacOS生命周期启动',first.output);
    if(!ready('first'))return;
    const originalPort=fs.readFileSync(path.join(dir,'first.port'),'utf8');
    const cancelled=start('cancelled',{CANCEL_ONLY:'1'});await waitFor(()=>cancelled.exitCode!==null);
    check(!gone(first.pid)&&!gone(backendPid('first')),'MacOS取消重启保留旧实例');
    let second=start('second',{FIXTURE_PORT:originalPort});
    check(await waitFor(()=>ready('second'))&&gone(first.pid)&&gone(backendPid('first')),'MacOS旧终端仍开着先停旧再复用原端口',second.output);
    if(!ready('second'))return;
    second.kill('SIGHUP');check(await waitFor(()=>gone(second.pid)&&gone(backendPid('second'))&&!fs.existsSync(lock)),'MacOSHUP回收服务与操作锁',second.output);
    let third=start('third',{FIXTURE_PORT:originalPort});check(await waitFor(()=>ready('third')),'MacOS关闭后可重新启动',third.output);
    if(!ready('third'))return;
    third.kill('SIGKILL');check(await waitFor(()=>gone(backendPid('third'))&&!fs.existsSync(lock)),'MacOS主入口强退监护回收',third.output);
    const wrapper=start('parent',{FIXTURE_PORT:originalPort},true);check(await waitFor(()=>ready('parent')),'MacOS父死夹具启动',wrapper.output);
    if(!ready('parent'))return;
    const supervisorPid=Number(fs.readFileSync(path.join(dir,'parent.supervisor'),'utf8'));
    wrapper.kill('SIGKILL');check(await waitFor(()=>gone(supervisorPid)&&gone(backendPid('parent'))&&!fs.existsSync(lock)),'MacOS宿主异常结束触发同轮清理',wrapper.output);
    if(!gone(supervisorPid)||!gone(backendPid('parent'))||fs.existsSync(lock))return;
    fs.mkdirSync(lock);fs.writeFileSync(path.join(lock,'owner'),'999999\n');
    const legacy=start('legacy',{FIXTURE_PORT:originalPort});check(await waitFor(()=>ready('legacy')),'MacOS旧PID-only失效锁自动恢复',legacy.output);
    if(!ready('legacy'))return;
    legacy.kill('SIGTERM');check(await waitFor(()=>gone(legacy.pid)&&gone(backendPid('legacy'))&&!fs.existsSync(lock),20000),'MacOSTERM停止服务后才释放锁',legacy.output);
    if(!gone(backendPid('legacy')))return;
    const unrelated=spawn('/bin/sleep',['90'],{stdio:'ignore'});children.push(unrelated);
    fs.writeFileSync(path.join(runtime,'deploy-state/processes.tsv'),'supervisor\t'+unrelated.pid+'\twrong-start\twrong-command\n');
    fs.mkdirSync(lock);fs.writeFileSync(path.join(lock,'owner'),unrelated.pid+'\n');
    const reused=start('reused',{FIXTURE_PORT:originalPort});check(await waitFor(()=>ready('reused'))&&!gone(unrelated.pid),'MacOS旧PID复用不误停其它进程',reused.output);
    if(!ready('reused'))return;
    reused.kill('SIGTERM');check(await waitFor(()=>gone(reused.pid)&&gone(backendPid('reused'))&&!fs.existsSync(lock),20000),'MacOS复用PID场景正常退出',reused.output);
    if(!gone(backendPid('reused')))return;
    fs.mkdirSync(lock);fs.writeFileSync(path.join(lock,'owner'),String(process.pid));fs.writeFileSync(path.join(lock,'identity.tsv'),'undeployment\t'+process.pid+'\tfixture\tfixture\n');
    const blocked=start('blocked',{FIXTURE_PORT:originalPort});await waitFor(()=>blocked.exitCode!==null);
    check(blocked.exitCode!==0&&!ready('blocked')&&fs.existsSync(lock),'MacOS保留反部署事务锁',blocked.output);
    fs.rmSync(lock,{recursive:true});
    fs.mkdirSync(lock);
    const unknown=start('unknown');await waitFor(()=>unknown.exitCode!==null);
    check(unknown.exitCode!==0&&fs.existsSync(lock),'MacOS未知归属锁不删除',unknown.output);
    fs.rmSync(lock,{recursive:true});
    const parallelOne=start('parallel-one',{FIXTURE_PORT:originalPort});
    const parallelTwo=start('parallel-two',{FIXTURE_PORT:originalPort});
    const parallelReady=await waitFor(()=>ready('parallel-one')&&ready('parallel-two'));
    check(parallelReady&&[parallelOne,parallelTwo].filter(child=>!gone(child.pid)).length===1,'MacOS并发启动串行交接且仅存一轮',parallelOne.output+parallelTwo.output);
    for(const child of [parallelOne,parallelTwo])if(!gone(child.pid))child.kill('SIGTERM');
    check(await waitFor(()=>gone(parallelOne.pid)&&gone(parallelTwo.pid)&&!fs.existsSync(lock)),'MacOS并发交接后正常释放操作锁');
    check(fs.readFileSync(path.join(runtime,'business-preserved'),'utf8')==='unchanged','MacOS重启与信号不改业务数据');
  } finally {
    for(const child of children)if(child.exitCode===null&&child.signalCode===null)child.kill('SIGTERM');
    await waitFor(()=>children.every(child=>child.exitCode!==null||child.signalCode!==null),5000);
  }
}
await lifecycleChecks();
console.log(JSON.stringify({passed,failed,fixture:temp}));if(failed===0)fs.rmSync(temp,{recursive:true});process.exitCode=failed?1:0;
