const http=require('node:http');
const fs=require('node:fs');
const path=require('node:path');
const {spawn}=require('node:child_process');
const root='/Users/jobs/Desktop/啄木鸟维修平台-V3.8';
const dir=__dirname;
const log=fs.openSync(path.join(root,'docs/三次回归证据-2026-10-14/browser-backend.log'),'a');
const child=spawn(path.join(dir,'workbench'),[],{cwd:root,env:{...process.env,WB_ADDR:'127.0.0.1:18050',WB_DATA_DIR:path.join(dir,'data'),WB_KEY_FILE:path.join(dir,'keys/storage.key'),WB_WEB_DIR:path.join(root,'Workspace'),WB_TIDB_DSN:'',WB_BACKUP_DIR:''},stdio:['ignore',log,log]});
let pendingRules={},held=0,released=0;
const events=[];
const proxy=http.createServer((req,res)=>{
 if(req.url==='/__regression/status' && req.method==='GET'){res.writeHead(200,{'Content-Type':'application/json'});res.end(JSON.stringify({pendingRules,held,released,events}));return;}
 if(req.url==='/__regression/arm' && req.method==='POST'){let input='';req.on('data',b=>input+=b);req.on('end',()=>{const value=JSON.parse(input);pendingRules=value.rules;res.writeHead(200,{'Content-Type':'application/json'});res.end('{"armed":true}');});return;}
 const requestPath=req.url.split('?')[0],delay=req.method==='GET'?(pendingRules[requestPath]||0):0;
 if(delay){delete pendingRules[requestPath];held++;events.push({type:'response_held',path:req.url,at:Date.now()});}
 const upstream=http.request({host:'127.0.0.1',port:18050,path:req.url,method:req.method,headers:req.headers},reply=>{
  if(!delay){res.writeHead(reply.statusCode,reply.headers);reply.pipe(res);return;}
  const chunks=[];reply.on('data',b=>chunks.push(b));reply.on('end',()=>setTimeout(()=>{held--;released++;events.push({type:'response_released',path:req.url,at:Date.now()});res.writeHead(reply.statusCode,reply.headers);res.end(Buffer.concat(chunks));},delay));
 });
 upstream.on('error',()=>{res.writeHead(502,{'Content-Type':'application/json'});res.end('{"error":{"message":"isolated backend not ready"}}');});req.pipe(upstream);
});
proxy.listen(18051,'127.0.0.1',()=>console.log('isolated browser backend 18050 / timing proxy 18051'));
function stop(){proxy.close();if(child.exitCode===null)child.kill('SIGTERM');setTimeout(()=>{if(child.exitCode===null)child.kill('SIGKILL');process.exit(0);},1200).unref();}
process.on('SIGINT',stop);process.on('SIGTERM',stop);
child.once('exit',()=>{fs.closeSync(log);if(proxy.listening)proxy.close();});
