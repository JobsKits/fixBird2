import fs from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import http from 'node:http';
import {spawn} from 'node:child_process';
import {fileURLToPath} from 'node:url';

const here=path.dirname(fileURLToPath(import.meta.url));
const root=path.resolve(here,'../../../../..');
const desktop=path.join(root,'代码/前端/PC端/MacOS/Sources');
const data=path.join(root,'代码/前端/移动端/iOS/App/Data');
const work=await fs.mkdtemp(path.join(os.tmpdir(),'repair-local-auth-'));
const run=(command,args)=>new Promise((resolve,reject)=>{
  const child=spawn(command,args,{stdio:'inherit'});
  child.on('error',reject);
  child.on('exit',code=>code===0?resolve():reject(new Error(command+' failed: '+code)));
});
const sources=[];
for(const directory of await fs.readdir(data)){
  if(directory==='WBJobsTransport')continue;
  for(const file of await fs.readdir(path.join(data,directory)))if(file.endsWith('.swift'))sources.push(path.join(data,directory,file));
}
const binary=path.join(work,'RepairLocalAuthSmoke');
await fs.copyFile(path.join(root,'代码/前端/共享组件/Resources/ui-l10n.json'),path.join(work,'ui-l10n.json'));
await fs.copyFile(path.join(root,'代码/前端/PC端/原生共享契约/desktop-l10n.json'),path.join(work,'desktop-l10n.json'));
await run('xcrun',['swiftc','-D','DEBUG','-parse-as-library',path.join(here,'DesktopLocalAuthSmoke.swift'),...['DesktopLocalDemoAuth.swift','DesktopModel.swift','WBJobsTransport.swift','DesktopRedirectPolicy.swift'].map(f=>path.join(desktop,f)),...sources,'-o',binary]);
const rejection=http.createServer((request,response)=>{
  response.setHeader('Content-Type','application/json');
  if(request.url==='/api/v38/healthz')response.end(JSON.stringify({mode:'synthetic_demo'}));
  else {response.writeHead(401);response.end(JSON.stringify({error:'invalid_credentials',message:'fixture HTTP401 rejection'}));}
});
const production=http.createServer((request,response)=>{
  if(request.url==='/api/v38/healthz'){response.setHeader('Content-Type','application/json');response.end(JSON.stringify({mode:'production'}));}
  else request.socket.destroy();
});
const vacant=http.createServer();
const start=server=>new Promise(resolve=>server.listen(0,'127.0.0.1',()=>resolve(server.address().port)));
const offlinePort=await start(vacant);await new Promise(resolve=>vacant.close(resolve));
const rejectionPort=await start(rejection);const productionPort=await start(production);
try{
  for(const [mode,port]of [['offline',offlinePort],['rejection',rejectionPort],['production',productionPort]])await run(binary,[mode,'--wb-api-url',`http://127.0.0.1:${port}`]);
  console.log('PASS local native auth gates. Isolated test workspace: '+work);
}finally{
  await Promise.all([rejection,production].map(server=>new Promise(resolve=>server.close(resolve))));
}
