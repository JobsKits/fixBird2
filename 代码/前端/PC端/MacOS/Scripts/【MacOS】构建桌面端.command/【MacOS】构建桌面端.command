#!/bin/zsh
# 脚本自述：编译原生SwiftUI桌面端及相对路径引用的自有Foundation业务，随包复制本地合成PNG/MP4；只写本工程Dist和系统临时编译缓存。
# 运行提示：先展示自述，回车确认；Ctrl+C取消。不安装依赖，不启动服务，不修改系统设置。
SCRIPT_DIR=""
PROJECT_DIR=""
LOG_FILE=""
# 确认后解析自身位置并准备构建环境。
initialize() {
    setopt NO_NOMATCH
    set -e
    SCRIPT_DIR="$(cd "$(dirname "${(%):-%x}")" && pwd)"
    PROJECT_DIR="${SCRIPT_DIR:h:h}"
    LOG_FILE="${TMPDIR:-/tmp}/RepairDesktop-build.log"
}
# 输出内置自述并取得本次构建确认。
show_intro() {
    print '原生桌面端构建：需要本机Xcode命令行工具。编译当前源码到本工程Dist，日志在系统临时目录RepairDesktop-build.log。'
    print '回车继续；其它输入或Ctrl+C取消。'
    [[ -t 0 && -t 1 ]] || { print -u2 "请从可交互终端运行构建入口。"; exit 2; }
    local answer
    if [[ -z "${NO_COLOR+x}" && -n "$TERM" && "$TERM" != dumb ]]; then
        printf '\033[1;36m是否开始构建\033[0m？[\033[1;32m回车继续\033[0m / \033[1;31m其它输入取消\033[0m]：'
    else
        print -n "是否开始构建？[回车继续 / 其它输入取消]："
    fi
    IFS= read -r answer || exit 130
    [[ -z "$answer" ]] || exit 0
}
# 编译双架构、打包自含资源并校验本机签名。
build() {
    local app_dir="${PROJECT_DIR}/Dist/啄木鸟维修平台.app"
    local ios_data="${PROJECT_DIR}/../../移动端/iOS/App/Data"
    local -a sources
    sources=("${PROJECT_DIR}"/Sources/*.swift)
    local source
    for source in "${ios_data}"/*/*.swift; do
        [[ "$source" == */WBJobsTransport/* ]] || sources+=("$source")
    done
    mkdir -p "${app_dir}/Contents/MacOS" "${app_dir}/Contents/Resources"
    cp "${PROJECT_DIR}/Info.plist" "${app_dir}/Contents/Info.plist"
    cp "${PROJECT_DIR}/../../共享组件/Resources/ui-l10n.json" "${app_dir}/Contents/Resources/"
    cp "${PROJECT_DIR}/../原生共享契约/"*.json "${app_dir}/Contents/Resources/"
    cp "${PROJECT_DIR}/../原生共享契约/Unicode-LICENSE.txt" "${app_dir}/Contents/Resources/"
    cp "${PROJECT_DIR}/../原生共享契约/Assets/"*.png "${app_dir}/Contents/Resources/"
    cp "${PROJECT_DIR}/../原生共享契约/Assets/"*.mp4 "${app_dir}/Contents/Resources/"
    cp "${PROJECT_DIR}/../Web/维修工作台/assets/RepairLogo.png" "${app_dir}/Contents/Resources/"
    local compile_dir="$(mktemp -d "${TMPDIR:-/tmp}/RepairDesktop-build.XXXXXX")"
    local architecture
    : > "$LOG_FILE"
    for architecture in arm64 x86_64; do
        xcrun swiftc -D DEBUG -parse-as-library -target "${architecture}-apple-macos13.0" -O "${sources[@]}" -o "${compile_dir}/RepairDesktop-${architecture}" >>"$LOG_FILE" 2>&1 || { cat "$LOG_FILE"; return 1; }
    done
    lipo -create "${compile_dir}/RepairDesktop-arm64" "${compile_dir}/RepairDesktop-x86_64" -output "${app_dir}/Contents/MacOS/RepairDesktop"
    rm "${compile_dir}/RepairDesktop-arm64" "${compile_dir}/RepairDesktop-x86_64"
    rmdir "$compile_dir"
    write_manifests "$app_dir" "${sources[@]}"
    codesign --force --sign - "$app_dir" >>"$LOG_FILE" 2>&1
    codesign --verify --deep --strict "$app_dir" >>"$LOG_FILE" 2>&1
    print "已构建：${app_dir}"
}
# 用工程相对路径核对源码，用包内相对路径核对资源。
write_manifests() {
    local app_dir="$1"
    shift
    local source
    local -a source_paths
    for source in "$@"; do
        source_paths+=("${source#${PROJECT_DIR}/}")
    done
    (
        cd "$PROJECT_DIR"
        /usr/bin/shasum -a 256 -- Info.plist "${source_paths[@]}"
    ) > "${app_dir}/Contents/Resources/SourceManifest.sha256"
    (
        cd "${app_dir}/Contents/Resources"
        /usr/bin/shasum -a 256 -- *.json *.png *.mp4 Unicode-LICENSE.txt
    ) > "${app_dir}/Contents/Resources/ResourceManifest.sha256"
}
# 校验工具，不自动安装或修改系统环境。
check_environment() {
    command -v xcrun >/dev/null || { print "缺少Xcode命令行工具"; exit 1; }
}
# 唯一入口按确认、环境与构建顺序编排。
main() {
    show_intro # 自述并取得本次构建授权。
    initialize # 确认后解析目录与日志位置。
    check_environment # 校验本机编译工具。
    build # 生成双架构原生App并签名。
}
main "$@"
