// Created by Jobs on 2026年11月18日，星期三.
// Inspect the real bundled examples in an isolated executable; no backend or app build.
import { spawn } from 'node:child_process';
import { cp, mkdtemp, readdir } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

if (process.platform !== 'darwin') throw new Error('This media decoding verification requires MacOS and Xcode Command Line Tools.');
const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, '../../../../..');
const data = path.join(root, '代码/前端/移动端/iOS/App/Data');
const desktop = path.join(root, '代码/前端/PC端/MacOS/Sources');
const contract = path.join(root, '代码/前端/PC端/原生共享契约');
const work = await mkdtemp(path.join(os.tmpdir(), 'repair-bundled-media-'));
async function swiftFiles(directory) {
  const entries = await readdir(directory, { withFileTypes: true });
  const groups = await Promise.all(entries.map(entry => entry.isDirectory()
    ? swiftFiles(path.join(directory, entry.name))
    : entry.name.endsWith('.swift') ? [path.join(directory, entry.name)] : []));
  return groups.flat();
}
const run = (command, args) => new Promise((resolve, reject) => {
  const child = spawn(command, args, { stdio: 'inherit' });
  child.on('error', reject);
  child.on('exit', (code, signal) => code === 0 ? resolve() : reject(new Error(`${command} failed (${code ?? signal})`)));
});
await cp(path.join(contract, 'media-seed.json'), path.join(work, 'media-seed.json'));
for (const name of ['DeviceIntake.png', 'DeviceBoard.png', 'DeviceRepair.png', 'DeviceInspection.mp4']) {
  await cp(path.join(contract, 'Assets', name), path.join(work, name));
}
const files = (await swiftFiles(data)).filter(file => !file.includes('/WBJobsTransport/'));
const binary = path.join(work, 'DesktopBundledMediaSmoke');
await run('xcrun', ['swiftc', '-D', 'DEBUG', '-swift-version', '5', '-parse-as-library',
  ...files,
  path.join(desktop, 'WBJobsTransport.swift'),
  path.join(desktop, 'DesktopRedirectPolicy.swift'),
  path.join(desktop, 'DesktopDeviceMedia.swift'),
  path.join(root, '测试/前端/移动端/iOS/Data/WBFixture/WBFixture.swift'),
  path.join(root, '测试/前端/移动端/iOS/Data/WBStubTransport/WBStubTransport.swift'),
  path.join(here, 'DesktopBundledMediaSmoke.swift'), '-o', binary]);
await run(binary, []);
console.log('Isolated media and executable retained at ' + work);
