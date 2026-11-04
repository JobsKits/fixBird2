#!/bin/zsh
# 脚本自述：
# - 核心用途：按部署原点清单反向停止本项目进程、恢复原程序并撤回本次新增依赖。
# - 数据处理：fzf默认先备份；清零必须单独选择并复核。备份失败或身份冲突时停止删除。
# - 影响范围：仅已登记的本项目资源；保留原有共享工具、其它项目和数据库结构。
# - 运行提示：先阅读并回车，再用fzf明确确认；--check/--plan严格只读，不下载工具。
SCRIPT_ENTRY="$0"
PROJECT_DIR=""
RUNTIME_ROOT=""
ENV_ROOT=""
DEPLOY_STATE_DIR=""
DEPLOY_OPERATION_LOCK=""
DEPLOY_LOCK_HELD=0
PROJECT_ENV_DIR=""
FZF_EXECUTABLE=""
DATA_ACTION=""
BACKUP_ROOT=""
OPERATION_DIR=""
CHECK_MODE=0
PLAN_MODE=0
OUTPUT_COLOR=0
EXPECTED_OS="darwin"
EXPECTED_DISTRO=""

# 只解析绝对路径和现有祖先，不依赖启动目录或执行状态文件。
# 读取私有清单中的单个字段，不执行状态内容。
state_value() {
  awk -F '\t' -v key="$1" '$1==key{sub(/^[^\t]*\t/,"");print;exit}' "$DEPLOY_STATE_DIR/settings.tsv"
}
# 规范化绝对路径并拒绝控制字符与未解析的穿越片段。
canonical_path() {
  local value="$1" suffix='' parent
  case "$value" in */../*|*/./*|*/..|*/.) return 1;; ''|*$'\n'*|*$'\t'*|*$'\r'*) return 1;; /*) ;; *) return 1;; esac
  while [ ! -d "$value" ]; do
    parent="$(dirname "$value")"; [ "$parent" != "$value" ] || return 1
    suffix="/$(basename "$value")$suffix"; value="$parent"
  done
  printf '%s%s\n' "$(cd -P "$value" && pwd)" "$suffix"
}
# 使用已有SHA256基础工具计算单文件摘要。
hash_file() {
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}';
  elif command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}';
  else return 1; fi
}
# 指纹含相对文件名与目录，拒绝任何软链接，避免误删指向其它资源的目录。
resource_digest() {
  local target="$1"
  [ ! -L "$target" ] || return 1
  if [ -f "$target" ]; then hash_file "$target"; return; fi
  [ -d "$target" ] || { printf '%s\n' absent; return; }
  [ -z "$(find "$target" -type l -print -quit)" ] || return 1
  (cd "$target" && { if command -v shasum >/dev/null 2>&1; then find . -type f -exec shasum -a 256 {} +; else find . -type f -exec sha256sum {} +; fi; find . -type d -print; } | LC_ALL=C sort | { if command -v shasum >/dev/null 2>&1; then shasum -a 256; else sha256sum; fi; } | awk '{print $1}')
}
# 终端和已建立的操作日志同步输出纯文本。
message() {
  printf '%s\n' "$1"
  [ -z "$OPERATION_DIR" ] || printf '%s\n' "$1" >> "$OPERATION_DIR/operation.log"
}
# 明确报错并保留当前恢复依据。
fail() { message "✖ $1" >&2; exit 1; }
# 固定自述按终端能力显示颜色，非交互与NO_COLOR保持纯文本。
intro_line() {
  if [ -t 1 ] && [ -n "${TERM:-}" ] && [ "${TERM:-}" != dumb ] && [ -z "${NO_COLOR+x}" ]; then
    printf '\033[%sm%s\033[0m\n' "$1" "$2"
  else
    printf '%s\n' "$2"
  fi
}
# 运行时说明为脚本内固定文本，普通调用先确认，计划入口不落盘。
show_script_intro_and_wait() {
  parse_options "$@"
  if [ -n "${ZSH_VERSION:-}" ]; then setopt NO_NOMATCH; fi
  intro_line '1;31' '================ 维修平台配对反部署 ================'
  intro_line '0;34' '恢复部署原点：停止清单中身份匹配的进程，撤回本项目新增SDK／依赖并恢复原程序。'
  intro_line '0;34' '数据用fzf选择：备份（默认）或清零；备份和匹配密钥验证成功后才处理原数据。'
  intro_line '0;34' '不会删除其它项目、共享已有SDK、数据库结构或自行配置的DNS／订阅。'
  intro_line '0;34' 'Esc／空选取消，清零还需空格复核。--check／--plan只读，不安装或下载fzf。'
  if [ "$CHECK_MODE" = 1 ] || [ "$PLAN_MODE" = 1 ]; then return; fi
  [ -t 0 ] && [ -t 1 ] || fail '正常反部署需要交互终端；只读审阅使用--check或--plan。'
  local answer
  printf '%s' '已阅读影响范围，按回车继续；其它输入取消：'
  IFS= read -r answer || exit 0
  [ -z "$answer" ] || exit 0
}
prepare_context() {
  local dir target parent guard=0 current="$SCRIPT_ENTRY"
  case "$current" in /*) ;; *) current="$(pwd)/$current";; esac
  while [ -L "$current" ]; do
    [ "$guard" -lt 16 ] || fail '入口软链接层数异常。'
    parent="$(cd -P "$(dirname "$current")" && pwd)" || exit 1
    target="$(readlink "$current")" || exit 1
    case "$target" in /*) current="$target";; *) current="$parent/$target";; esac
    guard=$((guard + 1))
  done
  dir="$(cd -P "$(dirname "$current")" && pwd)" || exit 1
  while [ "$dir" != / ]; do
    if [ -f "$dir/代码/后端/后端代码/go.mod" ]; then PROJECT_DIR="$dir"; break; fi
    dir="$(dirname "$dir")"
  done
  [ -n "$PROJECT_DIR" ] || fail '找不到完整维修项目。'
  case "$(uname -s)" in
    Darwin) [ "$EXPECTED_OS" = darwin ] || fail '请使用MacOS对应入口。'; ENV_ROOT="${WB_ENV_ROOT:-$HOME/Library/Caches/JobsSoftwareEnvironments}"; RUNTIME_ROOT="${WB_RUNTIME_DIR:-$HOME/Library/Application Support/JobsSoftwareProjects/RepairWorkbench/Runtime}";;
    Linux) [ "$EXPECTED_OS" = linux ] || fail '请使用Linux对应入口。'; ENV_ROOT="${WB_ENV_ROOT:-${XDG_CACHE_HOME:-$HOME/.cache}/JobsSoftwareEnvironments}"; RUNTIME_ROOT="${WB_RUNTIME_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/JobsSoftwareProjects/RepairWorkbench/Runtime}";
      [ "$(awk -F= '$1=="ID"{gsub(/"/,"",$2);print;exit}' /etc/os-release)" = "$EXPECTED_DISTRO" ] || fail '发行版不匹配，请使用本系统入口。';;
    *) fail '此入口仅支持对应MacOS／Linux。';;
  esac
  RUNTIME_ROOT="$(canonical_path "$RUNTIME_ROOT")" || fail '运行资料路径无效。'
  ENV_ROOT="$(canonical_path "$ENV_ROOT")" || fail '机器环境路径无效。'
  DEPLOY_STATE_DIR="$RUNTIME_ROOT/deploy-state"
  DEPLOY_OPERATION_LOCK="$RUNTIME_ROOT/.deployment-operation.lock"
}
# 只允许原清单中的固定程序、本项目专属环境和原子创建的会话目录。
validate_state() {
  [ -d "$DEPLOY_STATE_DIR" ] && [ ! -L "$DEPLOY_STATE_DIR" ] || fail '没有有效部署原点清单；保留旧环境，不能推测原有SDK归属。'
  local file project_id target kind before backup signature n
  for file in settings.tsv artifacts.tsv processes.tsv; do
    [ -f "$DEPLOY_STATE_DIR/$file" ] && [ ! -L "$DEPLOY_STATE_DIR/$file" ] && [ -O "$DEPLOY_STATE_DIR/$file" ] || fail '部署清单缺失、归属异常或是软链接。'
  done
  [ "$(state_value schema)" = 1 ] && [ "$(state_value project_root)" = "$PROJECT_DIR" ] && [ "$(state_value runtime_root)" = "$RUNTIME_ROOT" ] && [ "$(state_value env_root)" = "$ENV_ROOT" ] || fail '部署清单与当前项目或目录不匹配。'
  project_id="$(printf '%s' "$PROJECT_DIR" | cksum | awk '{print $1}')"
  PROJECT_ENV_DIR="$ENV_ROOT/Projects/RepairWorkbench/$project_id"
  [ "$(state_value project_env)" = "$PROJECT_ENV_DIR" ] && [ "$(state_value binary)" = "$RUNTIME_ROOT/workbench" ] || fail '部署清单资源超出本项目作用域。'
  for target in "$(state_value data_dir)" "$(state_value key_file)"; do
    [ -n "$target" ] && [ "$target" = "$(canonical_path "$target")" ] && [ ! -L "$target" ] || fail '数据或密钥目标不是规范绝对路径。'
    case "$target" in "$PROJECT_DIR/"*) fail '数据或密钥不能位于源码目录。';; esac
    case "$PROJECT_DIR/|$ENV_ROOT/|$RUNTIME_ROOT/|$HOME/" in *"$target/"*) fail '数据或密钥目标覆盖关键根目录，拒绝删除。';; esac
  done
  while IFS=$'\t' read -r kind target before backup signature; do
    [ "$target" = "$(canonical_path "$target")" ] && [ ! -L "$target" ] || fail '清单含软链接或非规范目标。'
    case "$kind:$target" in
      "file:$RUNTIME_ROOT/workbench"|"tree:$PROJECT_ENV_DIR") ;;
      "session:$RUNTIME_ROOT"/deploy-session.*) [ "$(dirname "$target")" = "$RUNTIME_ROOT" ] || fail '会话目录越界。';;
      *) fail '清单含未知资源，停止而不扩大清理范围。';;
    esac
    case "$before" in absent) [ "$backup" = '-' ] || fail '原点记录异常。';; existing)
      n="${backup#previous/}"; case "$n" in ''|*[!0-9]*) fail '原件备份路径越界。';; esac
      [ "$backup" = "previous/$n" ] && [ -e "$DEPLOY_STATE_DIR/$backup" ] && [ ! -L "$DEPLOY_STATE_DIR/$backup" ] || fail '原件备份不可用。';;
      *) fail '原点类别无效。';;
    esac
    if [ "$before" = existing ]; then
      [ -f "$DEPLOY_STATE_DIR/$backup.sha256" ] && [ "$(resource_digest "$DEPLOY_STATE_DIR/$backup")" = "$(cat "$DEPLOY_STATE_DIR/$backup.sha256")" ] || fail '原件恢复副本校验失败。'
    fi
  done < "$DEPLOY_STATE_DIR/artifacts.tsv"
}
# 仅复用已有选择器，反部署不引入新的安装。
select_fzf() {
  local candidate="${WB_FZF_BIN:-$(command -v fzf 2>/dev/null || true)}"
  if [ -n "$candidate" ] && [ -x "$candidate" ]; then FZF_EXECUTABLE="$candidate"; return; fi
  for candidate in "$PROJECT_ENV_DIR"/Tools/Fzf/*/*/fzf "$ENV_ROOT"/Fzf/*/*/fzf; do
    [ -x "$candidate" ] && { FZF_EXECUTABLE="$candidate"; return; }
  done
  fail '没有可用fzf；请指定已有WB_FZF_BIN，本反部署入口不会为删除额外安装依赖。'
}
# 隔离fzf用户配置并把空选、取消与异常作为停止。
choose() {
  local chosen result
  chosen="$(FZF_DEFAULT_OPTS='' FZF_DEFAULT_OPTS_FILE=/dev/null FZF_DEFAULT_COMMAND='' "$FZF_EXECUTABLE" --no-multi --delimiter='\t' --with-nth=2 --height=45% --border --prompt="$1" --header="$2")"; result=$?
  case "$result" in 0) ;; 1|130) exit 130;; *) exit "$result";; esac
  [ -n "$chosen" ] || exit 130
  printf '%s\n' "${chosen%%$'\t'*}"
}
select_data_action() {
  DATA_ACTION="$(printf 'backup\t数据库／文件数据备份（默认）\nclear\t数据库／文件数据清零（不保留本次业务备份）\ncancel\t取消\n' | choose '数据处理 > ' '备份成功并核验后清理原数据；Esc取消。')" || exit 0
  case "$DATA_ACTION" in backup|clear) ;; cancel) exit 0;; *) fail '数据选择无效。';; esac
  message "作用范围：程序 $(state_value binary)；本项目环境 $PROJECT_ENV_DIR"
  message "业务数据：$(state_value data_dir)；匹配密钥：$(state_value key_file)；存储：$(state_value storage)"
  local choice answer
  choice="$(printf 'cancel\t取消（默认）\nexecute\t已核对范围，执行配对反部署\n' | choose '执行确认 > ' '先停止本次进程；备份失败、资源指纹冲突或PID复用会停止后续操作。')" || exit 0
  [ "$choice" = execute ] || exit 0
  if [ "$DATA_ACTION" = clear ]; then
    printf '%s' '清零不可恢复；按空格后回车确认，其它输入取消：'
    IFS= read -r answer || exit 0
    [ "$answer" = ' ' ] || exit 0
  fi
}
# 比较启动时间与完整命令后才停止，PID被复用或权限不明时绝不发送信号。
stop_recorded_processes() {
  local role pid started command current_started current_command count
  while IFS=$'\t' read -r role pid started command; do
    case "$pid" in ''|*[!0-9]*) fail '进程清单PID无效。';; esac
    if ! kill -0 "$pid" 2>/dev/null; then
      [ -z "$(LC_ALL=C ps -p "$pid" -o lstart= 2>/dev/null)" ] || fail '进程权限不明，保留并停止。'
      continue
    fi
    current_started="$(LC_ALL=C ps -p "$pid" -o lstart= | sed 's/^ *//')"
    current_command="$(LC_ALL=C ps -p "$pid" -o command=)"
    [ "$started" = "$current_started" ] && [ "$command" = "$current_command" ] || fail "PID $pid 身份已变化，未发送停止信号。"
    kill -TERM "$pid" || fail '无法停止归属已核验的进程。'
    count=0
    while kill -0 "$pid" 2>/dev/null && [ "$count" -lt 100 ]; do sleep 0.1; count=$((count+1)); done
    kill -0 "$pid" 2>/dev/null && fail '进程未在宽限内退出；保留数据与依赖，不强行清理。'
  done < "$DEPLOY_STATE_DIR/processes.tsv"
}
# 原子取得与部署共用的操作锁，避免并发写入。
acquire_operation_lock() {
  mkdir "$DEPLOY_OPERATION_LOCK" 2>/dev/null || fail '仍有部署操作或异常残留锁；核对原终端，不能删除锁绕过。'
  DEPLOY_LOCK_HELD=1
  printf '%s\n' "$$" > "$DEPLOY_OPERATION_LOCK/owner"
}
# 只在主执行层释放自己持有的锁。
release_operation_lock() {
  [ "${ZSH_SUBSHELL:-0}" = 0 ] && [ "${BASH_SUBSHELL:-0}" = 0 ] || return 0
  if [ "$DEPLOY_LOCK_HELD" = 1 ] && [ "$(cat "$DEPLOY_OPERATION_LOCK/owner" 2>/dev/null)" = "$$" ]; then
    rm "$DEPLOY_OPERATION_LOCK/owner" && rmdir "$DEPLOY_OPERATION_LOCK" || true
  fi
  DEPLOY_LOCK_HELD=0
}
# 所有原点对象先整体预检；其中任一被并发改动时，尚未开始清理数据。
preflight_artifacts() {
  local kind target before backup signature current
  while IFS=$'\t' read -r kind target before backup signature; do
    current="$(resource_digest "$target")" || fail "目标包含链接或不能读取：$target"
    local original=absent
    [ "$before" != existing ] || original="$(resource_digest "$DEPLOY_STATE_DIR/$backup")"
    if [ "$current" = "$original" ]; then continue; fi
    if [ "$before" = existing ] && [ -f "$DEPLOY_STATE_DIR/restoring.tsv" ] && grep -Fx "$target" "$DEPLOY_STATE_DIR/restoring.tsv" >/dev/null && [ "$current" = absent ]; then continue; fi
    if [ "$signature" = '-' ]; then
      [ "$current" = absent ] || fail '部署未完整封存该对象，保留现场并停止。'
    else
      [ "$current" = "$signature" ] || fail "部署后资源已改变，保留并停止：$target"
    fi
  done < "$DEPLOY_STATE_DIR/artifacts.tsv"
  local lock_pid="$(cat "$(state_value data_dir)/writer.lock" 2>/dev/null || true)"
  if [ -n "$lock_pid" ]; then
    case "$lock_pid" in *[!0-9]*) fail '文件写锁格式不明，保留数据。';; esac
    ! kill -0 "$lock_pid" 2>/dev/null || fail '仍有文件写入者，不能处理业务数据。'
  fi
}
prepare_operation_directory() {
  umask 077
  BACKUP_ROOT="$(canonical_path "${WB_UNDEPLOY_BACKUP_DIR:-$(dirname "$RUNTIME_ROOT")/UndeploymentBackups}")" || fail '备份目标必须为绝对路径。'
  local protected_target
  for protected_target in "$(state_value data_dir)" "$(state_value key_file)"; do
    case "$BACKUP_ROOT/" in "$protected_target/"*) fail '备份位置不能位于待清理数据或密钥内部。';; esac
    case "$protected_target/" in "$BACKUP_ROOT/"*) fail '备份位置不能包含待清理数据或密钥。';; esac
  done
  case "$BACKUP_ROOT/" in "$RUNTIME_ROOT/"*|"$PROJECT_ENV_DIR/"*|"$PROJECT_DIR/"*) fail '备份／审计目标不能位于待清理目录或项目源码内。';; esac
  if [ -f "$DEPLOY_STATE_DIR/undeploy-operation.tsv" ]; then
    OPERATION_DIR="$(awk -F '\t' '$1=="directory"{print $2}' "$DEPLOY_STATE_DIR/undeploy-operation.tsv")"
    [ "$DATA_ACTION" = "$(awk -F '\t' '$1=="action"{print $2}' "$DEPLOY_STATE_DIR/undeploy-operation.tsv")" ] || fail '存在未完成反部署，请继续同一种数据处理方式。'
    case "$OPERATION_DIR" in "$BACKUP_ROOT"/repair-undeploy.*) ;; *) fail '未完成操作的备份位置与当前配置不符。';; esac
    [ -d "$OPERATION_DIR" ] && [ ! -L "$OPERATION_DIR" ] && [ "$OPERATION_DIR" = "$(canonical_path "$OPERATION_DIR")" ] || fail '未完成操作的恢复目录不可用。'
    return
  fi
  mkdir -p "$BACKUP_ROOT" || fail '备份根不可写。'
  OPERATION_DIR="$(mktemp -d "$BACKUP_ROOT/repair-undeploy.XXXXXXXX")" || fail '无法建立独立操作目录。'
  cp -pR "$DEPLOY_STATE_DIR" "$OPERATION_DIR/DeploymentState" || fail '无法保留私有恢复清单。'
  : > "$OPERATION_DIR/operation.log"
  printf 'directory\t%s\naction\t%s\n' "$OPERATION_DIR" "$DATA_ACTION" > "$DEPLOY_STATE_DIR/undeploy-operation.tsv" || fail '无法保存反部署续跑位置。'
}
# 复制业务资料后再次核对源与副本，防止复制期间变化。
copy_verified() {
  local src="$1" dst="$2" before after
  [ -e "$src" ] || return 0
  before="$(resource_digest "$src")" || fail '源资料包含软链接或无法读取。'
  cp -pR "$src" "$dst" || fail '备份复制失败，原件保留。'
  after="$(resource_digest "$dst")" || fail '备份资料无法核验。'
  [ "$before" = "$after" ] && [ "$before" = "$(resource_digest "$src")" ] || fail '备份内容或复制期间源状态变化，原件保留。'
}
# 先配对备份并验证原程序解密结果，再允许清理。
backup_business_data() {
  [ "$DATA_ACTION" = backup ] || return 0
  [ ! -f "$DEPLOY_STATE_DIR/data-clear-started" ] || return 0
  local data="$(state_value data_dir)" key="$(state_value key_file)" binary="$(state_value binary)"
  if [ -f "$data/snapshot.enc" ]; then [ -f "$key" ] && [ "$(wc -c < "$key" | tr -d ' ')" = 32 ] || fail '业务快照缺少对应32字节密钥，拒绝删除。'; fi
  if [ -f "$OPERATION_DIR/BACKUP_VERIFIED" ]; then
    [ "$(resource_digest "$data")" = "$(cat "$OPERATION_DIR/data.sha256")" ] && [ "$(resource_digest "$key")" = "$(cat "$OPERATION_DIR/key.sha256")" ] || fail '备份完成后原数据已变化，保留新状态并停止。'
    return
  fi
  [ ! -e "$OPERATION_DIR/Data" ] || rm -r -- "$OPERATION_DIR/Data" || fail '无法重试未完成备份。'
  [ ! -e "$OPERATION_DIR/storage.key" ] || rm -- "$OPERATION_DIR/storage.key" || fail '无法重试密钥备份。'
  copy_verified "$data" "$OPERATION_DIR/Data"
  copy_verified "$key" "$OPERATION_DIR/storage.key"
  if [ "$(state_value storage)" = tidb ] || [ -f "$data/snapshot.enc" ]; then
    [ -x "$binary" ] && [ -f "$key" ] || fail '缺少可验证应用数据的原程序或密钥。'
    [ ! -e "$OPERATION_DIR/database.wbbak" ] || rm -- "$OPERATION_DIR/database.wbbak" || fail '无法重试未完成聚合备份。'
    [ ! -e "$OPERATION_DIR/database.wbbak.manifest.json" ] || rm -- "$OPERATION_DIR/database.wbbak.manifest.json" || fail '无法重试未完成摘要清单。'
    WB_TIDB_DSN="$(state_value db_dsn)" WB_REQUIRE_DB_TLS="$(state_value db_tls)" WB_DATA_DIR="$data" WB_KEY_FILE="$key" \
      "$binary" -backup "$OPERATION_DIR/database.wbbak" >> "$OPERATION_DIR/operation.log" 2>&1 || fail '应用备份或密钥解密验证失败；数据、程序与密钥保留。'
    [ -s "$OPERATION_DIR/database.wbbak" ] && [ -s "$OPERATION_DIR/database.wbbak.manifest.json" ] || fail 'TiDB备份或清单缺失。'
    local expected_hash
    expected_hash="$(sed -n 's/.*"sha256": "\([0-9a-f]*\)".*/\1/p' "$OPERATION_DIR/database.wbbak.manifest.json")"
    [ -n "$expected_hash" ] && [ "$(hash_file "$OPERATION_DIR/database.wbbak")" = "$expected_hash" ] || fail 'TiDB备份摘要不匹配，数据库保留。'
  fi
  resource_digest "$data" > "$OPERATION_DIR/data.sha256" || fail '无法封存已备份源数据状态。'
  resource_digest "$key" > "$OPERATION_DIR/key.sha256" || fail '无法封存已备份密钥状态。'
  printf '%s\n' verified > "$OPERATION_DIR/BACKUP_VERIFIED"
  message "备份已逐项核验：${OPERATION_DIR}；匹配密钥及私有配置须一并保管。"
}
# 按数据阶段检查点处理当前应用数据，失败可原位续跑。
clear_business_data() {
  [ ! -f "$DEPLOY_STATE_DIR/data-cleared" ] || return 0
  : > "$DEPLOY_STATE_DIR/data-clear-started" || fail '无法记录数据处理阶段。'
  local data="$(state_value data_dir)" key="$(state_value key_file)" binary="$(state_value binary)"
  if [ "$(state_value storage)" = tidb ] && [ ! -f "$DEPLOY_STATE_DIR/database-cleared" ]; then
    local -a clear_backup_args=()
    if [ "$DATA_ACTION" = backup ]; then clear_backup_args=(-clear-storage-backup "$OPERATION_DIR/database.wbbak"); fi
    WB_TIDB_DSN="$(state_value db_dsn)" WB_REQUIRE_DB_TLS="$(state_value db_tls)" WB_DATA_DIR="$data" WB_KEY_FILE="$key" \
      "$binary" -clear-storage -confirm-clear-storage "${clear_backup_args[@]}" >> "$OPERATION_DIR/operation.log" 2>&1 || fail 'TiDB应用清零失败，未继续移除程序或本地数据。'
    : > "$DEPLOY_STATE_DIR/database-cleared" || fail '无法记录数据库处理完成阶段。'
  fi
  [ ! -e "$data" ] || rm -r -- "$data" || fail '移除业务数据失败，恢复依据已保留。'
  [ ! -e "$key" ] || rm -- "$key" || fail '移除匹配密钥失败。'
  rmdir "$(dirname "$key")" 2>/dev/null || true
  : > "$DEPLOY_STATE_DIR/data-cleared" || fail '无法记录数据处理完成阶段。'
}
# 按资源原点及恢复检查点逐项撤回，已恢复对象幂等跳过。
restore_artifacts() {
  local kind target before backup signature
  while IFS=$'\t' read -r kind target before backup signature; do
    local original=absent current
    [ "$before" != existing ] || original="$(resource_digest "$DEPLOY_STATE_DIR/$backup")"
    current="$(resource_digest "$target")" || fail '恢复目标包含未知链接。'
    [ "$current" != "$original" ] || continue
    printf '%s\n' "$target" >> "$DEPLOY_STATE_DIR/restoring.tsv" || fail '无法记录资源恢复检查点。'
    [ ! -e "$target" ] || rm -r -- "$target" || fail '无法撤回本项目资源。'
    if [ "$before" = existing ]; then
      mkdir -p "$(dirname "$target")" && cp -pR "$DEPLOY_STATE_DIR/$backup" "$target" || fail '恢复部署前原件失败；恢复副本保留。'
    fi
    [ "$(resource_digest "$target")" = "$original" ] || fail '恢复后的原件摘要不符，保留清单。'
  done < "$DEPLOY_STATE_DIR/artifacts.tsv"
  local missing_parent
  if [ -f "$DEPLOY_STATE_DIR/missing-parents.tsv" ]; then
    while IFS= read -r missing_parent; do
      case "$missing_parent" in ''|/|"$HOME"|"$PROJECT_DIR") fail '空目录回收清单包含关键根目录。';; esac
      [ "$missing_parent" = "$(canonical_path "$missing_parent")" ] && [ ! -L "$missing_parent" ] || fail '空目录回收路径存在链接或非规范片段。'
      case "$RUNTIME_ROOT/|$PROJECT_ENV_DIR/|$(state_value data_dir)/|$(state_value key_file)/" in *"$missing_parent/"*) ;; *) fail '空目录回收超出原部署路径。';; esac
    done < "$DEPLOY_STATE_DIR/missing-parents.tsv"
    cp -p "$DEPLOY_STATE_DIR/missing-parents.tsv" "$OPERATION_DIR/missing-parents.tsv" || fail '无法保留空目录回收范围。'
  fi
  local initial="$(state_value initial_runtime)" env_was="$(state_value env_was)" projects_was="$(state_value projects_was)" repair_was="$(state_value repair_was)"
  rm -r -- "$DEPLOY_STATE_DIR" || fail '无法移除已完成的部署状态。'
  release_operation_lock
  [ "$repair_was" != absent ] || rmdir "$ENV_ROOT/Projects/RepairWorkbench" 2>/dev/null || true
  [ "$projects_was" != absent ] || rmdir "$ENV_ROOT/Projects" 2>/dev/null || true
  [ "$env_was" != absent ] || rmdir "$ENV_ROOT" 2>/dev/null || true
  [ "$initial" != absent ] || rmdir "$RUNTIME_ROOT" 2>/dev/null || true
  if [ -f "$OPERATION_DIR/missing-parents.tsv" ]; then
    while IFS= read -r missing_parent; do rmdir "$missing_parent" 2>/dev/null || true; done < "$OPERATION_DIR/missing-parents.tsv"
  fi
  message '配对反部署完成：数据按所选方式处理，原程序与原有依赖已还原；未改动共享工具及数据库结构。'
}
# 参数解析集中在固定自述入口前半段，计划模式不等待交互。
parse_options() {
  case "$#:${1:-}" in 0:) ;; 1:--check) CHECK_MODE=1;; 1:--plan) PLAN_MODE=1;; 1:--help|1:-h) printf '%s\n' '用法：本入口 [--check|--plan]；正常运行使用fzf，不支持跳过确认。'; exit 0;; *) printf '%s\n' '未知参数。' >&2; exit 2;; esac
}
# 计划分支只验证结构与路径，完成后退出，不进入写入入口。
handle_readonly_modes() {
  [ "$CHECK_MODE" = 1 ] || [ "$PLAN_MODE" = 1 ] || return 0
  printf '项目：%s\n运行资料：%s\n' "$PROJECT_DIR" "$RUNTIME_ROOT"
  if [ ! -f "$DEPLOY_STATE_DIR/settings.tsv" ]; then printf '%s\n' '未找到部署原点清单；旧环境保留，不执行推测清理。'; exit 0; fi
  validate_state
  printf '存储：%s\n配对程序：%s\n' "$(state_value storage)" "$(state_value binary)"
  printf '%s\n' '计划：fzf备份默认／清零选择→确认→PID身份停机→锁→摘要核验→外置备份→数据处理→恢复原点。只读完成。'
  exit 0
}
# 在停机前完成清单核验、选择器发现与全部执行授权。
prepare_interactive_plan() {
  validate_state
  select_fzf
  select_data_action
}
# 取得写锁并建立退出清理，随后复查资源并保存可续跑的操作目录。
initialize_undeployment() {
  set -o pipefail
  if [ -n "${ZSH_VERSION:-}" ]; then setopt NO_NOMATCH; else trap release_operation_lock EXIT; fi
  trap 'exit 130' INT
  trap 'exit 143' TERM
  acquire_operation_lock
  validate_state
  preflight_artifacts
  prepare_operation_directory
}
# zsh全局退出陷阱只处理主执行层，命令替换与子Shell不能释放主操作锁。
TRAPEXIT() {
  release_operation_lock
}
# 高层调用展示生命周期，不在编排入口散落参数分支或文件操作。
main() {
  show_script_intro_and_wait "$@" # 先展示固定自述，正常入口等待确认。
  prepare_context # 由脚本位置解析项目和机器路径。
  handle_readonly_modes # 只读检查／计划完成后直接退出。
  prepare_interactive_plan # 验证归属并取得fzf数据选择与执行授权。
  stop_recorded_processes # 仅停止身份匹配的本项目进程。
  initialize_undeployment # 串行写操作，复查资源及恢复依据。
  backup_business_data # 默认完整备份、验证密钥及摘要。
  clear_business_data # 按明确选择处理本应用数据。
  restore_artifacts # 撤回新增对象，恢复原件并保留操作记录。
}
main "$@"
