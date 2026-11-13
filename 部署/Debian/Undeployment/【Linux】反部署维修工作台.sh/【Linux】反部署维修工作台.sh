#!/bin/bash
# 脚本自述：
# - 核心用途：按部署原点清单反向停止本项目进程、恢复原程序并撤回本次新增依赖。
# - 数据处理：fzf默认先备份；清零必须单独选择并复核。备份失败或身份冲突时停止删除。
# - 影响范围：仅已登记的本项目资源；保留原有共享工具、其它项目和数据库结构。
# - 运行提示：先阅读并回车，再用fzf明确确认；--check/--plan严格只读，不下载工具。
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
    jobs_terminal_style_run /bin/bash "$jobs_style_bootstrap_script" "$@"
    jobs_style_bootstrap_result=$?
    exit "$jobs_style_bootstrap_result"
}
jobs_terminal_style_bootstrap "$0" "$@"
# <<< Jobs terminal style protection v1 <<<

# JOBS_INPUT_CHOICE_STYLE_BEGIN
# 只展示提示选项；不读取答案、不改变默认值、返回码或业务环境。
jobs_prompt_color_ready() {
  [ -z "${NO_COLOR+x}" ] && [ -n "${TERM:-}" ] && [ "${TERM:-}" != dumb ] &&
    [ "${PLAIN_OUTPUT:-0}" != 1 ] && [ "${IS_SOURCETREE_RUNTIME:-0}" != 1 ]
}
# 原生 awk 分段着色；任意/非空输入优先，括号内外沿用同一个选项。
jobs_prompt_format() {
  /usr/bin/awk -v color="${1:-0}" -v lines="${2:-0}" -v keep="${3:-0}" '
    function typedEnter(value, start, prefix) {
      prefix = substr(value, 1, start - 1)
      gsub(/[“”‘’「」『』"]/, "", prefix)
      gsub(sprintf("%c", 39), "", prefix)
      if (prefix ~ /(空格|[Ss][Pp][Aa][Cc][Ee])[[:space:]]*(后|再|并|[Tt][Hh][Ee][Nn])?[[:space:]]*$/) return 1
      return prefix ~ /(输入|键入|填写|[Tt]ype)[^；;|]*[[:alnum:]_+-]+[[:space:]]*(后|再|并)?[[:space:]]*$/
    }
    function greenPosition(value, token, start) {
      if (match(value, /(直接|仅|只需|只|按下|按)?[[:space:]]*(回车|回車)/)) {
        start = RSTART
        return typedEnter(value, start) ? 0 : start
      }
      if (!match(value, /(^|[^[:alnum:]_])([Ee][Nn][Tt][Ee][Rr]|[Rr][Ee][Tt][Uu][Rr][Nn])([^[:alnum:]_]|$)/)) return 0
      start = RSTART
      token = substr(value, RSTART, RLENGTH)
      match(token, /[Ee][Nn][Tt][Ee][Rr]|[Rr][Ee][Tt][Uu][Rr][Nn]/)
      start += RSTART - 1
      return typedEnter(value, start) ? 0 : start
    }
    function segment(value, inherited, start, kind, prefix, body, red, green, connector, left, right, splitAt) {
      if (value == "") return value
      kind = inherited
      start = 1
      if (!kind) {
        if (match(value, /(输入)?(任意|任何)(非空)?(字符|内容|输入|键)|非空(字符|内容|输入)?|其它输入|其他输入|[Tt]ype (anything|any[^ ]*)|[Pp]ress any key/)) {
          red = RSTART
        }
        green = greenPosition(value)
        if (red && green && green < red) {
          left = substr(value, 1, red - 1)
          right = substr(value, red)
          connector = ""
          if (match(left, /(或者|或)[[:space:]]*$/)) {
            connector = substr(left, RSTART)
            left = substr(left, 1, RSTART - 1)
          }
          return segment(left, 0) connector segment(right, 31)
        }
        if (red && green && red < green && match(value, /或[[:space:]]*(直接|仅|只需|只|按下|按)?(回车|回車)/)) {
          splitAt = RSTART
          return segment(substr(value, 1, splitAt - 1), 31) "或" segment(substr(value, splitAt + length("或")), 0)
        }
        if (red) {
          kind = 31
          start = red
        } else if (green) {
          kind = 32
          start = green
        }
      }
      if (!kind || !color) return value
      prefix = substr(value, 1, start - 1)
      body = substr(value, start)
      return prefix esc "[1;" kind "m" body esc "[0m"
    }
    function render(value, output, part, boundary, inherited, kind, consumed, depth, original) {
      original = value
      gsub(esc "\\[[0-9;]*m", "", value)
      if (color && keep && !greenPosition(value) && value !~ /(任意|任何|非空|其它输入|其他输入|[Tt]ype (anything|any[^ ]*)|[Pp]ress any key)/) return original
      output = ""
      inherited = 0
      depth = 0
      while (match(value, /[；;\/|，,、？?：:=＝（）()\[\]【】]/)) {
        part = substr(value, 1, RSTART - 1)
        boundary = substr(value, RSTART, RLENGTH)
        consumed = RSTART + RLENGTH
        output = output segment(part, inherited) boundary
        if (boundary ~ /[（(\[【]/) {
          depth++
          if (part ~ /(任意|任何|非空|其它输入|其他输入|[Tt]ype (anything|any[^ ]*)|[Pp]ress any key)/) inherited = 31
          else if (greenPosition(part)) inherited = 32
        } else if (boundary ~ /[）)\]】]/) {
          if (depth) depth--
        } else if (boundary ~ /[：:=＝]/) {
          if (!inherited) {
            if (part ~ /(任意|任何|非空|其它输入|其他输入)/) inherited = 31
            else if (greenPosition(part)) inherited = 32
          }
        } else if (!depth) inherited = 0
        value = substr(value, consumed)
      }
      return output segment(value, inherited)
    }
    BEGIN { esc = sprintf("%c", 27); first = 1 }
    {
      if (lines == 2) {
        if (!first) printf "%s\n", render(pending)
        pending = $0
        first = 0
        next
      }
      if (!lines && !first) printf "\n"
      printf "%s", render($0)
      if (lines) printf "\n"
      first = 0
    }
    END {
      if (lines == 2 && !first) {
        sub(sprintf("%c", 1) "$", "", pending)
        printf "%s", render(pending)
      }
    }
  '
}
# read 的命令替换会使 stdout 成为管道，按输入与提示所在 stderr 判断终端。
jobs_prompt_render() {
  local jobs_prompt_color=0
  if [ -t 0 ] && [ -t 2 ] && jobs_prompt_color_ready; then jobs_prompt_color=1; fi
  printf "%s" "$1" | jobs_prompt_format "$jobs_prompt_color" 0
}
# 仅放在显示链末端；tee 在此函数之前接收纯文本，不把 ANSI 写入日志。
jobs_prompt_stream() {
  local jobs_prompt_color=0
  if [ -t 1 ] && jobs_prompt_color_ready; then jobs_prompt_color=1; fi
  jobs_prompt_format "$jobs_prompt_color" 1 1
}
# 显示管道保留原末尾换行；只删除本轮追加的最后一个结束标记。
jobs_prompt_filter() {
  local jobs_prompt_color=0
  if [ -t 1 ] && jobs_prompt_color_ready; then jobs_prompt_color=1; fi
  { /bin/cat; printf '\001'; } | jobs_prompt_format "$jobs_prompt_color" 2 1
}
# 仅包装原 printf/echo/print 展示，原参数、尾换行与显示命令退出码保持不变。
jobs_prompt_output() {
  local jobs_prompt_status=0 jobs_prompt_stderr=0 jobs_prompt_arg="" jobs_prompt_previous=""
  if [ "${1:-}" = print ]; then
    for jobs_prompt_arg in "$@"; do
      case "$jobs_prompt_arg" in -?*u2*|-u2) jobs_prompt_stderr=1 ;; esac
      if [ "$jobs_prompt_previous" = -u ] && [ "$jobs_prompt_arg" = 2 ]; then jobs_prompt_stderr=1; fi
      jobs_prompt_previous="$jobs_prompt_arg"
      [ "$jobs_prompt_arg" != -- ] || break
    done
  fi
  if [ -n "${ZSH_VERSION:-}" ]; then
    if [ "$jobs_prompt_stderr" = 1 ]; then
      "$@" 2>&1 | jobs_prompt_filter >&2
      jobs_prompt_status=$(( ${pipestatus[1]} != 0 ? ${pipestatus[1]} : ${pipestatus[2]} ))
    else
      "$@" | jobs_prompt_filter
      jobs_prompt_status=$(( ${pipestatus[1]} != 0 ? ${pipestatus[1]} : ${pipestatus[2]} ))
    fi
  elif [ -n "${BASH_VERSION:-}" ]; then
    "$@" | jobs_prompt_filter
    jobs_prompt_status=$(( ${PIPESTATUS[0]} != 0 ? ${PIPESTATUS[0]} : ${PIPESTATUS[1]} ))
  else
    "$@" | jobs_prompt_filter
    jobs_prompt_status=$?
  fi
  return "$jobs_prompt_status"
}
# 仅替换日志 primitive 的 tee：磁盘同步追加纯文，终端保留非选项原色。
jobs_prompt_tee() {
  local jobs_prompt_log="$1" jobs_prompt_line="" jobs_prompt_newline=0
  while :; do
    jobs_prompt_line=""
    if IFS= read -r jobs_prompt_line; then jobs_prompt_newline=1; else jobs_prompt_newline=0; [ -n "$jobs_prompt_line" ] || break; fi
    if [ "$jobs_prompt_newline" = 1 ]; then
      { printf '%s\n' "$jobs_prompt_line"; printf '\001'; } | jobs_prompt_format 0 2 >> "$jobs_prompt_log" || return $?
      printf '%s\n' "$jobs_prompt_line" | jobs_prompt_filter || return $?
    else
      { printf '%s' "$jobs_prompt_line"; printf '\001'; } | jobs_prompt_format 0 2 >> "$jobs_prompt_log" || return $?
      printf '%s' "$jobs_prompt_line" | jobs_prompt_filter || return $?
    fi
  done
}
# JOBS_INPUT_CHOICE_STYLE_END

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
EXPECTED_OS="linux"
EXPECTED_DISTRO="debian"

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
  jobs_prompt_output printf '%s' '已阅读影响范围，按回车继续；其它输入取消：'
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
    jobs_prompt_output printf '%s' '清零不可恢复；按空格后回车确认，其它输入取消：'
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
