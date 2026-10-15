const fs=require('node:fs'),path=require('node:path'),cp=require('node:child_process');
const root=path.resolve(__dirname,'../..'),go=path.join(root,'Tools/go/bin/go'),pkg='repair-platform/internal/workbench';
const container='jobs-v38-reg5-workbench-recheck';
const summary={date:'2026-10-15',completed:false,reason:'Initial full suite package hit default 10 minute limit without assertion failures; execute only roots that did not complete, all assertions unchanged.',container,sqlPort:14059,statusPort:18099,timeout:'30m',syntheticOnly:true};
const save=()=>fs.writeFileSync(path.join(__dirname,'unfinished-summary.json'),JSON.stringify(summary,null,2));save();
const read=file=>fs.readFileSync(path.join(__dirname,file),'utf8').split('\n').filter(Boolean).map(x=>JSON.parse(x));
async function main(){
 const first=read('go-tests.log');
 const listed=cp.spawnSync(go,['-C','Server','test','-list','^Test','./internal/workbench'],{cwd:root,encoding:'utf8'});fs.writeFileSync(path.join(__dirname,'workbench-test-list.log'),listed.stdout);if(listed.status!==0)throw Error('test listing failed');
 const names=listed.stdout.split('\n').filter(x=>/^Test\w+$/.test(x));
 const finished=new Set(first.filter(x=>x.Package===pkg&&x.Action==='pass'&&x.Test&&!x.Test.includes('/')).map(x=>x.Test));
 const selected=names.filter(x=>!finished.has(x));summary.workbenchTotalRoots=names.length;summary.alreadyCompletedRoots=finished.size;summary.selectedRoots=selected;save();
 if(first.some(x=>x.Action==='fail'&&x.Test))throw Error('Initial test assertion failure must be reviewed before timeout-only recovery');
 const ready=await fetch('http://127.0.0.1:18099/status',{signal:AbortSignal.timeout(2000)});if(!ready.ok)throw Error('isolated recheck database not ready');
 const args=['-C','Server','test','-race','-p','1','-timeout','30m','-json','./internal/workbench','-run','^('+selected.join('|')+')$','-count=1'];summary.command=[go,...args];save();console.log(JSON.stringify({alreadyCompletedRoots:finished.size,recheckingRoots:selected.length,timeout:summary.timeout}));
 const out=fs.createWriteStream(path.join(__dirname,'go-unfinished.log')),err=fs.createWriteStream(path.join(__dirname,'go-unfinished.stderr.log'));
 const child=cp.spawn(go,args,{cwd:root,env:{...process.env,REPAIR_TEST_TIDB_DSN:'root@tcp(127.0.0.1:14059)/repair_test_reg5_recheck?tls=false',WB_TEST_TIDB_DSN:'root@tcp(127.0.0.1:14059)/?tls=false'}});child.stdout.pipe(out);child.stderr.pipe(err);
 summary.exitCode=await new Promise((resolve,reject)=>{child.once('error',reject);child.once('close',resolve);});save();await Promise.all([require('node:stream/promises').finished(out),require('node:stream/promises').finished(err)]);
 const again=read('go-unfinished.log');summary.recheck={rootsPassed:again.filter(x=>x.Action==='pass'&&x.Test&&!x.Test.includes('/')).length,passResults:again.filter(x=>x.Action==='pass'&&x.Test).length,failResults:again.filter(x=>x.Action==='fail').length,skipResults:again.filter(x=>x.Action==='skip'&&x.Test).length,raceDetected:again.some(x=>String(x.Output||'').includes('WARNING: DATA RACE'))};
 const tests=new Map();for(const e of first){if(e.Action==='pass'&&e.Test&&(e.Package!==pkg||finished.has(e.Test.split('/')[0])))tests.set(e.Package+'\t'+e.Test,e);}for(const e of again){if(e.Action==='pass'&&e.Test)tests.set(e.Package+'\t'+e.Test,e);}
 const final=[...tests.values()];summary.mergedCoverage={rootsPassed:final.filter(x=>!x.Test.includes('/')).length,passResults:final.length,assertionFailures:first.filter(x=>x.Action==='fail'&&x.Test).length+again.filter(x=>x.Action==='fail'&&x.Test).length,skipResults:first.filter(x=>x.Action==='skip'&&x.Test).length+summary.recheck.skipResults,initialPackageTimeouts:first.filter(x=>x.Action==='fail'&&!x.Test).map(x=>x.Package),allWorkbenchRootsCovered:summary.recheck.rootsPassed===selected.length};
 summary.completed=true;summary.success=summary.exitCode===0&&summary.recheck.failResults===0&&summary.mergedCoverage.allWorkbenchRootsCovered;console.log(JSON.stringify(summary.mergedCoverage));if(!summary.success)process.exitCode=1;
}
main().catch(e=>{summary.error=e.message;process.exitCode=1;}).finally(()=>{const stop=cp.spawnSync('docker',['rm','--force',container],{encoding:'utf8'});fs.writeFileSync(path.join(__dirname,'test-recheck-database-stop.log'),stop.stdout+stop.stderr);summary.databaseRemoved=stop.status===0;save();console.log(JSON.stringify({completed:summary.completed,success:summary.success,databaseRemoved:summary.databaseRemoved,error:summary.error}));});
