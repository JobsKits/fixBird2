#!/usr/bin/env python3
"""自述：用临时Go overlay执行外置测试，不复制测试进核心代码、不下载SDK或依赖。"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[3]
MODULE = ROOT / '代码/后端/后端代码'
SOURCES = ROOT / '测试/后端/单元'


def machine_environment() -> tuple[Path, str]:
    """从当前用户环境定位公共工具，平台目录与部署入口保持一致。"""
    if sys.platform == 'darwin':
        base, system = Path.home() / 'Library/Caches', 'MacOS'
    elif os.name == 'nt':
        base, system = Path(os.environ.get('LOCALAPPDATA', str(Path.home() / 'AppData/Local'))), 'Windows'
    else:
        base, system = Path(os.environ.get('XDG_CACHE_HOME', str(Path.home() / '.cache'))), 'Linux'
    arch = {'x86_64': 'amd64', 'AMD64': 'amd64', 'aarch64': 'arm64'}.get(platform.machine(), platform.machine())
    return Path(os.environ.get('WB_ENV_ROOT', str(base / 'JobsSoftwareEnvironments'))).expanduser().resolve(), f'{system}-{arch}'


def find_go(explicit: str | None, environment: Path, target: str) -> str:
    """显式路径失败时直接报错；其它情况复用PATH或已有机器SDK。"""
    specified = explicit or os.environ.get('GO_BIN')
    if specified:
        candidate = Path(specified).expanduser()
        if not candidate.is_absolute():
            candidate = ROOT / candidate
        candidates = [str(candidate)]
    else:
        candidates = [shutil.which('go')]
        executable = 'go.exe' if os.name == 'nt' else 'go'
        candidates += [str(path) for path in sorted((environment / 'Go').glob(f'go*/{target}/go/bin/{executable}'), reverse=True)]
    for candidate in filter(None, candidates):
        result = subprocess.run([candidate, 'version'], text=True, capture_output=True)
        if result.returncode == 0:
            return candidate
    raise RuntimeError('没有可用Go；通过--go、GO_BIN或WB_ENV_ROOT指定已有机器SDK，本入口不会安装。')


def overlay_map() -> dict[str, str]:
    """保留原包上下文，虚拟测试路径只存在于临时映射文件。"""
    result = {}
    for source in sorted(SOURCES.rglob('*_test.go')):
        virtual = MODULE / source.relative_to(SOURCES)
        if virtual.exists():
            raise RuntimeError(f'核心代码出现重复测试：{virtual.relative_to(ROOT)}')
        result[str(virtual)] = str(source)
    if not result:
        raise RuntimeError('外置Go测试为空，拒绝把未执行写成通过。')
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--list', action='store_true', help='只显示映射，不启动Go或写文件')
    parser.add_argument('--run', action='store_true', help='明确执行测试，供命令行和CI使用')
    parser.add_argument('--go', help='已有Go可执行文件；相对路径以项目根为准')
    parser.add_argument('--race', action='store_true', help='启用Go竞态检测，需健康CGO工具链')
    parser.add_argument('--vet', action='store_true', help='测试后执行go vet')
    parser.add_argument('--package', action='append', choices=['./cmd/workbench', './internal/workbench'], help='只执行指定包，可重复；默认两个包')
    args = parser.parse_args()
    mapping = overlay_map()
    print('维修后端外置测试：临时overlay映射；源码、业务运行数据及已有服务保持独立。', flush=True)
    if args.list:
        for virtual, source in mapping.items():
            print(f'{Path(virtual).relative_to(MODULE)} <- {Path(source).relative_to(ROOT)}')
        print(f'共{len(mapping)}份测试；未启动Go、未创建文件。')
        return 0
    if not args.run:
        if not sys.stdin.isatty():
            raise RuntimeError('未提供--run且没有交互终端；只读使用--list。')
        if input('将使用已有工具和依赖，缓存位于机器环境；回车执行，其它输入取消：'):
            print('已取消。')
            return 0
    environment, target = machine_environment()
    go = find_go(args.go, environment, target)
    cache = environment / 'Go/Cache' / target
    env = dict(os.environ)
    for name, leaf in [('GOCACHE', 'Build'), ('GOMODCACHE', 'Modules'), ('GOPATH', 'Path')]:
        env.setdefault(name, str(cache / leaf))
    env.update(GOTOOLCHAIN='local', GOTELEMETRY='off', GOPROXY='off', GOSUMDB='off')
    packages = args.package or ['./cmd/workbench', './internal/workbench']
    with tempfile.TemporaryDirectory(prefix='RepairWorkbench-GoTests-') as temp:
        overlay = Path(temp) / 'Overlay.json'
        overlay.write_text(json.dumps({'Replace': mapping}, ensure_ascii=False), encoding='utf-8')
        common = [go, '-C', str(MODULE)]
        command = common + ['test', '-overlay', str(overlay), '-mod=readonly', '-count=1', '-timeout=10m']
        if args.race:
            command.append('-race')
        result = subprocess.run(command + packages, env=env)
        if result.returncode:
            return result.returncode
        if args.vet:
            return subprocess.run(common + ['vet', '-overlay', str(overlay), '-mod=readonly'] + packages, env=env).returncode
    return 0


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except (OSError, RuntimeError, subprocess.SubprocessError) as error:
        print(f'失败：{error}', file=sys.stderr)
        raise SystemExit(1)
