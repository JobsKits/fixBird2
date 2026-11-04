# 脚本自述：
# - 名称：【Windows】验证网页菜单.ps1；Created by Jobs on 2026年11月3日，星期二.
# - 用途：隔离验证真实部署函数的地址菜单、连续选择、打开失败与服务退出处理。
# - 范围：只在系统临时目录写夹具；假Session/fzf和假浏览器，不联网、不调用Windows Job Object或真实服务。
# - 运行：普通运行先回车确认，自动化显式传-Run；失败保留夹具，成功清理本次临时目录。
[CmdletBinding()]
param([switch]$Run)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$testEntry = Join-Path $PSScriptRoot '..\..\..\..\部署\Windows\Deployment\【Windows】部署.ps1\【Windows】部署.ps1'
$testRoot = $null
$passed = $false
$total = 0

# 明确只读加载与替身边界，确认前不创建夹具。
function Confirm-TestIntroduction {
    Write-Host '================ Windows网页菜单隔离验证 ================'
    Write-Host '加载真实部署函数；使用假进程会话和假浏览器，不执行部署、联网或Windows原生API。'
    Write-Host '仅写系统临时目录；成功清理本次夹具，失败保留。Ctrl+C可取消。'
    if ($Run) { return }
    if ([Console]::IsInputRedirected) { throw '自动化请显式传-Run，普通运行需交互终端。' }
    Write-Host '按回车开始；其它输入取消：' -NoNewline
    if ([Console]::ReadLine() -cne '') { exit 0 }
}
# 以失败即停的方式检查可观察结果。
function Assert-Test {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}
# 记录各独立行为的通过结果。
function Pass-Test {
    param([string]$Name)
    $script:total += 1
    Write-Host ('PASS ' + $Name)
}
# 用拥有退出状态的替身记录，不启动真实进程。
function New-FakeProcess {
    param([bool]$Exited = $true, [int]$Code = 0)
    $process = [pscustomobject]@{ HasExited = $Exited; ExitCode = $Code; Released = $false }
    $process | Add-Member ScriptMethod WaitForExit { param($Timeout) return $this.HasExited }
    return $process
}
# 假会话只读写夹具，注入fzf结果并记录与真实函数交互的边界。
function New-FakeSession {
    $session = [pscustomobject]@{
        MenuResult = "`nlocal|本机地址｜http://127.0.0.1:18098/`n"
        MenuExitCode = 0
        MenuWait = $false
        Menus = (New-Object 'Collections.Generic.List[object]')
        StartedItems = @()
        CheckCount = 0
        Death = ''
        Disposed = $false
    }
    $session | Add-Member ScriptMethod StartMenu {
        param($File, $Arguments, $Directory, $Environment, $InputPath, $OutputPath)
        $this.StartedItems = @([IO.File]::ReadAllLines($InputPath, [Text.Encoding]::UTF8))
        if ($Arguments -notcontains '--expect=esc,ctrl-c') { throw '菜单未区分Esc与Ctrl+C。' }
        if (-not [string]::IsNullOrEmpty($Environment['FZF_DEFAULT_OPTS'])) { throw '继承的fzf配置未隔离。' }
        [IO.File]::WriteAllText($OutputPath, $this.MenuResult, (New-Object Text.UTF8Encoding($false)))
        $process = New-FakeProcess (-not $this.MenuWait) $this.MenuExitCode
        $this.Menus.Add($process)
        return $process
    }
    $session | Add-Member ScriptMethod FlushOutput { param($Process, $Timeout) return $true }
    $session | Add-Member ScriptMethod ReleaseMenu { param($Process) $Process.Released = $true }
    $session | Add-Member ScriptMethod CheckLogHealth {
        $this.CheckCount += 1
        if ($this.CheckCount -ge 3) {
            if ($this.Death -eq 'backend') { $script:Backend.HasExited = $true }
            if ($this.Death -eq 'tunnel') { $script:Tunnel.HasExited = $true }
        }
    }
    $session | Add-Member ScriptMethod Dispose {
        foreach ($menu in $this.Menus) { $menu.HasExited = $true; $menu.Released = $true }
        $script:Backend.HasExited = $true
        if ($script:Tunnel) { $script:Tunnel.HasExited = $true }
        $this.Disposed = $true
    }
    return $session
}
# 每组重置真实函数使用的状态，替身不影响项目运行目录。
function Reset-BrowserFixture {
    $script:Session = New-FakeSession
    $script:BrowserMenu = $null
    $script:BrowserMenuPaused = $false
    $script:BrowserItems = @()
    $script:Backend = New-FakeProcess $false 37
    $script:Tunnel = $null
    $script:DeployLock = $null
    $script:AllowedMail = $null
    $script:PublicDemo = $false
    $script:FzfExecutable = 'fixture-fzf'
    $script:AppEnvironment = @{ WB_ADDR = '127.0.0.1:18098' }
    $script:RunDirectory = $script:testRoot
    $script:LogFile = Join-Path $script:testRoot 'deployment.log'
    $script:OpenedUrls = New-Object 'Collections.Generic.List[string]'
    $script:FailOpen = $false
}
# 浏览器替身只记录调用，首次失败可按组注入。
function Start-Process {
    [CmdletBinding()]
    param([string]$FilePath)
    $script:OpenedUrls.Add($FilePath)
    if ($script:FailOpen) { $script:FailOpen = $false; throw 'fixture-browser-open-failed' }
}
# 用真实菜单启动和完成函数处理一组可控结果。
function Invoke-MenuFixture {
    param([string]$Address, [string]$Result, [int]$Code = 0)
    $script:Session.MenuResult = $Result
    $script:Session.MenuExitCode = $Code
    Start-BrowserMenu $Address
    Complete-BrowserMenu $Address
}
# 验证连续选择、打开失败、取消、服务退出及取消异常的清理边界。
function Invoke-BrowserSuite {
    $public = 'https://fixture-only-browser-menu.trycloudflare.com'
    $local = 'http://127.0.0.1:18098/'
    Reset-BrowserFixture
    Invoke-MenuFixture $public ("`npublic|公网地址｜" + $public + "`n")
    Invoke-MenuFixture $public ("`nlocal|本机地址｜" + $local + "`n")
    Assert-Test ($script:OpenedUrls.Count -eq 2 -and $script:OpenedUrls[0] -ceq $public -and $script:OpenedUrls[1] -ceq $local) '公网／本机映射或连续选择失败。'
    Assert-Test ($null -eq $script:BrowserMenu -and -not $script:BrowserMenuPaused -and -not $script:Backend.HasExited) '打开后没有返回可重选状态或停止了后端。'
    Pass-Test 'public-local-repeat'

    Reset-BrowserFixture
    $script:FailOpen = $true
    Invoke-MenuFixture $public ("`npublic|公网地址｜" + $public + "`n")
    Invoke-MenuFixture $public ("`nlocal|本机地址｜" + $local + "`n")
    Assert-Test ($script:OpenedUrls.Count -eq 2 -and -not $script:BrowserMenuPaused -and -not $script:Backend.HasExited) '浏览器失败后无法继续选择或中断服务。'
    Pass-Test 'open-failure-retry'

    foreach ($case in @(
        @{ Name = 'escape-pauses'; Result = "esc`npublic|公网地址｜$public`n"; Code = 0 },
        @{ Name = 'empty-pauses'; Result = ''; Code = 1 },
        @{ Name = 'pause-row'; Result = "`npause|收起菜单（服务继续运行，回车再选）`n"; Code = 0 },
        @{ Name = 'invalid-selection'; Result = "`nlocal|http://untrusted.invalid`n"; Code = 0 },
        @{ Name = 'menu-error-pauses'; Result = ''; Code = 9 }
    )) {
        Reset-BrowserFixture
        Invoke-MenuFixture $public $case.Result $case.Code
        Assert-Test ($script:OpenedUrls.Count -eq 0 -and $script:BrowserMenuPaused -and -not $script:Backend.HasExited) ('取消或非法结果打开了网页／停止了服务：' + $case.Name)
        Pass-Test $case.Name
    }

    Reset-BrowserFixture
    Invoke-MenuFixture '' ("`nlocal|本机地址｜" + $local + "`n")
    Assert-Test ($script:Session.StartedItems.Count -eq 2 -and @($script:Session.StartedItems | Where-Object { $_ -like 'public|*' }).Count -eq 0) '服务器模式错误地显示公网入口。'
    Pass-Test 'server-only-local'

    foreach ($death in @('backend', 'tunnel')) {
        Reset-BrowserFixture
        $script:Session.MenuWait = $true
        $script:Session.Death = $death
        if ($death -eq 'tunnel') {
            $script:Tunnel = New-FakeProcess $false 43
            [IO.File]::WriteAllText((Join-Path $script:testRoot 'tunnel.log'), $public, (New-Object Text.UTF8Encoding($false)))
        }
        $owned = $script:Session
        $errorText = ''
        try { Watch-Deployment } catch { $errorText = $_.Exception.Message } finally { Clear-OwnedDeployment }
        $expected = $(if ($death -eq 'backend') { '37' } else { '43' })
        Assert-Test ($errorText.Contains($expected) -and $owned.Menus.Count -eq 1 -and $owned.Disposed -and $owned.Menus[0].Released) ('菜单等待期间服务退出未清理：' + $death)
        Pass-Test ('waiting-' + $death + '-exit')
    }

    Reset-BrowserFixture
    $owned = $script:Session
    $cancelled = $false
    try { Invoke-MenuFixture $public "ctrl-c`n" } catch { $cancelled = $_.Exception -is [OperationCanceledException] } finally { Clear-OwnedDeployment }
    Assert-Test ($cancelled -and $owned.Disposed -and $script:OpenedUrls.Count -eq 0) '菜单Ctrl+C未进入会话清理。'
    Pass-Test 'ctrl-c-cleans-session'
}

Confirm-TestIntroduction
try {
    $tokens = $null
    $errors = $null
    $ast = [Management.Automation.Language.Parser]::ParseFile($testEntry, [ref]$tokens, [ref]$errors)
    Assert-Test ($errors.Count -eq 0) '部署入口存在PowerShell语法错误。'
    $nativeSource = @($ast.FindAll({ param($node) $node -is [Management.Automation.Language.StringConstantExpressionAst] -and $node.Value.Contains('public sealed class JobsRepairDeploySession') }, $true))[0].Value
    Add-Type -TypeDefinition $nativeSource
    Pass-Test 'powershell-and-native-manager-compile'
    . $testEntry
    $script:testRoot = Join-Path ([IO.Path]::GetTempPath()) ('repair-windows-menu-' + [Guid]::NewGuid().ToString('N'))
    $null = New-Item -ItemType Directory -Path $script:testRoot
    Write-Host ('夹具：' + $script:testRoot)
    Invoke-BrowserSuite
    $passed = $true
    Write-Host ("通过$total 组；未运行Windows原生Job Object／ACL、真实浏览器、服务或隧道。")
} finally {
    if ($testRoot -and $passed) { Remove-Item -LiteralPath $testRoot -Recurse -Force }
    elseif ($testRoot) { Write-Host ('失败夹具保留：' + $testRoot) }
}
