import fs from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import {spawn} from 'node:child_process';
import {fileURLToPath} from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, '../../../../..');
const desktop = path.join(root, '代码/前端/PC端/MacOS/Sources');
const data = path.join(root, '代码/前端/移动端/iOS/App/Data');
const work = await fs.mkdtemp(path.join(os.tmpdir(), 'repair-order-filter-'));
const sources = [];
for (const entry of await fs.readdir(data, {withFileTypes: true})) {
  if (!entry.isDirectory() || entry.name === 'WBJobsTransport') continue;
  for (const file of await fs.readdir(path.join(data, entry.name))) {
    if (file.endsWith('.swift')) sources.push(path.join(data, entry.name, file));
  }
}
const run = (command, args) => new Promise((resolve, reject) => {
  const child = spawn(command, args, {stdio: 'inherit'});
  child.on('error', reject);
  child.on('exit', code => code === 0 ? resolve() : reject(new Error(command + ' failed: ' + code)));
});
await fs.copyFile(path.join(root, '代码/前端/共享组件/Resources/ui-l10n.json'), path.join(work, 'ui-l10n.json'));
await fs.copyFile(path.join(root, '代码/前端/PC端/原生共享契约/desktop-l10n.json'), path.join(work, 'desktop-l10n.json'));
await fs.copyFile(path.join(root, '代码/前端/PC端/原生共享契约/password-emoji-ranges.json'), path.join(work, 'password-emoji-ranges.json'));
const binary = path.join(work, 'OrderFilterSmoke');
await run('xcrun', [
  'swiftc', '-D', 'DEBUG', '-parse-as-library', path.join(here, 'DesktopOrderFilterSmoke.swift'),
  ...['DesktopModel.swift', 'DesktopTimestamp.swift', 'DesktopPasswordPolicy.swift', 'DesktopLocalDemoAuth.swift', 'DesktopDeviceMedia.swift', 'WBJobsTransport.swift', 'DesktopRedirectPolicy.swift'].map(file => path.join(desktop, file)),
  ...sources, '-o', binary,
]);
await run(binary, []);
console.log('PASS actual DesktopModel/WBStore filter regression. Isolated workspace: ' + work);
