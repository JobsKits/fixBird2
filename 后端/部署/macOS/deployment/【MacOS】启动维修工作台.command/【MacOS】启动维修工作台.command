#!/bin/zsh
# 脚本自述：
# - 脚本名称：【MacOS】启动维修工作台.command
# - 核心用途：构建并运行 V3.8 维修工作台，供本机合成样例演示。
# - 影响范围：默认写本项目 .runtime；自定义数据和备份目录按配置写入。
# - 运行提示：先阅读内置自述，按回车继续；按 Ctrl+C 取消或停止服务。
# shell: zsh

SCRIPT_ENTRY="$0"
SCRIPT_DIR=""
SCRIPT_PATH=""
SCRIPT_BASENAME=""
PROJECT_DIR=""
LOG_FILE=""
GO_EXECUTABLE=""
WORKBENCH_BINARY=""
OUTPUT_COLOR=0

# 根据入口的真实位置准备展示路径，支持项目根目录的相对软链接。
prepare_display_context() {
  SCRIPT_PATH="${SCRIPT_ENTRY:A}"
  SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
  SCRIPT_BASENAME="${SCRIPT_PATH:t:r}"
  PROJECT_DIR="$(cd "${SCRIPT_DIR}/../../../../.." && pwd)"
  LOG_FILE="${TMPDIR:-/tmp}/${SCRIPT_BASENAME}.log"
  if [[ -t 1 && -n "${TERM:-}" && "${TERM:-}" != dumb && -z "${NO_COLOR+x}" ]]; then
    OUTPUT_COLOR=1
  fi
}
# 以指定的颜色展示一行，自述在非彩色终端自动使用纯文本。
display_line() {
  local style="$1"
  local content="$2"
  if [[ "$OUTPUT_COLOR" == 1 ]]; then
    printf '\033[%sm%s\033[0m\n' "$style" "$content"
  else
    print -r -- "$content"
  fi
}
# 打印固定的脚本内置自述，不依赖外部说明文件。
display_intro() {
  display_line '1;31' '================ V3.8 维修工作台 ================'
  display_line '0;34' '1、用途：构建 Go 后端并打开本机工作台访问入口。'
  display_line '0;34' '2、范围：默认写本项目 .runtime；自定义存储／备份按配置写入，不修改系统。'
  display_line '0;34' '3、依赖：优先 GO_BIN，其次 PATH，再查项目 Tools/go/bin/go。'
  display_line '0;34' '4、默认：127.0.0.1:8098，仅合成样例；真实资料内测须另行落实安全条件。'
  display_line '0;34' '5、策略：回车继续；Ctrl+C 取消。启动后 Ctrl+C 停止服务。'
  display_line '0;34' "日志位置：${LOG_FILE}"
  display_line '1;31' '=================================================='
}
# 在任何文件写入和构建之前展示用途并等待用户确认。
show_script_intro_and_wait() {
  prepare_display_context
  display_intro
  if [[ ! -t 0 ]]; then
    print -u2 -r -- '✖ 当前没有可交互输入，请在系统终端中运行该脚本。'
    exit 1
  fi
  local confirmation=""
  read -r 'confirmation?👉 已了解用途与影响，按回车继续；按 Ctrl+C 取消：'
}
# 确认后初始化选项、日志和中断处理。
initialize_runtime() {
  setopt NO_NOMATCH PIPE_FAIL
  : > "$LOG_FILE"
  OUTPUT_COLOR=0 display_intro >> "$LOG_FILE"
  trap 'print -r -- "已取消。"; exit 130' INT
}
# 将业务状态同步到终端和日志。
log_message() {
  local style="$1"
  local content="$2"
  print -r -- "$content" >> "$LOG_FILE"
  display_line "$style" "$content"
}
# 在明确失败时保留诊断并结束流程。
fail() {
  log_message '1;31' "✖ $1"
  exit "${2:-1}"
}
# 验证候选 Go 二进制可执行且能够返回版本信息。
accept_go_candidate() {
  local candidate="$1"
  [[ -n "$candidate" && -x "$candidate" ]] || return 1
  "$candidate" version >> "$LOG_FILE" 2>&1 || return 1
  GO_EXECUTABLE="${candidate:A}"
  return 0
}
# 从显式配置、现有 PATH 或项目便携工具中发现健康的 Go。
find_go() {
  if [[ -n "${GO_BIN:-}" ]]; then
    local configured_go="$GO_BIN"
    [[ "$configured_go" == /* ]] || configured_go="${PROJECT_DIR}/${configured_go}"
    accept_go_candidate "$configured_go" || fail "GO_BIN 不可用：${GO_BIN}。请指定已有 Go 可执行文件。"
    return 0
  fi
  local path_candidate="$(command -v go 2>/dev/null)"
  if accept_go_candidate "$path_candidate"; then
    return 0
  fi
  if accept_go_candidate "${PROJECT_DIR}/Tools/go/bin/go"; then
    return 0
  fi
  fail '未发现可用 Go。请先准备 Go 并设置 GO_BIN，或放入项目 Tools/go；脚本不会自动安装工具。'
}
# 将可配置的数据目录和页面目录按项目位置解析。
configure_paths() {
  export WB_ADDR="${WB_ADDR:-127.0.0.1:8098}"
  export WB_DATA_DIR="${WB_DATA_DIR:-${PROJECT_DIR}/.runtime/data}"
  export WB_WEB_DIR="${WB_WEB_DIR:-${PROJECT_DIR}/前端/Web网页/维修工作台}"
  [[ "$WB_DATA_DIR" == /* ]] || export WB_DATA_DIR="${PROJECT_DIR}/${WB_DATA_DIR}"
  [[ "$WB_WEB_DIR" == /* ]] || export WB_WEB_DIR="${PROJECT_DIR}/${WB_WEB_DIR}"
  if [[ -n "${WB_KEY_FILE:-}" && "$WB_KEY_FILE" != /* ]]; then
    export WB_KEY_FILE="${PROJECT_DIR}/${WB_KEY_FILE}"
  fi
  if [[ -n "${WB_BACKUP_DIR:-}" && "$WB_BACKUP_DIR" != /* ]]; then
    export WB_BACKUP_DIR="${PROJECT_DIR}/${WB_BACKUP_DIR}"
  fi
  WORKBENCH_BINARY="${PROJECT_DIR}/.runtime/workbench"
}
# 拒绝非回环监听地址，避免把合成演示入口公开到网络。
check_loopback_address() {
  if [[ ! "$WB_ADDR" =~ '^(127\.0\.0\.1|localhost|\[::1\]):([0-9]+)$' ]]; then
    fail 'WB_ADDR 只接受 127.0.0.1、localhost 或 [::1] 加端口。'
  fi
  local configured_port=$((10#${match[2]}))
  [[ "$configured_port" -gt 0 && "$configured_port" -le 65535 ]] || fail '监听端口必须在 1..65535。'
}
# 检查源码与页面入口，失败时不创建运行目录。
check_environment() {
  find_go
  configure_paths
  check_loopback_address
  [[ -f "${PROJECT_DIR}/后端/Go服务端/go.mod" ]] || fail '缺少 后端/Go服务端/go.mod，请保留完整项目目录。'
  [[ -d "${PROJECT_DIR}/后端/Go服务端/cmd/workbench" ]] || fail '缺少 后端/Go服务端/cmd/workbench 新后端入口。'
  [[ -f "${WB_WEB_DIR}/index.html" ]] || fail "缺少工作台页面：${WB_WEB_DIR}/index.html。"
  log_message '1;34' "ℹ Go：${GO_EXECUTABLE}"
  log_message '1;34' "ℹ 访问：http://${WB_ADDR}/"
}
# 在项目内构建独立的新工作台程序，构建失败不启动旧产物。
build_workbench() {
  mkdir -p "${PROJECT_DIR}/.runtime" || fail '无法创建 .runtime 运行目录。'
  cd "${PROJECT_DIR}/后端/Go服务端" || fail '无法进入 后端/Go服务端 目录。'
  log_message '1;34' 'ℹ 正在构建 V3.8 工作台……'
  local build_exit_codes=()
  "$GO_EXECUTABLE" build -o "$WORKBENCH_BINARY" ./cmd/workbench 2>&1 | tee -a "$LOG_FILE"
  build_exit_codes=("${pipestatus[@]}")
  if [[ "${build_exit_codes[1]}" != 0 ]]; then
    fail "Go 构建失败，退出码 ${build_exit_codes[1]}；请查看日志：${LOG_FILE}。" "${build_exit_codes[1]}"
  fi
  if [[ "${build_exit_codes[2]}" != 0 ]]; then
    fail "构建输出无法写入日志，退出码 ${build_exit_codes[2]}：${LOG_FILE}。" "${build_exit_codes[2]}"
  fi
  log_message '1;32' '✔ 构建完成，正在启动。'
}
# 以新程序替换脚本进程，Ctrl+C 直接停止自己启动的服务。
run_workbench() {
  log_message '1;34' "ℹ 请在浏览器访问 http://${WB_ADDR}/，停止服务按 Ctrl+C。"
  log_message '1;34' "ℹ 数据目录：${WB_DATA_DIR}"
  log_message '1;33' '⚠ 默认账号与数据用于合成演示；不要录入真实客户资料。'
  trap - INT
  exec "$WORKBENCH_BINARY" > >(tee -a "$LOG_FILE") 2>&1
}
# 编排自述确认、依赖检查、构建与本机启动。
main() {
  show_script_intro_and_wait # 展示内置自述，等待回车确认。
  initialize_runtime # 确认后初始化日志、选项及中断处理。
  check_environment # 检查现有 Go、源码、页面和回环地址。
  build_workbench # 编译新工作台到本项目 .runtime。
  run_workbench # 运行新服务并保留终端日志。
}

main "$@"
