const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '../..');
const current = '/Users/jobs/Documents/Github/啄木鸟维修平台/需求';
const documents = [
  'README.md', '部署文档.md', '代码地图.md', 'AGENTS.md',
  'docs/实现范围.md', 'docs/workbench-contract.md',
  'docs/二次回归报告-2026-10-14.md', 'docs/二次修复说明-2026-10-14.md',
  'docs/三次回归报告-2026-10-15.md',
].map(p => path.join(root, p)).concat([
  path.join(current, '二次回归分析与测试报告-V3.8-2026-10-14.md'),
  path.join(current, '二次修复与回归报告-V3.8-2026-10-14.md'),
  path.join(current, '三次回归分析与测试报告-V3.8-2026-10-15.md'),
]);
const errors = [];
let checkedLocalLinks = 0;
const ids = source => Array.from(source.matchAll(/\bid\s*=\s*(?:"([^"]+)"|'([^']+)'|([^\s>]+))/g), m => m[1] || m[2] || m[3]);
for (const file of documents) {
  const source = fs.readFileSync(file, 'utf8').replace(/^```[^\n]*\n[\s\S]*?^```\s*$/gm, '');
  const anchors = ids(source);
  if (new Set(anchors).size !== anchors.length) errors.push({file, error:'duplicate id'});
  const urls = Array.from(source.matchAll(/\]\(([^)]+)\)|\bhref="([^"]+)"/g), m => m[1] || m[2]);
  for (let url of urls) {
    if (/^(https?:|mailto:|app:|codex:)/.test(url)) continue;
    url = url.replace(/^<|>$/g, '');
    const [reference, hash] = url.split('#');
    const target = reference ? path.resolve(path.dirname(file), decodeURIComponent(reference)) : file;
    checkedLocalLinks++;
    if (!fs.existsSync(target)) { errors.push({file, url, error:'missing target'}); continue; }
    if (hash && path.extname(target) === '.md' && !ids(fs.readFileSync(target, 'utf8')).includes(decodeURIComponent(hash))) errors.push({file,url,error:'missing explicit anchor'});
  }
}
function copyMatches(name, destination) {
  const source = fs.readFileSync(path.join(root, 'docs', name), 'utf8');
  const adjusted = source.replace(/\]\((\.\.?\/)([^)]*)\)/g, (_, base, target) => '](' + '../../../../Desktop/啄木鸟维修平台-V3.8' + (base === './' ? '/docs/' : '/') + target + ')');
  return adjusted === fs.readFileSync(path.join(current, destination), 'utf8');
}
const reportCopiesSameContentAfterLinkBaseAdjustment = copyMatches('二次回归报告-2026-10-14.md','二次回归分析与测试报告-V3.8-2026-10-14.md') && copyMatches('二次修复说明-2026-10-14.md','二次修复与回归报告-V3.8-2026-10-14.md');
const thirdCopyMatches=copyMatches("三次回归报告-2026-10-15.md","三次回归分析与测试报告-V3.8-2026-10-15.md");
if (!thirdCopyMatches) errors.push({error:"third report differs"});
if (!reportCopiesSameContentAfterLinkBaseAdjustment) errors.push({error:'report copy differs'});
const result = {documents:documents.length,checkedLocalLinks,errors,reportCopiesSameContentAfterLinkBaseAdjustment,thirdCopyMatches};
fs.writeFileSync(path.join(__dirname,'document-check.json'),JSON.stringify(result,null,2));
console.log(JSON.stringify(result));
if (errors.length) process.exitCode = 1;
