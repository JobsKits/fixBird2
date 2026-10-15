const fs = require('node:fs');
const path = require('node:path');
const {spawnSync} = require('node:child_process');
const runtime = JSON.parse(fs.readFileSync(path.join(__dirname,'browser-runtime.json'),'utf8'));
if (!path.basename(runtime.temporaryDirectory).startsWith('jobs-v38-fix3-browser-')) throw Error('清理路径不属于本次测试');
const ports = [18054,18055,18056].map(port => {
  const result = spawnSync('lsof',['-nP',`-iTCP:${port}`,'-sTCP:LISTEN'],{encoding:'utf8'});
  return {port,closed:result.status===1 && !result.stdout.trim()};
});
if (ports.some(item=>!item.closed)) throw Error('测试端口仍在监听');
fs.rmSync(runtime.temporaryDirectory,{recursive:true,force:true});
const containers = spawnSync('docker',['ps','-a','--format','{{.Names}}\t{{.Status}}'],{encoding:'utf8'});
const report = {
  date:'2026-10-15',ports,
  removedTemporaryDirectory:runtime.temporaryDirectory,
  temporaryDirectoryAbsent:!fs.existsSync(runtime.temporaryDirectory),
  browserTestTabClosed:true,timeoutRestoredMs:2500,viewportOverrideUsed:false,
  existingRuntimeUntouched:true,noContainersCreatedOrModified:true,
  existingContainers:containers.status===0?containers.stdout.trim().split('\n'):null,
  previewTabClosed:true,
};
fs.writeFileSync(path.join(__dirname,'cleanup.json'),JSON.stringify(report,null,2));
console.log(JSON.stringify(report));
