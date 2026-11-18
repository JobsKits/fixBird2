import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import http from 'node:http';
import {spawn} from 'node:child_process';
import {fileURLToPath} from 'node:url';

const endpoint=new URL(process.argv[2]??'');
if(endpoint.hostname!=='127.0.0.1'||!endpoint.port||endpoint.port==='8098')throw new Error('An isolated loopback backend is required');
const here=path.dirname(fileURLToPath(import.meta.url));
const root=path.resolve(here,'../../../../..');
const source=path.join(root,'代码/前端/PC端/MacOS/Sources');
const data=path.join(root,'代码/前端/移动端/iOS/App/Data');
const work=await fs.mkdtemp(path.join(os.tmpdir(),'repair-directory-retry-'));
const files=[];
for(const directory of await fs.readdir(data)){
  if(directory==='WBJobsTransport')continue;
  for(const file of await fs.readdir(path.join(data,directory)))if(file.endsWith('.swift'))files.push(path.join(data,directory,file));
}
const run=(cmd,args)=>new Promise((resolve,reject)=>{
  const child=spawn(cmd,args,{stdio:'inherit'});child.on('error',reject);child.on('exit',code=>code===0?resolve():reject(new Error(cmd+' failed: '+code)));
});
const binary=path.join(work,'DirectoryRetrySmoke');
await run('xcrun',['swiftc','-D','DEBUG','-parse-as-library',path.join(here,'DesktopDirectoryRetrySmoke.swift'),...['DesktopCustomerDirectory.swift','WBJobsTransport.swift','DesktopRedirectPolicy.swift'].map(f=>path.join(source,f)),...files,'-o',binary]);
let discarded=false;const keys=[];
const proxy=http.createServer((request,response)=>{
  const forward=http.request(new URL(request.url,endpoint),{method:request.method,headers:{...request.headers,host:endpoint.host}},upstream=>{
    if(request.method==='POST'&&request.url==='/api/v38/customer-directory')keys.push(request.headers['idempotency-key']);
    if(!discarded&&request.method==='POST'&&request.url==='/api/v38/customer-directory'&&upstream.statusCode===201){discarded=true;upstream.resume();upstream.on('end',()=>response.destroy());return;}
    response.writeHead(upstream.statusCode,upstream.headers);upstream.pipe(response);
  });
  forward.on('error',()=>response.destroy());request.pipe(forward);
});
await new Promise(resolve=>proxy.listen(0,'127.0.0.1',resolve));
try{
  await run(binary,[`http://127.0.0.1:${proxy.address().port}`]);
  if(keys.length!==2||keys[0]!==keys[1])throw new Error('Directory retry did not reuse exactly one request key');
  console.log('PASS transport receipts: two wire calls, identical Idempotency-Key; changed-body attempt sent no request');
}finally{await new Promise(resolve=>proxy.close(resolve));}
