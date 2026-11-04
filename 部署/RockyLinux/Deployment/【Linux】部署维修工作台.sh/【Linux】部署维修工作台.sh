#!/bin/bash
# 脚本自述：
# - 核心用途：用 fzf 选择本地部署＋内网穿透或服务器部署，构建并运行维修工作台。
# - 外网访问：默认浏览器打开链接后用指定邮箱收验证码；邮箱只验证访问者身份。原生App／API联调可选无邮箱验证的公开演示，仅用合成数据。
# - 影响范围：缺失公共工具下载到机器环境；运行资料留在本项目独立用户目录；不注册服务、不改全局PATH或防火墙。
# - 运行提示：先回车确认再选择模式；Esc取消；Ctrl+C停止本次子进程并保留数据。

SCRIPT_ENTRY="$0"
PROJECT_DIR=""
ENV_ROOT=""
RUNTIME_ROOT=""
PLATFORM_LABEL=""
SCRIPT_PATH=""
LOG_FILE=""
CHECK_MODE=0
PLAN_MODE=0
PLAN_TARGET=""
DEPLOY_MODE=""
GO_EXECUTABLE=""
FZF_EXECUTABLE=""
CLOUDFLARED_EXECUTABLE=""
TOOL_RESULT=""
PLATFORM_OS=""
PLATFORM_ARCH=""
API_PID=""
TUNNEL_PID=""
BROWSER_MENU_PID=""
BROWSER_MENU_PAUSED=0
BROWSER_OPEN_PIDS=()
PUBLIC_URL=""
QR_BINARY=""
QR_PAGE=""
QR_GENERATION=0
WORKBENCH_BINARY=""
RUN_DIR=""
ALLOWED_MAIL=""
PUBLIC_TUNNEL=0
OUTPUT_COLOR=0
EXPECTED_OS="linux"
EXPECTED_DISTRO="rocky"
DEPLOY_STATE_DIR=""
DEPLOY_OPERATION_LOCK=""
DEPLOY_LOCK_HELD=0
PROJECT_ENV_DIR=""
MISSING_RUNTIME_PARENTS=""

# 根据脚本真实位置向上寻找本项目，不依赖启动工作目录。
prepare_display_context() {
  local current="$SCRIPT_ENTRY" parent target guard=0
  case "$current" in /*) ;; *) current="$(pwd)/$current";; esac
  while [ -L "$current" ]; do
    [ "$guard" -lt 16 ] || { printf '%s\n' '入口软链接层数异常。' >&2; exit 1; }
    parent="$(cd -P "$(dirname "$current")" && pwd)" || exit 1
    target="$(readlink "$current")" || exit 1
    case "$target" in /*) current="$target";; *) current="$parent/$target";; esac
    guard=$((guard + 1))
  done
  parent="$(cd -P "$(dirname "$current")" && pwd)" || exit 1
  SCRIPT_PATH="$parent/$(basename "$current")"
  while [ "$parent" != / ]; do
    if [ -f "$parent/代码/后端/后端代码/go.mod" ] && [ -d "$parent/代码/后端/后端代码/cmd/workbench" ]; then PROJECT_DIR="$parent"; break; fi
    parent="$(dirname "$parent")"
  done
  [ -n "$PROJECT_DIR" ] || { printf '%s\n' '找不到完整维修项目：代码/后端/后端代码/go.mod。' >&2; exit 1; }
  resolve_machine_paths
  LOG_FILE="${TMPDIR:-/tmp}/维修部署-$$.log"
  if [ -t 1 ] && [ -n "${TERM:-}" ] && [ "${TERM:-}" != dumb ] && [ -z "${NO_COLOR+x}" ]; then OUTPUT_COLOR=1; fi
}
# 只读解析机器公共环境与本项目运行资料，不依赖启动工作目录。
resolve_machine_paths() {
  local environment_default runtime_default
  case "$(uname -s)" in
    Darwin)
      PLATFORM_LABEL="MacOS"
      environment_default="$HOME/Library/Caches/JobsSoftwareEnvironments"
      runtime_default="$HOME/Library/Application Support/JobsSoftwareProjects/RepairWorkbench/Runtime";;
    Linux)
      PLATFORM_LABEL="Linux"
      environment_default="${XDG_CACHE_HOME:-$HOME/.cache}/JobsSoftwareEnvironments"
      runtime_default="${XDG_STATE_HOME:-$HOME/.local/state}/JobsSoftwareProjects/RepairWorkbench/Runtime";;
    *) printf '%s\n' '无法解析本平台机器环境目录。' >&2; exit 1;;
  esac
  ENV_ROOT="${WB_ENV_ROOT:-$environment_default}"
  RUNTIME_ROOT="${WB_RUNTIME_DIR:-$runtime_default}"
  case "$ENV_ROOT" in /*) ;; *) printf '%s\n' 'WB_ENV_ROOT必须是机器环境绝对路径。' >&2; exit 1;; esac
  case "$RUNTIME_ROOT" in /*) ;; *) printf '%s\n' 'WB_RUNTIME_DIR必须是运行资料绝对路径。' >&2; exit 1;; esac
  case "$ENV_ROOT" in "$PROJECT_DIR"|"$PROJECT_DIR"/*) printf '%s\n' '公共工具环境不能位于项目源码目录。' >&2; exit 1;; esac
}
# 显示运行时固定自述，检查和计划模式保持严格只读。
show_script_intro_and_wait() {
  prepare_display_context
  parse_options "$@"
  display_line '1;31' '================ 维修平台双模式部署 ================'
  display_line '0;34' '1、本地部署＋内网穿透：运行本机后端，免费Quick Tunnel生成临时HTTPS公网链接。'
  display_line '0;34' '   默认浏览器访问：打开链接→输入允许的邮箱→收取并填写验证码→进入工作台。'
  display_line '0;34' '   邮箱只用于公网入口身份验证，与维修业务无关；原生App／API联调请选择公开演示，仅用合成数据。'
  display_line '0;34' '2、服务器部署：仅构建并运行后端，不建立穿透；保留回环监听与现有数据语义。'
  display_line '0;34' '3、缺失Go／fzf／cloudflared将从官方锁定来源校验后放入机器公共环境缓存，已有健康工具复用。'
  display_line '0;34' '4、不安装系统服务、不改全局网络、PATH或电源；公网联调仅用合成数据。'
  display_line '0;34' '5、回车后用fzf选择；部署前Esc／空选取消，子菜单←返回。Ctrl+C停止本次子进程，保留业务数据。'
  display_line '0;34' '6、启动后显示各端URL与离线二维码，fzf可打开公网／本机地址或扫码页面；服务保持运行。'
  display_line '0;34' '   网页菜单Esc仅收起，原终端回车再选；Linux需桌面会话和xdg-open，无桌面时只提示，不安装桌面或停止服务。'
  display_line '0;34' "日志：$LOG_FILE（正常确认后才创建）；--check／--plan不写日志。"
  if [ "$CHECK_MODE" = 1 ] || [ "$PLAN_MODE" = 1 ]; then return 0; fi
  [ -t 0 ] && [ -t 1 ] || { printf '%s\n' '没有交互终端；正常部署必须在终端使用fzf。只读审阅用--check或--plan。' >&2; exit 1; }
  local confirmation
  printf '%s' '已了解本地写入与访问影响，按回车继续；其它输入取消：'
  IFS= read -r confirmation || exit 0
  [ -z "$confirmation" ] || exit 0
}
# 仅接受无副作用的检查／计划选项，不提供绕过正常选择的模式参数。
parse_options() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --check) CHECK_MODE=1;;
      --plan) PLAN_MODE=1;;
      --mode) shift; [ "$#" -gt 0 ] || { printf '%s\n' '--mode缺少值。' >&2; exit 2; }; PLAN_TARGET="$1";;
      --help|-h) printf '%s\n' '用法：入口 [--check | --plan [--mode local|server]]；正常运行必须交互选择。'; exit 0;;
      *) printf '未知参数：%s\n' "$1" >&2; exit 2;;
    esac
    shift
  done
  if [ -n "$PLAN_TARGET" ] && [ "$PLAN_MODE" != 1 ]; then printf '%s\n' '--mode只用于--plan，不能跳过fzf。' >&2; exit 2; fi
  case "$PLAN_TARGET" in ''|local|server) ;; *) printf '%s\n' '计划模式只接受local或server。' >&2; exit 2;; esac
}
# 将指定样式的文本显示到终端，并在日志已经建立后追加纯文本记录。
display_line() {
  if [ "$OUTPUT_COLOR" = 1 ]; then printf '\033[%sm%s\033[0m\n' "$1" "$2"; else printf '%s\n' "$2"; fi
}
# 向正常运行日志追加必要诊断，不输出凭据或完整环境。
log_message() {
  display_line "$1" "$2"
  [ -n "$RUN_DIR" ] && printf '%s\n' "$2" >> "$LOG_FILE"
}
# 在当前执行层明确失败并触发本次子进程清理。
fail() { log_message '1;31' "✖ $1"; exit "${2:-1}"; }
# 识别实际系统与CPU架构，拒绝错误平台包。
detect_platform() {
  case "$(uname -s)" in Darwin) PLATFORM_OS=darwin;; Linux) PLATFORM_OS=linux;; *) printf '%s\n' '此入口仅支持MacOS或Linux。' >&2; exit 1;; esac
  [ "$PLATFORM_OS" = "$EXPECTED_OS" ] || { printf '当前平台不匹配本入口：需要%s，实际%s。\n' "$EXPECTED_OS" "$PLATFORM_OS" >&2; exit 1; }
  if [ "$PLATFORM_OS" = linux ]; then
    local actual_id
    actual_id="$(awk -F= '$1=="ID"{gsub(/"/,"",$2);print $2;exit}' /etc/os-release 2>/dev/null)"
    [ "$actual_id" = "$EXPECTED_DISTRO" ] || { printf '发行版不匹配：需要%s，实际%s；请使用本系统目录入口。\n' "$EXPECTED_DISTRO" "${actual_id:-unknown}" >&2; exit 1; }
  fi
  case "$(uname -m)" in x86_64|amd64) PLATFORM_ARCH=amd64;; arm64|aarch64) PLATFORM_ARCH=arm64;; *) printf '%s\n' '未提供此CPU架构的锁定工具。' >&2; exit 1;; esac
}
# 执行不下载不写入的路径与锁定清单结构检查。
handle_readonly_modes() {
  if [ "$CHECK_MODE" != 1 ] && [ "$PLAN_MODE" != 1 ]; then return 0; fi
  detect_platform
  printf '项目：%s\n系统：%s/%s\n' "$PROJECT_DIR" "$PLATFORM_OS" "$PLATFORM_ARCH"
  printf '公共环境：%s\n运行资料：%s\n' "$ENV_ROOT" "$RUNTIME_ROOT"
  [ -f "$PROJECT_DIR/代码/前端/PC端/Web/维修工作台/index.html" ] || { printf '%s\n' '缺少Web页面。' >&2; exit 1; }
  [ -f "$PROJECT_DIR/部署/deploy-tools.lock.tsv" ] || { printf '%s\n' '缺少工具锁定清单。' >&2; exit 1; }
  printf '%s\n' '模式：本地部署＋内网穿透（默认浏览器访问，指定邮箱收验证码；App／API联调可选公开演示）；服务器部署（无隧道）。'
  printf '计划选择：%s\n' "${PLAN_TARGET:-由正常运行fzf选择}"
  printf '%s\n' '正常流程：确认→准备fzf→选择模式→健康Go/必要穿透工具→构建新二进制→本机health→必要隧道→fzf选地址打开浏览器并持续监控→退出清理。'
  printf '%s\n' '只读完成：没有下载、缓存/配置/日志写入、构建、业务启动或公网连接。'
  exit 0
}
# 在用户确认后准备日志、运行目录和异常退出处理。
initialize_runtime() {
  set -o pipefail
  if [ -n "${ZSH_VERSION:-}" ]; then setopt NO_NOMATCH; fi
  umask 077
  detect_platform
  [ ! -L "$RUNTIME_ROOT" ] || fail '运行资料目录是软链接；请先核对真实目录。'
  RUNTIME_ROOT="$(deploy_state_path "$RUNTIME_ROOT")" || fail '运行资料目录无效。'
  local runtime_existed=absent runtime_parent="$RUNTIME_ROOT"
  while [ ! -e "$runtime_parent" ]; do
    if [ -z "$MISSING_RUNTIME_PARENTS" ]; then MISSING_RUNTIME_PARENTS="$runtime_parent"; else MISSING_RUNTIME_PARENTS="$MISSING_RUNTIME_PARENTS
$runtime_parent"; fi
    runtime_parent="$(dirname "$runtime_parent")"
  done
  [ ! -e "$RUNTIME_ROOT" ] || runtime_existed=existing
  mkdir -p "$RUNTIME_ROOT" || fail '无法创建项目运行目录。'
  RUN_DIR="$(mktemp -d "$RUNTIME_ROOT/deploy-session.XXXXXXXX")" || fail '无法原子创建本次运行目录。'
  (set -C; : > "$LOG_FILE") 2>/dev/null || { printf '%s\n' '无法独占创建部署日志；已有同名文件时不会覆盖或跟随软链接。' >&2; exit 1; }
  trap cleanup EXIT
  deploy_state_initialize "$runtime_existed"
  trap 'exit 130' INT
  trap 'exit 143' TERM
  trap cleanup EXIT
}
# 仅终止本次启动并仍属于本次作业的后端与隧道进程。
cleanup() {
  [ "${ZSH_SUBSHELL:-0}" = 0 ] && [ "${BASH_SUBSHELL:-0}" = 0 ] || return 0
  local child guard
  for child in "$BROWSER_MENU_PID" "$TUNNEL_PID" "$API_PID"; do
    [ -n "$child" ] || continue
    if kill -0 "$child" 2>/dev/null; then
      kill -TERM "$child" 2>/dev/null || true
      guard=0
      while kill -0 "$child" 2>/dev/null && [ "$guard" -lt 30 ]; do sleep 0.1; guard=$((guard + 1)); done
      kill -0 "$child" 2>/dev/null && kill -KILL "$child" 2>/dev/null || true
    fi
    guard=0
    while kill -0 "$child" 2>/dev/null && [ "$guard" -lt 20 ]; do sleep 0.1; guard=$((guard + 1)); done
    if kill -0 "$child" 2>/dev/null; then
      printf '本次子进程%s未在宽限内结束，请核对操作系统状态；没有扩大停止范围。\n' "$child" >&2
    else wait "$child" 2>/dev/null || true; fi
  done
  BROWSER_MENU_PID=""; API_PID=""; TUNNEL_PID=""
  expire_access_qr
  deploy_state_finish
}
# 计算SHA256，不引入额外语言运行时。
hash_file() {
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}';
  elif command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}';
  else fail '缺少系统SHA256工具，不能跳过下载校验。'; fi
}
# 只从锁定HTTPS来源下载到本次缓存，失败不执行不完整文件。
download_verified() {
  local source_url="$1" target_file="$2" expected="$3" actual
  case "$source_url" in https://*) ;; *) fail '锁定来源必须为HTTPS。';; esac
  log_message '0;34' "来源｜$source_url"
  log_message '0;34' "目标｜$target_file"
  if command -v curl >/dev/null 2>&1; then
    curl --fail --location --show-error --connect-timeout 10 --max-time 240 --retry 2 --output "$target_file.part" "$source_url" >> "$LOG_FILE" 2>&1 || fail "下载失败：$source_url；检查本机网络或日志。"
  elif command -v wget >/dev/null 2>&1; then
    wget --timeout=30 --tries=2 -O "$target_file.part" "$source_url" >> "$LOG_FILE" 2>&1 || fail "下载失败：$source_url。"
  else fail '系统缺少curl/wget；请按本系统文档准备基础下载命令，不能绕过校验。'; fi
  actual="$(hash_file "$target_file.part")"
  [ "$actual" = "$expected" ] || fail "SHA256不匹配，停止使用下载文件：$target_file.part"
  mv "$target_file.part" "$target_file" || fail '无法落盘已校验归档。'
}
# 只为缺失工具读取本仓锁定清单并安装到机器环境缓存。
install_cached_tool() {
  local tool="$1" row version filename expected source_url kind cache archive staging candidate tool_directory version_directory download_directory
  row="$(awk -F '\t' -v t="$tool" -v o="$PLATFORM_OS" -v a="$PLATFORM_ARCH" '$1==t&&$2==o&&$3==a{print;exit}' "$PROJECT_DIR/部署/deploy-tools.lock.tsv")"
  [ -n "$row" ] || fail "缺少${tool}的$PLATFORM_OS/${PLATFORM_ARCH}官方锁定包。"
  version="$(printf '%s\n' "$row" | cut -f4)"; filename="$(printf '%s\n' "$row" | cut -f5)"
  expected="$(printf '%s\n' "$row" | cut -f6)"; source_url="$(printf '%s\n' "$row" | cut -f7)"; kind="$(printf '%s\n' "$row" | cut -f8)"
  case "$tool" in go) tool_directory=Go; version_directory="go$version";; fzf) tool_directory=Fzf; version_directory="$version";; cloudflared) tool_directory=Cloudflared; version_directory="$version";; esac
  cache="$PROJECT_ENV_DIR/Tools/$tool_directory/$version_directory/$PLATFORM_LABEL-$PLATFORM_ARCH"
  [ ! -L "$ENV_ROOT" ] && [ ! -L "$PROJECT_ENV_DIR/Tools/$tool_directory" ] && [ ! -L "$PROJECT_ENV_DIR/Tools/$tool_directory/$version_directory" ] && [ ! -L "$cache" ] || fail '工具缓存目录是软链接，拒绝跟随到项目外。'
  [ ! -L "$cache/go" ] && [ ! -L "$cache/go/bin" ] && [ ! -L "$cache/$tool" ] || fail '工具缓存内部存在软链接，需先人工核对。'
  if [ "$tool" = go ]; then candidate="$cache/go/bin/go"; else candidate="$cache/$tool"; fi
  if tool_healthy "$tool" "$candidate"; then TOOL_RESULT="$candidate"; return 0; fi
  mkdir -p "$(dirname "$cache")" || fail '工具缓存目录不可写。'
  [ ! -L "$PROJECT_ENV_DIR/Downloads" ] || fail '下载缓存目录是软链接，拒绝跟随。'
  mkdir -p "$PROJECT_ENV_DIR/Downloads" || fail '无法创建机器下载缓存。'
  download_directory="$(mktemp -d "$PROJECT_ENV_DIR/Downloads/$tool-$version-$PLATFORM_LABEL-$PLATFORM_ARCH.XXXXXXXX")" || fail '无法创建独立下载目录。'
  archive="$download_directory/$filename"; staging="$download_directory/Extract"
  download_verified "$source_url" "$archive" "$expected"
  mkdir -p "$staging" || fail '无法创建独立解包目录。'
  case "$kind" in
    tar.gz|tgz) command -v tar >/dev/null 2>&1 || fail '缺少系统tar。'; tar -xzf "$archive" -C "$staging" >> "$LOG_FILE" 2>&1 || fail "解包${tool}失败。";;
    binary) cp "$archive" "$staging/$tool" || fail '无法保存工具。';;
    *) fail "此Shell入口不处理归档类型：$kind";;
  esac
  if [ "$tool" = go ]; then candidate="$staging/go/bin/go"; else candidate="$staging/$tool"; fi
  [ -f "$candidate" ] && [ ! -L "$candidate" ] || fail '归档缺少预期普通可执行文件。'
  chmod u+x "$candidate" || fail '无法赋予本次工具执行位。'
  tool_healthy "$tool" "$candidate" || fail "安装后${tool}健康复检失败。"
  if [ -e "$cache" ]; then mv "$cache" "$RUN_DIR/tool-before-$tool" || fail '无法保留原损坏工具缓存。'; fi
  mv "$staging" "$cache" || fail '工具缓存安装失败。'
  if [ "$tool" = go ]; then TOOL_RESULT="$cache/go/bin/go"; else TOOL_RESULT="$cache/$tool"; fi
  log_message '0;34' "已准备｜$tool $version｜来源 $source_url"
}
# 对实际调用的工具执行最小版本和必要参数健康检查。
tool_healthy() {
  local tool="$1" candidate="$2" info minor
  [ -n "$candidate" ] && [ -x "$candidate" ] || return 1
  case "$tool" in
    go) info="$("$candidate" version 2>/dev/null)" || return 1; minor="$(printf '%s\n' "$info" | sed -n 's/.*go1\.\([0-9][0-9]*\).*/\1/p')"; [ -n "$minor" ] && [ "$minor" -ge 24 ];;
    fzf) FZF_DEFAULT_OPTS='' FZF_DEFAULT_OPTS_FILE=/dev/null FZF_DEFAULT_COMMAND='' "$candidate" --version >/dev/null 2>&1 && FZF_DEFAULT_OPTS='' FZF_DEFAULT_OPTS_FILE=/dev/null FZF_DEFAULT_COMMAND='' "$candidate" --help 2>/dev/null | grep -- '--expect' >/dev/null;;
    cloudflared)
      "$candidate" --version >/dev/null 2>&1 || return 1
      info="$("$candidate" tunnel --help 2>/dev/null)" || return 1
      printf '%s\n' "$info" | grep -- '--url' >/dev/null && printf '%s\n' "$info" | grep -- '--config' >/dev/null && printf '%s\n' "$info" | grep -- '--no-autoupdate' >/dev/null;;
    *) return 1;;
  esac
}
# 优先复用已有健康fzf，缺失才准备机器环境副本。
prepare_fzf() {
  local candidate="${WB_FZF_BIN:-$(command -v fzf 2>/dev/null || true)}"
  if tool_healthy fzf "$candidate"; then FZF_EXECUTABLE="$candidate"; else install_cached_tool fzf; FZF_EXECUTABLE="$TOOL_RESULT"; fi
}
# 用fzf选择两种部署模式，取消和空选不会进入构建或启动。
select_deploy_mode() {
  local selected code scope
  while :; do
    selected="$(printf '%s\n' $'local\t本地部署＋内网穿透' $'server\t服务器部署' | FZF_DEFAULT_OPTS='' FZF_DEFAULT_OPTS_FILE=/dev/null FZF_DEFAULT_COMMAND='' "$FZF_EXECUTABLE" --no-multi --delimiter='\t' --with-nth=2 --height=40% --border --prompt='部署模式 > ' --header='回车选择；Esc取消。本地模式生成公网链接，默认浏览器需用指定邮箱收验证码。')"
    code=$?
    case "$code" in 0) ;; 1|130) log_message '0;34' '已取消，没有构建或启动业务。'; exit 0;; *) fail "fzf选择器异常退出：$code。" "$code";; esac
    [ -n "$selected" ] || { log_message '0;34' '已取消，没有构建或启动业务。'; exit 0; }
    case "$selected" in
      $'server\t服务器部署') DEPLOY_MODE=server; return 0;;
      $'local\t本地部署＋内网穿透') DEPLOY_MODE=local;;
      *) fail '选择结果异常。';;
    esac
    scope="$(printf '%s\n' $'private\t浏览器访问（指定邮箱收验证码）' $'public\t公开演示／App联调（隧道不验证邮箱）' | FZF_DEFAULT_OPTS='' FZF_DEFAULT_OPTS_FILE=/dev/null FZF_DEFAULT_COMMAND='' "$FZF_EXECUTABLE" --no-multi --delimiter='\t' --with-nth=2 --height=40% --border --expect=left --prompt='外网访问方式 > ' --header=$'默认浏览器：打开公网链接→输入允许的邮箱→收取并填写验证码。\n邮箱只验证访问者身份，与维修业务无关。\n原生App／API不能完成网页验证码，请选公开演示。\n公开演示：取得链接即可到达服务入口；仅用合成数据。\n←返回部署模式；Esc全取消。')"
    code=$?
    case "$code:$scope" in 0:left|1:left|0:$'left\nprivate\t浏览器访问（指定邮箱收验证码）'|0:$'left\npublic\t公开演示／App联调（隧道不验证邮箱）') continue;; esac
    case "$code" in 0) ;; 1|130) log_message '0;34' '已取消，没有构建或启动业务。'; exit 0;; *) fail "fzf访问范围选择器异常退出：$code。" "$code";; esac
    [ -n "$scope" ] || { log_message '0;34' '已取消，没有构建或启动业务。'; exit 0; }
    case "$scope" in
      $'\nprivate\t浏览器访问（指定邮箱收验证码）') PUBLIC_TUNNEL=0; return 0;;
      $'\npublic\t公开演示／App联调（隧道不验证邮箱）') PUBLIC_TUNNEL=1; return 0;;
      *) fail '访问范围选择异常。';;
    esac
  done
}
# 仅为本地模式收集受限访问邮箱，公开访问必须明确输入PUBLIC。
configure_tunnel_access() {
  [ "$DEPLOY_MODE" = local ] || return 0
  log_message '1;31' '关闭此运行终端，服务将结束'
  if [ "$PUBLIC_TUNNEL" = 1 ]; then
    printf '%s\n' '已选择公开演示／App联调：隧道不验证邮箱，任何取得链接的人都能到达服务入口。'
    printf '%s\n' '风险：任何取得地址的人可访问已知演示身份；只允许合成数据。'
    printf '%s' '确认公开合成演示请输入PUBLIC；其它输入取消：'
    local confirmation; IFS= read -r confirmation || exit 0
    [ "$confirmation" = PUBLIC ] || exit 0
    ALLOWED_MAIL=''
  else
    printf '%s\n' '已选择浏览器访问：邮箱只用于公网入口身份验证，与维修业务无关。'
    printf '%s\n' '访问者打开HTTPS链接后，输入允许的邮箱，再收取并填写一次性验证码才能进入。'
    printf '%s\n' '原生App／普通API客户端不能完成网页验证码；联调时应选择公开演示。'
    ALLOWED_MAIL="${WB_TUNNEL_ALLOWED_MAIL:-}"
    if [ -z "$ALLOWED_MAIL" ]; then
      printf '%s' '输入允许访问者的邮箱（本人或受邀者，多个用逗号分隔）；空行取消：'
      IFS= read -r ALLOWED_MAIL || exit 0
    fi
    case "$ALLOWED_MAIL" in *@*.*) ;; '') exit 0;; *) fail '允许邮箱格式不正确，不能默认公开。';; esac
  fi
}
# 发现可用Go，显式配置错误时不擅自更换到其它版本。
prepare_go() {
  local candidate=""
  if [ -n "${GO_BIN:-}" ]; then
    candidate="$GO_BIN"; case "$candidate" in /*) ;; *) candidate="$PROJECT_DIR/$candidate";; esac
    tool_healthy go "$candidate" || fail 'GO_BIN指定工具不可用或低于Go1.24。'
    GO_EXECUTABLE="$candidate"; return 0
  fi
  candidate="$(command -v go 2>/dev/null || true)"
  if tool_healthy go "$candidate"; then GO_EXECUTABLE="$candidate"; return 0; fi
  for candidate in "$ENV_ROOT"/Go/go*/"$PLATFORM_LABEL-$PLATFORM_ARCH"/go/bin/go; do
    if tool_healthy go "$candidate"; then GO_EXECUTABLE="$candidate"; return 0; fi
  done
  install_cached_tool go; GO_EXECUTABLE="$TOOL_RESULT"
}
# 为本地模式准备支持受限邮箱的cloudflared，不修改健康已有工具。
prepare_tunnel_tool() {
  [ "$DEPLOY_MODE" = local ] || return 0
  local candidate="${WB_CLOUDFLARED_BIN:-$(command -v cloudflared 2>/dev/null || true)}"
  if tool_healthy cloudflared "$candidate"; then
    if [ "$PUBLIC_TUNNEL" = 1 ] || "$candidate" tunnel --help 2>&1 | grep -- '--allowed-mail' >/dev/null; then CLOUDFLARED_EXECUTABLE="$candidate"; return 0; fi
    log_message '0;34' '已有cloudflared缺少邮箱访问限制，保留它并准备机器环境内锁定版本。'
  fi
  install_cached_tool cloudflared; CLOUDFLARED_EXECUTABLE="$TOOL_RESULT"
  if [ "$PUBLIC_TUNNEL" != 1 ]; then "$CLOUDFLARED_EXECUTABLE" tunnel --help 2>&1 | grep -- '--allowed-mail' >/dev/null || fail '当前cloudflared未提供邮箱限制，不会回退为公开访问。'; fi
}
# 解析项目本地路径并保留原有数据、密钥和回环监听语义。
configure_paths() {
  export WB_ADDR="${WB_ADDR:-127.0.0.1:8098}"
  case "$WB_ADDR" in 127.0.0.1:*|localhost:*|'[::1]':*) ;; *) fail 'WB_ADDR只允许本机回环地址。';; esac
  local port="${WB_ADDR##*:}"
  case "$port" in ''|*[!0-9]*) fail '监听端口无效。';; esac
  [ "$port" -gt 0 ] && [ "$port" -le 65535 ] || fail '监听端口须在1..65535。'
  export WB_PROJECT_ROOT="$PROJECT_DIR" WB_RUNTIME_DIR="$RUNTIME_ROOT"
  export WB_DATA_DIR="${WB_DATA_DIR:-$RUNTIME_ROOT/data}"
  export WB_WEB_DIR="${WB_WEB_DIR:-$PROJECT_DIR/代码/前端/PC端/Web/维修工作台}"
  export WB_ADMIN_DIR="${WB_ADMIN_DIR:-$PROJECT_DIR/代码/前端/后台管理端/Web}"
  export WB_ADMIN_FLUTTER_DIR="${WB_ADMIN_FLUTTER_DIR:-$PROJECT_DIR/代码/前端/后台管理端/Flutter/Dist/Web}"
  export WB_CLIENT_FLUTTER_DIR="${WB_CLIENT_FLUTTER_DIR:-$PROJECT_DIR/代码/前端/移动端/Flutter/Dist/Web}"
  export WB_ADMIN_CONTRACT_DIR="${WB_ADMIN_CONTRACT_DIR:-$PROJECT_DIR/代码/前端/后台管理端/共享契约}"
  local name value
  for name in WB_DATA_DIR WB_WEB_DIR WB_ADMIN_DIR WB_ADMIN_FLUTTER_DIR WB_CLIENT_FLUTTER_DIR WB_ADMIN_CONTRACT_DIR WB_KEY_FILE WB_BACKUP_DIR; do
    eval 'value=${'"$name"'-}'
    if [ -n "$value" ]; then case "$value" in /*) ;; *) value="$PROJECT_DIR/$value";; esac; export "$name=$value"; fi
  done
  [ -f "$WB_WEB_DIR/index.html" ] || fail '缺少工作台页面。'
  WORKBENCH_BINARY="$RUNTIME_ROOT/workbench"
  local go_cache="$PROJECT_ENV_DIR/GoCache/$PLATFORM_LABEL-$PLATFORM_ARCH"
  for name in Build Modules Path; do [ ! -L "$go_cache/$name" ] || fail "缓存${name}是软链接，拒绝跟随。"; done
  export GOCACHE="$go_cache/Build" GOMODCACHE="$go_cache/Modules" GOPATH="$go_cache/Path" GOTOOLCHAIN=local GOTELEMETRY=off
}
# 只用新构建成功的二进制启动，不回退执行旧产物。
build_workbench() {
  local pending="$RUN_DIR/workbench.new" result
  log_message '0;34' "构建｜$GO_EXECUTABLE｜代码/后端/后端代码"
  cd "$PROJECT_DIR/代码/后端/后端代码" || fail '源码目录不可进入。'
  "$GO_EXECUTABLE" build -o "$pending" ./cmd/workbench >> "$LOG_FILE" 2>&1
  result=$?
  [ "$result" = 0 ] || fail "构建失败，不启动旧程序。日志：$LOG_FILE" "$result"
  [ -x "$pending" ] || fail '构建没有生成新的可执行文件，不启动旧程序。'
  mv "$pending" "$WORKBENCH_BINARY" || fail '无法替换本项目构建产物。'
}
# 用有界TCP连接探测任何已有监听，避免将非HTTP端口当作空闲。
assert_port_available() {
  local host="${WB_ADDR%:*}" port="${WB_ADDR##*:}" probe count=0 result
  host="${host#\[}"; host="${host%\]}"
  /bin/bash -c 'exec 3<>"/dev/tcp/$1/$2"' _ "$host" "$port" >/dev/null 2>&1 &
  probe=$!
  while kill -0 "$probe" 2>/dev/null && [ "$count" -lt 20 ]; do sleep 0.05; count=$((count + 1)); done
  if kill -0 "$probe" 2>/dev/null; then
    kill -TERM "$probe" 2>/dev/null || true
    sleep 0.1
    kill -0 "$probe" 2>/dev/null && kill -KILL "$probe" 2>/dev/null || true
    fail '目标端口的TCP探测未及时完成，停止而不冒险复用。'
  fi
  wait "$probe"; result=$?
  [ "$result" != 0 ] || fail '目标端口已有TCP监听，本入口不会复用或停止它。'
}
# 在本地健康检查通过后才允许启动穿透，失败不复用其它已有服务。
start_and_check_backend() {
  command -v curl >/dev/null 2>&1 || fail '健康检查需要系统curl；不能只凭进程存在判定服务成功。'
  assert_port_available
  "$WORKBENCH_BINARY" >> "$LOG_FILE" 2>&1 &
  API_PID=$!
  deploy_state_process backend "$API_PID"
  local count=0
  while [ "$count" -lt 60 ]; do
    kill -0 "$API_PID" 2>/dev/null || fail "本次后端提前退出。日志：$LOG_FILE"
    if curl --fail --silent --connect-timeout 1 --max-time 2 "http://$WB_ADDR/api/v38/healthz" > "$RUN_DIR/health.json" 2>/dev/null; then
      kill -0 "$API_PID" 2>/dev/null || fail '本次后端退出，拒绝将其它服务当成启动成功。'
      log_message '0;34' "本机健康通过｜http://$WB_ADDR/｜管理端 /admin/"; return 0
    fi
    sleep 0.25; count=$((count + 1))
  done
  fail "本机健康检查超时。日志：$LOG_FILE"
}
# 仅清除本次客户端继承的Tunnel环境配置，保留调用者环境。
run_quick_client() {
  local name
  for name in $(env | sed -n 's/^\(TUNNEL_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$name"; done
  exec "$CLOUDFLARED_EXECUTABLE" "$@"
}
# 仅本地模式连接免费Quick Tunnel，访问限制只作用于本次子进程。
start_tunnel() {
  [ "$DEPLOY_MODE" = local ] || { log_message '0;34' '服务器模式：没有建立穿透；对外HTTPS由部署方另行配置。'; return 0; }
  printf '{}\n' > "$RUN_DIR/quick-empty.yml" || fail '无法创建本次独立Quick配置；不会改动用户cloudflared配置。'
  if [ "$PUBLIC_TUNNEL" = 1 ]; then
    run_quick_client tunnel --config "$RUN_DIR/quick-empty.yml" --no-autoupdate --url "http://$WB_ADDR" > "$RUN_DIR/tunnel.log" 2>&1 &
  else
    run_quick_client tunnel --config "$RUN_DIR/quick-empty.yml" --no-autoupdate --url "http://$WB_ADDR" --allowed-mail "$ALLOWED_MAIL" > "$RUN_DIR/tunnel.log" 2>&1 &
  fi
  TUNNEL_PID=$!
  deploy_state_process tunnel "$TUNNEL_PID"
  log_message '0;34' '正在建立Quick Tunnel；无账号／域名费用，随机地址、无可用性保证，大陆网络需实测。'
}
# 二维码仅由独立锁定模块在本机生成；辅助功能失败不影响业务启动。
prepare_access_qr() {
  QR_BINARY="$RUN_DIR/qr-access"
  if ! (
    set -o pipefail
    cd "$PROJECT_DIR/部署/公共组件/地址二维码" || exit 1
    configure_go_module_source
    log_message '0;34' '二维码依赖来源｜github.com/skip2/go-qrcode；版本与校验见部署/公共组件/地址二维码/go.mod、go.sum。'
    "$GO_EXECUTABLE" build -mod=readonly -o "$QR_BINARY" . 2>&1 | tee -a "$LOG_FILE"
  ); then
    QR_BINARY=''
    log_message '1;31' '二维码工具未能构建；保留完整URL，后端与隧道继续按原流程运行。'
  fi
}
# 地址变化或退出时撤销旧展示页，避免把旧码继续当成本次入口。
expire_access_qr() {
  if [ -n "$QR_PAGE" ] && [ -x "$QR_BINARY" ]; then
    "$QR_BINARY" --expire --output-dir "$(dirname "$QR_PAGE")" >> "$LOG_FILE" 2>&1 || log_message '1;31' '旧二维码页失效标记失败；请停止使用之前的码。'
  fi
  QR_PAGE=''
}
# 展示各端完整URL；终端不足宽或无颜色时用本地页面和SVG扫码。
show_access_qr() {
  local base="${PUBLIC_URL%/}" width=0 output result
  local -a qr_args
  expire_access_qr
  if [ -n "$base" ]; then
    log_message '0;34' "公网地址｜用户／工程师工作台｜$base/"
    log_message '0;34' "公网地址｜管理端｜$base/admin/"
  fi
  log_message '0;34' "仅本机地址｜用户／工程师工作台｜http://$WB_ADDR/"
  log_message '0;34' "仅本机地址｜管理端｜http://$WB_ADDR/admin/；手机不可通过回环地址访问。"
  [ -n "$QR_BINARY" ] && [ -x "$QR_BINARY" ] || return 0
  QR_GENERATION=$((QR_GENERATION + 1))
  output="$RUN_DIR/access-qr-$QR_GENERATION"
  qr_args=(--output-dir "$output" --title '维修平台访问入口')
  if [ -n "$base" ]; then
    qr_args+=(--entry "公网｜用户／工程师工作台|$base/" --entry "公网｜管理端|$base/admin/")
  fi
  qr_args+=(--entry "仅本机，手机不可用｜用户／工程师工作台|http://$WB_ADDR/" --entry "仅本机，手机不可用｜管理端|http://$WB_ADDR/admin/")
  if [ "$OUTPUT_COLOR" = 1 ]; then
    width="${COLUMNS:-0}"
    if command -v tput >/dev/null 2>&1; then width="$(tput cols 2>/dev/null)"; fi
    case "$width" in ''|*[!0-9]*) width=0;; esac
    qr_args+=(--ansi)
  fi
  "$QR_BINARY" "${qr_args[@]}" --terminal-width "$width" > "$RUN_DIR/access-qr-output" 2>&1
  result=$?
  cat "$RUN_DIR/access-qr-output"
  LC_ALL=C awk '{gsub(sprintf("%c", 27) "\\[[0-9;]*m", ""); print}' "$RUN_DIR/access-qr-output" >> "$LOG_FILE"
  if [ "$result" = 0 ] && [ -f "$output/index.html" ]; then
    QR_PAGE="$output/index.html"
    log_message '0;34' "扫码页面｜$QR_PAGE；终端二维码不完整时，用菜单打开此页；页面内SVG可离线查看。"
  else
    log_message '1;31' '二维码生成失败；保留完整URL，服务继续运行，请勿使用之前的码。'
  fi
}

# 在后台显示地址选择器，让主循环继续监控后端与隧道。
start_browser_menu() {
  local header
  {
    if [ -n "$PUBLIC_URL" ]; then printf 'public\t公网地址｜%s\n' "$PUBLIC_URL"; fi
    printf 'local\t本机地址｜http://%s/\n' "$WB_ADDR"
    if [ -n "$QR_PAGE" ]; then printf 'qr\t打开扫码页面（各端二维码与原始URL）\n'; fi
    printf 'pause\t收起菜单（服务继续运行，回车再选）\n'
  } > "$RUN_DIR/browser-links.tsv" || fail '无法准备网页地址菜单。'
  header=$'回车：交给默认浏览器打开；打开后可继续选择。\n本机地址只供这台电脑访问。'
  if [ -n "$PUBLIC_URL" ]; then
    if [ "$PUBLIC_TUNNEL" = 1 ]; then
      header+=$'公网地址已公开，仅用合成数据。'
    else
      header+=$'公网地址需先完成邮箱验证码。'
    fi
  fi
  header+=$'\nLinux需桌面会话和xdg-open；无桌面时提示并保持服务。\nEsc收起菜单，服务继续；回车重新打开。Ctrl+C停止服务。'
  FZF_DEFAULT_OPTS='' FZF_DEFAULT_OPTS_FILE=/dev/null FZF_DEFAULT_COMMAND='' \
    "$FZF_EXECUTABLE" --no-multi --delimiter='\t' --with-nth=2 --height=40% --border \
      --expect=esc,ctrl-c --prompt='打开网页 > ' --header="$header" \
      < "$RUN_DIR/browser-links.tsv" > "$RUN_DIR/browser-selection" &
  BROWSER_MENU_PID=$!
  deploy_state_process menu "$BROWSER_MENU_PID"
}
# 只在已有桌面会话中异步调用系统浏览器，不安装GUI依赖。
open_browser_url() {
  if [ -z "${DISPLAY:-}" ] && [ -z "${WAYLAND_DISPLAY:-}" ]; then
    log_message '1;31' '当前没有Linux桌面会话，不能在本机打开浏览器；服务继续运行，可用其它设备访问公网地址。'
    return 1
  fi
  if ! command -v xdg-open >/dev/null 2>&1; then
    log_message '1;31' '当前没有xdg-open，不能调用默认浏览器；服务继续运行，不自动安装桌面依赖。'
    return 1
  fi
  xdg-open "$1" >> "$LOG_FILE" 2>&1 &
  BROWSER_OPEN_PIDS+=("$!")
}
# 收集浏览器启动失败，不等待可能持续运行的浏览器进程。
monitor_browser_open_requests() {
  local child result
  local -a pending=()
  for child in "${BROWSER_OPEN_PIDS[@]}"; do
    if kill -0 "$child" 2>/dev/null; then
      pending+=("$child")
    else
      wait "$child"; result=$?
      if [ "$result" != 0 ]; then
        log_message '1;31' "默认浏览器打开请求退出码${result}；服务继续运行，可在菜单中重选。详情：$LOG_FILE"
      fi
    fi
  done
  BROWSER_OPEN_PIDS=("${pending[@]}")
}
# 处理一次选择，浏览器打开失败也不停止服务或阻止再次选择。
handle_browser_menu_result() {
  local result selection key row action url
  wait "$BROWSER_MENU_PID"; result=$?; BROWSER_MENU_PID=''
  selection="$(cat "$RUN_DIR/browser-selection")"
  key="${selection%%$'\n'*}"
  if [ "$key" = ctrl-c ]; then exit 130; fi
  if [ "$key" = esc ] || [ "$result" = 1 ] || [ "$result" = 130 ] || [ -z "$selection" ]; then
    BROWSER_MENU_PAUSED=1
    log_message '0;34' '网页菜单已收起，服务继续运行；回车重新选择，Ctrl+C停止服务。'
    return 0
  fi
  if [ "$result" != 0 ]; then
    BROWSER_MENU_PAUSED=1
    log_message '1;31' "网页选择器退出码${result}；服务继续运行，回车重试菜单，Ctrl+C停止。"
    return 0
  fi
  row="${selection#*$'\n'}"
  action="${row%%$'\t'*}"
  case "$key:$action" in
    :public) url="$PUBLIC_URL";;
    :local) url="http://$WB_ADDR/";;
    :qr) url="$QR_PAGE";;
    :pause)
      BROWSER_MENU_PAUSED=1
      log_message '0;34' '网页菜单已收起，服务继续运行；回车重新选择，Ctrl+C停止服务。'
      return 0;;
    *)
      BROWSER_MENU_PAUSED=1
      log_message '1;31' '网页选择结果无效，没有打开网页；服务继续运行，回车重新选择。'
      return 0;;
  esac
  if [ -n "$url" ] && open_browser_url "$url"; then
    log_message '0;34' "已请求默认浏览器打开：${url}；可继续选择其它地址。"
  else
    log_message '1;31' "未能打开网页：${url}；服务继续运行，可在菜单中重选。"
  fi
}
# 显示本次地址并监控服务及网页菜单，后端或隧道退出时回收本次子进程。
monitor_processes() {
  local shown=0 elapsed=0 address result resume_menu timeout_seconds="${WB_TUNNEL_START_TIMEOUT:-45}"
  if [ "$DEPLOY_MODE" = local ]; then
    case "$timeout_seconds" in ''|*[!0-9]*) fail 'WB_TUNNEL_START_TIMEOUT须为1..600整数。';; esac
    [ "$timeout_seconds" -gt 0 ] && [ "$timeout_seconds" -le 600 ] || fail 'WB_TUNNEL_START_TIMEOUT须为1..600整数。'
  fi
  while kill -0 "$API_PID" 2>/dev/null; do
    if [ -n "$TUNNEL_PID" ]; then
      kill -0 "$TUNNEL_PID" 2>/dev/null || fail "穿透进程退出，将停止本次后端。日志：$RUN_DIR/tunnel.log"
      address="$(grep -Eo 'https://[a-zA-Z0-9-]+\.trycloudflare\.com' "$RUN_DIR/tunnel.log" 2>/dev/null | tail -1)"
      if [ -n "$address" ] && [ "$address" != "$PUBLIC_URL" ]; then
        if [ -n "$BROWSER_MENU_PID" ]; then kill -TERM "$BROWSER_MENU_PID" 2>/dev/null || true; wait "$BROWSER_MENU_PID" 2>/dev/null || true; BROWSER_MENU_PID=''; fi
        PUBLIC_URL="$address"
        log_message '0;34' "公网入口（待外网验收）：$address"
        show_access_qr
        log_message '1;31' '关闭此运行终端，服务将结束'
        log_message '0;34' "隧道日志：$RUN_DIR/tunnel.log；请用手机移动网络核验登录、真实写入及刷新重读。"
        shown=1
      elif [ "$shown" = 0 ]; then
        elapsed=$((elapsed + 1))
        [ "$elapsed" -lt "$((timeout_seconds * 2))" ] || fail "未取得公网入口，停止本次会话；查看$RUN_DIR/tunnel.log。"
      fi
    fi
    monitor_browser_open_requests
    if [ "$DEPLOY_MODE" = server ] || [ "$shown" = 1 ]; then
      if [ -n "$BROWSER_MENU_PID" ]; then
        if ! kill -0 "$BROWSER_MENU_PID" 2>/dev/null; then handle_browser_menu_result; fi
      elif [ "$BROWSER_MENU_PAUSED" = 1 ]; then
        if [ -t 0 ] && IFS= read -r -t 1 resume_menu; then BROWSER_MENU_PAUSED=0; fi
      else
        start_browser_menu
      fi
    fi
    sleep 0.5
  done
  wait "$API_PID"; result=$?; API_PID=''
  [ "$result" = 0 ] || fail "本次后端退出码：$result。" "$result"
}

# 首次部署的原点清单跨重启保留；状态文件仅解析字段，绝不作为脚本执行。
deploy_state_value() {
  awk -F '\t' -v key="$1" '$1==key {sub(/^[^\t]*\t/,"");print;exit}' "$DEPLOY_STATE_DIR/settings.tsv"
}
# 规范化机器路径，并拒绝控制字符或未解析的穿越片段。
deploy_state_path() {
  local value="$1" suffix='' parent
  case "$value" in */../*|*/./*|*/..|*/.) return 1;; ''|*$'\n'*|*$'\r'*|*$'\t'*) return 1;; /*) ;; *) value="$PROJECT_DIR/$value";; esac
  while [ ! -d "$value" ]; do
    parent="$(dirname "$value")"; [ "$parent" != "$value" ] || return 1
    suffix="/$(basename "$value")$suffix"; value="$parent"
  done
  printf '%s%s\n' "$(cd -P "$value" && pwd)" "$suffix"
}
# 为普通文件或无链接目录生成稳定内容摘要。
deploy_state_digest() {
  local target="$1"
  [ ! -L "$target" ] || return 1
  if [ -f "$target" ]; then hash_file "$target"; return; fi
  [ -d "$target" ] || { printf '%s\n' absent; return; }
  [ -z "$(find "$target" -type l -print -quit)" ] || return 1
  (cd "$target" && { if command -v shasum >/dev/null 2>&1; then find . -type f -exec shasum -a 256 {} +; else find . -type f -exec sha256sum {} +; fi; find . -type d -print; } | LC_ALL=C sort | { if command -v shasum >/dev/null 2>&1; then shasum -a 256; else sha256sum; fi; } | awk '{print $1}')
}
# 首次修改前保留原件与原点类别，后续部署不覆盖。
deploy_state_track() {
  local kind="$1" target="$2" number before=absent backup='-' signature
  [ ! -L "$target" ] || fail "清单对象是软链接，停止：$target"
  awk -F '\t' -v p="$target" '$2==p{found=1}END{exit !found}' "$DEPLOY_STATE_DIR/artifacts.tsv" && return 0
  number="$(wc -l < "$DEPLOY_STATE_DIR/artifacts.tsv" | tr -d ' ')"
  if [ -e "$target" ]; then
    before=existing; backup="previous/$number"
    cp -pR "$target" "$DEPLOY_STATE_DIR/$backup" || fail '无法保存部署前原件，停止修改。'
    deploy_state_digest "$DEPLOY_STATE_DIR/$backup" > "$DEPLOY_STATE_DIR/$backup.sha256" || fail '无法验证原件副本。'
  fi
  signature="$(deploy_state_digest "$target")" || fail '无法计算部署前原件指纹。'
  printf '%s\t%s\t%s\t%s\t%s\n' "$kind" "$target" "$before" "$backup" "$signature" >> "$DEPLOY_STATE_DIR/artifacts.tsv" || fail '无法保存原点清单。'
}
# 原子更新本次部署完成后的资源摘要。
deploy_state_seal() {
  local target="$1" signature pending
  [ -n "$DEPLOY_STATE_DIR" ] && [ -f "$DEPLOY_STATE_DIR/artifacts.tsv" ] || return 0
  signature="$(deploy_state_digest "$target")" || return 1
  pending="$DEPLOY_STATE_DIR/artifacts.pending.$$"
  awk -F '\t' -v OFS='\t' -v p="$target" -v s="$signature" '$2==p{$5=s}{print}' "$DEPLOY_STATE_DIR/artifacts.tsv" > "$pending" && mv "$pending" "$DEPLOY_STATE_DIR/artifacts.tsv"
}
# 把进程PID、启动时间与完整命令作为归属证据保存。
deploy_state_process() {
  [ -n "$DEPLOY_STATE_DIR" ] && [ -f "$DEPLOY_STATE_DIR/processes.tsv" ] || return 0
  local role="$1" pid="$2" started command pending
  [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null || return 0
  started="$(LC_ALL=C ps -p "$pid" -o lstart= | sed 's/^ *//')"
  command="$(LC_ALL=C ps -p "$pid" -o command=)"
  case "$command$started" in *$'\t'*|*$'\n'*) fail '进程身份含不支持的控制字符。';; esac
  pending="$DEPLOY_STATE_DIR/processes.pending.$$"
  awk -F '\t' -v r="$role" '$1!=r' "$DEPLOY_STATE_DIR/processes.tsv" > "$pending" || fail '无法读取进程归属清单。'
  printf '%s\t%s\t%s\t%s\n' "$role" "$pid" "$started" "$command" >> "$pending" && mv "$pending" "$DEPLOY_STATE_DIR/processes.tsv" || fail '无法记录进程身份。'
}
# 记录首次部署前不存在的父目录；撤回时只尝试清理这些空目录。
deploy_state_missing_parents() {
  local dir
  if [ -n "$MISSING_RUNTIME_PARENTS" ]; then printf '%s\n' "$MISSING_RUNTIME_PARENTS" >> "$DEPLOY_STATE_DIR/missing-parents.tsv"; fi
  for dir in "$(dirname "$PROJECT_ENV_DIR")" "$(dirname "$(deploy_state_value data_dir)")" "$(dirname "$(deploy_state_value key_file)")"; do
    while [ ! -e "$dir" ]; do
      printf '%s\n' "$dir" >> "$DEPLOY_STATE_DIR/missing-parents.tsv" || fail '无法记录原本不存在的父目录。'
      dir="$(dirname "$dir")"
    done
  done
}

# 取得串行锁并建立或核验首轮私有原点清单。
deploy_state_initialize() {
  local existed="$1" project_id data key storage=file value
  RUNTIME_ROOT="$(deploy_state_path "$RUNTIME_ROOT")" || fail '运行目录无效。'
  ENV_ROOT="$(deploy_state_path "$ENV_ROOT")" || fail '机器环境目录无效。'
  RUN_DIR="$(deploy_state_path "$RUN_DIR")" || fail '部署会话目录无效。'
  DEPLOY_STATE_DIR="$RUNTIME_ROOT/deploy-state"
  DEPLOY_OPERATION_LOCK="$RUNTIME_ROOT/.deployment-operation.lock"
  mkdir "$DEPLOY_OPERATION_LOCK" 2>/dev/null || fail '部署／反部署正在运行；先结束原运行终端，不删除操作锁。'
  DEPLOY_LOCK_HELD=1
  printf '%s\n' "$$" > "$DEPLOY_OPERATION_LOCK/owner"
  project_id="$(printf '%s' "$PROJECT_DIR" | cksum | awk '{print $1}')"
  PROJECT_ENV_DIR="$ENV_ROOT/Projects/RepairWorkbench/$project_id"
  [ "$PROJECT_ENV_DIR" = "$(deploy_state_path "$PROJECT_ENV_DIR")" ] || fail '专属环境祖先含软链接，拒绝写入。'
  data="$(deploy_state_path "${WB_DATA_DIR:-$RUNTIME_ROOT/data}")" || fail '数据目录无效。'
  key="$(deploy_state_path "${WB_KEY_FILE:-$(dirname "$data")/keys/storage.key}")" || fail '密钥路径无效。'
  [ -z "${WB_TIDB_DSN:-}" ] || storage=tidb
  for value in "$PROJECT_DIR" "$RUNTIME_ROOT" "$ENV_ROOT" "$data" "$key" "${WB_TIDB_DSN:-}" "${WB_REQUIRE_DB_TLS:-false}"; do
    case "$value" in *$'\t'*|*$'\n'*|*$'\r'*) fail '配置不能包含tab或换行。';; esac
  done
  [ ! -L "$DEPLOY_STATE_DIR" ] || fail '部署状态目录是软链接。'
  if [ -f "$DEPLOY_STATE_DIR/settings.tsv" ]; then
    [ "$(deploy_state_value schema)" = 1 ] && [ "$(deploy_state_value project_root)" = "$PROJECT_DIR" ] && [ "$(deploy_state_value env_root)" = "$ENV_ROOT" ] && [ "$(deploy_state_value data_dir)" = "$data" ] && [ "$(deploy_state_value key_file)" = "$key" ] && [ "$(deploy_state_value storage)" = "$storage" ] && [ "$(deploy_state_value db_dsn)" = "${WB_TIDB_DSN:-}" ] || fail '已有部署原点与当前配置不同；先按原配置完成反部署，不覆盖旧清单。'
  else
    [ ! -e "$DEPLOY_STATE_DIR" ] || fail '部署状态残缺，保留现场并停止。'
    mkdir -p "$DEPLOY_STATE_DIR/previous" || fail '无法建立部署原点目录。'
    {
      printf 'schema\t1\nproject_root\t%s\nruntime_root\t%s\nenv_root\t%s\nproject_env\t%s\ndata_dir\t%s\nkey_file\t%s\nstorage\t%s\nbinary\t%s\ninitial_runtime\t%s\n' "$PROJECT_DIR" "$RUNTIME_ROOT" "$ENV_ROOT" "$PROJECT_ENV_DIR" "$data" "$key" "$storage" "$RUNTIME_ROOT/workbench" "$existed"
      local root_path state_name
      for state_name in env projects repair; do
        case "$state_name" in env) root_path="$ENV_ROOT";; projects) root_path="$ENV_ROOT/Projects";; repair) root_path="$ENV_ROOT/Projects/RepairWorkbench";; esac
        if [ -e "$root_path" ]; then printf '%s_was\texisting\n' "$state_name"; else printf '%s_was\tabsent\n' "$state_name"; fi
      done
      printf 'db_dsn\t%s\ndb_tls\t%s\n' "${WB_TIDB_DSN:-}" "${WB_REQUIRE_DB_TLS:-false}"
    } > "$DEPLOY_STATE_DIR/settings.tsv" || fail '无法保存私有部署配置。'
    : > "$DEPLOY_STATE_DIR/artifacts.tsv"; : > "$DEPLOY_STATE_DIR/processes.tsv"
    : > "$DEPLOY_STATE_DIR/missing-parents.tsv"
    deploy_state_missing_parents
  fi
  deploy_state_track tree "$PROJECT_ENV_DIR"
  deploy_state_track file "$RUNTIME_ROOT/workbench"
  printf 'session\t%s\tabsent\t-\t-\n' "$RUN_DIR" >> "$DEPLOY_STATE_DIR/artifacts.tsv"
  deploy_state_process supervisor "$$"
}
# 主会话退出后封存目录状态并释放自己持有的操作锁。
deploy_state_finish() {
  [ "${ZSH_SUBSHELL:-0}" = 0 ] && [ "${BASH_SUBSHELL:-0}" = 0 ] || return 0
  if [ "$DEPLOY_LOCK_HELD" = 1 ]; then
    local session_path resource_kind before backup signature
    while IFS=$'\t' read -r resource_kind session_path before backup signature; do
      [ "$resource_kind" != session ] || deploy_state_seal "$session_path" || printf '%s\n' '会话目录无法封存；反部署保留现场。' >&2
    done < "$DEPLOY_STATE_DIR/artifacts.tsv"
    deploy_state_seal "$PROJECT_ENV_DIR" || printf '%s\n' '无法封存依赖指纹；反部署将保留冲突对象。' >&2
    if [ "$(cat "$DEPLOY_OPERATION_LOCK/owner" 2>/dev/null)" = "$$" ]; then
      rm "$DEPLOY_OPERATION_LOCK/owner" && rmdir "$DEPLOY_OPERATION_LOCK" || true
    fi
    DEPLOY_LOCK_HELD=0
  fi
}

# 编排正常交互、机器环境工具准备、构建和受控生命周期。
main() {
  show_script_intro_and_wait "$@" # 先展示影响并确认，检查和计划保持只读。
  handle_readonly_modes # 完成只读审阅后立即退出。
  initialize_runtime # 确认后在本项目独立用户目录建立日志与清理边界。
  prepare_fzf # 复用健康选择器，缺失才准备机器环境副本。
  select_deploy_mode # 两种模式必须由正常入口fzf明确选择。
  configure_tunnel_access # 本地模式默认收集允许访问邮箱。
  prepare_go # 复用已有Go或从官方锁定来源准备本地缓存。
  prepare_tunnel_tool # 仅本地模式准备穿透工具。
  configure_paths # 保留数据与路径配置并限制回环监听。
  build_workbench # 构建成功才替换本项目运行程序。
  prepare_access_qr # 使用已有Go构建独立离线二维码工具，失败保留URL。
  start_and_check_backend # 核实本次后端健康再继续。
  show_access_qr # 回环入口明确仅本机；公网地址就绪后自动重生成。
  start_tunnel # 仅已选择本地模式时建立受限隧道。
  monitor_processes # 监控本次子进程并在结束时清理。
}

main "$@"
