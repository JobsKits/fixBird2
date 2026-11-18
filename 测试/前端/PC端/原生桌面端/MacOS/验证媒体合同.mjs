// Created by Jobs on 2026年11月18日，星期三.
// Compile actual Foundation sources with controlled responses; no network or user data.
import { spawn } from 'node:child_process';
import { mkdtemp, readdir } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

if (process.platform !== 'darwin') throw new Error('This Foundation/CryptoKit verification requires MacOS and Xcode Command Line Tools.');
const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, '../../../../..');
const data = path.join(root, '代码/前端/移动端/iOS/App/Data');
async function swiftFiles(directory) {
  const entries = await readdir(directory, { withFileTypes: true });
  const groups = await Promise.all(entries.map(entry => entry.isDirectory()
    ? swiftFiles(path.join(directory, entry.name))
    : entry.name.endsWith('.swift') ? [path.join(directory, entry.name)] : []));
  return groups.flat();
}
const files = (await swiftFiles(data)).filter(file => !file.includes('/WBJobsTransport/'));
const work = await mkdtemp(path.join(os.tmpdir(), 'repair-media-foundation-'));
const binary = path.join(work, 'MediaFoundationTests');
const run = (command, args) => new Promise((resolve, reject) => {
  const child = spawn(command, args, { stdio: 'inherit' });
  child.on('error', reject);
  child.on('exit', (code, signal) => code === 0 ? resolve() : reject(new Error(`${command} failed (${code ?? signal})`)));
});
await run('xcrun', ['swiftc', '-D', 'DEBUG', '-swift-version', '5', '-parse-as-library',
  ...files,
  path.join(root, '代码/前端/PC端/MacOS/Sources/WBJobsTransport.swift'),
  path.join(root, '代码/前端/PC端/MacOS/Sources/DesktopRedirectPolicy.swift'),
  path.join(root, '测试/前端/移动端/iOS/Data/WBFixture/WBFixture.swift'),
  path.join(root, '测试/前端/移动端/iOS/Data/WBStubTransport/WBStubTransport.swift'),
  path.join(here, 'MediaFoundationTests.swift'), '-o', binary]);
await run(binary, []);
console.log('Isolated test executable retained at ' + work);
