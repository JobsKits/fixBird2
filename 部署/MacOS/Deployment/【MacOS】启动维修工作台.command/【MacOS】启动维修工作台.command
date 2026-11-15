#!/bin/zsh
# 脚本自述：
# - 核心用途：用 fzf 选择本地部署＋内网穿透或服务器部署，构建并运行维修工作台。
# - 外网访问：本地模式回车确认后生成公开演示链接，无需邮箱或确认词；显示前台与管理后台网页二维码，仅用合成数据。
# - 影响范围：缺失公共工具下载到机器环境；运行资料留在本项目独立用户目录；不注册服务、不改全局PATH或防火墙。
# - 运行提示：先回车确认再选择模式；Esc取消；Ctrl+C停止本次子进程并保留数据。

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
    jobs_terminal_style_run /bin/zsh "$jobs_style_bootstrap_script" "$@"
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
PUBLIC_URL=""
QR_BINARY=""
QR_PAGE=""
QR_GENERATION=0
WORKBENCH_BINARY=""
RUN_DIR=""
OUTPUT_COLOR=0
EXPECTED_OS="darwin"
EXPECTED_DISTRO=""
DEPLOY_STATE_DIR=""
DEPLOY_OPERATION_LOCK=""
DEPLOY_LOCK_HELD=0
PROJECT_ENV_DIR=""
MISSING_RUNTIME_PARENTS=""
RUNTIME_EXISTED=absent
DEPLOY_HANDOFF_FD=""
GUARDIAN_PID=""
DEPLOY_OWNER_PID=""
CLEANUP_RUNNING=0

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
  display_line '0;34' '   本地模式回车确认公开演示，无需填写邮箱或输入确认词；任何取得链接的人均可访问入口，仅用合成数据。'
  display_line '0;34' '2、服务器部署：仅构建并运行后端，不建立穿透；保留回环监听与现有数据语义。'
  display_line '0;34' '3、菜单用健康Go／fzf引导；选定模式后查询官方最新稳定工具，校验下载至本项目机器缓存。'
  display_line '0;34' '   仅版本达标且功能健康才复用；业务库只列更新待单独回归，不改源码依赖锁或全局环境。'
  display_line '0;34' '4、不安装系统服务、不改全局网络、PATH或电源；公网联调仅用合成数据。'
  jobs_prompt_output display_line '0;34' '5、↑/↓选择、回车确认，Esc／空选取消；模式和公开范围确认后自动停止同项目旧实例，再启动新版。'
  display_line '0;34' '6、启动后显示前台和管理后台Web网页URL与离线二维码，fzf可打开公网／本机地址或扫码页面；Ctrl+C停止本次服务，保留数据。'
  jobs_prompt_output display_line '0;34' '   网页菜单Esc仅收起，服务继续；回到终端按回车再次选择。'
  display_line '1;31' '关闭此运行终端，服务将结束'
  display_line '0;34' "日志：$LOG_FILE（正常确认后才创建）；--check／--plan不写日志。"
  if [ "$CHECK_MODE" = 1 ] || [ "$PLAN_MODE" = 1 ]; then return 0; fi
  [ -t 0 ] && [ -t 1 ] || { printf '%s\n' '没有交互终端；正常部署必须在终端使用fzf。只读审阅用--check或--plan。' >&2; exit 1; }
  local confirmation
  jobs_prompt_output printf '%s' '已了解本地写入与访问影响，按回车继续；其它输入取消：'
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
  printf '%s\n' '模式：本地部署＋内网穿透（公开合成演示，回车确认，无需邮箱或确认词）；服务器部署（无隧道）。'
  printf '计划选择：%s\n' "${PLAN_TARGET:-由正常运行fzf选择}"
  printf '%s\n' '正常流程：确认→引导fzf并选择模式→引导Go编译解析器→查询官方稳定工具并择新→业务库只检查更新→readonly构建新二进制→本机health→必要隧道→fzf选地址打开浏览器并持续监控→退出清理。'
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
  local runtime_parent="$RUNTIME_ROOT" project_id
  while [ ! -e "$runtime_parent" ]; do
    if [ -z "$MISSING_RUNTIME_PARENTS" ]; then MISSING_RUNTIME_PARENTS="$runtime_parent"; else MISSING_RUNTIME_PARENTS="$MISSING_RUNTIME_PARENTS
$runtime_parent"; fi
    runtime_parent="$(dirname "$runtime_parent")"
  done
  [ ! -e "$RUNTIME_ROOT" ] || RUNTIME_EXISTED=existing
  mkdir -p "$RUNTIME_ROOT" || fail '无法创建项目运行目录。'
  RUN_DIR="$(mktemp -d "$RUNTIME_ROOT/deploy-session.XXXXXXXX")" || fail '无法原子创建本次运行目录。'
  (set -C; : > "$LOG_FILE") 2>/dev/null || { printf '%s\n' '无法独占创建部署日志；已有同名文件时不会覆盖或跟随软链接。' >&2; exit 1; }
  project_id="$(printf '%s' "$PROJECT_DIR" | cksum | awk '{print $1}')"
  PROJECT_ENV_DIR="$ENV_ROOT/Projects/RepairWorkbench/$project_id"
  DEPLOY_STATE_DIR="$RUNTIME_ROOT/deploy-state"
  DEPLOY_OPERATION_LOCK="$RUNTIME_ROOT/.deployment-operation.lock"
  DEPLOY_OWNER_PID="$$"
  trap 'exit 129' HUP
  trap 'exit 130' INT
  trap 'exit 143' TERM
}
# 仅终止本次启动并仍属于本次作业的后端与隧道进程。
cleanup() {
  [ "${ZSH_SUBSHELL:-0}" = 0 ] && [ "${BASH_SUBSHELL:-0}" = 0 ] || return 0
  [ "$CLEANUP_RUNNING" = 0 ] || return 0
  CLEANUP_RUNNING=1
  trap '' HUP INT TERM
  cleanup_dependency_commands
  local role child started command
  if [ "$DEPLOY_LOCK_HELD" = 1 ] && [ -f "$DEPLOY_STATE_DIR/processes.tsv" ]; then
    while IFS=$'\t' read -r role child started command; do
      case "$role" in backend|tunnel|menu|guardian) deploy_state_stop_identity "$child" "$started" "$command" || true;; esac
    done < "$DEPLOY_STATE_DIR/processes.tsv"
  fi
  BROWSER_MENU_PID=""; API_PID=""; TUNNEL_PID=""
  expire_access_qr
  deploy_state_finish
  deploy_state_release_handoff
}
# zsh的函数内EXIT陷阱会随函数返回触发；全局定义才能覆盖整次会话。
TRAPEXIT() {
  [ "${ZSH_SUBSHELL:-0}" = 0 ] || return 0
  if [ -n "$RUN_DIR" ]; then cleanup; fi
}
# 计算SHA256，不引入额外语言运行时。
hash_file() {
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}';
  elif command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}';
  else fail '缺少系统SHA256工具，不能跳过下载校验。'; fi
}
# 官方归档逐次有界获取；网络故障持续重试，摘要/权限/来源错误直接停止。
download_verified() {
  local source_url="$1" target_file="$2" expected="$3" actual code http_code delay=1 transfer_log="$2.transfer.log"
  case "$source_url" in https://*) ;; *) fail '官方来源必须为HTTPS。';; esac
  log_message '0;34' "来源｜$source_url"
  log_message '0;34' "目标｜$target_file"
  while :; do
    if [ -f "$target_file.part" ] && [ "$(hash_file "$target_file.part")" = "$expected" ]; then mv "$target_file.part" "$target_file" || fail '无法保存校验后的归档。'; return 0; fi
    code=0; http_code=''
    if command -v curl >/dev/null 2>&1; then
      run_dependency_command "$target_file.http" curl --fail --location --show-error --connect-timeout 10 --max-time 240 --continue-at - --write-out '%{http_code}' --output "$target_file.part" "$source_url" || code=$?
      http_code="$(cat "$target_file.http" 2>/dev/null)"
      [ "$code" -lt 128 ] || exit "$code"
      if [ "$code" != 0 ]; then
        case "$code:$http_code" in
          33:*|*:416) : > "$target_file.part";;
          6:*|7:*|18:*|28:*|35:*|52:*|55:*|56:*|*:408|*:429|*:5[0-9][0-9]) ;;
          *) fail "下载被拒绝或本机条件不满足（curl=$code，HTTP=$http_code）；不使用部分文件。";;
        esac
      fi
    elif command -v wget >/dev/null 2>&1; then
      run_dependency_command "$transfer_log" wget --server-response --continue --timeout=30 --tries=1 -O "$target_file.part" "$source_url" || code=$?
      [ "$code" -lt 128 ] || exit "$code"
      cat "$transfer_log" >> "$LOG_FILE"
      http_code="$(awk '/HTTP\/[0-9.]+ [0-9][0-9][0-9]/{value=$2} END{print value}' "$transfer_log")"
      if [ "$code" != 0 ]; then
        case "$code:$http_code" in
          4:*|*:408|*:429|*:5[0-9][0-9]) ;;
          *) fail "下载被拒绝或本机条件不满足（wget=$code，HTTP=$http_code）；不使用部分文件。";;
        esac
      fi
    else fail '系统缺少curl/wget；请按本系统文档准备基础下载命令。'; fi
    if [ "$code" = 0 ]; then
      actual="$(hash_file "$target_file.part")"
      [ "$actual" = "$expected" ] || fail "SHA256不匹配，停止使用下载文件：$target_file.part"
      mv "$target_file.part" "$target_file" || fail '无法保存已校验归档。'
      return 0
    fi
    dependency_retry_wait "$delay" "官方归档暂未获取完成"
    [ "$delay" -ge 15 ] || delay=$((delay * 2)); [ "$delay" -le 15 ] || delay=15
  done
}
# 只为缺失工具读取本仓锁定清单并安装到机器环境缓存。
install_cached_tool() {
  local tool="$1" row="${2:-}" version filename expected source_url kind cache archive staging candidate tool_directory version_directory download_directory
  [ -n "$row" ] || row="$(awk -F '\t' -v t="$tool" -v o="$PLATFORM_OS" -v a="$PLATFORM_ARCH" '$1==t&&$2==o&&$3==a{print;exit}' "$PROJECT_DIR/部署/deploy-tools.lock.tsv")"
  [ -n "$row" ] || fail "缺少${tool}的$PLATFORM_OS/${PLATFORM_ARCH}官方锁定包。"
  version="$(printf '%s\n' "$row" | cut -f4)"; filename="$(printf '%s\n' "$row" | cut -f5)"
  expected="$(printf '%s\n' "$row" | cut -f6)"; source_url="$(printf '%s\n' "$row" | cut -f7)"; kind="$(printf '%s\n' "$row" | cut -f8)"
  case "$tool" in go) tool_directory=Go; version_directory="go$version";; fzf) tool_directory=Fzf; version_directory="$version";; cloudflared) tool_directory=Cloudflared; version_directory="$version";; esac
  cache="$PROJECT_ENV_DIR/Tools/$tool_directory/$version_directory/$PLATFORM_LABEL-$PLATFORM_ARCH"
  [ ! -L "$ENV_ROOT" ] && [ ! -L "$PROJECT_ENV_DIR/Tools/$tool_directory" ] && [ ! -L "$PROJECT_ENV_DIR/Tools/$tool_directory/$version_directory" ] && [ ! -L "$cache" ] || fail '工具缓存目录是软链接，拒绝跟随到项目外。'
  [ ! -L "$cache/go" ] && [ ! -L "$cache/go/bin" ] && [ ! -L "$cache/$tool" ] || fail '工具缓存内部存在软链接，需先人工核对。'
  if [ "$tool" = go ]; then candidate="$cache/go/bin/go"; else candidate="$cache/$tool"; fi
  if tool_healthy "$tool" "$candidate"; then
    if [ -z "${DEPENDENCY_RESOLVER:-}" ] || tool_meets_version "$tool" "$candidate" "$version"; then TOOL_RESULT="$candidate"; return 0; fi
  fi
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
  if [ -n "${DEPENDENCY_RESOLVER:-}" ]; then tool_meets_version "$tool" "$candidate" "$version" || fail "安装后${tool}版本不达标。"; fi
  printf '%s\n' "$expected" > "$staging/artifact.sha256"
  hash_file "$candidate" > "$staging/executable.sha256"
  if [ -e "$cache" ]; then mv "$cache" "$RUN_DIR/tool-before-$tool" || fail '无法保留原损坏工具缓存。'; fi
  mv "$staging" "$cache" || fail '工具缓存安装失败。'
  if [ "$tool" = go ]; then TOOL_RESULT="$cache/go/bin/go"; else TOOL_RESULT="$cache/$tool"; fi
  log_message '0;34' "已准备｜$tool $version｜来源 $source_url"
}
# 仅按本轮PID、启动时间与命令快照回收下载/检查子树。
stop_dependency_tree() {
  local pid="$1" identity="$2" child child_identity
  [ "$pid" != "$$" ] || return 0
  [ -n "$identity" ] && [ "$(LC_ALL=C ps -p "$pid" -o lstart= -o command= 2>/dev/null)" = "$identity" ] || return 0
  for child in $(LC_ALL=C ps -axo pid=,ppid= | awk -v parent="$pid" '$2==parent{print $1}'); do
    [ "$(LC_ALL=C ps -p "$pid" -o lstart= -o command= 2>/dev/null)" = "$identity" ] || return 0
    [ "$(LC_ALL=C ps -p "$child" -o ppid= 2>/dev/null | tr -d ' ')" = "$pid" ] || continue
    child_identity="$(LC_ALL=C ps -p "$child" -o lstart= -o command= 2>/dev/null)"
    stop_dependency_tree "$child" "$child_identity"
  done
  [ "$(LC_ALL=C ps -p "$pid" -o lstart= -o command= 2>/dev/null)" = "$identity" ] || return 0
  kill -TERM "$pid" 2>/dev/null || true
  sleep .1
  if [ "$(LC_ALL=C ps -p "$pid" -o lstart= -o command= 2>/dev/null)" = "$identity" ]; then kill -KILL "$pid" 2>/dev/null || true; fi
}
# 工作进程先登记再启动命令，父入口异常退出时独立收回本轮子树。
dependency_command_worker() {
  local owner="$1" owner_identity="$2" output="$3" worker child='' child_started='' result=0
  shift 3
  if [ -n "${ZSH_VERSION:-}" ]; then zmodload zsh/system || return 1; worker="${sysparams[pid]}";
  elif [ -n "${BASHPID:-}" ]; then worker="$BASHPID";
  else worker="$(exec /bin/sh -c 'printf "%s" "$PPID"')"; fi
  [ -n "$worker" ] && [ "$worker" != "$owner" ] || return 2
  [ ! -L "$RUN_DIR/dependency-workers.tsv" ] || return 1
  printf '%s\t%s\n' "$worker" "$(LC_ALL=C ps -p "$worker" -o lstart= -o command= 2>/dev/null)" >> "$RUN_DIR/dependency-workers.tsv" || return 1
  DEPENDENCY_WORKER_PID="$worker"; DEPENDENCY_WORKER_CHILD=''; DEPENDENCY_WORKER_STARTED=''
  dependency_worker_finish() {
    trap - EXIT
    trap '' HUP INT TERM
    local identity
    local owned="${DEPENDENCY_WORKER_CHILD:-}"
    if [ -n "$owned" ] && [ "$(LC_ALL=C ps -p "$owned" -o ppid= 2>/dev/null | tr -d ' ')" = "$DEPENDENCY_WORKER_PID" ] && [ "$(LC_ALL=C ps -p "$owned" -o lstart= 2>/dev/null)" = "$DEPENDENCY_WORKER_STARTED" ]; then
      identity="$(LC_ALL=C ps -p "$owned" -o lstart= -o command= 2>/dev/null)"
      stop_dependency_tree "$owned" "$identity"
    fi
    [ -z "$owned" ] || wait "$owned" 2>/dev/null || true
  }
  trap 'dependency_worker_finish' EXIT
  trap 'exit 129' HUP
  trap 'exit 130' INT
  trap 'exit 143' TERM
  "$@" > "$output" 2>> "$LOG_FILE" &
  child=$!
  child_started="$(LC_ALL=C ps -p "$child" -o lstart= 2>/dev/null)"
  DEPENDENCY_WORKER_CHILD="$child"; DEPENDENCY_WORKER_STARTED="$child_started"
  while kill -0 "$child" 2>/dev/null; do
    [ "$(LC_ALL=C ps -p "$owner" -o lstart= -o command= 2>/dev/null)" = "$owner_identity" ] || return 129
    sleep .2
  done
  if wait "$child"; then result=0; else result=$?; fi
  child=''; DEPENDENCY_WORKER_CHILD=''
  return "$result"
}
# 前台仅等待本轮监督子进程，退出清理可即时中断其实际命令。
run_dependency_command() {
  local output="$1" owner_identity worker result
  shift
  owner_identity="$(LC_ALL=C ps -p "$$" -o lstart= -o command= 2>/dev/null)"
  dependency_command_worker "$$" "$owner_identity" "$output" "$@" &
  worker=$!
  if wait "$worker"; then return 0; else result=$?; return "$result"; fi
}
# 下载/查询产物封存前，先停止本轮仍存活的短作业。
cleanup_dependency_commands() {
  local pid identity
  [ -n "${RUN_DIR:-}" ] && [ -f "$RUN_DIR/dependency-workers.tsv" ] && [ ! -L "$RUN_DIR/dependency-workers.tsv" ] || return 0
  while IFS=$'\t' read -r pid identity; do
    case "$pid" in ''|*[!0-9]*) continue;; esac
    stop_dependency_tree "$pid" "$identity"
  done < "$RUN_DIR/dependency-workers.tsv"
}
# 只给可重试的网络获取等待退避，校验与参数错误直接停止。
dependency_retry_wait() {
  local seconds="$1" reason="$2"
  log_message '1;33' "$reason；${seconds}秒后继续获取，Ctrl+C可取消。"
  run_dependency_command "$RUN_DIR/dependency-wait.out" sleep "$seconds" || exit "$?"
}
# 用本轮私有副本查询和构建，源工程的模块锁始终不写入。
prepare_module_copy() {
  local source="$1" name="$2" directory="$RUN_DIR/module-manifests/$2"
  [ -f "$source/go.mod" ] || fail "缺少模块清单：$source/go.mod"
  mkdir -p "$directory" || fail '无法创建本轮模块清单目录。'
  cp "$source/go.mod" "$directory/module.mod" || fail '无法复制模块清单。'
  if [ -f "$source/go.sum" ]; then cp "$source/go.sum" "$directory/module.sum" || fail '无法复制模块校验锁。'; fi
  MODULE_MODFILE="$directory/module.mod"
}
# 解析器只依赖标准库，由菜单引导阶段已准备的健康Go构建。
prepare_dependency_resolver() {
  local source="$PROJECT_DIR/部署/公共组件/依赖版本"
  prepare_module_copy "$source" resolver
  DEPENDENCY_RESOLVER="$RUN_DIR/dependency-versions"
  log_message '0;34' '依赖检查｜准备本轮官方稳定版本解析器；不会修改源码或全局工具。'
  (cd "$source" && GOROOT= GOWORK=off GOTOOLCHAIN=local GOTELEMETRY=off run_dependency_command "$RUN_DIR/dependency-build.out" "$GO_EXECUTABLE" build -mod=readonly -modfile="$MODULE_MODFILE" -o "$DEPENDENCY_RESOLVER" .) >> "$LOG_FILE" 2>&1 || fail '版本解析器构建失败，停止部署。'
}
# 读取实际稳定版号，拒绝把开发版或预发布输出当作稳定工具。
tool_version() {
  local tool="$1" candidate="$2" info
  case "$tool" in
    go) info="$(GOROOT= GOTOOLCHAIN=local "$candidate" version 2>/dev/null)" || return 1; printf '%s\n' "$info" | sed -nE 's/^go version go([0-9]+\.[0-9]+(\.[0-9]+)?)([[:space:]].*)?$/\1/p';;
    fzf) info="$(FZF_DEFAULT_OPTS='' FZF_DEFAULT_OPTS_FILE=/dev/null FZF_DEFAULT_COMMAND='' "$candidate" --version 2>/dev/null)" || return 1; printf '%s\n' "$info" | sed -nE 's/^([0-9]+\.[0-9]+(\.[0-9]+)?)([[:space:]].*)?$/\1/p';;
    cloudflared) info="$("$candidate" --version 2>/dev/null)" || return 1; printf '%s\n' "$info" | sed -nE 's/^cloudflared version ([0-9]+\.[0-9]+(\.[0-9]+)?)([[:space:]].*)?$/\1/p';;
    *) return 1;;
  esac
}
# 比较器用退出码区分旧版本与非法输入，不把旧版当解析器故障。
tool_at_least() {
  local installed="$1" target="$2" result code
  if result="$("$DEPENDENCY_RESOLVER" --compare "$installed" --at-least "$target" 2>> "$LOG_FILE")"; then
    [ "$result" = 1 ] || fail '版本比较器返回异常。'
    return 0
  else
    code=$?
    if [ "$code" = 1 ] && [ "$result" = 0 ]; then return 1; fi
    fail '无法可靠比较工具版本，停止部署。'
  fi
}
# 只有当前功能与实际稳定版本同时达标，候选工具才可复用。
tool_meets_version() {
  local tool="$1" candidate="$2" target="$3" version
  tool_healthy "$tool" "$candidate" || return 1
  case "$candidate" in "$PROJECT_ENV_DIR"/Tools/*)
    local cache_root="${candidate%/*}"
    [ "$tool" != go ] || cache_root="${candidate%/go/bin/go}"
    [ -f "$cache_root/executable.sha256" ] && [ "$(cat "$cache_root/executable.sha256")" = "$(hash_file "$candidate")" ] || return 1;;
  esac
  version="$(tool_version "$tool" "$candidate")" || return 1
  [ -n "$version" ] && tool_at_least "$version" "$target"
}
# 每次正常部署重新查官方稳定发行版，只有临时网络失败持续重试。
resolve_latest_asset() {
  local tool="$1" row code delay=1 expected_url
  local -a arguments
  arguments=(--tool "$tool" --os "$PLATFORM_OS" --arch "$PLATFORM_ARCH" --locked-manifest "$PROJECT_DIR/部署/deploy-tools.lock.tsv")
  [ "$tool" != go ] || arguments+=(--minimum-go 1.24.0)
  while :; do
    if run_dependency_command "$RUN_DIR/dependency-latest-$tool.tsv" "$DEPENDENCY_RESOLVER" "${arguments[@]}"; then row="$(cat "$RUN_DIR/dependency-latest-$tool.tsv")"; break; else code=$?; fi
    [ "$code" -lt 128 ] || exit "$code"
    [ "$code" = 75 ] || fail "官方${tool}版本或摘要无法确认，停止部署；详见日志。"
    dependency_retry_wait "$delay" "官方${tool}版本查询暂未完成"
    [ "$delay" -ge 15 ] || delay=$((delay * 2)); [ "$delay" -le 15 ] || delay=15
  done
  [ "$(printf '%s\n' "$row" | awk -F '\t' 'NF==8{n++} END{print n+0}')" = 1 ] && [ "$(printf '%s\n' "$row" | wc -l | tr -d ' ')" = 1 ] || fail '官方版本解析行格式不完整。'
  IFS=$'\t' read -r RESOLVED_TOOL RESOLVED_OS RESOLVED_ARCH RESOLVED_VERSION RESOLVED_FILENAME RESOLVED_SHA RESOLVED_URL RESOLVED_KIND <<RESOLVED_ASSET
$row
RESOLVED_ASSET
  [ "$RESOLVED_TOOL/$RESOLVED_OS/$RESOLVED_ARCH" = "$tool/$PLATFORM_OS/$PLATFORM_ARCH" ] || fail '官方版本平台或架构与本机不符。'
  printf '%s\n' "$RESOLVED_VERSION" | grep -Eq '^[0-9]+\.[0-9]+(\.[0-9]+)?$' || fail '官方版本不是稳定数字版本。'
  if [ "$RESOLVED_KIND" = unsupported ]; then
    [ "$RESOLVED_FILENAME/$RESOLVED_SHA/$RESOLVED_URL" = '-/-/-' ] || fail '不支持的平台资产返回格式异常。'
  else
    case "$RESOLVED_KIND" in tar.gz|tgz|binary) ;; *) fail '官方资产归档类型与本Shell平台不符。';; esac
    printf '%s\n' "$RESOLVED_SHA" | grep -Eq '^[a-fA-F0-9]{64}$' || fail '官方资产缺少可信SHA256。'
    case "$RESOLVED_FILENAME" in ''|*/*|*\\*|*:*|.|..) fail '官方资产文件名无效。';; esac
    case "$tool" in go) expected_url="https://go.dev/dl/$RESOLVED_FILENAME";; fzf) expected_url="https://github.com/junegunn/fzf/releases/download/v$RESOLVED_VERSION/$RESOLVED_FILENAME";; cloudflared) expected_url="https://github.com/cloudflare/cloudflared/releases/download/$RESOLVED_VERSION/$RESOLVED_FILENAME";; esac
    [ "$RESOLVED_URL" = "$expected_url" ] || fail '官方资产来源与稳定版本不匹配。'
  fi
  RESOLVED_ROW="$row"
}
# 从显式、PATH与所有版本缓存择新；不覆盖显式文件或系统公共工具。
resolve_latest_tool() {
  local tool="$1" explicit='' initial='' candidate version current_version best='' best_version='' directory relative target row kind
  resolve_latest_asset "$tool"
  target="$RESOLVED_VERSION"; row="$RESOLVED_ROW"; kind="$RESOLVED_KIND"
  case "$tool" in
    go) explicit="${GO_BIN:-}"; initial="${GO_EXECUTABLE:-}"; directory=Go; relative=go/bin/go;;
    fzf) explicit="${WB_FZF_BIN:-}"; initial="${FZF_EXECUTABLE:-}"; directory=Fzf; relative=fzf;;
    cloudflared) explicit="${WB_CLOUDFLARED_BIN:-}"; initial="${CLOUDFLARED_EXECUTABLE:-}"; directory=Cloudflared; relative=cloudflared;;
  esac
  [ -n "$initial" ] || initial="$(command -v "$tool" 2>/dev/null || true)"
  current_version="$(tool_version "$tool" "$initial" 2>/dev/null || true)"
  log_message '0;34' "工具版本｜$tool｜当前 ${current_version:-未安装或不可识别}｜官方稳定目标 $target"
  if [ -n "$explicit" ]; then
    case "$explicit" in /*) ;; *) explicit="$PROJECT_DIR/$explicit";; esac
    tool_meets_version "$tool" "$explicit" "$target" || fail "显式${tool}未达到官方稳定目标$target或功能不兼容；请更新显式配置，原文件保留。"
    best="$explicit"
  else
    [ "$kind" != unsupported ] || fail "官方${tool} $target未提供$PLATFORM_OS/$PLATFORM_ARCH成品；仅可显式指定匹配的原生新版工具。"
    for candidate in "$initial" "$(command -v "$tool" 2>/dev/null || true)" "$ENV_ROOT/$directory"/*/"$PLATFORM_LABEL-$PLATFORM_ARCH/$relative" "$PROJECT_ENV_DIR/Tools/$directory"/*/"$PLATFORM_LABEL-$PLATFORM_ARCH/$relative"; do
      tool_meets_version "$tool" "$candidate" "$target" || continue
      version="$(tool_version "$tool" "$candidate")"
      if [ -z "$best" ] || tool_at_least "$version" "$best_version"; then best="$candidate"; best_version="$version"; fi
    done
    if [ -z "$best" ]; then install_cached_tool "$tool" "$row"; best="$TOOL_RESULT"; fi
    tool_meets_version "$tool" "$best" "$target" || fail "${tool}采用版本复检未达到官方目标，停止部署。"
  fi
  version="$(tool_version "$tool" "$best")"
  log_message '0;34' "采用工具｜$tool $version｜$best"
  case "$tool" in go) GO_EXECUTABLE="$best";; fzf) FZF_EXECUTABLE="$best";; cloudflared) CLOUDFLARED_EXECUTABLE="$best";; esac
}
# 菜单引导完成后，最终构建与运行统一采用重新核验的稳定版本。
prepare_latest_tools() {
  resolve_latest_tool go
  resolve_latest_tool fzf
  if [ "$DEPLOY_MODE" = local ]; then resolve_latest_tool cloudflared; fi
}
# 仅报告当前模块路径可更新版本，不升级业务库或发现换路径的新主版本。
check_module_updates() {
  local name="$1" source="$2" code output="$RUN_DIR/module-updates-$1.txt" seconds="${WB_DEPENDENCY_CHECK_TIMEOUT_SECONDS:-30}"
  case "$seconds" in ''|*[!0-9]*) fail 'WB_DEPENDENCY_CHECK_TIMEOUT_SECONDS须为1..300秒。';; esac
  [ "$seconds" -ge 1 ] && [ "$seconds" -le 300 ] || fail '业务依赖检查超时须为1..300秒。'
  prepare_module_copy "$source" "$name-check"
  log_message '0;34' "业务依赖检查｜$name｜最多${seconds}秒，仅检查当前模块路径；源码依赖锁保持不变。"
  if (configure_go_module_source && GOROOT= run_dependency_command "$output" "$DEPENDENCY_RESOLVER" --module-report --go-bin "$GO_EXECUTABLE" --module-dir "$source" --modfile "$MODULE_MODFILE" --timeout-seconds "$seconds"); then
    if [ -s "$output" ]; then
      log_message '1;33' "业务库可更新｜$name｜需单独升级与回归："
      awk -F '\t' 'NF==3{printf "%s %s -> %s\n",$1,$2,$3}' "$output" | tee -a "$LOG_FILE"
    else log_message '0;34' "业务依赖检查完成｜$name当前模块路径未报告更新；未检查换路径的新主版本。"; fi
  else
    code=$?
    [ "$code" = 3 ] || fail "业务依赖检查的参数、路径或源码锁校验失败（$name，退出码$code）；停止核对。" "$code"
    log_message '1;33' "业务依赖检查未完成或超时｜$name｜按现有锁构建，不视为已确认最新；详见日志。"
  fi
}
# 后端和二维码各自独立检查，客户端工具链不在本部署中暗中升级。
check_business_dependencies() {
  check_module_updates backend "$PROJECT_DIR/代码/后端/后端代码"
  check_module_updates qr "$PROJECT_DIR/部署/公共组件/地址二维码"
}

# 对实际调用的工具执行最小版本和必要参数健康检查。
tool_healthy() {
  local tool="$1" candidate="$2" info minor
  [ -n "$candidate" ] && [ -x "$candidate" ] || return 1
  case "$tool" in
    go) info="$(GOROOT= GOTOOLCHAIN=local GOTELEMETRY=off "$candidate" version 2>/dev/null)" || return 1; minor="$(printf '%s\n' "$info" | sed -n 's/.*go1\.\([0-9][0-9]*\).*/\1/p')"; [ -n "$minor" ] && [ "$minor" -ge 24 ];;
    fzf) FZF_DEFAULT_OPTS='' FZF_DEFAULT_OPTS_FILE=/dev/null FZF_DEFAULT_COMMAND='' "$candidate" --version >/dev/null 2>&1 && FZF_DEFAULT_OPTS='' FZF_DEFAULT_OPTS_FILE=/dev/null FZF_DEFAULT_COMMAND='' "$candidate" --help 2>/dev/null | grep -- '--expect' >/dev/null;;
    cloudflared)
      "$candidate" --version >/dev/null 2>&1 || return 1
      info="$("$candidate" tunnel --help 2>/dev/null)" || return 1
      printf '%s\n' "$info" | grep -- '--url' >/dev/null && printf '%s\n' "$info" | grep -- '--config' >/dev/null && printf '%s\n' "$info" | grep -- '--no-autoupdate' >/dev/null;;
    *) return 1;;
  esac
}
# 选择模式前只读复用健康fzf；缺失时放本次会话，不改旧部署清单。
prepare_fzf() {
  local candidate="${WB_FZF_BIN:-$(command -v fzf 2>/dev/null || true)}" previous_env="$PROJECT_ENV_DIR" project_id
  if tool_healthy fzf "$candidate"; then FZF_EXECUTABLE="$candidate"; return 0; fi
  project_id="$(printf '%s' "$PROJECT_DIR" | cksum | awk '{print $1}')"
  for candidate in "$ENV_ROOT/Projects/RepairWorkbench/$project_id"/Tools/Fzf/*/"$PLATFORM_LABEL-$PLATFORM_ARCH"/fzf; do
    if tool_healthy fzf "$candidate"; then FZF_EXECUTABLE="$candidate"; return 0; fi
  done
  PROJECT_ENV_DIR="$RUN_DIR/bootstrap-environment"
  install_cached_tool fzf
  FZF_EXECUTABLE="$TOOL_RESULT"
  PROJECT_ENV_DIR="$previous_env"
}
# 用fzf选择两种部署模式，取消和空选不会停止旧实例或启动业务。
select_deploy_mode() {
  local selected code
  selected="$(printf '%s\n' $'local\t本地部署＋内网穿透' $'server\t服务器部署' | FZF_DEFAULT_OPTS='' FZF_DEFAULT_OPTS_FILE=/dev/null FZF_DEFAULT_COMMAND='' "$FZF_EXECUTABLE" --no-multi --delimiter='\t' --with-nth=2 --height=40% --border --bind='up:up,down:down' --prompt='部署模式 > ' --header='↑/↓选择、回车确认；Esc取消。本地模式生成前台和管理后台网页的公网演示链接。')"
  code=$?
  case "$code" in
    0) ;;
    1|130) log_message '0;34' '已取消，没有构建或启动业务。'; exit 0;;
    *) fail "fzf选择器异常退出：$code。" "$code";;
  esac
  [ -n "$selected" ] || { log_message '0;34' '已取消，没有构建或启动业务。'; exit 0; }
  case "$selected" in
    $'server\t服务器部署') DEPLOY_MODE=server;;
    $'local\t本地部署＋内网穿透') DEPLOY_MODE=local;;
    *) fail '选择结果异常。';;
  esac
}
# 本地模式只需回车确认公开范围，取消时保留原运行实例。
configure_tunnel_access() {
  [ "$DEPLOY_MODE" = local ] || return 0
  log_message '1;31' '关闭此运行终端，服务将结束'
  log_message '0;34' '将公开前台和管理后台的演示入口：任何取得链接的人均可访问；只使用合成数据。'
  local confirmation
  jobs_prompt_output printf '%s' '已了解公开演示范围，按回车继续；其它输入取消：'
  IFS= read -r confirmation || exit 0
  [ -z "$confirmation" ] || exit 0
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
# 为本地模式复用健康cloudflared，缺失时校验安装锁定版本。
prepare_tunnel_tool() {
  [ "$DEPLOY_MODE" = local ] || return 0
  local candidate="${WB_CLOUDFLARED_BIN:-$(command -v cloudflared 2>/dev/null || true)}"
  if tool_healthy cloudflared "$candidate"; then
    CLOUDFLARED_EXECUTABLE="$candidate"
    return 0
  fi
  install_cached_tool cloudflared; CLOUDFLARED_EXECUTABLE="$TOOL_RESULT"
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
# 只为未配置下载源的构建子进程设置回退，不覆盖用户或私库策略。
configure_go_module_source() {
  local effective_proxy go_env_file
  effective_proxy="$("$GO_EXECUTABLE" env GOPROXY)" || fail '无法读取Go模块下载源。'
  go_env_file="$("$GO_EXECUTABLE" env GOENV)" || fail '无法读取Go环境配置位置。'
  if [ "${GOPROXY+x}" = x ]; then
    log_message '0;34' '依赖来源｜沿用进程显式GOPROXY（含空值／off），不追加公共镜像。'
  elif [ "$go_env_file" != off ] && [ -f "$go_env_file" ] && grep -q '^GOPROXY=' "$go_env_file"; then
    log_message '0;34' '依赖来源｜沿用Go用户配置GOPROXY，不追加公共镜像。'
  elif [ "$effective_proxy" = 'https://proxy.golang.org,direct' ]; then
    export GOPROXY='https://goproxy.cn|https://proxy.golang.org|direct'
    log_message '0;34' '依赖来源｜https://goproxy.cn → https://proxy.golang.org → 模块源码仓库；网络错误自动回退。'
  else
    log_message '0;34' '依赖来源｜沿用Go现有下载策略，不追加公共镜像。'
  fi
  log_message '0;34' "依赖缓存｜$GOMODCACHE；下载源仅本次构建生效，退出即撤回，不执行go env -w，不修改校验策略。"
}
# 子进程隔离下载源；只用新构建成功的二进制启动，不回退执行旧产物。
build_workbench() {
  (
    local pending="$RUN_DIR/workbench.new" result
    set -o pipefail
    cd "$PROJECT_DIR/代码/后端/后端代码" || fail '源码目录不可进入。'
    prepare_module_copy "$PROJECT_DIR/代码/后端/后端代码" backend-build
    configure_go_module_source
    log_message '0;34' "构建｜$GO_EXECUTABLE｜代码/后端/后端代码"
    GOROOT= GOWORK=off "$GO_EXECUTABLE" build -mod=readonly -o "$pending" -modfile="$MODULE_MODFILE" ./cmd/workbench 2>&1 | tee -a "$LOG_FILE"
    result=$?
    [ "$result" = 0 ] || fail "构建失败，不启动旧程序。日志：$LOG_FILE" "$result"
    [ -x "$pending" ] || fail '构建没有生成新的可执行文件，不启动旧程序。'
    mv "$pending" "$WORKBENCH_BINARY" || fail '无法替换本项目构建产物。'
  )
  local result=$?
  [ "$result" = 0 ] || exit "$result"
  deploy_state_seal "$WORKBENCH_BINARY" || fail '无法封存新构建程序指纹。'
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
# 监督子Shell先登记，再允许实际服务启动，父Shell强退也保留回收入口。
run_session_child() {
  local role="$1" child result=0
  shift
  zmodload zsh/system || return 1
  SESSION_CHILD_PID="${sysparams[pid]}"
  session_child_finish() {
    trap '' HUP INT TERM
    local candidate started command parent
    for candidate in $(/usr/bin/pgrep -P "$SESSION_CHILD_PID" 2>/dev/null); do
      started="$(LC_ALL=C ps -p "$candidate" -o lstart= 2>/dev/null | sed 's/^ *//')"
      command="$(LC_ALL=C ps -p "$candidate" -o command= 2>/dev/null)"
      parent="$(LC_ALL=C ps -p "$candidate" -o ppid= 2>/dev/null | tr -d ' ')"
      [ "$parent" != "$SESSION_CHILD_PID" ] || deploy_state_stop_identity "$candidate" "$started" "$command" || true
    done
  }
  # 显式exit会展开函数局部变量，归属PID保存在本监督子Shell的独立状态中。
  trap 'session_child_finish' EXIT
  trap 'exit 129' HUP
  trap 'exit 130' INT
  trap 'exit 143' TERM
  deploy_state_process "$role" "$SESSION_CHILD_PID"
  printf '%s\n' "$SESSION_CHILD_PID" > "$RUN_DIR/child-ready-$role" || return 1
  "$@" &
  child=$!
  wait "$child"; result=$?
  return "$result"
}
# 屏障仅核对本轮监督进程，不复用上一菜单的登记。
wait_session_child_ready() {
  local role="$1" pid="$2" count=0
  while [ "$(cat "$RUN_DIR/child-ready-$role" 2>/dev/null)" != "$pid" ]; do
    kill -0 "$pid" 2>/dev/null || fail "本次$role监督进程提前退出。"
    [ "$count" -lt 100 ] || fail "本次$role监督登记超时。"
    sleep 0.02; count=$((count + 1))
  done
}
# 在本地健康检查通过后才允许启动穿透，失败不复用其它已有服务。
start_and_check_backend() {
  command -v curl >/dev/null 2>&1 || fail '健康检查需要系统curl；不能只凭进程存在判定服务成功。'
  assert_port_available
  run_session_child backend "$WORKBENCH_BINARY" >> "$LOG_FILE" 2>&1 &
  API_PID=$!
  wait_session_child_ready backend "$API_PID"
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
# 仅本地模式连接免费Quick Tunnel，使用本次独立配置。
start_tunnel() {
  [ "$DEPLOY_MODE" = local ] || { log_message '0;34' '服务器模式：没有建立穿透；对外HTTPS由部署方另行配置。'; return 0; }
  printf '{}\n' > "$RUN_DIR/quick-empty.yml" || fail '无法创建本次独立Quick配置；不会改动用户cloudflared配置。'
  run_session_child tunnel run_quick_client tunnel --config "$RUN_DIR/quick-empty.yml" --no-autoupdate --url "http://$WB_ADDR" > "$RUN_DIR/tunnel.log" 2>&1 &
  TUNNEL_PID=$!
  wait_session_child_ready tunnel "$TUNNEL_PID"
  log_message '0;34' '正在建立Quick Tunnel；无账号／域名费用，随机地址、无可用性保证，大陆网络需实测。'
}
# 二维码仅由独立锁定模块在本机生成；辅助功能失败不影响业务启动。
prepare_access_qr() {
  QR_BINARY="$RUN_DIR/qr-access"
  if ! (
    set -o pipefail
    cd "$PROJECT_DIR/部署/公共组件/地址二维码" || exit 1
    prepare_module_copy "$PROJECT_DIR/部署/公共组件/地址二维码" qr-build
    configure_go_module_source
    log_message '0;34' '二维码依赖来源｜github.com/skip2/go-qrcode；版本与校验见部署/公共组件/地址二维码/go.mod、go.sum。'
    GOROOT= GOWORK=off "$GO_EXECUTABLE" build -mod=readonly -o "$QR_BINARY" -modfile="$MODULE_MODFILE" . 2>&1 | tee -a "$LOG_FILE"
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
    jobs_prompt_output printf 'pause\t收起菜单（服务继续运行，回车再选）\n'
  } > "$RUN_DIR/browser-links.tsv" || fail '无法准备网页地址菜单。'
  header=$'回车：交给默认浏览器打开；打开后可继续选择。\n本机地址只供这台电脑访问。'
  if [ -n "$PUBLIC_URL" ]; then
    header+=$'\n公网地址已公开，仅用合成数据。'
  fi
  header+=$'\nEsc收起菜单，服务继续；回车重新打开。Ctrl+C停止服务。'
  FZF_DEFAULT_OPTS='' FZF_DEFAULT_OPTS_FILE=/dev/null FZF_DEFAULT_COMMAND='' \
    run_session_child menu "$FZF_EXECUTABLE" --no-multi --delimiter='\t' --with-nth=2 --height=40% --border \
      --expect=esc,ctrl-c --prompt='打开网页 > ' --header="$header" \
      < "$RUN_DIR/browser-links.tsv" > "$RUN_DIR/browser-selection" &
  BROWSER_MENU_PID=$!
  wait_session_child_ready menu "$BROWSER_MENU_PID"
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
    jobs_prompt_output log_message '0;34' '网页菜单已收起，服务继续运行；回车重新选择，Ctrl+C停止服务。'
    return 0
  fi
  if [ "$result" != 0 ]; then
    BROWSER_MENU_PAUSED=1
    jobs_prompt_output log_message '1;31' "网页选择器退出码$result；服务继续运行，回车重试菜单，Ctrl+C停止。"
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
      jobs_prompt_output log_message '0;34' '网页菜单已收起，服务继续运行；回车重新选择，Ctrl+C停止服务。'
      return 0;;
    *)
      BROWSER_MENU_PAUSED=1
      jobs_prompt_output log_message '1;31' '网页选择结果无效，没有打开网页；服务继续运行，回车重新选择。'
      return 0;;
  esac
  if [ -n "$url" ] && open "$url" 2>> "$LOG_FILE"; then
    log_message '0;34' "已交给默认浏览器打开：$url；可继续选择其它地址。"
  else
    log_message '1;31' "未能打开网页：$url；服务继续运行，可在菜单中重选。"
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
    if [ "$DEPLOY_MODE" = server ] || [ "$shown" = 1 ]; then
      if [ -n "$BROWSER_MENU_PID" ]; then
        if ! kill -0 "$BROWSER_MENU_PID" 2>/dev/null; then handle_browser_menu_result; fi
      elif [ "$BROWSER_MENU_PAUSED" = 1 ]; then
        if [ -t 0 ] && IFS= read -r -t 0.1 resume_menu; then BROWSER_MENU_PAUSED=0; fi
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

# 核对身份和僵尸状态，旧PID被复用时不向新进程发送信号。
deploy_state_same_process() {
  local pid="$1" started="$2" command="$3" current_started current_command state
  case "$pid" in ''|*[!0-9]*) return 1;; esac
  current_started="$(LC_ALL=C ps -p "$pid" -o lstart= 2>/dev/null | sed 's/^ *//')"
  current_command="$(LC_ALL=C ps -p "$pid" -o command= 2>/dev/null)"
  state="$(LC_ALL=C ps -p "$pid" -o stat= 2>/dev/null)"
  case "$state" in *Z*) return 1;; esac
  [ -n "$started" ] && [ -n "$command" ] && [ "$started" = "$current_started" ] && [ "$command" = "$current_command" ]
}
# 每次发信号前重新核对；宽限后仍只处理同一身份。
deploy_state_stop_identity() {
  local pid="$1" started="$2" command="$3" count=0
  deploy_state_same_process "$pid" "$started" "$command" || return 0
  kill -TERM "$pid" 2>/dev/null || return 1
  while deploy_state_same_process "$pid" "$started" "$command" && [ "$count" -lt 50 ]; do sleep 0.1; count=$((count + 1)); done
  if deploy_state_same_process "$pid" "$started" "$command"; then kill -KILL "$pid" 2>/dev/null || return 1; fi
  count=0
  while deploy_state_same_process "$pid" "$started" "$command" && [ "$count" -lt 30 ]; do sleep 0.1; count=$((count + 1)); done
  deploy_state_same_process "$pid" "$started" "$command" && return 1
  wait "$pid" 2>/dev/null || true
  return 0
}
# 交接锁由内核释放；锁文件留在临时目录，不借删锁实现互斥。
deploy_state_acquire_handoff() {
  local key lock_file
  zmodload zsh/system || fail '无法加载系统文件锁，未停止旧实例。'
  key="$(printf '%s' "$RUNTIME_ROOT" | shasum -a 256 | awk '{print $1}')"
  lock_file="${TMPDIR:-/tmp}/repair-deploy-handoff-$UID-$key.lock"
  [ ! -L "$lock_file" ] && { [ ! -e "$lock_file" ] || { [ -f "$lock_file" ] && [ -O "$lock_file" ]; }; } || fail '交接锁归属异常。'
  if [ ! -e "$lock_file" ]; then (set -C; : > "$lock_file") 2>/dev/null || { [ -f "$lock_file" ] && [ ! -L "$lock_file" ] && [ -O "$lock_file" ]; } || fail '无法创建交接锁。'; fi
  zsystem flock -t 30 -f DEPLOY_HANDOFF_FD "$lock_file" || fail '另一轮启动或反部署正在交接，请稍后重试。'
}
deploy_state_release_handoff() {
  if [ -n "$DEPLOY_HANDOFF_FD" ]; then
    zsystem flock -u "$DEPLOY_HANDOFF_FD" 2>/dev/null || true
    DEPLOY_HANDOFF_FD=''
  fi
}
# 只有模式已确认才停旧；旧清单与当前项目必须逐项吻合。
deploy_state_handoff_previous() {
  local owner='' lock_snapshot='' inode='' identity='' role pid started command old_supervisor=''
  [ ! -L "$DEPLOY_OPERATION_LOCK" ] || fail '操作锁是软链接，保留现场。'
  if [ -e "$DEPLOY_OPERATION_LOCK" ]; then
    [ -d "$DEPLOY_OPERATION_LOCK" ] && [ -O "$DEPLOY_OPERATION_LOCK" ] && [ -f "$DEPLOY_OPERATION_LOCK/owner" ] && [ ! -L "$DEPLOY_OPERATION_LOCK/owner" ] || fail '旧操作锁缺少可核验归属，保留现场。'
    owner="$(cat "$DEPLOY_OPERATION_LOCK/owner")"
    case "$owner" in ''|*[!0-9]*) fail '旧操作锁PID无效。';; esac
    inode="$(ls -di "$DEPLOY_OPERATION_LOCK" | awk '{print $1}')"
    if [ -e "$DEPLOY_OPERATION_LOCK/identity.tsv" ]; then
      [ -f "$DEPLOY_OPERATION_LOCK/identity.tsv" ] && [ ! -L "$DEPLOY_OPERATION_LOCK/identity.tsv" ] || fail '操作锁身份文件异常。'
      identity="$(cat "$DEPLOY_OPERATION_LOCK/identity.tsv")"
      case "$identity" in $'deployment\t'*) ;; *) fail '存在反部署事务或未知操作锁，未停止任何进程。';; esac
    fi
    lock_snapshot="$owner|$identity"
  fi
  if [ ! -e "$DEPLOY_STATE_DIR" ]; then
    [ -z "$owner" ] || fail '旧锁没有配套部署清单，不能推测归属。'
    return 0
  fi
  [ -d "$DEPLOY_STATE_DIR" ] && [ ! -L "$DEPLOY_STATE_DIR" ] || fail '旧部署状态目录异常。'
  for role in settings.tsv processes.tsv artifacts.tsv; do
    [ -f "$DEPLOY_STATE_DIR/$role" ] && [ ! -L "$DEPLOY_STATE_DIR/$role" ] && [ -O "$DEPLOY_STATE_DIR/$role" ] || fail '旧部署清单缺失或归属异常。'
  done
  [ "$(deploy_state_value schema)" = 1 ] && [ "$(deploy_state_value project_root)" = "$PROJECT_DIR" ] && [ "$(deploy_state_value runtime_root)" = "$RUNTIME_ROOT" ] && [ "$(deploy_state_value env_root)" = "$ENV_ROOT" ] || fail '旧部署不属于当前项目或配置，保留原实例。'
  [ ! -e "$DEPLOY_STATE_DIR/undeploy-operation.tsv" ] && [ ! -e "$DEPLOY_STATE_DIR/restoring.tsv" ] || fail '存在未完成的反部署／恢复事务，请从反部署入口续跑。'
  cp -p "$DEPLOY_STATE_DIR/processes.tsv" "$RUN_DIR/previous-processes.tsv" || fail '无法保存旧进程交接快照。'
  while IFS=$'\t' read -r role pid started command; do
    case "$role" in supervisor|backend|tunnel|menu|guardian) ;; *) fail '旧进程清单包含未知角色，未停止旧实例。';; esac
    case "$pid" in ''|*[!0-9]*) fail '旧进程清单PID无效。';; esac
    [ -n "$started" ] && [ -n "$command" ] || fail '旧进程身份不完整。'
    if [ "$role" = supervisor ]; then
      old_supervisor="$pid"
      [ -z "$owner" ] || [ "$owner" = "$pid" ] || { [ -z "$identity" ] && [ -z "$(LC_ALL=C ps -p "$owner" -o lstart= 2>/dev/null)" ]; } || fail '操作锁与旧部署入口不一致，保留现场。'
      if [ -n "$identity" ]; then [ "$identity" = "$(printf 'deployment\t%s\t%s\t%s' "$pid" "$started" "$command")" ] || fail '操作锁身份与清单不一致。'; fi
    fi
  done < "$RUN_DIR/previous-processes.tsv"
  [ -z "$owner" ] || [ -n "$old_supervisor" ] || { [ -z "$(LC_ALL=C ps -p "$owner" -o lstart= 2>/dev/null)" ] || fail '旧锁持有者仍在运行且无入口身份，保留现场。'; }
  while IFS=$'\t' read -r role pid started command; do
    [ "$role" != supervisor ] || { deploy_state_stop_identity "$pid" "$started" "$command" || fail '旧部署入口未退出，保留锁与原实例。'; }
  done < "$RUN_DIR/previous-processes.tsv"
  while IFS=$'\t' read -r role pid started command; do
    [ "$role" = supervisor ] || { deploy_state_stop_identity "$pid" "$started" "$command" || fail '旧部署子进程未退出，未开始新部署。'; }
  done < "$RUN_DIR/previous-processes.tsv"
  if [ -n "$owner" ] && [ -d "$DEPLOY_OPERATION_LOCK" ]; then
    [ ! -L "$DEPLOY_OPERATION_LOCK" ] && [ "$inode" = "$(ls -di "$DEPLOY_OPERATION_LOCK" | awk '{print $1}')" ] && [ "$lock_snapshot" = "$(cat "$DEPLOY_OPERATION_LOCK/owner" 2>/dev/null)|$(cat "$DEPLOY_OPERATION_LOCK/identity.tsv" 2>/dev/null)" ] || fail '交接期间锁已变化，保留现场。'
    [ -z "$(find "$DEPLOY_OPERATION_LOCK" -mindepth 1 -maxdepth 1 ! -name owner ! -name identity.tsv -print)" ] || fail '旧锁含未知内容，保留现场。'
    [ ! -e "$DEPLOY_OPERATION_LOCK/identity.tsv" ] || rm -- "$DEPLOY_OPERATION_LOCK/identity.tsv" || fail '无法释放已失效的身份记录。'
    rm -- "$DEPLOY_OPERATION_LOCK/owner" && rmdir "$DEPLOY_OPERATION_LOCK" || fail '无法释放已核验的失效锁。'
    log_message '0;34' '已核验并回收上次部署失效锁，业务数据保留。'
  fi
  [ -z "$old_supervisor" ] || log_message '0;34' '同项目旧部署已停止，开始本轮部署；后续取消或失败不会自动恢复旧进程。'
}
# 选择模式后才进入串行交接与原点写入。
deploy_state_begin_selected() {
  deploy_state_acquire_handoff
  deploy_state_handoff_previous
  deploy_state_initialize "$RUNTIME_EXISTED"
  deploy_state_start_guardian
}
# 主入口或其宿主异常消失后，独立监护仅回收匹配本轮清单的进程。
deploy_state_start_guardian() {
  local owner="$$" owner_started owner_command parent="$PPID" parent_started parent_command
  owner_started="$(LC_ALL=C ps -p "$owner" -o lstart= | sed 's/^ *//')"
  owner_command="$(LC_ALL=C ps -p "$owner" -o command=)"
  parent_started="$(LC_ALL=C ps -p "$parent" -o lstart= | sed 's/^ *//')"
  parent_command="$(LC_ALL=C ps -p "$parent" -o command=)"
  (
    trap '' HUP
    trap - INT TERM EXIT
    local role pid started command qr count=0
    if [ -n "$DEPLOY_HANDOFF_FD" ]; then exec {DEPLOY_HANDOFF_FD}>&-; DEPLOY_HANDOFF_FD=''; fi
    while deploy_state_same_process "$owner" "$owner_started" "$owner_command"; do
      if ! deploy_state_same_process "$parent" "$parent_started" "$parent_command"; then
        kill -HUP "$owner" 2>/dev/null || true
        break
      fi
      sleep 0.5
    done
    while deploy_state_same_process "$owner" "$owner_started" "$owner_command" && [ "$count" -lt 100 ]; do sleep 0.1; count=$((count + 1)); done
    if deploy_state_same_process "$owner" "$owner_started" "$owner_command"; then deploy_state_stop_identity "$owner" "$owner_started" "$owner_command" || exit 1; fi
    [ "$(cat "$DEPLOY_OPERATION_LOCK/owner" 2>/dev/null)" = "$owner" ] || exit 0
    cleanup_dependency_commands
    while IFS=$'\t' read -r role pid started command; do
      case "$role" in backend|tunnel|menu) deploy_state_stop_identity "$pid" "$started" "$command" || exit 1;; esac
    done < "$DEPLOY_STATE_DIR/processes.tsv"
    if [ -x "$RUN_DIR/qr-access" ]; then
      for qr in "$RUN_DIR"/access-qr-*(N/); do "$RUN_DIR/qr-access" --expire --output-dir "$qr" >> "$LOG_FILE" 2>&1 || true; done
    fi
    GUARDIAN_CONTEXT=1
    deploy_state_finish
  ) </dev/null >> "$LOG_FILE" 2>&1 &
  GUARDIAN_PID=$!
  deploy_state_process guardian "$GUARDIAN_PID"
}
# 已完成交接后，建立或核验首轮私有原点清单。
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
  printf 'deployment\t%s\t%s\t%s\n' "$$" "$(LC_ALL=C ps -p $$ -o lstart= | sed 's/^ *//')" "$(LC_ALL=C ps -p $$ -o command=)" > "$DEPLOY_OPERATION_LOCK/identity.tsv" || fail '无法保存操作锁身份。'
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
  { [ "${ZSH_SUBSHELL:-0}" = 0 ] && [ "${BASH_SUBSHELL:-0}" = 0 ]; } || [ "${GUARDIAN_CONTEXT:-0}" = 1 ] || return 0
  if [ "$DEPLOY_LOCK_HELD" = 1 ]; then
    local session_path resource_kind before backup signature
    while IFS=$'\t' read -r resource_kind session_path before backup signature; do
      [ "$resource_kind" != session ] || deploy_state_seal "$session_path" || printf '%s\n' '会话目录无法封存；反部署保留现场。' >&2
    done < "$DEPLOY_STATE_DIR/artifacts.tsv"
    deploy_state_seal "$PROJECT_ENV_DIR" || printf '%s\n' '无法封存依赖指纹；反部署将保留冲突对象。' >&2
    if [ "$(cat "$DEPLOY_OPERATION_LOCK/owner" 2>/dev/null)" = "${DEPLOY_OWNER_PID:-$$}" ]; then
      [ ! -f "$DEPLOY_OPERATION_LOCK/identity.tsv" ] || rm -- "$DEPLOY_OPERATION_LOCK/identity.tsv"
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
  configure_tunnel_access # 本地模式回车确认公开合成演示，取消保留旧实例。
  deploy_state_begin_selected # 模式及公开范围确认后串行接管同项目旧实例。
  prepare_go # 健康Go只用于引导标准库版本解析器，最终工具还需查询官方最新。
  configure_paths # 设置本项目机器缓存与回环路径，不修改全局工具。
  prepare_dependency_resolver # 临时构建官方稳定版本解析器，检查和计划不执行。
  prepare_latest_tools # 查询官方最新，显式旧版本停止；采用版本化项目缓存。
  check_business_dependencies # 仅报告业务库更新，不自动改动依赖锁。
  build_workbench # 仅构建成功才替换运行程序，失败保留退出码并停止后续启动。
  prepare_access_qr # 使用已有Go构建独立离线二维码工具，失败保留URL。
  start_and_check_backend # 核实本次后端健康再继续。
  deploy_state_release_handoff # 新后端健康后释放重启交接门禁。
  show_access_qr # 回环入口明确仅本机；公网地址就绪后自动重生成。
  start_tunnel # 仅已确认本地公开演示时建立隧道。
  monitor_processes # 监控本次子进程并在结束时清理。
}

main "$@"
