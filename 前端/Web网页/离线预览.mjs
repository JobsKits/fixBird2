#!/usr/bin/env node
// 自述：只在本机回环地址展示 维修工作台 合成样例；不连接业务后台，不保存真实资料。
import { createServer } from 'node:http';
import { readFile, realpath, stat } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const webRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '维修工作台');
const port = Number(process.env.WB_PREVIEW_PORT || 8099);
const mimeTypes = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.png': 'image/png',
  '.svg': 'image/svg+xml',
  '.json': 'application/json; charset=utf-8',
  '.ico': 'image/x-icon'
};

// 按真实路径限制静态文件范围，阻止目录穿越与数据目录公开。
async function serve(request, response) {
  response.setHeader('Cache-Control', 'no-store');
  response.setHeader('X-Content-Type-Options', 'nosniff');
  try {
    const pathname = decodeURIComponent(new URL(request.url, 'http://127.0.0.1').pathname);
    if (pathname === '/api' || pathname.startsWith('/api/')) {
      response.writeHead(503, { 'Content-Type': 'application/json; charset=utf-8' });
      response.end(JSON.stringify({ error: 'offline_preview', message: '独立离线预览服务，未连接业务后台' }));
      return;
    }
    if (!['GET', 'HEAD'].includes(request.method)) {
      response.writeHead(405, { Allow: 'GET, HEAD' });
      response.end('Only static preview is available.');
      return;
    }
    const file = path.resolve(webRoot, '.' + (pathname === '/' ? '/index.html' : pathname));
    if (!file.startsWith(webRoot + path.sep)) {
      response.writeHead(403);
      response.end('Forbidden');
      return;
    }
    const [resolvedRoot, resolvedFile] = await Promise.all([realpath(webRoot), realpath(file)]);
    if (!resolvedFile.startsWith(resolvedRoot + path.sep)) {
      response.writeHead(403);
      response.end('Forbidden');
      return;
    }
    const info = await stat(resolvedFile);
    if (!info.isFile()) throw new Error('not a file');
    const content = await readFile(resolvedFile);
    response.writeHead(200, { 'Content-Type': mimeTypes[path.extname(file)] || 'application/octet-stream' });
    response.end(request.method === 'HEAD' ? undefined : content);
  } catch {
    response.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
    response.end('Not found');
  }
}

// 启动静态演示服务，不读写业务存储或连接任何外部接口。
function main() {
  console.log('离线预览：只展示 维修工作台 合成样例，不连接业务后台，不保存真实资料。');
  if (!Number.isInteger(port) || port < 1 || port > 65535) {
    console.error('✖ WB_PREVIEW_PORT 必须是 1..65535 的整数。');
    process.exitCode = 1;
    return;
  }
  const server = createServer(serve);
  server.on('error', error => {
    console.error(`✖ 离线预览启动失败：${error.message}`);
    process.exitCode = 1;
  });
  server.listen(port, '127.0.0.1', () => {
    console.log(`✔ 浏览器访问 http://127.0.0.1:${port}/；Ctrl+C 停止。`);
  });
  const stop = () => server.close(() => process.exit());
  process.once('SIGINT', stop);
  process.once('SIGTERM', stop);
}

main();
