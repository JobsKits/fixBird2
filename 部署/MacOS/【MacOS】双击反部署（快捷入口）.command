#!/bin/zsh
# 脚本自述：MacOS 反部署快捷入口，仅转交既有反部署脚本；复用其自述、数据选择、确认和参数。
SCRIPT_ENTRY="$0"
# 从快捷文件自身位置调用唯一反部署实现，保持其退出结果。
forward_undeployment() {
  local shortcut_dir shortcut_target
  shortcut_dir="$(CDPATH= cd -- "$(dirname -- "$SCRIPT_ENTRY")" && pwd -P)" || return 1
  shortcut_target="$shortcut_dir/Undeployment/【MacOS】反部署维修工作台.command/【MacOS】反部署维修工作台.command"
  if [ ! -f "$shortcut_target" ]; then
    printf '%s\n' "找不到反部署脚本：$shortcut_target；请保留快捷入口与同名脚本包的相对位置。" >&2
    return 1
  fi
  exec /bin/zsh "$shortcut_target" "$@"
}
# 仅转交反部署入口，复用内层自述与确认。
main() {
  forward_undeployment "$@" # 定位并转交原反部署实现，保留参数和退出码。
}
main "$@"
