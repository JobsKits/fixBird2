const fs = require('node:fs');
const path = require('node:path');
const {spawn} = require('node:child_process');
const root = path.resolve(__dirname,'../..');
const go = path.join(root,'Tools/go/bin/go');
const result = {date:'2026-10-15',completed:false,steps:[]};
const container = 'jobs-v38-r4-tidb-'+Date.now();
let owned = false;
function save(){fs.writeFileSync(path.join(__dirname,'baseline-summary.json'),JSON.stringify(result,null,2));}
async function run(name,cmd,args,env={},cwd=root){
  const out=fs.createWriteStream(path.join(__dirname,name+'.log'));
  const err=fs.createWriteStream(path.join(__dirname,name+'.stderr.log'));
  const child=spawn(cmd,args,{cwd,env:{...process.env,...env}});
  child.stdout.pipe(out);child.stderr.pipe(err);
  const exitCode=await new Promise((resolve,reject)=>{child.once('error',reject);child.once('close',resolve);});
  out.end();err.end();
  const value={name,exitCode,command:[cmd,...args]};result.steps.push(value);save();console.log(JSON.stringify(value));
  return exitCode;
}
async function main(){
  const previous=JSON.parse(fs.readFileSync(path.join(root,'docs/三次修复验证-2026-10-15/source-verification.json'),'utf8')).after;
  const crypto=require('node:crypto');
  const current=previous.map(entry=>({path:entry.path,sha256:crypto.createHash('sha256').update(fs.readFileSync(path.join(root,entry.path))).digest('hex')}));
  fs.writeFileSync(path.join(__dirname,'source-before.json'),JSON.stringify(current,null,2));
  result.matchesPreviousFix=current.every((entry,i)=>entry.sha256===previous[i].sha256);
  if(!result.matchesPreviousFix) throw Error('源码与已验收修复不一致，先核对变化');
  await run('go-version',go,['version']);
  if(await run('test-database-start','docker',['run','--detach','--rm','--name',container,'--publish','127.0.0.1:14046:4000','--publish','127.0.0.1:18086:10080','pingcap/tidb:v8.5.8','--store=unistore','--path=/tmp/tidb-r4','--host=0.0.0.0','--status-host=0.0.0.0'])!==0) throw Error('独立测试数据库未启动');
  owned=true;result.database={container,sqlPort:14046,statusPort:18086,syntheticOnly:true};save();
  let ready=false;
  for(let i=0;i<90;i++){
    try{const response=await fetch('http://127.0.0.1:18086/status',{signal:AbortSignal.timeout(1000)});ready=response.ok;if(ready)break;}catch{}
    await new Promise(resolve=>setTimeout(resolve,1000));
  }
  if(!ready)throw Error('独立测试数据库未就绪');
  result.database.ready=true;save();
  const env={REPAIR_TEST_TIDB_DSN:'root@tcp(127.0.0.1:14046)/repair_test_r4?tls=false',WB_TEST_TIDB_DSN:'root@tcp(127.0.0.1:14046)/?tls=false'};
  const webFiles=['Web/tests','WebAdmin/tests','Workspace/tests'].flatMap(dir=>fs.readdirSync(path.join(root,dir)).filter(name=>name.endsWith('.test.cjs')).map(name=>dir+'/'+name));
  await Promise.all([
    run('go-tests',go,['-C','Server','test','-race','-p','1','-json','./...','-count=1'],env),
    run('web-tests',process.execPath,['--test',...webFiles]),
    run('http-smoke',process.execPath,['Scripts/验证工作台.mjs']),
  ]);
  await run('go-vet',go,['-C','Server','vet','-p','1','./...'],env);
  await run('contention-repeat',go,['-C','Server','test','-race','-json','./internal/repository','-run','^TestRepositoryContract$/^tidb-optimistic$','-count=10'],env);
  for(const file of ['Workspace/app.js','Workspace/data.js','Workspace/tests/app.test.cjs','Workspace/tests/data.test.cjs','Scripts/验证工作台.mjs'])await run('syntax-'+path.basename(file),process.execPath,['--check',file]);
  const lines=fs.readFileSync(path.join(__dirname,'go-tests.log'),'utf8').split('\n').filter(Boolean).map(line=>JSON.parse(line));
  result.go={rootsPassed:lines.filter(x=>x.Action==='pass'&&x.Test&&!x.Test.includes('/')).length,passResults:lines.filter(x=>x.Action==='pass'&&x.Test).length,failResults:lines.filter(x=>x.Action==='fail').length,skipResults:lines.filter(x=>x.Action==='skip'&&x.Test).length,packagesWithoutTests:lines.filter(x=>x.Action==='skip'&&!x.Test).length};
  result.completed=true;
} 
main().catch(error=>{result.error=error.message;process.exitCode=1;console.error(error.message);}).finally(async()=>{
  if(owned){await run('test-database-stop','docker',['rm','--force',container]);result.database.removed=true;}
  save();
});
