import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../../..');
if(process.argv.length!==3||process.argv[2]!=='--run'){console.log('用途：以临时目录与假工具验证配对反部署；不操作真实服务、SDK或数据库。显式执行：node 验证反部署.mjs --run');process.exit(0);}
const temp=fs.mkdtempSync(path.join(fs.realpathSync(os.tmpdir()),'repair-undeploy-check-'));
let passed=0;let failed=0;
const systems=['MacOS','Ubuntu','Debian','RockyLinux','AlibabaCloudLinux'];
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
function run(shell,script,env){
  const isolated={...process.env};
  for(const key of Object.keys(isolated))if(key.startsWith('WB_'))delete isolated[key];
  return spawnSync(shell,['-c',script],{cwd:root,env:{...isolated,...env,NO_COLOR:'1',PATH:'/usr/bin:/bin:/usr/sbin:/sbin'},encoding:'utf8',timeout:60000});
}
function check(ok,name,detail=''){if(ok){passed++;console.log('PASS '+name);}else{failed++;console.log('FAIL '+name+' '+detail.slice(-1000));}}
for(const sys of systems){const mac=sys==='MacOS',shell=mac?'/bin/zsh':'/bin/bash';const deploy=mac?'【MacOS】启动维修工作台.command':'【Linux】部署维修工作台.sh';const remove=mac?'【MacOS】反部署维修工作台.command':'【Linux】反部署维修工作台.sh';const ds=path.join(root,'部署',sys,'Deployment',deploy,deploy);const us=path.join(root,'部署',sys,'Undeployment',remove,remove);const dmod=path.join(temp,sys+'-deploy.sh'),umod=path.join(temp,sys+'-undeploy.sh');for(const [src,dst] of [[ds,dmod],[us,umod]]){const text=fs.readFileSync(src,'utf8');if(!text.endsWith('main "$@"\n'))throw Error('入口结构异常');fs.writeFileSync(dst,text.slice(0,-'main "$@"\n'.length));check(spawnSync(shell,['-n',src]).status===0,sys+'语法 '+path.basename(src));}
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
console.log(JSON.stringify({passed,failed,fixture:temp}));if(failed===0)fs.rmSync(temp,{recursive:true});process.exitCode=failed?1:0;
