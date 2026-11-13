#!/usr/bin/env bash

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
    jobs_terminal_style_run /usr/bin/env bash "$jobs_style_bootstrap_script" "$@"
    jobs_style_bootstrap_result=$?
    exit "$jobs_style_bootstrap_result"
}
jobs_terminal_style_bootstrap "$0" "$@"
# <<< Jobs terminal style protection v1 <<<

# ================================== 路径 & 日志 ==================================
# 仅渲染自述：标题红色加粗，编号正文蓝色常规字重；非彩色终端输出纯文本。
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

jobs_intro_style() {
  local intro_color=0
  if [ -t 1 ] && [ -n "${TERM:-}" ] && [ "${TERM:-}" != dumb ] &&
     [ -z "${NO_COLOR+x}" ] && [ "${PLAIN_OUTPUT:-0}" != 1 ] &&
     [ "${IS_SOURCETREE_RUNTIME:-0}" != 1 ]; then
    intro_color=1
  fi
  /usr/bin/awk -v color="$intro_color" -v role="${1:-body}" '
    BEGIN { esc = sprintf("%c", 27) }
    {
      gsub(esc "\\[[0-9;]*m", "")
      gsub(/\\(033|e|x1[bB])\[[0-9;]*m/, "")
      if (!color || $0 ~ /^[[:space:]]*$/) { print; next }
      numbered = ($0 ~ /^[[:space:]➤ℹ🔹✔⚠]*([0-9]+[、.)）]|[0-9]+️⃣|[-•])/)
      heading = ($0 ~ /^[[:space:]]*#{1,6}[[:space:]]/ || $0 ~ /[：:][[:space:]]*$/ || $0 ~ /^[[:space:]]*[=━─-]{3}/)
      title = (!numbered && (role == "title" || heading))
      if (role == "auto" && !seen && !numbered) title = 1
      if ($0 !~ /^[[:space:]]*[=━─-]+[[:space:]]*$/) seen = 1
      printf "%s%s%s\n", esc (title ? "[1;31m" : "[0;34m"), $0, esc "[0m"
    }
  '
}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")" && pwd)"
SCRIPT_PATH="${SCRIPT_DIR}/$(basename -- "$0")"
SCRIPT_BASENAME=$(basename "$0" | sed 's/\.[^.]*$//')   # 当前脚本名（去掉扩展名）
LOG_FILE="/tmp/${SCRIPT_BASENAME}.log"                  # 设置对应的日志文件路径

log()            { echo -e "$1" | jobs_prompt_tee "$LOG_FILE"; }
color_echo()     { log "\033[1;32m$1\033[0m"; }
info_echo()      { log "\033[1;34mℹ $1\033[0m"; }
success_echo()   { log "\033[1;32m✔ $1\033[0m"; }
warn_echo()      { log "\033[1;33m⚠ $1\033[0m"; }
warm_echo()      { log "\033[1;33m$1\033[0m"; }
note_echo()      { log "\033[1;35m➤ $1\033[0m"; }
error_echo()     { log "\033[1;31m✖ $1\033[0m"; }
err_echo()       { log "\033[1;31m$1\033[0m"; }
debug_echo()     { log "\033[1;35m🐞 $1\033[0m"; }
highlight_echo() { log "\033[1;36m🔹 $1\033[0m"; }
gray_echo()      { log "\033[0;90m$1\033[0m"; }
bold_echo()      { log "\033[1m$1\033[0m"; }
underline_echo() { log "\033[4m$1\033[0m"; }

init_log() {
  : > "$LOG_FILE"  # 清空旧日志
}

# ================================== 自述 & 确认 ==================================
show_intro_and_wait() {
  bold_echo "========== CocoaPods 发布辅助脚本 (${SCRIPT_BASENAME}) ==========" | jobs_intro_style title
  gray_echo "脚本路径: $SCRIPT_PATH" | jobs_intro_style body
  gray_echo "日志文件: $LOG_FILE" | jobs_intro_style body
  echo | jobs_intro_style body

  note_echo "本脚本将执行以下步骤：" | jobs_intro_style title
  note_echo "1) 自检 Homebrew，如无则安装；可选更新。" | jobs_intro_style body
  note_echo "2) 通过 Homebrew 安装/升级 fzf。" | jobs_intro_style body
  note_echo "3) 在脚本当前目录查找 *.podspec，多文件时用 fzf 选择；没有就循环让你输入路径。" | jobs_intro_style body
  note_echo "4) 如果检测到 Git 仓库且当前 HEAD 有 tag，则把该 tag 写入 podspec 的 version 字段。" | jobs_intro_style body
  note_echo "5) 解析选中的 podspec，读取 name 和 version，仅作为信息展示。" | jobs_intro_style body
  note_echo "6) 执行 pod lib lint --allow-warnings，仅 lint 通过才继续（可选）。" | jobs_intro_style body
  note_echo "7) 检测是否已经登录 CocoaPods trunk：" | jobs_intro_style body
  note_echo "   - 已登录：跳过 pod trunk register，不再询问。" | jobs_intro_style body
  note_echo "   - 未登录：只在首次时询问是否执行 pod trunk register。" | jobs_intro_style body
  note_echo "8) 执行 pod trunk push <podspec> --allow-warnings，把 Pod 推到 trunk。" | jobs_intro_style body
  note_echo "9) 最后执行 pod trunk info <name> 查看远端信息。" | jobs_intro_style body
  echo | jobs_intro_style body
  warm_echo "建议先确认：" | jobs_intro_style title
  warm_echo "1) 当前 git 分支正确，代码已提交。" | jobs_intro_style body
  warm_echo "2) 如需用 Git tag 控制版本号，HEAD 已打好 tag。" | jobs_intro_style body
  warm_echo "3) 若之前从未注册过 trunk，本次可能需要进行一次 pod trunk register。" | jobs_intro_style body
  echo | jobs_intro_style body

  read -r -p "$(jobs_prompt_render "按 [Enter] 继续执行，或按 Ctrl+C 终止脚本... ")" _
  echo | jobs_intro_style body
}

# ================================== 工具函数 ==================================
get_cpu_arch() {
  uname -m
}

inject_shellenv_block() {
  local profile_file="$1"
  local shellenv_cmd="$2"

  [[ -z "$profile_file" || -z "$shellenv_cmd" ]] && return 1

  touch "$profile_file" || return 1

  if grep -Fq "$shellenv_cmd" "$profile_file" 2>/dev/null; then
    info_echo "Homebrew shellenv 已存在于 $profile_file"
    return 0
  fi

  {
    echo ""
    echo "# >>> Homebrew shellenv (added by $SCRIPT_BASENAME) >>>"
    echo "$shellenv_cmd"
    echo "# <<< Homebrew shellenv <<<"
  } >> "$profile_file"

  success_echo "已写入 Homebrew shellenv 到 $profile_file"
}

ensure_command() {
  local cmd="$1"
  local hint="$2"
  if ! command -v "$cmd" &>/dev/null; then
    error_echo "未检测到命令: $cmd"
    [[ -n "$hint" ]] && note_echo "$hint"
    exit 1
  fi
}

# ================================== Homebrew & fzf ==================================
install_homebrew() {
  local arch="$(get_cpu_arch)"                   # 获取当前架构（arm64 或 x86_64）
  local shell_path="${SHELL##*/}"                # 获取当前 shell 名称（如 zsh、bash）
  local profile_file=""
  local brew_bin=""
  local shellenv_cmd=""

  if ! command -v brew &>/dev/null; then
    warn_echo "🧩 未检测到 Homebrew，正在安装中...（架构：$arch）"

    if [[ "$arch" == "arm64" ]]; then
      # Apple Silicon 原生 Homebrew（/opt/homebrew）
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || {
        error_echo "❌ Homebrew 安装失败（arm64）"
        exit 1
      }
      brew_bin="/opt/homebrew/bin/brew"
    else
      # Intel 或在 Apple Silicon 下装一份 Intel 版 Homebrew（需要 Rosetta）
      arch -x86_64 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || {
        error_echo "❌ Homebrew 安装失败（x86_64）"
        exit 1
      }
      brew_bin="/usr/local/bin/brew"
    fi

    success_echo "✅ Homebrew 安装成功"

    # ==== 注入 shellenv 到对应配置文件（自动生效） ====
    shellenv_cmd="eval \"$(${brew_bin} shellenv)\""
    case "$shell_path" in
      zsh)   profile_file="$HOME/.zprofile" ;;
      bash)  profile_file="$HOME/.bash_profile" ;;
      *)     profile_file="$HOME/.profile" ;;
    esac
    inject_shellenv_block "$profile_file" "$shellenv_cmd"

    # 立刻对当前会话生效（不等重开终端）
    eval "$(${brew_bin} shellenv)"

  else
    info_echo "🔄 Homebrew 已安装。是否执行更新？"
    jobs_prompt_output echo "👉 直接按 [Enter]：跳过更新"
    jobs_prompt_output echo "👉 输入任意字符后回车：执行更新（brew update && brew upgrade && brew cleanup && brew doctor && brew -v）"
    local confirm
    IFS= read -r confirm
    if [[ -n "$confirm" ]]; then
      info_echo "⏳ 正在更新 Homebrew..."
      brew update       || { error_echo "❌ brew update 失败"; return 1; }
      brew upgrade      || { error_echo "❌ brew upgrade 失败"; return 1; }
      brew cleanup      || { error_echo "❌ brew cleanup 失败"; return 1; }
      brew doctor       || { warn_echo  "⚠️  brew doctor 有警告/错误，请按提示处理"; }
      brew -v           || { warn_echo  "⚠️  打印 brew 版本失败（可忽略）"; }
      success_echo "✅ Homebrew 已更新"
    else
      note_echo "⏭️ 已选择跳过 Homebrew 更新"
    fi
  fi
}

install_fzf() {
  if ! command -v fzf &>/dev/null; then
    note_echo "📦 未检测到 fzf，正在通过 Homebrew 安装..."
    brew install fzf || { error_echo "❌ fzf 安装失败"; exit 1; }
    success_echo "✅ fzf 安装成功"
  else
    info_echo "🔄 fzf 已安装。是否执行升级？"
    jobs_prompt_output echo "👉 直接按 [Enter]：跳过升级"
    jobs_prompt_output echo "👉 输入任意字符后回车：执行升级（brew upgrade fzf && brew cleanup）"

    local confirm
    IFS= read -r confirm
    if [[ -n "$confirm" ]]; then
      info_echo "⏳ 正在升级 fzf..."
      brew upgrade fzf       || { error_echo "❌ fzf 升级失败"; return 1; }
      brew cleanup           || { warn_echo  "⚠️  brew cleanup 执行时有警告"; }
      success_echo "✅ fzf 已升级到最新版本"
    else
      note_echo "⏭️ 已选择跳过 fzf 升级"
    fi
  fi
}

# ================================== Podspec 选择 ==================================
PODSPEC_PATH=""
PODSPEC_BASENAME=""
POD_NAME=""
POD_VERSION=""
GIT_TAG=""

select_podspec_in_script_dir() {
  local search_dir="$SCRIPT_DIR"
  local podspec_files=("$search_dir"/*.podspec)

  if [[ ! -e "${podspec_files[0]}" ]]; then
    warn_echo "在脚本目录($search_dir)下未找到任何 *.podspec 文件。"
    ask_podspec_from_user
    return
  fi

  if [[ ${#podspec_files[@]} -eq 1 ]]; then
    PODSPEC_PATH="${podspec_files[0]}"
    PODSPEC_BASENAME="$(basename "$PODSPEC_PATH")"
    success_echo "自动选中 podspec: $PODSPEC_BASENAME"
    return
  fi

  # 多个 podspec，用 fzf 选择
  ensure_command fzf "请先安装 fzf（brew install fzf）"
  note_echo "检测到多个 podspec，请选择要发布的那个："

  local selected_basename
  selected_basename=$(printf '%s\n' "${podspec_files[@]##"$search_dir"/}" | \
    fzf --prompt="选择 podspec: " --height=40%) || {
    error_echo "未选择任何 podspec，发布流程中断。"
    exit 1
  }

  PODSPEC_PATH="$search_dir/$selected_basename"
  PODSPEC_BASENAME="$selected_basename"
  success_echo "已选择 podspec: $PODSPEC_BASENAME"
}

ask_podspec_from_user() {
  while :; do
    jobs_prompt_output warm_echo "请手动输入要发布的 .podspec 文件路径（可直接将文件拖入终端后回车）："
    printf "> "
    local input
    IFS= read -r input

    # 处理拖入路径时自动加的引号
    input="${input%\"}"; input="${input#\"}"
    input="${input%\'}"; input="${input#\'}"

    # 处理 ~
    input=${input/#~/$HOME}

    if [[ -f "$input" ]]; then
      PODSPEC_PATH="$input"
      PODSPEC_BASENAME="$(basename "$PODSPEC_PATH")"
      success_echo "已选择 podspec: $PODSPEC_BASENAME"
      break
    else
      error_echo "路径无效或文件不存在: $input"
    fi
  done
}

# ================================== Git tag → version 同步 ==================================
find_git_repo_root() {
  # 从脚本目录往上找 .git
  local dir="$SCRIPT_DIR"
  while [[ "$dir" != "/" && ! -d "$dir/.git" ]]; do
    dir="$(dirname "$dir")"
  done
  if [[ -d "$dir/.git" ]]; then
    echo "$dir"
    return 0
  fi
  return 1
}

sync_podspec_version_with_git_tag_if_possible() {
  local repo_root
  if ! repo_root=$(find_git_repo_root); then
    debug_echo "未检测到 .git 目录，跳过 Git tag → version 同步。"
    return
  fi

  if ! command -v git &>/dev/null; then
    warn_echo "检测到 .git，但系统未安装 git，无法同步 version。"
    return
  fi

  info_echo "检测到 Git 仓库: $repo_root"

  # 只取“当前 HEAD 上的 tag”
  local tags
  tags=$(cd "$repo_root" && git tag --points-at HEAD)
  if [[ -z "$tags" ]]; then
    warn_echo "当前 HEAD 没有打 tag，保持 podspec 中原有 version，不做自动覆盖。"
    return
  fi

  local tag
  tag=$(printf '%s\n' "$tags" | head -n1)
  GIT_TAG="$tag"
  highlight_echo "使用 Git tag 作为版本号: $GIT_TAG"
  ensure_command ruby "需要 Ruby 来修改 podspec 中 version 字段。"

  local spec_file="$PODSPEC_PATH"
  local ruby_script
  ruby_script=$(cat << 'RUBY'
spec_path = ARGV[0]
new_version = ARGV[1]
content = File.read(spec_path)
pattern = /(\.version\s*=\s*['"])[^'"]+(['"])/
unless content =~ pattern
  STDERR.puts "未在 podspec 中找到 version 字段。"
  exit 1
end
content.sub!(pattern) { "#{$1}#{new_version}#{$2}" }
File.write(spec_path, content)
RUBY
  )

  if ruby -e "$ruby_script" "$spec_file" "$GIT_TAG" 2>/tmp/podspec_version_update_error.log; then
    success_echo "已将 podspec 中的 version 更新为 Git tag: $GIT_TAG"
  else
    warn_echo "尝试用 Git tag 更新 version 失败，详情见 /tmp/podspec_version_update_error.log；将使用原始 version。"
  fi
}

# ================================== Podspec 解析 ==================================
read_podspec_metadata() {
  ensure_command ruby "CocoaPods 依赖 Ruby，请先安装 Ruby 环境。"

  local spec_file="$PODSPEC_PATH"
  if [[ ! -f "$spec_file" ]]; then
    error_echo "podspec 文件不存在: $spec_file"
    exit 1
  fi

  local ruby_script
  ruby_script=$(cat << 'RUBY'
require 'cocoapods'
spec_path = ARGV[0]
spec = Pod::Specification.from_file(spec_path)
puts spec.name
puts spec.version
RUBY
  )

  local output
  if ! output=$(ruby -e "$ruby_script" "$spec_file" 2>/tmp/podspec_parse_error.log); then
    error_echo "使用 Ruby 解析 podspec 失败，详情见 /tmp/podspec_parse_error.log"
    exit 1
  fi

  POD_NAME=$(echo "$output" | sed -n '1p')
  POD_VERSION=$(echo "$output" | sed -n '2p')

  if [[ -z "$POD_NAME" || -z "$POD_VERSION" ]]; then
    error_echo "未能从 podspec 中解析出 name/version，请检查文件。"
    exit 1
  fi

  info_echo "📦 Pod 名称: $POD_NAME"
  info_echo "🏷 版本号: $POD_VERSION"
}

# ================================== CocoaPods trunk 相关 ==================================
ensure_cocoapods() {
  ensure_command pod "请先安装 CocoaPods，例如: sudo gem install cocoapods"
}

is_trunk_logged_in() {
  # 使用 pod trunk me 判断是否已经登录；只要成功就认为“注册+登录过”
  local tmp_log="/tmp/pod_trunk_me_${SCRIPT_BASENAME}.log"
  if pod trunk me >"$tmp_log" 2>&1; then
    local name email
    name=$(grep -E '^\s*Name:'  "$tmp_log" | sed 's/^[[:space:]]*Name:[[:space:]]*//')
    email=$(grep -E '^\s*Email:' "$tmp_log" | sed 's/^[[:space:]]*Email:[[:space:]]*//')
    if [[ -n "$name" || -n "$email" ]]; then
      info_echo "当前已登录 CocoaPods trunk: ${name:-?} <${email:-?}>"
    else
      info_echo "当前已登录 CocoaPods trunk。"
    fi
    return 0
  fi
  debug_echo "pod trunk me 失败，推测当前环境尚未登录 trunk。"
  return 1
}

maybe_trunk_register() {
  # 如果已经登录过 trunk，就完全跳过，不再问
  if is_trunk_logged_in; then
    note_echo "检测到已登录 CocoaPods trunk，跳过 pod trunk register 步骤。"
    return
  fi

  warm_echo "当前环境尚未登录 CocoaPods trunk（pod trunk me 失败）。"
  warm_echo "通常只在首次使用该邮箱时需要执行 pod trunk register。"
  echo "是否现在执行 pod trunk register? [y/N]"
  printf "> "
  local ans
  IFS= read -r ans
  if [[ ! "$ans" =~ ^[Yy]$ ]]; then
    note_echo "已选择跳过 pod trunk register（若从未注册过，该环境可能无法成功 pod trunk push）。"
    return
  fi

  local email
  while :; do
    warm_echo "请输入用于 CocoaPods trunk 的注册邮箱："
    printf "> "
    IFS= read -r email
    if [[ -n "$email" ]]; then
      break
    fi
    warn_echo "邮箱不能为空。"
  done

  info_echo "执行: pod trunk register $email 'Jobs' --description='$PODSPEC_BASENAME'"
  if pod trunk register "$email" 'Jobs' --description="$PODSPEC_BASENAME"; then
    success_echo "已发起 trunk 注册请求。"
    note_echo "请前往邮箱查收 CocoaPods 发来的确认邮件并完成验证后再继续发布。"
  else
    error_echo "pod trunk register 执行失败，你可以手动检查原因或稍后重试。"
  fi
}

# ================================== CocoaPods 发布 ==================================
run_pod_lib_lint() {
  info_echo "开始执行 pod lib lint --allow-warnings $PODSPEC_BASENAME"
  if pod lib lint --allow-warnings "$PODSPEC_PATH"; then
    success_echo "✅ pod lib lint 校验通过"
  else
    error_echo "❌ pod lib lint 校验失败，发布流程终止。"
    exit 1
  fi
}

maybe_run_pod_lib_lint() {
  warm_echo "是否先执行 pod lib lint --allow-warnings？"
  jobs_prompt_output echo "👉 直接按 [Enter]：先执行 pod lib lint（推荐，确保本地能通过）"
  jobs_prompt_output echo "👉 输入任意内容后回车：跳过 lint，直接进行 trunk 发布流程（风险自负）"
  printf "> "
  local ans
  IFS= read -r ans
  echo

  if [[ -z "$ans" ]]; then
    note_echo "将先执行 pod lib lint ..."
    run_pod_lib_lint
  else
    warn_echo "已选择跳过 pod lib lint，脚本将直接进入 trunk 发布流程。"
  fi
}

push_to_trunk() {
  info_echo "准备执行 pod trunk push $PODSPEC_BASENAME --allow-warnings"
  warm_echo "确保该 Pod 已完成 trunk 邮箱验证，并且本地 'pod trunk me' 状态正常。"
  jobs_prompt_output echo "按 [Enter] 继续推送，或 Ctrl+C 取消。"
  IFS= read -r _

  local tmp_log="/tmp/pod_trunk_push_${SCRIPT_BASENAME}.log"
  info_echo "pod trunk push 输出已同步记录到: $tmp_log"

  # 执行 push，并通过 tee 显示 + 记录日志
  pod trunk push "$PODSPEC_PATH" --allow-warnings 2>&1 | tee "$tmp_log"
  local exit_code=${PIPESTATUS[0]}   # 取 pipeline 中第一个命令（pod）的退出码

  if [[ $exit_code -eq 0 ]]; then
    success_echo "✅ pod trunk push 成功 ($POD_NAME $POD_VERSION)"
    return 0
  fi

  # ---- 失败情况：先判断是不是 CocoaPods 的内部错误 ----
  if grep -q "An internal server error occurred" "$tmp_log"; then
    warn_echo "⚠ 检测到 CocoaPods Trunk 返回 Internal Server Error（服务器内部错误）。"
    note_echo "大概率是 CocoaPods 官方服务故障，并不一定是你的 podspec 有问题。"
    echo
    jobs_prompt_output warm_echo "按 [Enter] 继续执行后续步骤（本次 push 失败，但脚本不会中断）；"
    jobs_prompt_output warm_echo "或者输入任意字符后回车：立刻结束脚本。"
    printf "> "
    local ans
    IFS= read -r ans
    if [[ -z "$ans" ]]; then
      note_echo "已选择继续：脚本将跳过本次 push 错误，继续执行后续步骤。"
      return 0
    else
      error_echo "已根据你的选择终止脚本。"
      exit 1
    fi
  fi

  # ---- 其它错误：仍然直接终止 ----
  error_echo "❌ pod trunk push 失败，请检查上面的错误信息（非服务器内部错误）。"
  exit 1
}

show_trunk_info() {
  info_echo "查询 trunk 上的 Pod 信息: $POD_NAME"
  if pod trunk info "$POD_NAME"; then
    success_echo "已展示 pod trunk info $POD_NAME"
  else
    warn_echo "pod trunk info 查询失败，请确认该 Pod 是否已成功发布。"
  fi
}

# ================================== main ==================================
main() {
  init_log
  show_intro_and_wait

  # 1. 自检 / 安装 Homebrew + fzf
  install_homebrew
  install_fzf
  ensure_cocoapods

  # 2. 选择 podspec
  select_podspec_in_script_dir

  # 3. 如果有 Git 仓库 & HEAD 有 tag，用 tag 覆盖 podspec 的 version
  sync_podspec_version_with_git_tag_if_possible

  # 4. 解析 name / version
  read_podspec_metadata

  # 5. 是否执行 lint（回车执行，否则直接跳过）
  maybe_run_pod_lib_lint

  # 6. trunk register（仅在当前环境未登录 trunk 时，才问一次）
  maybe_trunk_register

  # 7. push & 查看 info
  push_to_trunk
  show_trunk_info

  success_echo "🎉 发布流程结束。"
}

main "$@"
