// 自述：只读核对目录、迁移文件哈希与维护中文档链接，结果写入本证据目录。
const fs=require('node:fs');
const path=require('node:path');
const crypto=require('node:crypto');
const root=path.resolve(__dirname,'../..');
const before=JSON.parse(fs.readFileSync(path.join(__dirname,'整理前清单.json'),'utf8'));
const mapPath=old=>{const move=before.moves.find(([from])=>old===from||old.startsWith(from+'/'));return move?move[1]+old.slice(move[0].length):old;};
const hash=data=>crypto.createHash('sha256').update(data).digest('hex');
const missing=[],changed=[],unchanged=[];
for(const entry of before.files){const current=mapPath(entry.path),file=path.join(root,current);if(!fs.existsSync(file)){missing.push({before:entry.path,current});continue;}const digest=hash(fs.readFileSync(file));(digest===entry.sha256?unchanged:changed).push({before:entry.path,current,sha256:digest});}
const expectedNonDocumentChanges=new Set(['codegraph.json','后端/Go服务端/.env.example','后端/Go服务端/cmd/workbench/main.go','后端/Go服务端/internal/config/config.go','验证/验证工作台.mjs','验证/旧版基线/validate.mjs','验证/旧版基线/smoke-api.mjs','验证/旧版基线/parse-powershell.ps1','前端/Web网页/离线预览.mjs','后端/部署/macOS/deployment/【MacOS】启动维修工作台.command/【MacOS】启动维修工作台.command']);
const unexpectedChanges=changed.filter(x=>!x.current.endsWith('.md')&&!expectedNonDocumentChanges.has(x.current));
const folders=['前端/iOS','前端/Android','前端/鸿蒙','前端/微信小程序','前端/Web网页/维修工作台','前端/Web网页/旧版用户网页','后端/Go服务端','后端/管理后台页面','验证/旧版基线'];
for(const os of ['macOS','Windows','Linux/Ubuntu','Linux/Debian','Linux/RockyLinux','Linux/AlibabaCloudLinux']){folders.push('后端/部署/'+os,'后端/部署/'+os+'/deployment','后端/部署/'+os+'/undeployment');}
const missingFolders=folders.filter(p=>!fs.existsSync(path.join(root,p)));
const oldPathsRemaining=before.moves.map(([from])=>from).filter(p=>fs.existsSync(path.join(root,p)));
const shortcut=path.join(root,'【MacOS】启动维修工作台.command');
const shortcutValid=fs.lstatSync(shortcut).isSymbolicLink()&&fs.realpathSync(shortcut)===path.join(root,'后端/部署/macOS/deployment/【MacOS】启动维修工作台.command/【MacOS】启动维修工作台.command');
const documents=[];
// 原始需求与历史证据不是本次维护文档；root docs 下的报告、合同仍检查。
function collect(dir){for(const d of fs.readdirSync(dir,{withFileTypes:true})){if(['Tools','.runtime','.codegraph','.git','node_modules','需求'].includes(d.name))continue;const file=path.join(dir,d.name);if(d.isDirectory()){if(path.relative(root,file).startsWith('docs/'))continue;collect(file);}else if(d.name.endsWith('.md'))documents.push(file);}}
collect(root);
const ids=s=>[...s.matchAll(/\bid\s*=\s*(?:"([^"]+)"|'([^']+)'|([^\s>]+))/g)].map(m=>m[1]||m[2]||m[3]);
const errors=[];let links=0;
for(const file of documents){const source=fs.readFileSync(file,'utf8').replace(/^\s*```[^\n]*\n[\s\S]*?^\s*```\s*$/gm,'');const anchors=ids(source);if(new Set(anchors).size!==anchors.length)errors.push({file:path.relative(root,file),error:'duplicate id'});for(const m of source.matchAll(/\]\(([^)]+)\)|\bhref="([^"]+)"/g)){const url=(m[1]||m[2]).replace(/^<|>$/g,'');if(/^(https?:|mailto:|app:|codex:)/.test(url))continue;const [ref,fragment]=url.split('#');let target;try{target=ref?path.resolve(path.dirname(file),decodeURIComponent(ref)):file;}catch{errors.push({file,url,error:'invalid URL'});continue;}links++;if(!fs.existsSync(target))errors.push({file:path.relative(root,file),url,error:'missing target'});else if(fragment&&target.endsWith('.md')&&!ids(fs.readFileSync(target,'utf8')).includes(decodeURIComponent(fragment)))errors.push({file:path.relative(root,file),url,error:'missing explicit anchor'});}}
const result={beforeFiles:before.files.length,unchanged:unchanged.length,changed,missing,unexpectedChanges,requiredFolders:folders.length,missingFolders,oldPathsRemaining,shortcutValid,documents:documents.length,localLinks:links,documentErrors:errors,historyRawFilesChanged:changed.filter(x=>x.before.startsWith('docs/')&&!x.before.endsWith('.md')),passed:missing.length===0&&unexpectedChanges.length===0&&missingFolders.length===0&&oldPathsRemaining.length===0&&shortcutValid&&errors.length===0};
fs.writeFileSync(path.join(__dirname,'目录与文档核对.json'),JSON.stringify(result,null,2)+'\n');
console.log(JSON.stringify({...result,changed:changed.map(x=>x.current)}));
if(!result.passed)process.exitCode=1;
