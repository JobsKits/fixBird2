#requires -Version 5.1
# 脚本自述：使用本机.NET 10或以上SDK编译原生WPF桌面端；仅写本工程obj/bin/Dist及公共NuGet缓存。
# 运行提示：先读自述再回车确认；Ctrl+C取消。不安装SDK、不启动服务、不修改系统设置。
$script:ProjectDir = $null
$script:BuildLog = $null
# 展示固定自述，确认前不写文件。
function Show-Intro {
    Write-Host '原生Windows桌面端构建：需要.NET 10或以上SDK；写入本工程Dist，首次下载官方NuGet运行包。'
    Write-Host '回车继续；其它输入取消。日志位于系统临时目录RepairDesktop-build.log。'
    if ([Console]::IsInputRedirected) { throw '请从可交互终端运行构建入口。' }
    $answer = Read-Host '是否开始构建？[回车继续 / 其它输入取消]'
    if ($null -eq $answer -or $answer -ne '') { exit 0 }
}
# 确认后解析本工程路径并校验SDK。
function Initialize-Build {
    $script:ErrorActionPreference = 'Stop'
    $script:ProjectDir = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
    $script:BuildLog = Join-Path ([IO.Path]::GetTempPath()) 'RepairDesktop-build.log'
    Get-Command dotnet -ErrorAction Stop | Out-Null
}
# 自包含发布，保留真实失败退出码。
function Invoke-Build {
    $projectFile = Join-Path $script:ProjectDir 'RepairDesktop.csproj'
    $outputDir = Join-Path $script:ProjectDir 'Dist/win-x64'
    & dotnet publish $projectFile -c Release -r win-x64 --self-contained true -o $outputDir -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true *> $script:BuildLog
    if ($LASTEXITCODE -ne 0) { Get-Content $script:BuildLog; throw "构建失败：$LASTEXITCODE" }
    $sources = @(Get-ChildItem -LiteralPath (Join-Path $script:ProjectDir 'Sources') -Filter '*.cs' -File)
    $sources += Get-Item -LiteralPath $projectFile
    $sourceManifest = foreach ($file in $sources) {
        $relative = $file.FullName.Substring($script:ProjectDir.Length).TrimStart([char[]]'\/')
        "$( (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant() )  $relative"
    }
    $sourceManifest | Set-Content -LiteralPath (Join-Path $outputDir 'SourceManifest.sha256') -Encoding UTF8
    $resourceRoot = Join-Path $outputDir 'Resources'
    $resourceManifest = foreach ($file in Get-ChildItem -LiteralPath $resourceRoot -File) {
        "$( (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant() )  $($file.Name)"
    }
    $resourceManifest | Set-Content -LiteralPath (Join-Path $outputDir 'ResourceManifest.sha256') -Encoding UTF8
    Write-Host "已构建：$outputDir"
}
# 入口只编排高层流程。
function Main {
    Show-Intro # 展示用途并确认本次构建。
    Initialize-Build # 解析路径与检查工具。
    Invoke-Build # 执行自包含发布。
}
try { Main; exit 0 } catch { [Console]::Error.WriteLine($_.Exception.Message); exit 1 }
