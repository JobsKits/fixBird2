#!/usr/bin/env node
// Jobs：仅用临时工程、假工具与显式提供的真实解析器验证Shell五平台依赖更新；不联网、不安装SDK。
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { spawn, spawnSync } from 'node:child_process';
const here=path.dirname(fileURLToPath(import.meta.url)), project=path.resolve(here,'../../../..');
const resolverIndex=process.argv.indexOf('--resolver');
if(!process.argv.includes('--run')||resolverIndex<0||!process.argv[resolverIndex+1]){console.log('用途：隔离检查官方latest采用、取消与源码锁保护。执行：node 验证依赖更新.mjs --run --resolver <已构建解析器>');process.exit(0)}
const realResolver=path.resolve(process.argv[resolverIndex+1]);assert.ok(fs.statSync(realResolver).isFile());
const scratch=fs.mkdtempSync(path.join(os.tmpdir(),'repair-dependency-check-'));
const hash=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const quote=value=>"'"+String(value).replaceAll("'","'\\''")+"'";
const sleep=ms=>new Promise(resolve=>setTimeout(resolve,ms));
let total=0;
const write=(file,body,mode=0o600)=>{fs.mkdirSync(path.dirname(file),{recursive:true});fs.writeFileSync(file,body,{mode});fs.chmodSync(file,mode)};
const goBody=version=>`#!/bin/sh
printf '%s\\n' "$*" >> "$WB_TEST_GO_CALLS"
case "$1" in
 version) echo 'go version go${version} fixture/fixture';;
 env) case "$2" in GOPROXY) printf '%s\\n' 'https://proxy.golang.org,direct';; GOENV) printf '%s\\n' off;; *) exit 91;; esac;;
 list)
  case "$WB_TEST_MODULE_MODE" in
   fail) exit 29;;
   hang) /bin/sleep 300 & echo $! > "$WB_TEST_HANG_PID"; wait; exit 0;;
   drift) printf '%s\\n' '// changed during query' >> "$WB_TEST_MODULE_SOURCE/go.mod";;
  esac
  cat "$WB_TEST_MODULE_JSON";;
 build)
  out=''; mod=''; readonly=0
  while [ "$#" -gt 0 ]; do case "$1" in -o) out="$2"; shift;; -modfile=*) mod="$1";; -mod=readonly) readonly=1;; esac; shift; done
  [ "$readonly" = 1 ] && [ -n "$mod" ] && [ "$GOWORK" = off ] || exit 92
  cp "$WB_TEST_REAL_RESOLVER" "$out"; chmod +x "$out";;
 *) exit 93;;
esac
`;
const fzfBody=version=>`#!/bin/sh
case "$1" in --version) echo '${version} (fixture)';; --help) echo '--expect';; *) exit 90;; esac
`;
const cloudBody=version=>`#!/bin/sh
case "$1" in --version) echo 'cloudflared version ${version}';; *) echo '--url --config --no-autoupdate --allowed-mail';; esac
`;
const fakeResolver=`#!/bin/sh
if [ "$1" = --compare ] || [ "$1" = --module-report ]; then exec "$WB_TEST_REAL_RESOLVER" "$@"; fi
tool=''; platform=''; arch=''; minimum=0
while [ "$#" -gt 0 ]; do case "$1" in --tool) tool="$2"; shift;; --os) platform="$2"; shift;; --arch) arch="$2"; shift;; --minimum-go) minimum=1; shift;; --locked-manifest) shift;; *) exit 2;; esac; shift; done
[ "$minimum" = 0 ] || [ "$tool" = go ] || exit 2
printf '%s\\n' "$tool" >> "$WB_TEST_META_CALLS"
case "$WB_TEST_META_MODE" in
 invalid) echo 'invalid fixture metadata' >&2; exit 2;;
 forever) echo 'retryable fixture network' >&2; exit 75;;
 once) if [ ! -f "$WB_TEST_RETRY_STAMP" ]; then touch "$WB_TEST_RETRY_STAMP"; exit 75; fi;;
 unsupported) printf '%s\\t%s\\t%s\\t1.27.4\\t-\\t-\\t-\\tunsupported\\n' "$tool" "$platform" "$arch"; exit 0;;
esac
awk -F '\\t' -v t="$tool" -v o="$platform" -v a="$arch" '$1==t&&$2==o&&$3==a{print}' "$WB_TEST_ASSET_ROWS"
`;
const fakeCurl=`#!/bin/sh
printf '%s\\n' called >> "$WB_TEST_CURL_CALLS"
out=''; url=''
while [ "$#" -gt 0 ]; do case "$1" in --output) out="$2"; shift;; --write-out|--max-time|--connect-timeout|--continue-at) shift;; https://*) url="$1";; esac; shift; done
case "$WB_TEST_CURL_MODE" in
 hang) echo $$ > "$WB_TEST_CURL_PID"; exec /bin/sleep 300;;
 once) if [ ! -f "$WB_TEST_CURL_RETRY" ]; then touch "$WB_TEST_CURL_RETRY"; printf 503; exit 22; fi;;
 bad) printf broken > "$out"; printf 200; exit 0;;
esac
name=$(basename "$url")
cp "$WB_TEST_ASSET_ROOT/$name" "$out" || exit 23
printf 200
`;
const platforms=[['MacOS','darwin','MacOS','/bin/zsh'],['Ubuntu','linux','Linux','/bin/bash'],['Debian','linux','Linux','/bin/bash'],['RockyLinux','linux','Linux','/bin/bash'],['AlibabaCloudLinux','linux','Linux','/bin/bash']];
function fixture(platform,label){
 const [system,goos,display,shell]=platform, base=path.join(scratch,system+'-'+label), source=path.join(base,'project'),run=path.join(base,'run'),envroot=path.join(base,'environment'),cache=path.join(envroot,'Projects','RepairWorkbench','fixture'),bin=path.join(base,'bin'),assets=path.join(base,'assets');
 const native=path.join(project,'部署',system,'Deployment',system==='MacOS'?'【MacOS】启动维修工作台.command':'【Linux】部署维修工作台.sh',system==='MacOS'?'【MacOS】启动维修工作台.command':'【Linux】部署维修工作台.sh');
 const content=fs.readFileSync(native,'utf8');assert.ok(content.trimEnd().endsWith('main "$@"'));
 write(path.join(base,'native-functions.sh'),content.replace(/main "\$@"\s*$/,''));
 fs.mkdirSync(run,{recursive:true});fs.mkdirSync(cache,{recursive:true});
 for(const name of ['backend','qr']){write(path.join(source,name,'go.mod'),'module example.test/'+name+'\n\ngo 1.24.0\n');write(path.join(source,name,'go.sum'),'example.test/locked v1.0.0 h1:fixture\n')}
 write(path.join(bin,'uname'),'#!/bin/sh\ncase "$1" in -s) echo '+(goos==='darwin'?'Darwin':'Linux')+';; -m) echo arm64;; *) echo fixture;; esac\n',0o700);write(path.join(bin,'go'),goBody('1.27.4'),0o700);write(path.join(bin,'fzf'),fzfBody('0.75.0'),0o700);write(path.join(bin,'cloudflared'),cloudBody('2026.11.0'),0o700);write(path.join(bin,'curl'),fakeCurl,0o700);write(path.join(base,'resolver'),fakeResolver,0o700);
 const moduleJson=path.join(base,'modules.json');write(moduleJson,JSON.stringify({Path:'example.test/library',Version:'v1.0.0',Update:{Path:'example.test/library',Version:'v1.1.0'}})+'\n');
 const rows=[];
 for(const [tool,version,filename,kind] of [['go','1.27.4',`go1.27.4.${goos}-arm64.tar.gz`,'tar.gz'],['fzf','0.75.0',`fzf-0.75.0-${goos}_arm64.tar.gz`,'tar.gz'],['cloudflared','2026.11.0',`cloudflared-${goos}-arm64`,'binary']]){
  const file=path.join(assets,filename);
  if(kind==='binary')write(file,cloudBody(version),0o700);else{const packed=path.join(base,'pack-'+tool),relative=tool==='go'?'go/bin/go':'fzf';write(path.join(packed,relative),tool==='go'?goBody(version):fzfBody(version),0o700);fs.mkdirSync(assets,{recursive:true});const tar=spawnSync('/usr/bin/tar',['-czf',file,'-C',packed,tool==='go'?'go':'fzf']);assert.equal(tar.status,0)}
  const url=tool==='go'?'https://go.dev/dl/'+filename:`https://github.com/${tool==='fzf'?'junegunn/fzf':'cloudflare/cloudflared'}/releases/download/${tool==='fzf'?'v':''}${version}/${filename}`;
  rows.push([tool,goos,'arm64',version,filename,hash(file),url,kind].join('\t'));
 }
 const rowFile=path.join(base,'rows.tsv');write(rowFile,rows.join('\n')+'\n');write(path.join(source,'部署/deploy-tools.lock.tsv'),'tool\tos\tarch\tversion\tfilename\tsha256\turl\tkind\n'+rows.join('\n')+'\n');
 const environment={...process.env,PATH:bin+':/usr/bin:/bin:/usr/sbin:/sbin',NO_COLOR:'1',WB_TEST_REAL_RESOLVER:realResolver,WB_TEST_META_MODE:'ok',WB_TEST_MODULE_MODE:'ok',WB_TEST_CURL_MODE:'ok',WB_TEST_META_CALLS:path.join(base,'meta-calls'),WB_TEST_GO_CALLS:path.join(base,'go-calls'),WB_TEST_CURL_CALLS:path.join(base,'curl-calls'),WB_TEST_META_ROOT:base,WB_TEST_RETRY_STAMP:path.join(base,'retry-stamp'),WB_TEST_CURL_RETRY:path.join(base,'curl-retry'),WB_TEST_CURL_PID:path.join(base,'curl.pid'),WB_TEST_ASSET_ROWS:rowFile,WB_TEST_ASSET_ROOT:assets,WB_TEST_MODULE_JSON:moduleJson,WB_TEST_MODULE_SOURCE:path.join(source,'backend'),WB_TEST_HANG_PID:path.join(base,'module-child.pid')};
 for(const key of ['GO_BIN','WB_FZF_BIN','WB_CLOUDFLARED_BIN','GOROOT','WB_ENV_ROOT','WB_RUNTIME_DIR'])delete environment[key];
 const prefix=`source ${quote(path.join(base,'native-functions.sh'))}\n${system==='MacOS'?'setopt NO_NOMATCH':'set +e'}\nPROJECT_DIR=${quote(source)}\nRUN_DIR=${quote(run)}\nENV_ROOT=${quote(envroot)}\nPROJECT_ENV_DIR=${quote(cache)}\nRUNTIME_ROOT=${quote(path.join(base,'runtime'))}\nPLATFORM_OS=${quote(goos)}\nPLATFORM_ARCH=arm64\nPLATFORM_LABEL=${quote(display)}\nLOG_FILE=${quote(path.join(base,'deploy.log'))}\nDEPENDENCY_RESOLVER=${quote(path.join(base,'resolver'))}\nGO_EXECUTABLE=${quote(path.join(bin,'go'))}\nFZF_EXECUTABLE=${quote(path.join(bin,'fzf'))}\nOUTPUT_COLOR=0\nDEPLOY_MODE=server\nmkdir -p "$RUN_DIR"\ntrap 'exit 143' TERM\ntrap 'exit 130' INT\n${system==='MacOS'?'':"trap 'cleanup' EXIT"}\n`;
 return{base,source,run,cache,envroot,bin,environment,shell,native,display,prefix,exec(body,extra={}){const file=path.join(base,'case.sh');write(file,prefix+body+'\n');return spawnSync(shell,shell.endsWith('zsh')?['-f',file]:['--noprofile','--norc',file],{env:{...environment,...extra},encoding:'utf8',timeout:20000})},spawn(body,extra={}){const file=path.join(base,'case.sh');write(file,prefix+body+'\n');return spawn(shell,shell.endsWith('zsh')?['-f',file]:['--noprofile','--norc',file],{env:{...environment,...extra},stdio:['ignore','pipe','pipe']})}};
}
function check(result,label,expected=0){assert.equal(result.status,expected,label+'\n'+result.stdout+'\n'+result.stderr);total++;console.log('PASS '+label)}
async function waitFile(file){for(let i=0;i<200;i++){if(fs.existsSync(file))return;await sleep(20)}throw Error('marker timeout '+file)}
async function cancelCase(f,body,marker,extra){const child=f.spawn(body,extra);let output='';child.stdout.on('data',s=>output+=s);child.stderr.on('data',s=>output+=s);try{await waitFile(marker);child.kill('SIGTERM');const result=await new Promise((resolve,reject)=>{const timer=setTimeout(()=>reject(Error('cancel timeout '+output)),12000);child.on('exit',(code,signal)=>{clearTimeout(timer);resolve({code,signal})})});assert.equal(result.code,143,output);const workerFile=path.join(f.run,'dependency-workers.tsv');if(fs.existsSync(workerFile))for(const line of fs.readFileSync(workerFile,'utf8').trim().split('\n')){const [pid,...identity]=line.split('\t');const actual=spawnSync('/bin/ps',['-p',pid,'-o','lstart=','-o','command='],{encoding:'utf8'}).stdout.trimEnd();assert.notEqual(actual,identity.join('\t'),'owned worker remains '+pid)}if(fs.existsSync(f.environment.WB_TEST_CURL_PID)){const pid=fs.readFileSync(f.environment.WB_TEST_CURL_PID,'utf8').trim();assert.equal(spawnSync('/bin/ps',['-p',pid,'-o','pid='],{encoding:'utf8'}).stdout.trim(),'','download child remains')}total++;console.log('PASS '+path.basename(f.base)+' cancels without next build or owned worker')}finally{if(child.exitCode===null)child.kill('SIGKILL')}}
try{
 for(const platform of platforms){
  const name=platform[0];
  let f=fixture(platform,'reuse');
  write(path.join(f.bin,'go'),goBody('1.24.9'),0o700);
  for(const version of ['1.27.9','1.27.10'])write(path.join(f.envroot,'Go','go'+version,f.display+'-arm64','go/bin/go'),goBody(version),0o700);
  let r=f.exec('resolve_latest_tool go\nprintf "%s" "$GO_EXECUTABLE" > "$RUN_DIR/selected"');check(r,name+' chooses highest semantic cache over old PATH');assert.ok(fs.readFileSync(path.join(f.run,'selected'),'utf8').includes('go1.27.10'));
  f=fixture(platform,'explicit-old');write(path.join(f.bin,'go'),goBody('1.24.9'),0o700);const before=hash(path.join(f.bin,'go'));r=f.exec('resolve_latest_tool go\nprintf build > "$RUN_DIR/built"',{GO_BIN:path.join(f.bin,'go')});assert.notEqual(r.status,0);assert.equal(hash(path.join(f.bin,'go')),before);assert.ok(!fs.existsSync(path.join(f.run,'built')));total++;console.log('PASS '+name+' preserves and rejects explicit old SDK');
  f=fixture(platform,'download');write(path.join(f.bin,'fzf'),fzfBody('0.74.5'),0o700);r=f.exec('dependency_retry_wait() { printf retry >> "$RUN_DIR/retries"; }\nresolve_latest_tool fzf\nprintf "%s" "$FZF_EXECUTABLE" > "$RUN_DIR/selected"',{WB_TEST_META_MODE:'once',WB_TEST_CURL_MODE:'once'});check(r,name+' retries transient metadata/download and adopts verified latest');assert.ok(fs.readFileSync(path.join(f.run,'selected'),'utf8').includes('/Tools/Fzf/0.75.0/'));assert.equal(fs.readFileSync(f.environment.WB_TEST_CURL_CALLS,'utf8').trim().split('\n').length,2);
  f=fixture(platform,'digest');write(path.join(f.bin,'fzf'),fzfBody('0.74.5'),0o700);r=f.exec('resolve_latest_tool fzf\nprintf build > "$RUN_DIR/built"',{WB_TEST_CURL_MODE:'bad'});assert.notEqual(r.status,0);assert.ok(!fs.existsSync(path.join(f.run,'built')));assert.equal(fs.readFileSync(f.environment.WB_TEST_CURL_CALLS,'utf8').trim().split('\n').length,1);total++;console.log('PASS '+name+' rejects digest error without retry or stale build');
  f=fixture(platform,'unsupported');r=f.exec('resolve_latest_tool go\nprintf build > "$RUN_DIR/built"',{WB_TEST_META_MODE:'unsupported'});assert.notEqual(r.status,0);assert.ok(!fs.existsSync(path.join(f.run,'built')));r=f.exec('resolve_latest_tool go',{WB_TEST_META_MODE:'unsupported',GO_BIN:path.join(f.bin,'go')});check(r,name+' unsupported asset requires matching explicit healthy tool');
  f=fixture(platform,'modes');r=f.exec('prepare_latest_tools');check(r,name+' queries only selected-mode tools');assert.deepEqual(fs.readFileSync(f.environment.WB_TEST_META_CALLS,'utf8').trim().split('\n'),['go','fzf']);
  f=fixture(platform,'local-mode');r=f.exec('DEPLOY_MODE=local\nprepare_latest_tools');check(r,name+' local mode also checks cloudflared stable target');assert.deepEqual(fs.readFileSync(f.environment.WB_TEST_META_CALLS,'utf8').trim().split('\n'),['go','fzf','cloudflared']);
  f=fixture(platform,'cloud-capability');write(path.join(f.bin,'cloudflared'),cloudBody('2026.11.0').replace(' --allowed-mail',''),0o700);if(name!=='MacOS'){r=f.exec('PUBLIC_TUNNEL=0\nresolve_latest_tool cloudflared\nprintf build > "$RUN_DIR/built"',{WB_CLOUDFLARED_BIN:path.join(f.bin,'cloudflared')});assert.notEqual(r.status,0);assert.ok(!fs.existsSync(path.join(f.run,'built')));total++;console.log('PASS '+name+' private tunnel requires allowed-mail capability before build')}r=f.exec('PUBLIC_TUNNEL=1\nresolve_latest_tool cloudflared',{WB_CLOUDFLARED_BIN:path.join(f.bin,'cloudflared')});check(r,name+' public tunnel retains its existing capability scope');
  f=fixture(platform,'invalid-metadata');r=f.exec('resolve_latest_tool go\nprintf build > "$RUN_DIR/built"',{WB_TEST_META_MODE:'invalid'});assert.notEqual(r.status,0);assert.ok(!fs.existsSync(path.join(f.run,'built')));assert.equal(fs.readFileSync(f.environment.WB_TEST_META_CALLS,'utf8').trim().split('\n').length,1);total++;console.log('PASS '+name+' metadata validation failure stops without stale fallback');
  f=fixture(platform,'locked-build');const buildSource=path.join(f.source,'代码/后端/后端代码');write(path.join(buildSource,'go.mod'),'module fixture\n\ngo 1.24.0\n');write(path.join(buildSource,'go.sum'),'fixture v1.0.0 h1:fixture\n');const buildMod=hash(path.join(buildSource,'go.mod')),buildSum=hash(path.join(buildSource,'go.sum'));r=f.exec('WORKBENCH_BINARY="$RUNTIME_ROOT/workbench"\nmkdir -p "$RUNTIME_ROOT"\nbuild_workbench');check(r,name+' build uses readonly external module copy with workspace off');assert.equal(hash(path.join(buildSource,'go.mod')),buildMod);assert.equal(hash(path.join(buildSource,'go.sum')),buildSum);
  f=fixture(platform,'report');const sourceMod=hash(path.join(f.source,'backend/go.mod')),sourceSum=hash(path.join(f.source,'backend/go.sum'));r=f.exec('DEPENDENCY_RESOLVER="$WB_TEST_REAL_RESOLVER"\ncheck_module_updates backend "$PROJECT_DIR/backend"\nprintf build > "$RUN_DIR/built"');check(r,name+' real helper reports current module updates using external copy');assert.ok(r.stdout.includes('example.test/library v1.0.0 -> v1.1.0'));assert.equal(hash(path.join(f.source,'backend/go.mod')),sourceMod);assert.equal(hash(path.join(f.source,'backend/go.sum')),sourceSum);
  r=f.exec('DEPENDENCY_RESOLVER="$WB_TEST_REAL_RESOLVER"\ncheck_module_updates backend "$PROJECT_DIR/backend"\nprintf build > "$RUN_DIR/after-failure"',{WB_TEST_MODULE_MODE:'fail'});check(r,name+' module query failure is explicitly incomplete, locked build remains allowed');assert.ok(r.stdout.includes('未完成'));
  r=f.exec('DEPENDENCY_RESOLVER="$WB_TEST_REAL_RESOLVER"\ncheck_module_updates backend "$PROJECT_DIR/backend"\nprintf build > "$RUN_DIR/after-timeout"',{WB_TEST_MODULE_MODE:'hang',WB_DEPENDENCY_CHECK_TIMEOUT_SECONDS:'1'});check(r,name+' real helper bounds optional query and reaps child tree');assert.ok(r.stdout.includes('超时'));const hanging=fs.readFileSync(f.environment.WB_TEST_HANG_PID,'utf8').trim();assert.equal(spawnSync('/bin/ps',['-p',hanging,'-o','pid='],{encoding:'utf8'}).stdout.trim(),'');
  r=f.exec('DEPENDENCY_RESOLVER="$WB_TEST_REAL_RESOLVER"\ncheck_module_updates backend "$PROJECT_DIR/backend"\nprintf build > "$RUN_DIR/after-drift"',{WB_TEST_MODULE_MODE:'drift'});assert.notEqual(r.status,0);assert.ok(!fs.existsSync(path.join(f.run,'after-drift')));total++;console.log('PASS '+name+' source drift blocks next build');
  f=fixture(platform,'cancel-metadata');await cancelCase(f,'resolve_latest_tool go\nprintf build > "$RUN_DIR/built"',f.environment.WB_TEST_META_CALLS,{WB_TEST_META_MODE:'forever'});assert.ok(!fs.existsSync(path.join(f.run,'built')));
  f=fixture(platform,'cancel-download');write(path.join(f.bin,'fzf'),fzfBody('0.74.5'),0o700);await cancelCase(f,'resolve_latest_tool fzf\nprintf build > "$RUN_DIR/built"',f.environment.WB_TEST_CURL_PID,{WB_TEST_CURL_MODE:'hang'});assert.ok(!fs.existsSync(path.join(f.run,'built')));
  f=fixture(platform,'readonly');for(const option of ['--check','--plan']){const environment={...f.environment,WB_ENV_ROOT:path.join(f.base,'read-environment'),WB_RUNTIME_DIR:path.join(f.base,'read-runtime')};r=f.exec('PROJECT_DIR='+quote(project)+'\nSCRIPT_PATH='+quote(f.native)+'\nCHECK_MODE='+(option==='--check'?'1':'0')+'\nPLAN_MODE='+(option==='--plan'?'1':'0')+'\ndetect_platform() { PLATFORM_OS='+platform[1]+'; PLATFORM_ARCH=arm64; }\nhandle_readonly_modes');check(r,name+' simulated target '+option+' has no resolver/download/write');assert.ok(!fs.existsSync(path.join(f.run,'module-manifests')));r=spawnSync(f.shell,f.shell.endsWith('zsh')?['-f',f.native,option]:['--noprofile','--norc',f.native,option],{env:environment,encoding:'utf8',timeout:10000});assert.ok(r.status===0||(r.status===1&&/当前平台不匹配|发行版不匹配/.test(r.stdout+r.stderr)),r.stdout+r.stderr);assert.ok(!fs.existsSync(environment.WB_ENV_ROOT));assert.ok(!fs.existsSync(environment.WB_RUNTIME_DIR));assert.ok(!fs.existsSync(f.environment.WB_TEST_META_CALLS))}
 }
 fs.writeFileSync(path.join(scratch,'result.json'),JSON.stringify({passed:total,failed:0},null,2));console.log(JSON.stringify({passed:total,failed:0,scratch}));
}catch(error){console.error(error.stack);console.error('保留隔离夹具：'+scratch);process.exitCode=1}
