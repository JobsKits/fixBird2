const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const crypto = require('node:crypto');
const project = '/Users/jobs/Desktop/啄木鸟维修平台-V3.8';
const evidence = path.join(project, 'docs/四次回归证据-2026-10-15');
const temporary = fs.mkdtempSync(path.join(os.tmpdir(), 'jobs-v38-r4-backend-'));
const server = path.join(temporary, 'Server');
const copied = [];
function copy(directory) {
  for (const item of fs.readdirSync(path.join(project, 'Server', directory), {withFileTypes:true})) {
    if (['vendor', '.git', 'build', '.runtime', 'node_modules'].includes(item.name)) continue;
    const relative = path.join(directory, item.name);
    if (item.isDirectory()) { copy(relative); continue; }
    if (!item.name.endsWith('.go') && !['go.mod', 'go.sum'].includes(item.name)) continue;
    const bytes = fs.readFileSync(path.join(project, 'Server', relative));
    const target = path.join(server, relative);
    fs.mkdirSync(path.dirname(target), {recursive:true});
    fs.writeFileSync(target, bytes);
    copied.push({path:relative, sha256:crypto.createHash('sha256').update(bytes).digest('hex')});
  }
}
copy('');
fs.writeFileSync(path.join(server, 'internal/workbench/backend_deep_fourth_test.go'), fs.readFileSync(path.join(evidence,'backend-deep-fourth_test.go')));
fs.writeFileSync(path.join(evidence,'backend-runtime.json'), JSON.stringify({temporary, server, copied},null,2)+'\n');
process.stdout.write(server+'\n');
