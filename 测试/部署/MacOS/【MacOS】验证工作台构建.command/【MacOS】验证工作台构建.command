#!/bin/zsh -f
# 脚本自述：隔离验证工作台构建、健康接口、网页菜单及退出后的子进程回收。
# 所有替身、配置和产物仅写系统临时目录，不下载依赖、不联网或打开真实浏览器。
# 双击后回车确认；自动化可传 --run。失败保留临时夹具，成功自动清理。

# >>> Jobs terminal style protection v1 >>>
# 临时保护当前终端配色，业务进程自行管理原有退出清理。
jobs_terminal_style_run() {
    # 无法可靠保存原色时，沿用脚本已有的纯文本约定。
    jobs_terminal_style_plain() {
        PLAIN_OUTPUT=1
        NO_COLOR=1
        FORCE_COLOR=0
        CLICOLOR=0
        ANSI_COLORS_DISABLED=1
        npm_config_color=false
        export PLAIN_OUTPUT NO_COLOR FORCE_COLOR CLICOLOR ANSI_COLORS_DISABLED npm_config_color
        if "$@"; then
            jobs_style_exit_status=0
        else
            jobs_style_exit_status=$?
        fi
        exit "$jobs_style_exit_status"
    }
    if [ ! -t 0 ] || [ ! -t 1 ] || [ -z "${TERM:-}" ] ||
       [ "${TERM:-}" = dumb ] || [ "${NO_COLOR+x}" = x ] ||
       [ "${PLAIN_OUTPUT:-0}" = 1 ] || [ "${IS_SOURCETREE_RUNTIME:-0}" = 1 ] ||
       env | LC_ALL=C grep -qiE '^(SOURCETREE|SOURCE_TREE)'; then
        if "$@"; then
            jobs_style_exit_status=0
        else
            jobs_style_exit_status=$?
        fi
        exit "$jobs_style_exit_status"
    fi
    if [ -n "${TMUX:-}${STY:-}" ]; then
        jobs_terminal_style_plain "$@"
    fi
    jobs_style_tty=$(tty 2>/dev/null) || jobs_terminal_style_plain "$@"
    if ! ps -o pgid= -o tpgid= -p "$$" 2>/dev/null |
         LC_ALL=C awk 'NF == 2 && $1 == $2 && $1 > 0 { foreground = 1 } END { exit !foreground }'; then
        jobs_terminal_style_plain "$@"
    fi
    case ${JOBS_TERMINAL_STYLE_OWNER:-} in
        ''|*[!0-9]*) ;;
        *)
            if [ "${JOBS_TERMINAL_STYLE_TTY:-}" = "$jobs_style_tty" ] &&
               kill -0 "$JOBS_TERMINAL_STYLE_OWNER" 2>/dev/null; then
                if "$@"; then
                    jobs_style_exit_status=0
                else
                    jobs_style_exit_status=$?
                fi
                exit "$jobs_style_exit_status"
            fi
            ;;
    esac
    jobs_style_stty=$(stty -g 2>/dev/null < /dev/tty) || jobs_terminal_style_plain "$@"
    jobs_style_saved=''
    jobs_style_saved_rows=''
    jobs_style_applied_rows=''
    jobs_style_changed=0
    jobs_style_applied_complete=0
    jobs_style_query_active=0
    jobs_style_recovery=''
    jobs_style_exit_status=0
    jobs_style_esc=$(printf '\033')
    jobs_style_bel=$(printf '\007')
    # 只接受本次请求对应的 RGB 响应；非协议输入使本次探测失败。
    jobs_terminal_style_query() {
        jobs_style_query_key=$1
        printf '\033]%s;?\007' "$jobs_style_query_key" > /dev/tty || return 1
        jobs_style_reply=''
        for jobs_style_attempt in 1 2 3; do
            jobs_style_piece=$(dd bs=256 count=1 2>/dev/null < /dev/tty)
            jobs_style_reply=$jobs_style_reply$jobs_style_piece
            case $jobs_style_reply in
                *"$jobs_style_bel"|*"$jobs_style_esc\\") break ;;
                '') ;;
                "$jobs_style_esc"*) ;;
                *) break ;;
            esac
        done
        case $jobs_style_reply in
            "$jobs_style_esc]$jobs_style_query_key;rgb:"*"$jobs_style_bel")
                jobs_style_rgb=${jobs_style_reply#"$jobs_style_esc]$jobs_style_query_key;rgb:"}
                jobs_style_rgb=${jobs_style_rgb%"$jobs_style_bel"}
                ;;
            "$jobs_style_esc]$jobs_style_query_key;rgb:"*"$jobs_style_esc\\")
                jobs_style_rgb=${jobs_style_reply#"$jobs_style_esc]$jobs_style_query_key;rgb:"}
                jobs_style_rgb=${jobs_style_rgb%"$jobs_style_esc\\"}
                ;;
            *) return 1 ;;
        esac
        jobs_style_normalized=$(printf '%s\n' "$jobs_style_rgb" | LC_ALL=C awk -F/ '
            NF != 3 { exit 1 }
            {
                for (i = 1; i <= 3; i++) {
                    h = tolower($i)
                    if (length(h) < 1 || length(h) > 4 || h ~ /[^0-9a-f]/) exit 1
                    n = 0
                    for (j = 1; j <= length(h); j++) n = n * 16 + index("0123456789abcdef", substr(h, j, 1)) - 1
                    value[i] = int(n * 65535 / (16 ^ length(h) - 1) + 0.5)
                }
                printf "%d/%d/%d", value[1], value[2], value[3]
            }
        ') || return 1
        [ -n "$jobs_style_normalized" ]
    }
    # 查询可用不代表终端允许改色，按目标值核对实际生效结果。
    jobs_terminal_style_accepts_target() {
        jobs_style_requested_hex=''
        case $1 in
            10|12) jobs_style_requested_hex=ffffff ;;
            11) jobs_style_requested_hex=000000 ;;
            '4;'*)
                jobs_style_requested_index=0
                for jobs_style_requested_color in 000000 ff5f56 5fd787 ffd75f 5fafff d787ff 5fd7ff eeeeee 9e9e9e ff8787 87ffaf ffff87 87bfff ffafff afffff ffffff; do
                    if [ "4;$jobs_style_requested_index" = "$1" ]; then
                        jobs_style_requested_hex=$jobs_style_requested_color
                        break
                    fi
                    jobs_style_requested_index=$((jobs_style_requested_index + 1))
                done
                ;;
        esac
        [ -n "$jobs_style_requested_hex" ] || return 1
        printf '%s|%s\n' "$jobs_style_normalized" "$jobs_style_requested_hex" | LC_ALL=C awk -F'|' '
            function hexbyte(h) {
                return (index("0123456789abcdef", substr(h, 1, 1)) - 1) * 16 + index("0123456789abcdef", substr(h, 2, 1)) - 1
            }
            {
                if (split($1, actual, "/") != 3 || length($2) != 6) exit 1
                for (i = 1; i <= 3; i++) {
                    difference = actual[i] - hexbyte(substr($2, i * 2 - 1, 2)) * 257
                    if (difference < -255 || difference > 255) exit 1
                }
            }
        '
    }
    # 检测到后续改色时只恢复仍由本次保护持有的项，保留独立恢复入口。
    jobs_terminal_style_cleanup() {
        jobs_style_result=$1
        trap '' HUP INT TERM
        if [ "$jobs_style_query_active" = 1 ]; then
            stty "$jobs_style_stty" 2>/dev/null < /dev/tty || :
            jobs_style_query_active=0
        fi
        if [ "$jobs_style_changed" = 1 ]; then
            jobs_style_cleanup_ok=0
            jobs_style_conflicts=''
            jobs_style_restore_safe=''
            if [ "$jobs_style_applied_complete" = 1 ]; then
                jobs_style_stty=$(stty -g 2>/dev/null < /dev/tty) || jobs_style_stty=''
                if [ -n "$jobs_style_stty" ] && stty -echo -icanon min 0 time 1 2>/dev/null < /dev/tty; then
                    jobs_style_query_active=1
                    jobs_style_cleanup_ok=1
                    while IFS='|' read -r jobs_style_key jobs_style_expected jobs_style_original; do
                        [ -n "$jobs_style_key" ] || continue
                        if ! jobs_terminal_style_query "$jobs_style_key"; then
                            jobs_style_cleanup_ok=0
                            break
                        fi
                        if [ "$jobs_style_normalized" = "$jobs_style_expected" ]; then
                            jobs_style_restore_safe=$jobs_style_restore_safe$jobs_style_original
                        else
                            jobs_style_conflicts="$jobs_style_conflicts $jobs_style_key"
                        fi
                    done <<JOBS_STYLE_APPLIED
$jobs_style_applied_rows
JOBS_STYLE_APPLIED
                    stty "$jobs_style_stty" 2>/dev/null < /dev/tty || jobs_style_cleanup_ok=0
                    jobs_style_query_active=0
                fi
            fi
            if [ "$jobs_style_cleanup_ok" = 1 ] && printf '%s\033[0m' "$jobs_style_restore_safe" > /dev/tty; then
                if [ -z "$jobs_style_conflicts" ]; then
                    rm -f "$jobs_style_recovery"
                    rmdir "${jobs_style_recovery%/*}" 2>/dev/null || :
                else
                    printf '检测到运行期间的配色变更，已保留这些项：%s\n' "$jobs_style_conflicts" >&2
                    printf '确认要覆盖后续改色时才使用恢复入口：sh "%s"\n' "$jobs_style_recovery" >&2
                    [ "$jobs_style_result" -ne 0 ] || jobs_style_result=1
                fi
            else
                printf '终端配色未能安全自动恢复；确认覆盖当前配色后可运行：sh "%s"\n' "$jobs_style_recovery" >&2
                [ "$jobs_style_result" -ne 0 ] || jobs_style_result=1
            fi
        fi
        if [ "${2:-}" = continue ]; then
            jobs_style_cleanup_status=$jobs_style_result
            return 0
        fi
        exit "$jobs_style_result"
    }
    trap 'jobs_terminal_style_cleanup "$jobs_style_exit_status"' 0
    trap 'jobs_style_exit_status=129; exit 129' HUP
    trap 'jobs_style_exit_status=130; exit 130' INT
    trap 'jobs_style_exit_status=143; exit 143' TERM
    if ! stty -echo -icanon min 0 time 1 2>/dev/null < /dev/tty; then
        jobs_terminal_style_plain "$@"
    fi
    jobs_style_query_active=1
    jobs_style_probe_ok=1
    for jobs_style_key in 10 11 12 '4;0' '4;1' '4;2' '4;3' '4;4' '4;5' '4;6' '4;7' '4;8' '4;9' '4;10' '4;11' '4;12' '4;13' '4;14' '4;15'; do
        if ! jobs_terminal_style_query "$jobs_style_key"; then
            jobs_style_probe_ok=0
            break
        fi
        jobs_style_saved=$jobs_style_saved$jobs_style_reply
        jobs_style_saved_rows="$jobs_style_saved_rows$jobs_style_key|$jobs_style_reply
"
    done
    stty "$jobs_style_stty" 2>/dev/null < /dev/tty || { jobs_style_exit_status=1; exit 1; }
    jobs_style_query_active=0
    if [ "$jobs_style_probe_ok" != 1 ]; then
        printf '%s\n' '终端不支持完整配色保存，或启动时收到其它输入；保留原配色并使用纯文本。' >&2
        jobs_terminal_style_plain "$@"
    fi
    jobs_style_recovery_dir=$(umask 077; mktemp -d "${TMPDIR:-/tmp}/jobs-terminal-style.XXXXXX") || jobs_terminal_style_plain "$@"
    jobs_style_recovery=$jobs_style_recovery_dir/restore.sh
    if ! (umask 077; {
        printf '#!/bin/sh\n'
        printf '[ -t 0 ] && [ "$(tty)" = '\''%s'\'' ] || { printf '\''请在原终端运行恢复入口。\\n'\'' >&2; exit 1; }\n' "$jobs_style_tty"
        printf 'printf '\''本操作会覆盖此终端当前配色。确认恢复脚本启动前的配色，请输入 YES：'\'' >&2\n'
        printf 'IFS= read -r jobs_restore_choice\n[ "$jobs_restore_choice" = YES ] || exit 1\n'
        printf 'printf '\''%%s\\033[0m'\'' '\''%s'\'' > /dev/tty\n' "$jobs_style_saved"
    } > "$jobs_style_recovery"); then
        printf '%s\n' '无法保存终端配色恢复入口；保留原配色并使用纯文本。' >&2
        jobs_terminal_style_plain "$@"
    fi
    printf '正在准备本次终端临时配色；强退后恢复入口：sh "%s"\n' "$jobs_style_recovery" >&2
    jobs_style_changed=1
    printf '\033]10;#ffffff\007\033]11;#000000\007\033]12;#ffffff\007' > /dev/tty
    jobs_style_index=0
    for jobs_style_color in 000000 ff5f56 5fd787 ffd75f 5fafff d787ff 5fd7ff eeeeee 9e9e9e ff8787 87ffaf ffff87 87bfff ffafff afffff ffffff; do
        printf '\033]4;%s;#%s\007' "$jobs_style_index" "$jobs_style_color" > /dev/tty
        jobs_style_index=$((jobs_style_index + 1))
    done
    printf '\033[0m' > /dev/tty
    jobs_style_stty=$(stty -g 2>/dev/null < /dev/tty) || { jobs_style_exit_status=1; exit 1; }
    stty -echo -icanon min 0 time 1 2>/dev/null < /dev/tty || { jobs_style_exit_status=1; exit 1; }
    jobs_style_query_active=1
    jobs_style_probe_ok=1
    jobs_style_targets_ok=1
    while IFS='|' read -r jobs_style_key jobs_style_original; do
        [ -n "$jobs_style_key" ] || continue
        if ! jobs_terminal_style_query "$jobs_style_key"; then
            jobs_style_probe_ok=0
            break
        fi
        jobs_style_applied_rows="$jobs_style_applied_rows$jobs_style_key|$jobs_style_normalized|$jobs_style_original
"
        if ! jobs_terminal_style_accepts_target "$jobs_style_key"; then
            jobs_style_targets_ok=0
        fi
    done <<JOBS_STYLE_ORIGINAL
$jobs_style_saved_rows
JOBS_STYLE_ORIGINAL
    stty "$jobs_style_stty" 2>/dev/null < /dev/tty || { jobs_style_exit_status=1; exit 1; }
    jobs_style_query_active=0
    if [ "$jobs_style_probe_ok" != 1 ]; then
        printf '%s\n' '无法核实本次临时配色，已停止启动业务。' >&2
        jobs_style_exit_status=1
        exit 1
    fi
    jobs_style_applied_complete=1
    if [ "$jobs_style_targets_ok" != 1 ]; then
        jobs_terminal_style_cleanup 0 continue
        jobs_style_changed=0
        if [ "$jobs_style_cleanup_status" != 0 ]; then
            jobs_style_exit_status=1
            exit 1
        fi
        trap 'jobs_style_exit_status=129; exit 129' HUP
        trap 'jobs_style_exit_status=130; exit 130' INT
        trap 'jobs_style_exit_status=143; exit 143' TERM
        printf '%s\n' '终端未接受本次配色，已恢复原配色并使用纯文本。' >&2
        jobs_terminal_style_plain "$@"
    fi
    printf '%s\n' '本次终端已临时使用黑底白字。' >&2
    JOBS_TERMINAL_STYLE_TTY=$jobs_style_tty
    JOBS_TERMINAL_STYLE_OWNER=$$
    export JOBS_TERMINAL_STYLE_TTY JOBS_TERMINAL_STYLE_OWNER
    if "$@"; then
        jobs_style_exit_status=0
    else
        jobs_style_exit_status=$?
    fi
    exit "$jobs_style_exit_status"
}
# 仅监督直接执行的入口；被 source 时不切换配色、不重新执行业务。
jobs_terminal_style_bootstrap() {
    jobs_style_bootstrap_script=$1
    shift
    if [ -n "${ZSH_VERSION:-}" ]; then
        case ${ZSH_EVAL_CONTEXT:-} in
            *:file|*:file:*) return 0 ;;
        esac
    elif [ -n "${BASH_VERSION:-}" ] && [ "${BASH_SOURCE:-$jobs_style_bootstrap_script}" != "$jobs_style_bootstrap_script" ]; then
        return 0
    fi
    if [ "${JOBS_TERMINAL_STYLE_REEXEC:-}" = "$jobs_style_bootstrap_script" ]; then
        unset JOBS_TERMINAL_STYLE_REEXEC
        return 0
    fi
    if [ ! -t 0 ] || [ ! -t 1 ] || [ -z "${TERM:-}" ] ||
       [ "${TERM:-}" = dumb ] || [ "${NO_COLOR+x}" = x ] ||
       [ "${PLAIN_OUTPUT:-0}" = 1 ] || [ "${IS_SOURCETREE_RUNTIME:-0}" = 1 ] ||
       [ -n "${TMUX:-}${STY:-}" ] ||
       env | LC_ALL=C grep -qiE '^(SOURCETREE|SOURCE_TREE)'; then
        return 0
    fi
    case ${JOBS_TERMINAL_STYLE_OWNER:-} in
        ''|*[!0-9]*) ;;
        *)
            if kill -0 "$JOBS_TERMINAL_STYLE_OWNER" 2>/dev/null &&
               [ "${JOBS_TERMINAL_STYLE_TTY:-}" = "$(tty 2>/dev/null)" ]; then
                return 0
            fi
            ;;
    esac
    JOBS_TERMINAL_STYLE_REEXEC=$jobs_style_bootstrap_script
    export JOBS_TERMINAL_STYLE_REEXEC
    jobs_terminal_style_run /bin/zsh -f "$jobs_style_bootstrap_script" "$@"
    jobs_style_bootstrap_result=$?
    exit "$jobs_style_bootstrap_result"
}
jobs_terminal_style_bootstrap "$0" "$@"
# <<< Jobs terminal style protection v1 <<<

SCRIPT_ENTRY="$0"
TEST_ROOT=""
TEST_SOURCE=""
TEST_WORKER=""
TEST_GO=""
TEST_FZF=""
TEST_OPEN=""
TEST_RUNNER=""
TEST_LOG=""
TOTAL=0
FAILED=0
SUITE_PASSED=0

# 先说明测试边界，普通交互入口回车后才创建临时文件。
show_script_intro_and_wait() {
  printf '%s\n' '================ 工作台构建隔离验证 ================' \
    '使用假 Go／curl／fzf／open 验证构建、健康接口和网页菜单；不联网或打开真实浏览器。' \
    '仅在系统临时目录写夹具和日志；成功清理，失败保留位置供排查。' \
    'Ctrl+C 可取消；--run 用于明确授权的自动化执行。'
  case "$#:$1" in
    1:--run) return 0;;
    0:)
      [[ -t 0 ]] || { printf '%s\n' '请在终端运行，自动化需显式传 --run。' >&2; exit 2; }
      local answer
      read -r 'answer?按回车开始；其它输入取消：' || exit 0
      [[ -z "$answer" ]] || exit 0;;
    *) printf '%s\n' '用法：本脚本 [--run]' >&2; exit 2;;
  esac
}
# 同步显示并记录测试结果，不收集调用者环境。
test_log() {
  printf '%s\n' "$1" | tee -a "$TEST_LOG"
}
# 只清理本次已成功完成的临时夹具；失败保留原始日志。
cleanup_fixture() {
  if [[ -n "$TEST_RUNNER" ]]; then
    kill -TERM "$TEST_RUNNER" 2>/dev/null || true
    wait "$TEST_RUNNER" 2>/dev/null || true
    TEST_RUNNER=""
  fi
  if [[ -n "$TEST_ROOT" && -d "$TEST_ROOT" && "$SUITE_PASSED" = 1 ]]; then
    rm -r -- "$TEST_ROOT"
  fi
}
# 在脚本退出时统一清理，避免zsh函数内EXIT陷阱提前删掉夹具。
TRAPEXIT() {
  cleanup_fixture
}
# 中断时保留诊断，并返回终端常见的取消退出码。
TRAPINT() {
  exit 130
}
# 外部要求停止时保留已生成的诊断。
TRAPTERM() {
  exit 143
}
# 夹具解释器禁用用户启动配置，避免假工具受本机zsh配置和外部初始化影响。
# 原点清单需要真实文件与进程核验；启动等待给足预算，不以假后端先到期制造误报。
# 从自身位置找到项目入口，并准备隔离的源码副本和运行器。
prepare_fixture() {
  setopt NO_NOMATCH
  export PATH='/usr/bin:/bin:/usr/sbin:/sbin'
  local package_dir project_dir deployment temp_parent="${TMPDIR:-/tmp}"
  package_dir="$(cd -P "$(dirname "$SCRIPT_ENTRY")" && pwd)" || exit 1
  project_dir="$(cd "$package_dir/../../../.." && pwd)" || exit 1
  deployment="$project_dir/部署/MacOS/Deployment/【MacOS】启动维修工作台.command/【MacOS】启动维修工作台.command"
  [[ -f "$deployment" ]] || { printf '找不到启动入口：%s\n' "$deployment" >&2; exit 1; }
  [[ "$(tail -n 1 "$deployment")" = 'main "$@"' ]] || { printf '%s\n' '入口结构变化，拒绝加载可能执行部署的脚本。' >&2; exit 1; }
  /bin/zsh -n "$deployment" || exit 1
  TEST_ROOT="$(mktemp -d "${temp_parent%/}/repair-build-check.XXXXXX")" || exit 1
  TEST_LOG="$TEST_ROOT/suite.log"
  TEST_SOURCE="$TEST_ROOT/入口函数.zsh"
  TEST_WORKER="$TEST_ROOT/worker.zsh"
  TEST_GO="$TEST_ROOT/fake-go"
  TEST_FZF="$TEST_ROOT/fake-fzf"
  TEST_OPEN="$TEST_ROOT/fake-open"
  sed '$d' "$deployment" > "$TEST_SOURCE" || exit 1
  cat > "$TEST_WORKER" <<'WORKER'
source "$WB_TEST_SOURCE"
PROJECT_DIR="$WB_TEST_CASE/中文 空格工程"
RUN_DIR="$WB_TEST_CASE/session"
RUNTIME_ROOT="$WB_TEST_CASE/runtime"
ENV_ROOT="$WB_TEST_CASE/environments"
WORKBENCH_BINARY="$RUNTIME_ROOT/workbench"
LOG_FILE="$WB_TEST_CASE/build.log"
GO_EXECUTABLE="$WB_TEST_GO"
OUTPUT_COLOR=0
GOMODCACHE="$WB_TEST_CASE/modules"
# 本组验证真实子进程退出和网页交互；原点清单与PID复用由配对反部署回归独立核验。
if [[ -n "${WB_TEST_BROWSER:-}${WB_TEST_LIFECYCLE:-}" ]]; then
  deploy_state_initialize() { return 0; }
  deploy_state_process() { return 0; }
fi
if [[ -n "${WB_TEST_BROWSER:-}" ]]; then
  # 选择器和打开请求用函数替身，避免临时脚本启动时序干扰真实进程回收断言。
  fixture_fzf() {
    local count=0 action row
    zmodload zsh/system || return 42
    [[ ! -f "$WB_TEST_CASE/menu-count" ]] || count="$(cat "$WB_TEST_CASE/menu-count")"
    count=$((count + 1))
    printf '%s\n' "$count" > "$WB_TEST_CASE/menu-count"
    printf '%s\n' "${sysparams[pid]}" >> "$WB_TEST_CASE/menu-pids"
    cat > "$WB_TEST_CASE/menu-input.$count"
    action="$(sed -n "${count}p" "$WB_TEST_CASE/menu-actions")"
    case "$action" in
      public|local|pause)
        row="$(awk -F '\t' -v action="$action" '$1==action{print;exit}' "$WB_TEST_CASE/menu-input.$count")"
        [[ -n "$row" ]] || return 41
        printf '\n%s\n' "$row";;
      esc|ctrl-c) printf '%s\n' "$action";;
      empty) return 1;;
      *) exec /bin/sleep 300;;
    esac
  }
  open() {
    printf '%s\n' "$1" >> "$WB_TEST_CASE/open-urls"
    if [[ "$WB_TEST_BROWSER" = open-failure && ! -e "$WB_TEST_CASE/open-failed-once" ]]; then
      : > "$WB_TEST_CASE/open-failed-once"
      return 9
    fi
    return 0
  }
  RUN_DIR=''
  initialize_runtime
  WB_ADDR=127.0.0.1:18098
  DEPLOY_MODE="$WB_TEST_DEPLOY_MODE"
  PUBLIC_TUNNEL=1
  FZF_EXECUTABLE=fixture_fzf
  /bin/sleep 300 &
  API_PID=$!
  printf '%s\n' "$API_PID" > "$WB_TEST_CASE/backend-pid"
  if [[ "$DEPLOY_MODE" = local ]]; then
    /bin/sleep 300 &
    TUNNEL_PID=$!
    printf '%s\n' "$TUNNEL_PID" > "$WB_TEST_CASE/tunnel-pid"
    printf '%s\n' 'https://fixture-repair.trycloudflare.com' > "$RUN_DIR/tunnel.log"
  fi
  printf '%s\n' "$RUN_DIR" > "$WB_TEST_CASE/session-path"
  monitor_processes
  exit $?
fi
if [[ -n "${WB_TEST_LIFECYCLE:-}" ]]; then
  RUN_DIR=''
  /bin/sleep 300 &
  API_PID=$!
  printf '%s\n' "$API_PID" > "$WB_TEST_CASE/backend-pid"
  initialize_runtime
  [[ -n "$API_PID" ]] && kill -0 "$API_PID" 2>/dev/null || exit 95
  printf '%s\n' ready > "$WB_TEST_CASE/initialized"
  case "$WB_TEST_LIFECYCLE" in
    normal) exit 0;;
    fail) fail 'fixture-controlled-failure' 47;;
    term) while true; do /bin/sleep 0.05; done;;
  esac
fi
if [[ "${WB_TEST_HEALTH:-0}" = 1 ]]; then
  WORKBENCH_BINARY="$WB_TEST_CASE/fake-backend"
  WB_ADDR=127.0.0.1:18098
  trap 'if [[ -n "$API_PID" ]]; then kill -TERM "$API_PID" 2>/dev/null || true; wait "$API_PID" 2>/dev/null || true; fi' EXIT
  # 健康接口测试只验证地址，不绑定或探测真实端口。
  assert_port_available() { return 0; }
  # 假curl记录请求并立即成功，不发起网络连接。
  curl() { printf '%s\n' "$@" > "$WB_TEST_CASE/curl-arguments"; printf '{"ok":true}\n'; }
  start_and_check_backend
  printf '%s\n' "$API_PID" > "$WB_TEST_CASE/backend-pid"
  exit 0
fi
wb_before_proxy_set="${GOPROXY+x}"
wb_before_proxy="${GOPROXY-}"
cd / || exit 96
build_workbench
[[ "${GOPROXY+x}" = "$wb_before_proxy_set" && "${GOPROXY-}" = "$wb_before_proxy" ]] || exit 97
printf '%s\n' parent-environment-preserved > "$WB_TEST_CASE/parent-check"
WORKER
  cat > "$TEST_GO" <<'FAKE_GO'
#!/bin/zsh -f
printf '%s\n' "$*" >> "$WB_TEST_CASE/go-calls"
if [[ "$1" = env ]]; then
  case "$2" in
    GOPROXY) printf '%s\n' "$WB_TEST_EFFECTIVE_PROXY";;
    GOENV) printf '%s\n' "$WB_TEST_GOENV";;
    *) exit 90;;
  esac
  exit 0
fi
[[ "$1" = build && "$2" = -mod=readonly ]] || exit 91
printf 'GOPROXY_SET=%s\nGOPROXY=%s\nGOSUMDB=%s\nGOPRIVATE=%s\nGONOPROXY=%s\nGONOSUMDB=%s\n' \
  "${GOPROXY+x}" "${GOPROXY-}" "$GOSUMDB" "$GOPRIVATE" "$GONOPROXY" "$GONOSUMDB" > "$WB_TEST_CASE/build-environment"
[[ "$PWD" = "$WB_TEST_CASE/中文 空格工程/代码/后端/后端代码" ]] || exit 92
printf '%s\n' fake-go-stdout
printf '%s\n' fake-go-stderr >&2
if [[ "$WB_TEST_NO_BINARY" != 1 ]]; then
  printf '#!/bin/zsh -f\n# NEW_EXECUTABLE\nexit 0\n' > "$4" || exit 93
  chmod +x "$4" || exit 94
fi
exit "$WB_TEST_BUILD_RESULT"
FAKE_GO
  cat > "$TEST_FZF" <<'FAKE_FZF'
#!/bin/zsh -f
count=0
[[ ! -f "$WB_TEST_CASE/menu-count" ]] || count="$(cat "$WB_TEST_CASE/menu-count")"
count=$((count + 1))
printf '%s\n' "$count" > "$WB_TEST_CASE/menu-count"
printf '%s\n' "$$" >> "$WB_TEST_CASE/menu-pids"
cat > "$WB_TEST_CASE/menu-input.$count"
action="$(sed -n "${count}p" "$WB_TEST_CASE/menu-actions")"
case "$action" in
  public|local|pause)
    row="$(awk -F '\t' -v action="$action" '$1==action{print;exit}' "$WB_TEST_CASE/menu-input.$count")"
    [[ -n "$row" ]] || exit 41
    printf '\n%s\n' "$row";;
  esc|ctrl-c) printf '%s\n' "$action";;
  empty) exit 1;;
  *) exec /bin/sleep 300;;
esac
FAKE_FZF
  cat > "$TEST_OPEN" <<'FAKE_OPEN'
#!/bin/zsh -f
printf '%s\n' "$1" >> "$WB_TEST_CASE/open-urls"
if [[ "$WB_TEST_BROWSER" = open-failure && ! -e "$WB_TEST_CASE/open-failed-once" ]]; then
  : > "$WB_TEST_CASE/open-failed-once"
  printf '%s\n' fixture-open-failure >&2
  exit 23
fi
exit 0
FAKE_OPEN
  chmod +x "$TEST_GO" "$TEST_FZF" "$TEST_OPEN" || exit 1
  test_log "夹具与日志：$TEST_ROOT"
}
# 按完整行检查可观察结果，失败时明确指出证据位置。
expect_line() {
  if [[ ! -f "$2" ]] || ! grep -Fqx -- "$1" "$2"; then
    test_log "  缺少预期行：$1；文件：$2"
    return 1
  fi
}
# 每组用独立进程加载真实构建函数，仅 Go 命令被替换为假程序。
run_case() {
  local case_name="$1" mode="$2" expected_proxy="$3" expected_set="$4" expected_result="$5"
  local case_dir="$TEST_ROOT/$case_name" result case_failed=0 effective='https://proxy.golang.org,direct' goenv
  local -a case_env
  mkdir -p "$case_dir/中文 空格工程/代码/后端/后端代码" "$case_dir/session" "$case_dir/runtime" || exit 1
  printf '%s\n' OLD_EXECUTABLE > "$case_dir/runtime/workbench"
  cp "$case_dir/runtime/workbench" "$case_dir/old-binary"
  goenv="$case_dir/go-env"
  case_env=(env -u GOPROXY "GOENV=$goenv")
  case "$mode" in
    env-custom) effective='https://modules.example.invalid'; case_env+=("GOPROXY=$effective");;
    env-empty) case_env+=('GOPROXY=');;
    env-off) effective=off; case_env+=('GOPROXY=off');;
    file-custom) effective='https://private.example.invalid'; printf 'GOPROXY=%s\n' "$effective" > "$goenv";;
    file-default) printf 'GOPROXY=%s\n' "$effective" > "$goenv";;
    file-empty) printf 'GOPROXY=\n' > "$goenv";;
    goenv-off) goenv=off; case_env+=('GOENV=off');;
    effective-custom) effective=direct;;
  esac
  [[ ! -f "$goenv" ]] || cp "$goenv" "$case_dir/original-go-env"
  "${case_env[@]}" "WB_TEST_SOURCE=$TEST_SOURCE" "WB_TEST_GO=$TEST_GO" "WB_TEST_CASE=$case_dir" \
    "WB_TEST_EFFECTIVE_PROXY=$effective" "WB_TEST_GOENV=$goenv" "WB_TEST_BUILD_RESULT=${6:-0}" \
    "WB_TEST_NO_BINARY=${7:-0}" GOSUMDB=sum.golang.org 'GOPRIVATE=private.example.invalid/*' \
    'GONOPROXY=private.example.invalid/*' 'GONOSUMDB=private.example.invalid/*' \
    /bin/zsh -f "$TEST_WORKER" > "$case_dir/console.log" 2>&1
  result=$?
  if [[ -f "$case_dir/original-go-env" ]] && ! cmp -s "$case_dir/original-go-env" "$goenv"; then
    test_log '  用户Go配置文件发生变化'
    case_failed=1
  fi
  [[ "$result" = "$expected_result" ]] || { test_log "  预期退出码$expected_result，实际$result"; case_failed=1; }
  expect_line "GOPROXY_SET=$expected_set" "$case_dir/build-environment" || case_failed=1
  expect_line "GOPROXY=$expected_proxy" "$case_dir/build-environment" || case_failed=1
  expect_line 'GOSUMDB=sum.golang.org' "$case_dir/build-environment" || case_failed=1
  expect_line 'GOPRIVATE=private.example.invalid/*' "$case_dir/build-environment" || case_failed=1
  expect_line 'GONOPROXY=private.example.invalid/*' "$case_dir/build-environment" || case_failed=1
  expect_line 'GONOSUMDB=private.example.invalid/*' "$case_dir/build-environment" || case_failed=1
  local stream marker
  for stream in console.log build.log; do
    for marker in fake-go-stdout fake-go-stderr; do
      expect_line "$marker" "$case_dir/$stream" || case_failed=1
    done
  done
  if [[ "$expected_result" = 0 ]]; then
    expect_line '# NEW_EXECUTABLE' "$case_dir/runtime/workbench" || case_failed=1
    expect_line parent-environment-preserved "$case_dir/parent-check" || case_failed=1
    [[ ! -e "$case_dir/session/workbench.new" ]] || case_failed=1
  else
    cmp -s "$case_dir/old-binary" "$case_dir/runtime/workbench" || { test_log '  构建失败后旧产物发生变化'; case_failed=1; }
  fi
  [[ -f "$case_dir/go-calls" && "$(wc -l < "$case_dir/go-calls" | tr -d ' ')" = 3 ]] || { test_log '  出现预期之外的Go调用'; case_failed=1; }
  TOTAL=$((TOTAL + 1))
  if [[ "$case_failed" = 0 ]]; then
    test_log "✔ $case_name"
  else
    FAILED=$((FAILED + 1))
    test_log "✖ $case_name：$case_dir/console.log"
  fi
}
# 验证真实启动函数请求后端注册的健康路由，且回收本组假进程。
run_health_case() {
  local case_dir="$TEST_ROOT/health-endpoint" result case_failed=0 child
  mkdir -p "$case_dir/session" || exit 1
  printf '#!/bin/zsh -f\nexec /bin/sleep 300\n' > "$case_dir/fake-backend"
  chmod +x "$case_dir/fake-backend" || exit 1
  env "WB_TEST_SOURCE=$TEST_SOURCE" "WB_TEST_GO=$TEST_GO" "WB_TEST_CASE=$case_dir" WB_TEST_HEALTH=1 \
    /bin/zsh -f "$TEST_WORKER" > "$case_dir/console.log" 2>&1
  result=$?
  [[ "$result" = 0 ]] || { test_log "  健康检查退出码：$result"; case_failed=1; }
  expect_line 'http://127.0.0.1:18098/api/v38/healthz' "$case_dir/curl-arguments" || case_failed=1
  expect_line '{"ok":true}' "$case_dir/session/health.json" || case_failed=1
  if [[ -f "$case_dir/backend-pid" ]]; then
    child="$(cat "$case_dir/backend-pid")"
    if kill -0 "$child" 2>/dev/null; then
      test_log "  假后端没有被回收：$child"
      case_failed=1
    fi
  else
    case_failed=1
  fi
  TOTAL=$((TOTAL + 1))
  if [[ "$case_failed" = 0 ]]; then
    test_log '✔ health-endpoint'
  else
    FAILED=$((FAILED + 1))
    test_log "✖ health-endpoint：$case_dir/console.log"
  fi
}
# 只向父Shell发送TERM，验证退出陷阱真正回收子进程而非依赖终端广播。
run_lifecycle_case() {
  local mode="$1" expected_result="$2" case_dir="$TEST_ROOT/lifecycle-$1"
  local runner child result count=0 case_failed=0
  mkdir -p "$case_dir/runtime" || exit 1
  env "WB_TEST_SOURCE=$TEST_SOURCE" "WB_TEST_GO=$TEST_GO" "WB_TEST_CASE=$case_dir" "WB_TEST_LIFECYCLE=$mode" \
    /bin/zsh -f "$TEST_WORKER" > "$case_dir/console.log" 2>&1 &
  runner=$!
  while kill -0 "$runner" 2>/dev/null && [[ ! -f "$case_dir/initialized" && "$count" -lt 4500 ]]; do
    /bin/sleep 0.02
    count=$((count + 1))
  done
  if [[ ! -f "$case_dir/initialized" ]]; then
    test_log '  运行态初始化未完成，或函数返回时提前回收了子进程'
    case_failed=1
  fi
  if [[ "$mode" = term || "$case_failed" != 0 ]]; then
    kill -TERM "$runner" 2>/dev/null || true
  fi
  wait "$runner"
  result=$?
  [[ "$result" = "$expected_result" ]] || { test_log "  预期退出码$expected_result，实际$result"; case_failed=1; }
  if [[ -f "$case_dir/backend-pid" ]]; then
    child="$(cat "$case_dir/backend-pid")"
    if kill -0 "$child" 2>/dev/null; then
      test_log "  退出后遗留假后端：$child；测试仅终止本组记录的PID"
      kill -TERM "$child" 2>/dev/null || true
      case_failed=1
    fi
  else
    case_failed=1
  fi
  TOTAL=$((TOTAL + 1))
  if [[ "$case_failed" = 0 ]]; then
    test_log "✔ lifecycle-$mode"
  else
    FAILED=$((FAILED + 1))
    test_log "✖ lifecycle-$mode：$case_dir/console.log"
  fi
}
# 用真实监控循环配合假选择器和浏览器，观察地址映射、重选及后台进程回收。
run_browser_case() {
  local mode="$1" expected_result="$2" case_dir="$TEST_ROOT/browser-$1"
  local deploy_mode=local runner child result target_file count=0 ready=0 case_failed=0 expected_menus=1
  local -a expected_urls
  mkdir -p "$case_dir/runtime" "$case_dir/bin" || exit 1
  cp "$TEST_OPEN" "$case_dir/bin/open" || exit 1
  case "$mode" in
    url-selection|open-failure)
      printf '%s\n' public local pause > "$case_dir/menu-actions"
      expected_urls=('https://fixture-repair.trycloudflare.com' 'http://127.0.0.1:18098/')
      expected_menus=3;;
    server-local)
      deploy_mode=server
      printf '%s\n' local pause > "$case_dir/menu-actions"
      expected_urls=('http://127.0.0.1:18098/')
      expected_menus=2;;
    escape) printf '%s\n' esc > "$case_dir/menu-actions";;
    empty) printf '%s\n' empty > "$case_dir/menu-actions";;
    ctrl-c) printf '%s\n' ctrl-c > "$case_dir/menu-actions";;
    backend-exit|tunnel-exit|parent-term) printf '%s\n' wait > "$case_dir/menu-actions";;
    *) test_log "未知网页菜单测试：$mode"; exit 1;;
  esac
  env "PATH=$case_dir/bin:$PATH" "WB_TEST_SOURCE=$TEST_SOURCE" "WB_TEST_GO=$TEST_GO" \
    "WB_TEST_FZF=$TEST_FZF" "WB_TEST_CASE=$case_dir" "WB_TEST_BROWSER=$mode" \
    "WB_TEST_DEPLOY_MODE=$deploy_mode" /bin/zsh -f "$TEST_WORKER" > "$case_dir/console.log" 2>&1 &
  runner=$!
  TEST_RUNNER="$runner"
  while [[ "$count" -lt 600 ]]; do
    case "$mode" in
      backend-exit|tunnel-exit|parent-term)
        [[ ! -s "$case_dir/menu-pids" || ! -f "$case_dir/menu-input.1" ]] || { ready=1; break; };;
      ctrl-c)
        kill -0 "$runner" 2>/dev/null || { ready=1; break; };;
      *)
        grep -Fq '网页菜单已收起' "$case_dir/console.log" 2>/dev/null && { ready=1; break; };;
    esac
    kill -0 "$runner" 2>/dev/null || break
    /bin/sleep 0.05
    count=$((count + 1))
  done
  if [[ "$ready" != 1 ]]; then
    test_log '  网页菜单未在限定时间到达预期状态'
    case_failed=1
  fi
  case "$mode" in
    backend-exit|tunnel-exit)
      target_file="$case_dir/backend-pid"
      [[ "$mode" != tunnel-exit ]] || target_file="$case_dir/tunnel-pid"
      if [[ "$ready" = 1 && -s "$target_file" ]]; then
        child="$(cat "$target_file")"
        kill -TERM "$child" 2>/dev/null || { test_log '  假服务提前退出'; case_failed=1; }
      fi;;
    ctrl-c) ;;
    *)
      if [[ "$mode" != parent-term && "$ready" = 1 ]]; then
        for target_file in "$case_dir/backend-pid" "$case_dir/tunnel-pid"; do
          [[ -f "$target_file" ]] || continue
          child="$(cat "$target_file")"
          kill -0 "$child" 2>/dev/null || { test_log '  收起菜单意外停止了服务'; case_failed=1; }
        done
        /bin/sleep 0.6
        expect_line "$expected_menus" "$case_dir/menu-count" || case_failed=1
      fi
      kill -TERM "$runner" 2>/dev/null || true;;
  esac
  if [[ "$case_failed" != 0 ]]; then kill -TERM "$runner" 2>/dev/null || true; fi
  count=0
  while kill -0 "$runner" 2>/dev/null && [[ "$count" -lt 600 ]]; do
    /bin/sleep 0.05
    count=$((count + 1))
  done
  if kill -0 "$runner" 2>/dev/null; then
    test_log '  主进程没有在限定时间退出'
    kill -KILL "$runner" 2>/dev/null || true
    case_failed=1
  fi
  wait "$runner"
  result=$?
  TEST_RUNNER=""
  [[ "$result" = "$expected_result" ]] || { test_log "  预期退出码$expected_result，实际$result"; case_failed=1; }
  if (( ${#expected_urls[@]} > 0 )); then
    printf '%s\n' "${expected_urls[@]}" > "$case_dir/expected-open-urls"
    cmp -s "$case_dir/expected-open-urls" "$case_dir/open-urls" || { test_log '  浏览器打开地址或连续选择次数不符'; case_failed=1; }
  elif [[ -e "$case_dir/open-urls" ]]; then
    test_log '  取消或等待菜单时意外打开了浏览器'
    case_failed=1
  fi
  if [[ "$mode" = open-failure ]]; then
    [[ -f "$case_dir/open-failed-once" ]] || case_failed=1
    grep -Fq '未能打开网页' "$case_dir/console.log" || case_failed=1
    grep -Fq '已交给默认浏览器打开：http://127.0.0.1:18098/' "$case_dir/console.log" || case_failed=1
  fi
  if [[ "$deploy_mode" = local ]]; then
    printf '%s\n' public local pause > "$case_dir/expected-actions"
  else
    printf '%s\n' local pause > "$case_dir/expected-actions"
  fi
  if [[ -f "$case_dir/menu-input.1" ]]; then
    awk -F '\t' '{print $1}' "$case_dir/menu-input.1" > "$case_dir/actual-actions"
    cmp -s "$case_dir/expected-actions" "$case_dir/actual-actions" || { test_log '  菜单地址与当前部署模式不符'; case_failed=1; }
  else
    test_log '  没有进入假网页选择器'
    case_failed=1
  fi
  local pid_file
  for pid_file in "$case_dir/backend-pid" "$case_dir/tunnel-pid" "$case_dir/menu-pids"; do
    [[ -f "$pid_file" ]] || continue
    while IFS= read -r child; do
      if kill -0 "$child" 2>/dev/null; then
        test_log "  退出后遗留本组进程：$child；测试仅终止记录的PID"
        kill -TERM "$child" 2>/dev/null || true
        case_failed=1
      fi
    done < "$pid_file"
  done
  TOTAL=$((TOTAL + 1))
  if [[ "$case_failed" = 0 ]]; then
    test_log "✔ browser-$mode"
  else
    FAILED=$((FAILED + 1))
    test_log "✖ browser-$mode：$case_dir/console.log"
  fi
}
# 覆盖默认、自定义和显式空策略，并验证成功与失败的产物提交边界。
run_suite() {
  local fallback='https://goproxy.cn|https://proxy.golang.org|direct'
  run_case default-source default "$fallback" x 0
  run_case environment-custom env-custom https://modules.example.invalid x 0
  run_case environment-empty env-empty '' x 0
  run_case environment-off env-off off x 0
  run_case user-config-custom file-custom '' '' 0
  run_case user-config-default file-default '' '' 0
  run_case user-config-empty file-empty '' '' 0
  run_case disabled-user-config goenv-off "$fallback" x 0
  run_case existing-effective-policy effective-custom '' '' 0
  run_case failed-build-keeps-old default "$fallback" x 43 43
  run_case missing-binary-keeps-old default "$fallback" x 1 0 1
  run_health_case
  run_lifecycle_case normal 0
  run_lifecycle_case fail 47
  run_lifecycle_case term 143
  run_browser_case url-selection 143
  run_browser_case open-failure 143
  run_browser_case escape 143
  run_browser_case empty 143
  run_browser_case server-local 143
  run_browser_case backend-exit 143
  run_browser_case tunnel-exit 1
  run_browser_case ctrl-c 130
  run_browser_case parent-term 143
}
# 输出汇总并将失败准确传给自动化调用者。
finish_suite() {
  test_log "合计：$TOTAL 组，失败：$FAILED 组。"
  if [[ "$FAILED" != 0 ]]; then
    test_log "诊断日志保留：$TEST_LOG"
    exit 1
  fi
  test_log '全部通过；本次临时夹具将清理。'
  SUITE_PASSED=1
}
# 编排说明、隔离准备、验证和汇总。
main() {
  show_script_intro_and_wait "$@" # 先说明临时写入与执行边界并取得入口确认。
  prepare_fixture # 只在系统临时目录准备真实函数副本和工具替身。
  run_suite # 验证构建、健康地址、网页菜单及本次子进程回收。
  finish_suite # 汇总测试结果并传播失败状态。
}

main "$@"
