const http=require('node:http');
const fs=require('node:fs');
const os=require('node:os');
const path=require('node:path');
const {spawn}=require('node:child_process');
const root=path.resolve(__dirname,'../..');
const dir=fs.mkdtempSync(path.join(os.tmpdir(),'jobs-v38-fix4-browser-'));
const runtime={temporaryDirectory:dir,backend:'http://127.0.0.1:18070',proxy:'http://127.0.0.1:18071',syntheticOnly:true};
fs.writeFileSync(path.join(__dirname,'browser-runtime.json'),JSON.stringify(runtime,null,2));
let child,proxy;
const events=[];
let rules={};
async function main(){
  const build=spawn(path.join(root,'Tools/go/bin/go'),['-C','Server','build','-o',path.join(dir,'workbench'),'./cmd/workbench'],{cwd:root});
  const buildLog=fs.createWriteStream(path.join(__dirname,'native-build.log'));build.stdout.pipe(buildLog);build.stderr.pipe(buildLog);
  if(await new Promise(resolve=>build.once('close',resolve))!==0)throw Error('构建失败');
  const log=fs.openSync(path.join(__dirname,'browser-backend.log'),'a');
  child=spawn(path.join(dir,'workbench'),[],{cwd:root,env:{...process.env,WB_ADDR:'127.0.0.1:18070',WB_DATA_DIR:path.join(dir,'data'),WB_KEY_FILE:path.join(dir,'keys/storage.key'),WB_WEB_DIR:path.join(root,'Workspace'),WB_TIDB_DSN:'',WB_BACKUP_DIR:''},stdio:['ignore',log,log]});
  proxy=http.createServer((req,res)=>{
    if(req.url==='/__regression/status'){res.writeHead(200,{'Content-Type':'application/json'});res.end(JSON.stringify({events,pendingRules:rules}));return;}
    if(req.url==='/__regression/arm'&&req.method==='POST'){let raw='';req.on('data',value=>raw+=value);req.on('end',()=>{rules=JSON.parse(raw).rules;res.writeHead(200,{'Content-Type':'application/json'});res.end('{"armed":true}');});return;}
    const key=req.method+' '+req.url.split('?')[0];
    const rule=rules[key];if(rule)delete rules[key];
    const upstream=http.request({host:'127.0.0.1',port:18070,path:req.url,method:req.method,headers:req.headers},reply=>{
      const event={method:req.method,path:req.url,status:reply.statusCode,at:Date.now()};events.push(event);if(events.length>250)events.shift();
      if(!rule){res.writeHead(reply.statusCode,reply.headers);reply.pipe(res);return;}
      const chunks=[];reply.on('data',b=>chunks.push(b));reply.on('end',()=>setTimeout(()=>{
        if(rule.status){event.injectedStatus=rule.status;res.writeHead(rule.status,{'Content-Type':'application/json'});res.end(JSON.stringify({error:'diagnostic_failure',message:'独立回归故障注入'}));}
        else{res.writeHead(reply.statusCode,reply.headers);res.end(Buffer.concat(chunks));}
      },rule.delay||0));
    });
    upstream.on('error',()=>{res.writeHead(502,{'Content-Type':'application/json'});res.end('{"error":"backend_not_ready"}');});req.pipe(upstream);
  });
  proxy.listen(18071,'127.0.0.1',()=>console.log('独立后端18070，观测代理18071。'));
  child.once('exit',()=>{if(proxy.listening)proxy.close();fs.closeSync(log);});
}
function stop(){if(proxy)proxy.close();if(child&&child.exitCode===null)child.kill('SIGTERM');setTimeout(()=>{if(child&&child.exitCode===null)child.kill('SIGKILL');process.exit(0);},1200).unref();}
process.on('SIGINT',stop);process.on('SIGTERM',stop);
main().catch(error=>{console.error(error.message);process.exitCode=1;});
