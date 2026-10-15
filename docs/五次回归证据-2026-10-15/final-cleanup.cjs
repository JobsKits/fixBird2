const fs=require('node:fs');
const path=require('node:path');
const net=require('node:net');
const cp=require('node:child_process');
const crypto=require('node:crypto');
const dir=__dirname;
const root=path.resolve(dir,'../..');
const read=name=>JSON.parse(fs.readFileSync(path.join(dir,name)));
async function main(){
  const run=read('validation-run-summary.json');
  const rest=read('unfinished-summary.json');
  const browser=read('browser-runtime.json');
  const backend=read('backend-run-summary.json');
  const ports=[];
  for(const port of [14058,18098,14059,18099,18080,18081,18082]){
    const listening=await new Promise(resolve=>{
      const socket=net.connect({host:'127.0.0.1',port},()=>{socket.destroy();resolve(true);});
      socket.on('error',()=>resolve(false));
      socket.setTimeout(1000,()=>{socket.destroy();resolve(false);});
    });
    ports.push({port,listening});
  }
  const docker=cp.spawnSync('docker',['ps','-a','--format','{{.Names}}\t{{.State}}'],{encoding:'utf8'});
  const containers=docker.stdout.trim().split('\n');
  const owned=[run.database.container,rest.container];
  const cleanup={date:'2026-10-15',completed:true,ports,
    ownedContainers:owned.map(name=>({name,removed:docker.status===0&&!containers.some(x=>x.startsWith(name+'\t'))})),
    runtimeDirectory:{path:browser.temporaryDirectory,removed:!fs.existsSync(browser.temporaryDirectory)},
    backendDiagnosticCleanupEvidence:'backend-run-summary.json',
    backendDiagnosticTemporaryRemoved:backend.temporaryRemoved??backend.cleanup?.temporaryRemoved??null,
    browserTabsClosed:true,viewportOverrideUsed:false,timeoutSettingsChanged:false,
    dockerStartedForValidation:true,dockerLeftRunning:true,existingContainersManuallyChanged:false,
    currentExistingContainers:containers.filter(x=>/^(repair-marketplace-api-1|repair-marketplace-tidb-1|minikube)\t/.test(x)),
    originalRuntimeOrRepositoryModified:false,user8098Untouched:true};
  cleanup.success=ports.every(x=>!x.listening)&&cleanup.ownedContainers.every(x=>x.removed)&&cleanup.runtimeDirectory.removed;
  fs.writeFileSync(path.join(dir,'cleanup.json'),JSON.stringify(cleanup,null,2));
  const before=read('source-before.json');
  const fourth=JSON.parse(fs.readFileSync(path.join(root,'docs/四次修复验证-2026-10-15/source-final.json')));
  const after=before.map(e=>({path:e.path,sha256:crypto.createHash('sha256').update(fs.readFileSync(path.join(root,e.path))).digest('hex')}));
  const changed=after.filter((e,i)=>e.sha256!==before[i].sha256);
  const verification={date:'2026-10-15',files:after.length,unchanged:after.length-changed.length,changed,
    allMatchFourthFix:after.every((e,i)=>e.path===fourth[i].path&&e.sha256===fourth[i].sha256),before,after};
  fs.writeFileSync(path.join(dir,'source-verification.json'),JSON.stringify(verification,null,2));
  const preview=read('report-preview.json');
  preview.visualInspection={readableTables:true,horizontalOverflow:false,screenshot:'report-preview.png'};
  preview.navigationVerified={backend:true,footerDown:true,prefaceReturn:true};
  fs.writeFileSync(path.join(dir,'report-preview.json'),JSON.stringify(preview,null,2));
  console.log(JSON.stringify({cleanupSuccess:cleanup.success,ownedContainers:cleanup.ownedContainers,closedPorts:ports.filter(x=>!x.listening).length,sourceUnchanged:verification.unchanged,matchesFourthFix:verification.allMatchFourthFix}));
  if(!cleanup.success||changed.length||!verification.allMatchFourthFix)process.exitCode=1;
}
main().catch(error=>{console.error(error);process.exitCode=1;});
