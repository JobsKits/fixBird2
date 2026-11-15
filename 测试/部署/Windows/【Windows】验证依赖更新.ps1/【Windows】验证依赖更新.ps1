# 脚本自述：
# - 名称：【Windows】验证依赖更新.ps1；Created by Jobs on 2026年11月14日，星期六.
# - 用途：点载真实Windows部署函数，隔离验证版本选择、重试、业务库只读检查及只读入口。
# - 范围：仅写系统临时夹具，不联网、不下载、不启动服务，不实例化Windows Job Object。
# - 运行：已有PowerShell与本机原生依赖解析器；普通运行先回车，自动化显式传-Run。
[CmdletBinding()]
param([switch]$Run, [string]$Resolver, [string]$Go)

function Confirm-TestIntroduction {
    Write-Host '================ Windows依赖更新隔离验证 ================'
    Write-Host '使用真实部署函数和本机原生解析器；探针、网络、下载及进程会话均用替身。'
    Write-Host '仅写临时目录；业务报告使用已有Go与无外部依赖的临时模块，不修改项目锁。'
    if ($Run) { return }
    if ([Console]::IsInputRedirected) { throw '自动化请显式传-Run。' }
    Write-Host '按回车开始' -ForegroundColor Green -NoNewline
    Write-Host '；其它输入取消：' -ForegroundColor Red -NoNewline
    if ([Console]::ReadLine() -cne '') { exit 0 }
}

function Assert-Test {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Assert-Throws {
    param([scriptblock]$Action, [string]$Pattern)
    $message = ''
    try { & $Action | Out-Null } catch { $message = $_.Exception.Message }
    Assert-Test ($message -match $Pattern) ('预期失败未发生：' + $Pattern + '；实际：' + $message)
}

function Pass-Test {
    param([string]$Name)
    $script:PassedCount += 1
    Write-Host ('PASS ' + $Name)
}

function Set-TestFunction {
    param([string]$Name, [scriptblock]$Body)
    Set-Item -Path ('Function:script:' + $Name) -Value $Body
}

function Restore-TestFunction {
    param([string]$Name)
    if ($script:OriginalFunctions[$Name]) { Set-TestFunction $Name $script:OriginalFunctions[$Name] }
    else { Remove-Item -Path ('Function:script:' + $Name) -ErrorAction SilentlyContinue }
}

function Get-AssetFixture {
    param([string]$Tool = 'fzf', [string]$Version = '0.9.0', [string]$Kind = 'zip')
    $filename = if ($Tool -eq 'go') { 'go' + $Version + '.windows-amd64.zip' } elseif ($Tool -eq 'fzf') { 'fzf-' + $Version + '-windows_amd64.zip' } else { 'cloudflared-windows-amd64.exe' }
    $repo = if ($Tool -eq 'fzf') { 'junegunn/fzf' } else { 'cloudflare/cloudflared' }
    $tag = if ($Tool -eq 'fzf') { 'v' + $Version } else { $Version }
    $url = if ($Tool -eq 'go') { 'https://go.dev/dl/' + $filename } else { 'https://github.com/' + $repo + '/releases/download/' + $tag + '/' + $filename }
    if ($Kind -eq 'unsupported') { $filename = '-'; $url = '-' }
    return [pscustomobject]@{ tool=$Tool; os='windows'; arch='amd64'; version=$Version; filename=$filename; sha256=$(if ($Kind -eq 'unsupported') { '-' } else { 'a' * 64 }); url=$url; kind=$Kind }
}

function Get-AssetRow {
    param([object]$Asset)
    return (@($Asset.tool,$Asset.os,$Asset.arch,$Asset.version,$Asset.filename,$Asset.sha256,$Asset.url,$Asset.kind) -join "`t")
}

function Invoke-RealResolver {
    param([string[]]$Arguments)
    $output = @(& $script:NativeResolver @Arguments 2> (Join-Path $script:FixtureRoot 'resolver.stderr'))
    return [pscustomobject]@{ code=$LASTEXITCODE; text=($output -join "`n") }
}

function New-ToolFixture {
    param([string]$Path, [string]$Version, [switch]$Stamp)
    $null = New-Item -ItemType Directory -Force -Path ([IO.Path]::GetDirectoryName($Path))
    [IO.File]::WriteAllText($Path, 'fixture-' + $Version)
    $script:ToolVersions[$Path] = $Version
    if ($Stamp) { [IO.File]::WriteAllText((Join-Path ([IO.Path]::GetDirectoryName($Path)) 'executable.sha256'), (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash) }
    return $Path
}

function Invoke-ReadOnlySuite {
    $env:WB_ENV_ROOT = Join-Path $script:FixtureRoot 'untouched-environment'
    $env:WB_RUNTIME_DIR = Join-Path $script:FixtureRoot 'untouched-runtime'
    foreach ($name in @('Initialize-RunDirectory','Initialize-OwnedProcessSession','Ensure-DeploymentTool','Start-SelectedDeployment')) {
        Set-TestFunction $name { throw '只读入口触及变更或工具执行。' }
    }
    Invoke-RepairDeployment -CheckOnly | Out-Null
    Invoke-RepairDeployment -PlanOnly -ReviewMode local | Out-Null
    Assert-Test (-not (Test-Path -LiteralPath $env:WB_ENV_ROOT) -and -not (Test-Path -LiteralPath $env:WB_RUNTIME_DIR)) '只读入口创建了环境或运行目录。'
    foreach ($name in @('Initialize-RunDirectory','Initialize-OwnedProcessSession','Ensure-DeploymentTool','Start-SelectedDeployment')) { Restore-TestFunction $name }
    Pass-Test 'check-plan-no-tools-or-writes'
}

function Invoke-MetadataSuite {
    Set-TestFunction 'Start-Sleep' { param([int]$Seconds) $script:Delays.Add($Seconds) }
    Set-TestFunction 'Invoke-DependencyCapture' {
        param($File,[string[]]$Arguments,$Environment,$TimeoutSeconds,$TimeoutCode)
        $script:CapturedArguments.Add($Arguments.Clone())
        return $script:Replies.Dequeue()
    }
    foreach ($tool in @('go','fzf','cloudflared')) {
        $script:CapturedArguments.Clear(); $script:Delays.Clear()
        $asset = Get-AssetFixture $tool
        $script:Replies = New-Object 'Collections.Generic.Queue[object]'
        $script:Replies.Enqueue([pscustomobject]@{code=75;text='network unavailable'})
        $script:Replies.Enqueue([pscustomobject]@{code=0;text=(Get-AssetRow $asset)})
        $actual = Get-OfficialDependencyAsset $tool
        Assert-Test ($actual.version -eq $asset.version -and $script:Delays.Count -eq 1 -and $script:Delays[0] -eq 1) '75未退避重试。'
        foreach ($arguments in $script:CapturedArguments) {
            Assert-Test (($arguments -contains '--minimum-go') -eq ($tool -eq 'go')) 'minimum-go错误地传给非Go工具。'
            Assert-Test ($arguments -contains 'windows' -and $arguments -contains 'amd64' -and $arguments -contains '--locked-manifest') '未传入原生平台、架构或摘要回退清单。'
        }
    }
    Pass-Test 'metadata-75-retry-and-native-arguments'
    foreach ($reply in @([pscustomobject]@{code=2;text='invalid metadata'}, [pscustomobject]@{code=0;text=((Get-AssetRow (Get-AssetFixture)) -replace ('a' * 64),'bad-sha')})) {
        $script:Replies.Enqueue($reply); $script:Delays.Clear()
        Assert-Throws { Get-OfficialDependencyAsset 'fzf' } '无法确认|摘要'
        Assert-Test ($script:Replies.Count -eq 0 -and $script:Delays.Count -eq 0) '无效元数据或摘要被重试。'
    }
    Pass-Test 'metadata-invalid-and-bad-digest-stop'
    $script:Replies.Enqueue([pscustomobject]@{code=0;text=(Get-AssetRow (Get-AssetFixture 'cloudflared' '2026.11.0' 'unsupported'))})
    Assert-Test ((Get-OfficialDependencyAsset 'cloudflared').kind -eq 'unsupported') '不支持的平台行未正确保留。'
    Pass-Test 'metadata-unsupported-native-asset'
}

function Invoke-SelectionSuite {
    Set-TestFunction 'Get-OfficialDependencyAsset' { param($Tool) return $script:SelectionAsset }
    Set-TestFunction 'Get-Command' { param($Name,$CommandType,$ErrorAction) if ($script:PathTool) { return [pscustomobject]@{Source=$script:PathTool} } }
    Set-TestFunction 'Test-NativeExecutable' { param($Path) return $script:ToolVersions.ContainsKey($Path) }
    Set-TestFunction 'Test-ToolHealth' { param($Path,$Tool) return $script:ToolVersions.ContainsKey($Path) }
    Set-TestFunction 'Get-DeploymentToolVersion' { param($Path,$Tool) if ($script:ToolVersions.ContainsKey($Path)) { return $script:ToolVersions[$Path] }; return '' }
    Set-TestFunction 'Ensure-DeploymentTool' { param($Rows,$Tool,$RequiredAsset) $script:InstallCalls += 1; throw '夹具不允许下载。' }
    Set-TestFunction 'Invoke-DependencyCapture' { param($File,[string[]]$Arguments,$Environment,$TimeoutSeconds,$TimeoutCode) return (Invoke-RealResolver $Arguments) }
    $script:EnvironmentRoot = Join-Path $script:FixtureRoot 'environment'
    $script:ProjectCacheRoot = Join-Path $script:FixtureRoot 'project-cache'
    $script:SelectionAsset = Get-AssetFixture
    $script:PathTool = New-ToolFixture (Join-Path $script:FixtureRoot 'old-path/fzf.exe') '0.8.0'
    $null = New-ToolFixture (Join-Path $script:EnvironmentRoot 'Fzf/0.9.0/Windows-amd64/fzf.exe') '0.9.0'
    $bestShared = New-ToolFixture (Join-Path $script:EnvironmentRoot 'Fzf/0.10.0/Windows-amd64/fzf.exe') '0.10.0'
    $bestOwned = New-ToolFixture (Join-Path $script:ProjectCacheRoot 'Tools/Fzf/0.11.0/Windows-amd64/fzf.exe') '0.11.0' -Stamp
    $untrusted = New-ToolFixture (Join-Path $script:ProjectCacheRoot 'Tools/Fzf/0.99.0/Windows-amd64/fzf.exe') '0.99.0'
    $script:InstallCalls = 0
    $selected = Resolve-LatestDeploymentTool @() 'fzf'
    Assert-Test ($selected -eq $bestOwned -and $script:InstallCalls -eq 0) '未在全部版本缓存中语义择新，或采用无指纹缓存。'
    [IO.File]::WriteAllText((Join-Path ([IO.Path]::GetDirectoryName($bestOwned)) 'executable.sha256'), 'bad')
    Assert-Test ((Resolve-LatestDeploymentTool @() 'fzf') -eq $bestShared) '缓存指纹失配后仍复用。'
    Pass-Test 'old-path-semantic-cache-selection-and-fingerprint'
    $env:WB_FZF_BIN = $script:PathTool
    Assert-Throws { Resolve-LatestDeploymentTool @() 'fzf' } '显式'
    Assert-Test ($script:InstallCalls -eq 0 -and [IO.File]::ReadAllText($env:WB_FZF_BIN) -ceq 'fixture-0.8.0') '显式旧版被下载或覆盖。'
    Pass-Test 'explicit-old-tool-stops-without-overwrite'
    $script:SelectionAsset = Get-AssetFixture 'fzf' '0.9.0' 'unsupported'
    Remove-Item Env:WB_FZF_BIN
    Assert-Throws { Resolve-LatestDeploymentTool @() 'fzf' } '未提供'
    $env:WB_FZF_BIN = $bestShared
    Assert-Test ((Resolve-LatestDeploymentTool @() 'fzf') -eq $bestShared) '原生显式达标工具无法用于无官方资产的平台。'
    Remove-Item Env:WB_FZF_BIN
    Pass-Test 'unsupported-requires-explicit-compatible-native-tool'
    foreach ($name in @('Get-OfficialDependencyAsset','Get-Command','Get-DeploymentToolVersion','Ensure-DeploymentTool')) { Restore-TestFunction $name }
}

function Invoke-DownloadSuite {
    $destination = Join-Path $script:FixtureRoot 'download.partial'
    $script:DownloadAttempts = 0; $script:Delays.Clear()
    Set-TestFunction 'Save-VerifiedDownloadOnce' {
        param($Asset,$Destination)
        $script:DownloadAttempts += 1
        Assert-Test (-not (Test-Path -LiteralPath $Destination)) '网络重试前未移除本次部分文件。'
        [IO.File]::WriteAllText($Destination,'partial')
        if ($script:DownloadAttempts -eq 1) { throw (New-Object TimeoutException -ArgumentList 'fixture timeout') }
    }
    Save-VerifiedDownload (Get-AssetFixture) $destination
    Assert-Test ($script:DownloadAttempts -eq 2 -and $script:Delays.Count -eq 1) '临时下载超时未重试。'
    Remove-Item -LiteralPath $destination
    $script:DownloadAttempts = 0; $script:Delays.Clear()
    Set-TestFunction 'Save-VerifiedDownloadOnce' { param($Asset,$Destination) $script:DownloadAttempts += 1; throw 'SHA256校验失败。' }
    Assert-Throws { Save-VerifiedDownload (Get-AssetFixture) $destination } 'SHA256'
    Assert-Test ($script:DownloadAttempts -eq 1 -and $script:Delays.Count -eq 0) '摘要失败被当作网络问题重试。'
    Restore-TestFunction 'Save-VerifiedDownloadOnce'
    Pass-Test 'download-timeout-retries-digest-failure-stops'
}

function Invoke-CaptureSuite {
    Restore-TestFunction 'Invoke-DependencyCapture'
    $script:FakeProcess = [pscustomobject]@{ExitCode=0; Waited=$true; Killed=$false}
    $script:FakeProcess | Add-Member ScriptMethod WaitForExit { param($Timeout) return $this.Waited }
    $script:FakeProcess | Add-Member ScriptMethod Kill { $this.Killed=$true }
    $script:Session = [pscustomobject]@{Flush=$true}
    $script:Session | Add-Member ScriptMethod FlushOutput { param($Process,$Timeout) return $this.Flush }
    Set-TestFunction 'Start-OwnedProcess' { param($File,$Arguments,$Environment,$LogName) [IO.File]::WriteAllText((Join-Path $script:RunDirectory $LogName),"line`r`n"); return $script:FakeProcess }
    $reply = Invoke-DependencyCapture 'fixture'
    Assert-Test ($reply.code -eq 0 -and $reply.text -ceq 'line') '完整日志或退出码未保留。'
    $script:Session.Flush=$false
    Assert-Throws { Invoke-DependencyCapture 'fixture' } '封存'
    $script:Session.Flush=$true; $script:FakeProcess.Waited=$false
    $reply = Invoke-DependencyCapture 'fixture' @() @{} 1 3
    Assert-Test ($reply.code -eq 3 -and $script:FakeProcess.Killed) '业务查询超时未回收或未返回3。'
    Assert-Test ((Invoke-DependencyCapture 'fixture' @() @{} 1).code -eq 75) '元数据超时未返回75。'
    Pass-Test 'owned-capture-output-timeout-and-flush'
}

function Invoke-TunnelHealthSuite {
    Restore-TestFunction 'Test-ToolHealth'
    $path=New-ToolFixture (Join-Path $script:FixtureRoot 'health/cloudflared.exe') '2026.11.0'
    $script:HealthProcess=[pscustomobject]@{ExitCode=0}
    $script:HealthProcess | Add-Member ScriptMethod WaitForExit { param($Timeout) return $true }
    $script:Session=[pscustomobject]@{}
    $script:Session | Add-Member ScriptMethod FlushOutput { param($Process,$Timeout) return $true }
    Set-TestFunction 'Start-OwnedProcess' {
        param($File,$Arguments,$Environment,$LogName)
        $text=if ($Arguments -contains '--version') { 'cloudflared version 2026.11.0' } else { $script:TunnelHelp }
        [IO.File]::WriteAllText((Join-Path $script:RunDirectory $LogName),$text)
        return $script:HealthProcess
    }
    $script:TunnelHelp='--url --no-autoupdate --config'
    $script:PublicDemo=$false
    Assert-Test (-not (Test-ToolHealth $path 'cloudflared')) '私有模式漏检邮箱验证能力。'
    $script:TunnelHelp+=' --allowed-mail'
    Assert-Test (Test-ToolHealth $path 'cloudflared') '私有模式拒绝完整的隧道能力。'
    $script:TunnelHelp='--url --no-autoupdate --config'
    $script:PublicDemo=$true
    Assert-Test (Test-ToolHealth $path 'cloudflared') '公开模式错误地要求邮箱验证能力。'
    $script:TunnelHelp='--no-autoupdate --config'
    Assert-Test (-not (Test-ToolHealth $path 'cloudflared')) '公开模式漏检必要的URL能力。'
    $script:PublicDemo=$false
    Pass-Test 'public-and-private-tunnel-capability-gates'
}

function Invoke-ModuleSuite {
    $script:ProjectRoot = Join-Path $script:FixtureRoot 'source'
    foreach ($relative in @('代码/后端/后端代码','部署/公共组件/地址二维码')) {
        $module = Join-Path $script:ProjectRoot $relative
        $null = New-Item -ItemType Directory -Force -Path $module
        [IO.File]::WriteAllText((Join-Path $module 'go.mod'),"module example.test/fixture`n`ngo 1.24.0`n")
        [IO.File]::WriteAllText((Join-Path $module 'go.sum'),'')
    }
    $source = Join-Path $script:ProjectRoot '代码/后端/后端代码'
    $copy = New-ModuleManifestCopy $source 'real-report'
    Assert-Test ([IO.Path]::GetFileName($copy) -ceq 'module.mod' -and (Test-Path -LiteralPath ([IO.Path]::ChangeExtension($copy,'sum')))) '副本命名或go.sum复制不正确。'
    $env:GOPROXY='off'; $env:GOSUMDB='off'; $env:GOWORK='off'; $env:GOTOOLCHAIN='local'
    $env:GOENV='off'; $env:GOTELEMETRY='off'
    $env:GOPATH=Join-Path $script:FixtureRoot 'go-path'
    $env:GOCACHE=Join-Path $script:FixtureRoot 'go-build'
    $env:GOMODCACHE=Join-Path $script:FixtureRoot 'go-modules'
    $arguments = @('--module-report','--go-bin',$script:NativeGo,'--module-dir',$source,'--modfile',$copy,'--timeout-seconds','5')
    $reply = Invoke-RealResolver $arguments
    Assert-Test ($reply.code -eq 0 -and -not $reply.text) ('真实报告无法接受副本：' + $reply.code)
    [IO.File]::AppendAllText($copy,"// drift`n")
    Assert-Test ((Invoke-RealResolver $arguments).code -eq 2) '副本与源不一致未返回完整性错误2。'
    $copy = New-ModuleManifestCopy $source 'real-report-query-failure'
    # 已有Go的工具执行器面对固定go-list参数必然失败；不访问网络或引入假PE。
    $formatter = 'gofmt' + $(if ([Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT) { '.exe' } else { '' })
    $arguments = @('--module-report','--go-bin',(Join-Path ([IO.Path]::GetDirectoryName($script:NativeGo)) $formatter),'--module-dir',$source,'--modfile',$copy,'--timeout-seconds','5')
    Assert-Test ((Invoke-RealResolver $arguments).code -eq 3) '查询失败未区分为3。'
    Pass-Test 'real-helper-external-module-mod-sum-and-exit-codes'
    Set-TestFunction 'Get-ModuleBuildEnvironment' { param($Go) return @{} }
    Set-TestFunction 'Invoke-DependencyCapture' {
        param($File,[string[]]$Arguments,$Environment,$TimeoutSeconds,$TimeoutCode)
        $script:ReportCalls += 1
        Assert-Test ($Arguments -contains '--module-report' -and $Arguments -contains '--modfile' -and $TimeoutCode -eq 3) '业务检查参数或超时代码不正确。'
        return [pscustomobject]@{code=$script:ReportCode;text='fixture-report'}
    }
    foreach ($code in @(0,3)) {
        $script:ReportCode=$code; $script:ReportCalls=0; $script:Logs.Clear()
        Test-BusinessModuleUpdates $script:NativeGo
        Assert-Test ($script:ReportCalls -eq 2) '查询成功或暂时失败未检查两个模块。'
        if ($code -eq 3) { Assert-Test (($script:Logs -join "`n") -match '未完成或超时') '查询失败被误称为已确认最新。' }
    }
    $script:ReportCode=2; $script:ReportCalls=0
    Assert-Throws { Test-BusinessModuleUpdates $script:NativeGo } '源码锁校验失败'
    Assert-Test ($script:ReportCalls -eq 1) '完整性错误后仍继续其它模块。'
    $script:ReportCode=130; $cancelled=$false
    try { Test-BusinessModuleUpdates $script:NativeGo } catch { $cancelled=$_.Exception -is [OperationCanceledException] }
    Assert-Test $cancelled '取消未传播到部署清理。'
    Pass-Test 'business-report-success-warning-integrity-and-cancel'
}

function Invoke-TestMain {
    Confirm-TestIntroduction
    if (-not $Resolver -or -not $Go -or -not [IO.Path]::IsPathRooted($Resolver) -or -not [IO.Path]::IsPathRooted($Go) -or -not (Test-Path -LiteralPath $Resolver -PathType Leaf) -or -not (Test-Path -LiteralPath $Go -PathType Leaf)) { throw '请通过-Resolver与-Go指定已有的本机原生解析器与Go绝对路径；测试不会下载。' }
    $script:NativeResolver=$Resolver; $script:NativeGo=$Go
    $entry=Join-Path $PSScriptRoot '../../../../部署/Windows/Deployment/【Windows】部署.ps1/【Windows】部署.ps1'
    $tokens=$null; $errors=$null
    $null=[Management.Automation.Language.Parser]::ParseFile($entry,[ref]$tokens,[ref]$errors)
    Assert-Test ($errors.Count -eq 0) 'Windows部署脚本语法错误。'
    $saved=@{}
    foreach ($key in @('NO_COLOR','GO_BIN','WB_FZF_BIN','WB_CLOUDFLARED_BIN','WB_ENV_ROOT','WB_RUNTIME_DIR','GOPROXY','GOSUMDB','GOWORK','GOTOOLCHAIN','GOENV','GOTELEMETRY','GOPATH','GOCACHE','GOMODCACHE','WB_DEPENDENCY_CHECK_TIMEOUT_SECONDS')) { $saved[$key]=[Environment]::GetEnvironmentVariable($key) }
    $script:PassedCount=0; $script:FixtureRoot=$null; $complete=$false
    try {
        $env:NO_COLOR='1'
        foreach ($key in @('GO_BIN','WB_FZF_BIN','WB_CLOUDFLARED_BIN','WB_DEPENDENCY_CHECK_TIMEOUT_SECONDS')) { [Environment]::SetEnvironmentVariable($key,$null) }
        . $entry
        $temporaryBase=[IO.Path]::GetTempPath()
        # macOS的/var是系统链接；夹具用物理路径，保留真实函数拒绝重解析路径的规则。
        if ([Environment]::OSVersion.Platform -eq [PlatformID]::Unix) {
            Push-Location -LiteralPath $temporaryBase
            try { $temporaryBase=(& /bin/pwd -P) } finally { Pop-Location }
        }
        $script:FixtureRoot=Join-Path $temporaryBase ('repair-windows-dependencies-' + [Guid]::NewGuid().ToString('N'))
        $null=New-Item -ItemType Directory -Path $script:FixtureRoot
        Write-Host ('夹具：' + $script:FixtureRoot)
        $script:RunDirectory=Join-Path $script:FixtureRoot 'run'
        $null=New-Item -ItemType Directory -Path $script:RunDirectory
        $script:DependencyResolver=$Resolver; $script:ToolArch='amd64'
        $script:OriginalFunctions=@{}
        foreach ($name in @('Initialize-RunDirectory','Initialize-OwnedProcessSession','Ensure-DeploymentTool','Start-SelectedDeployment','Start-Sleep','Invoke-DependencyCapture','Get-OfficialDependencyAsset','Get-Command','Get-DeploymentToolVersion','Save-VerifiedDownloadOnce','Test-ToolHealth')) {
            $definition=Get-Item ('Function:'+$name) -ErrorAction SilentlyContinue
            $script:OriginalFunctions[$name]=$(if ($definition) { $definition.ScriptBlock } else { $null })
        }
        $script:CapturedArguments=New-Object 'Collections.Generic.List[object]'
        $script:Delays=New-Object 'Collections.Generic.List[int]'
        $script:Logs=New-Object 'Collections.Generic.List[string]'
        $script:ToolVersions=@{}
        Set-TestFunction 'Write-DeployLog' { param($Message,$Level,$Emphasize) $script:Logs.Add([string]$Message) }
        Invoke-ReadOnlySuite
        Invoke-MetadataSuite
        Invoke-SelectionSuite
        Invoke-DownloadSuite
        Invoke-TunnelHealthSuite
        Invoke-CaptureSuite
        Invoke-ModuleSuite
        $complete=$true
        Write-Host ("通过$script:PassedCount 组；未进行Windows原生进程回收、网络、SDK升级或真实部署验收。")
    } finally {
        foreach ($key in $saved.Keys) { [Environment]::SetEnvironmentVariable($key,$saved[$key]) }
        if ($script:FixtureRoot -and $complete) { Remove-Item -LiteralPath $script:FixtureRoot -Recurse -Force }
        elseif ($script:FixtureRoot) { Write-Host ('失败夹具保留：' + $script:FixtureRoot) }
    }
}

. Invoke-TestMain
