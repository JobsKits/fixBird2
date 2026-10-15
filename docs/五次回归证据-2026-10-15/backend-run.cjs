const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const crypto = require('node:crypto');
const cp = require('node:child_process');
const root = '/Users/jobs/Desktop/啄木鸟维修平台-V3.8';
const evidence = path.join(root, 'docs/五次回归证据-2026-10-15');
const digest = p => crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');
const sources = [];
function walk(dir) {
  for (const item of fs.readdirSync(dir, {withFileTypes:true})) {
    if (['.git','node_modules','Tools','.runtime','build','docs'].includes(item.name)) continue;
    const source = path.join(dir,item.name);
    if (item.isDirectory()) walk(source);
    else if (item.name.endsWith('.go') || ['go.mod','go.sum'].includes(item.name)) sources.push(source);
  }
}
walk(path.join(root,'Server'));
const before = Object.fromEntries(sources.map(p => [path.relative(root,p),digest(p)]));
const temporaryRoot = fs.mkdtempSync(path.join(os.tmpdir(),'jobs-v38-r5-backend-'));
const server = path.join(temporaryRoot,'Server');
const runs=[];
try {
  for (const source of sources) {
    const target = path.join(temporaryRoot,path.relative(root,source));
    fs.mkdirSync(path.dirname(target),{recursive:true});
    fs.copyFileSync(source,target);
  }
  const testSource=path.join(evidence,'backend-boundaries_test.go');
  const copiedTest=path.join(server,'internal/workbench/r5_external_boundaries_test.go');
  fs.copyFileSync(testSource,copiedTest);
  cp.execFileSync(path.join(root,'Tools/go/bin/gofmt'),['-w',copiedTest]);
  fs.copyFileSync(copiedTest,testSource);
  const commands=[
    {name:'all',pattern:'^TestR5Backend'},
    {name:'failures-repeat',pattern:'^TestR5Backend(ReworkReferenceGuards|FreeReworkQuote|IssueResolutionMustNotSilentlyRestartExpiredAcceptance|BackdatedDeliveryCannotPrecedeConfirmedQuote)$'},
  ];
  for (const command of commands) {
    const log = path.join(evidence,'backend-'+command.name+'.jsonl');
    const errLog=path.join(evidence,'backend-'+command.name+'.stderr.log');
    const out=fs.openSync(log,'w'), err=fs.openSync(errLog,'w');
    const args=['-C',server,'test','-race','-p','1','-json','./internal/workbench','-run',command.pattern,'-count=1'];
    const began=Date.now();
    const result=cp.spawnSync(path.join(root,'Tools/go/bin/go'),args,{stdio:['ignore',out,err],env:{...process.env,GOWORK:'off'},timeout:600000});
    fs.closeSync(out);fs.closeSync(err);
    const events=fs.readFileSync(log,'utf8').split('\n').filter(Boolean).map(x=>JSON.parse(x));
    const terminal=events.filter(e=>e.Test&&['pass','fail','skip'].includes(e.Action));
    const tally = values => Object.fromEntries(['pass','fail','skip'].map(a=>[a,values.filter(e=>e.Action===a).length]));
    const roots=terminal.filter(e=>!e.Test.includes('/'));
    const leaves=terminal.filter(e=>!terminal.some(other=>other.Test.startsWith(e.Test+'/')));
    runs.push({name:command.name,command:[path.join(root,'Tools/go/bin/go'),...args],status:result.status,signal:result.signal,error:result.error?.message,elapsedMs:Date.now()-began,total:tally(terminal),roots:tally(roots),leaves:tally(leaves),failures:terminal.filter(e=>e.Action==='fail').map(e=>e.Test),raceReported:fs.readFileSync(log,'utf8').includes('WARNING: DATA RACE')||fs.readFileSync(errLog,'utf8').includes('WARNING: DATA RACE')});
  }
} finally {
  const after=Object.fromEntries(sources.map(p=>[path.relative(root,p),digest(p)]));
  fs.rmSync(temporaryRoot,{recursive:true,force:true});
  fs.writeFileSync(path.join(evidence,'backend-run-summary.json'),JSON.stringify({at:new Date().toISOString(),before,after,unchanged:JSON.stringify(before)===JSON.stringify(after),copiedFiles:sources.length,temporaryRoot,temporaryRemoved:!fs.existsSync(temporaryRoot),runs},null,2));
}
console.log(JSON.stringify(runs,null,2));
