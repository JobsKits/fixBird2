import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { marked } from '/Users/jobs/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/marked/lib/marked.esm.js';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const source = fs.readFileSync(path.join(root, 'docs/三次回归报告-2026-10-15.md'), 'utf8');
const html = `<!doctype html><html lang="zh"><meta charset="utf-8"><title>V3.8 第三轮回归分析与测试报告</title><style>body{margin:0;background:#f3f5f4;color:#25342e;font:16px/1.65 system-ui,sans-serif}main{max-width:1120px;margin:32px auto;padding:40px;background:white;border-radius:16px}h1{font-size:32px}h2{margin-top:48px;padding-top:12px}a{color:#167359}table{width:100%;border-collapse:collapse;table-layout:fixed;font-size:14px}td,th{border:1px solid #d6dfd9;padding:10px;text-align:left;vertical-align:top;overflow-wrap:anywhere}th{background:#eaf4ee}code{overflow-wrap:anywhere;background:#f0f3f1}pre{padding:18px;background:#f0f3f1;white-space:pre-wrap}img{max-width:100%;height:auto}h2 a{text-decoration:none}@media(max-width:1200px){main{margin:16px;padding:24px}}</style><main>${marked.parse(source)}</main></html>`;
const server = http.createServer((req,res) => {
  if (req.url === '/' || req.url.startsWith('/#')) {res.writeHead(200,{'Content-Type':'text/html; charset=utf-8'});res.end(html);return;}
  const location = path.resolve(root, 'docs', '.' + decodeURIComponent(req.url));
  if (!location.startsWith(root + path.sep) || !fs.existsSync(location) || !fs.statSync(location).isFile()) {res.writeHead(404);res.end();return;}
  res.writeHead(200,{'Content-Type':location.endsWith('.png')?'image/png':'text/plain; charset=utf-8'});fs.createReadStream(location).pipe(res);
});
server.listen(18052,'127.0.0.1',()=>console.log('report preview 18052'));
process.on('SIGINT',()=>server.close());
