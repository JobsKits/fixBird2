import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../../..');
if (process.argv.length !== 3 || process.argv[2] !== '--run') {
  console.log('用途：在自有临时目录验证五平台反部署媒体备份；不连接数据库、不操作真实服务。执行：node 验证媒体备份.mjs --run');
  process.exit(0);
}
const temporary = fs.mkdtempSync(path.join(fs.realpathSync(os.tmpdir()), 'repair-media-backup-'));
let passed = 0;
let failed = 0;
const hash = 'b'.repeat(64);
const backend = `#!/bin/sh
if [ "$1" = -clear-storage ]; then
  [ "$3" = -clear-storage-backup ] && [ -s "$4" ] || exit 23
  printf '%s\\n' "$4" > "$CASE_ROOT/clear-reference"
  exit 0
fi
[ "$1" = -backup ] || exit 24
[ ! -e "$2" ] && [ ! -e "$2.media" ] || exit 25
printf encrypted-aggregate > "$2"
digest="$(shasum -a 256 "$2" | awk '{print $1}')"
if [ "$NO_MEDIA" = 1 ]; then
  printf '{"sha256":"%s"}\\n' "$digest" > "$2.manifest.json"
else
  mkdir "$2.media" || exit 26
  printf encrypted-frame > "$2.media/original.wbmedia"
  printf '{\\n  "sha256": "%s",\\n  "bytes": 19,\\n  "media": [{"sha256":"${hash}","text":"escaped \\\\"sha256\\\\" field"}]\\n}\\n' "$digest" > "$2.manifest.json"
fi
[ "$FAIL_MEDIA_BACKUP" != 1 ] || exit 27
`;
const prefix = `source "$MODULE"
DATA_ACTION=backup
DEPLOY_STATE_DIR="$CASE_ROOT/State"
OPERATION_DIR="$CASE_ROOT/Operation"
state_value() {
  case "$1" in
    data_dir) printf '%s\\n' "$CASE_ROOT/Data";;
    key_file) printf '%s\\n' "$CASE_ROOT/storage.key";;
    binary) printf '%s\\n' "$CASE_ROOT/backend";;
    storage) printf 'tidb\\n';;
    *) printf '\\n';;
  esac
}
`;
function invoke(shell, module, directory, body, extra = {}) {
  const env = { ...process.env };
  for (const key of Object.keys(env)) if (key.startsWith('WB_')) delete env[key];
  return spawnSync(shell, ['-c', prefix + body], {
    cwd: '/', encoding: 'utf8', timeout: 15000,
    env: { ...env, PATH: '/usr/bin:/bin:/usr/sbin:/sbin', NO_COLOR: '1', MODULE: module, CASE_ROOT: directory, ...extra },
  });
}
function fixture(label) {
  const directory = path.join(temporary, label + ' 中文 空格');
  fs.mkdirSync(directory);
  for (const child of ['Data', 'State', 'Operation']) fs.mkdirSync(path.join(directory, child));
  fs.writeFileSync(path.join(directory, 'Data/snapshot.enc'), 'source-original');
  fs.writeFileSync(path.join(directory, 'storage.key'), '12345678901234567890123456789012');
  fs.writeFileSync(path.join(directory, 'backend'), backend, { mode: 0o700 });
  return directory;
}
function check(label, run) {
  try {
    run(); passed++; console.log('PASS ' + label);
  } catch (error) {
    failed++; console.log('FAIL ' + label + ': ' + error.message);
  }
}
function success(result) {
  assert.equal(result.status, 0, result.stdout + result.stderr);
}
function reference(directory) {
  return fs.readFileSync(path.join(directory, 'Operation/database-backup.path'), 'utf8').trim();
}
const common = [];
for (const platform of ['MacOS', 'Ubuntu', 'Debian', 'RockyLinux', 'AlibabaCloudLinux']) {
  const mac = platform === 'MacOS';
  const shell = mac ? '/bin/zsh' : '/bin/bash';
  const name = mac ? '【MacOS】反部署维修工作台.command' : '【Linux】反部署维修工作台.sh';
  const source = fs.readFileSync(path.join(root, '部署', platform, 'Undeployment', name, name), 'utf8');
  assert.ok(source.endsWith('main "$@"\n'));
  common.push(source.slice(source.indexOf('# 只提取顶层字符串摘要'), source.indexOf('# 按资源原点及恢复检查点')));
  const module = path.join(temporary, platform + '.sh');
  fs.writeFileSync(module, source.slice(0, -'main "$@"\n'.length));
  check(platform + ' 媒体清单顶层SHA与清零引用', () => {
    const dir = fixture(platform + '-media');
    success(invoke(shell, module, dir, 'backup_business_data\nclear_business_data\n'));
    const archive = reference(dir);
    const manifest = JSON.parse(fs.readFileSync(archive + '.manifest.json', 'utf8'));
    assert.equal(manifest.media[0].sha256, hash);
    assert.equal(fs.readFileSync(path.join(dir, 'clear-reference'), 'utf8').trim(), archive);
    assert.ok(fs.existsSync(archive + '.media/original.wbmedia'));
    assert.ok(fs.existsSync(path.join(dir, 'Operation/BACKUP_VERIFIED')));
    assert.ok(!fs.existsSync(path.join(dir, 'Data')));
  });
  check(platform + ' 失败重试新目标且保留原候选旁件', () => {
    const dir = fixture(platform + '-retry');
    const first = invoke(shell, module, dir, 'backup_business_data\n', { FAIL_MEDIA_BACKUP: '1' });
    assert.notEqual(first.status, 0);
    assert.ok(fs.existsSync(path.join(dir, 'Data/snapshot.enc')));
    const candidates = fs.readdirSync(path.join(dir, 'Operation')).filter(name => name.startsWith('database-attempt.'));
    assert.equal(candidates.length, 1);
    const old = path.join(dir, 'Operation', candidates[0], 'database.wbbak.media/original.wbmedia');
    const before = fs.readFileSync(old);
    success(invoke(shell, module, dir, 'backup_business_data\nclear_business_data\n'));
    assert.deepEqual(fs.readFileSync(old), before);
    assert.notEqual(path.dirname(reference(dir)), path.dirname(path.dirname(old)));
    assert.equal(fs.readdirSync(path.join(dir, 'Operation')).filter(name => name.startsWith('database-attempt.')).length, 2);
  });
  check(platform + ' 未知旧旁件与链接安全保留', () => {
    const dir = fixture(platform + '-unknown');
    const sidecar = path.join(dir, 'Operation/database.wbbak.media');
    fs.mkdirSync(sidecar);
    fs.writeFileSync(path.join(sidecar, 'unknown'), 'preserve-unknown');
    fs.writeFileSync(path.join(dir, 'unrelated'), 'preserve-target');
    fs.symlinkSync(path.join(dir, 'unrelated'), path.join(sidecar, 'link'));
    fs.writeFileSync(path.join(dir, 'Operation/database.wbbak'), 'prior-backup');
    fs.writeFileSync(path.join(dir, 'Operation/database.wbbak.manifest.json'), 'prior-manifest');
    success(invoke(shell, module, dir, 'backup_business_data\nclear_business_data\n'));
    assert.equal(fs.readFileSync(path.join(sidecar, 'unknown'), 'utf8'), 'preserve-unknown');
    assert.ok(fs.lstatSync(path.join(sidecar, 'link')).isSymbolicLink());
    assert.equal(fs.readFileSync(path.join(dir, 'unrelated'), 'utf8'), 'preserve-target');
    assert.equal(fs.readFileSync(path.join(dir, 'Operation/database.wbbak'), 'utf8'), 'prior-backup');
    assert.equal(fs.readFileSync(path.join(dir, 'Operation/database.wbbak.manifest.json'), 'utf8'), 'prior-manifest');
  });
  check(platform + ' 无媒体紧凑清单兼容', () => {
    const dir = fixture(platform + '-legacy');
    success(invoke(shell, module, dir, 'backup_business_data\nclear_business_data\n', { NO_MEDIA: '1' }));
    assert.ok(!fs.existsSync(reference(dir) + '.media'));
  });
  check(platform + ' 旧已验证固定文件检查点兼容', () => {
    const dir = fixture(platform + '-verified');
    success(invoke(shell, module, dir, `"$CASE_ROOT/backend" -backup "$OPERATION_DIR/database.wbbak"
resource_digest "$CASE_ROOT/Data" > "$OPERATION_DIR/data.sha256"
resource_digest "$CASE_ROOT/storage.key" > "$OPERATION_DIR/key.sha256"
printf verified > "$OPERATION_DIR/BACKUP_VERIFIED"
backup_business_data
clear_business_data
`, { NO_MEDIA: '1' }));
    assert.equal(fs.readFileSync(path.join(dir, 'clear-reference'), 'utf8').trim(), path.join(dir, 'Operation/database.wbbak'));
  });
  check(platform + ' 异常备份检查点拒绝清零', () => {
    const dir = fixture(platform + '-checkpoint');
    fs.writeFileSync(path.join(dir, 'outside'), 'unrelated');
    fs.writeFileSync(path.join(dir, 'Operation/database-backup.path'), path.join(dir, 'outside') + '\n');
    const result = invoke(shell, module, dir, 'clear_business_data\n');
    assert.notEqual(result.status, 0);
    assert.ok(fs.existsSync(path.join(dir, 'Data/snapshot.enc')));
    assert.ok(!fs.existsSync(path.join(dir, 'clear-reference')));
    assert.equal(fs.readFileSync(path.join(dir, 'outside'), 'utf8'), 'unrelated');
    const recorded = fs.readFileSync(path.join(dir, 'Operation/database-backup.path'));
    assert.notEqual(invoke(shell, module, dir, 'backup_business_data\n').status, 0);
    assert.deepEqual(fs.readFileSync(path.join(dir, 'Operation/database-backup.path')), recorded);
    assert.ok(fs.existsSync(path.join(dir, 'Data/snapshot.enc')));
  });
  check(platform + ' 子级/重复/非法摘要拒绝', () => {
    const dir = fixture(platform + '-parser');
    for (const content of [JSON.stringify({ media: [{ sha256: hash }] }), '{"sha256":"' + hash + '","sha256":"' + hash + '"}', '{"sha256":"invalid","media":[{"sha256":"' + hash + '"}]}']) {
      fs.writeFileSync(path.join(dir, 'manifest'), content);
      assert.notEqual(invoke(shell, module, dir, 'backup_manifest_sha256 "$CASE_ROOT/manifest"\n').status, 0);
    }
  });
}
check('五副本备份/清零实现逐字一致', () => {
  for (const block of common) assert.equal(block, common[0]);
});
console.log(JSON.stringify({ passed, failed, fixture: temporary }));
if (failed === 0) fs.rmSync(temporary, { recursive: true });
process.exitCode = failed ? 1 : 0;
