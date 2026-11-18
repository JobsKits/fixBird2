# Created by Jobs on 2026年11月18日，星期三.
# 内部隔离夹具：只提取存储等待函数，编译临时假CLI；不加载反部署入口或读取真实收据。
# 在已有PowerShell/.NET SDK环境调用 Test-UndoStorageWait；-LongWait并行验证61秒备份／恢复及清零超时。
# 断言失败保持非零异常，所有假进程、临时源码和产物仅属于本次夹具。
# 对隔离断言失败给出具体场景。
function Assert-StorageWait {
    param([bool]$Condition,[string]$Message)
    if (-not $Condition) { throw $Message }
    $script:StorageWaitAssertionCount++
}
# 在独立运行空间执行实际等待函数，不导入其它反部署函数或顶层语句。
function Start-StorageWaitFixture {
    param([string]$Body,[string]$Binary,[string]$Marker,[int]$Milliseconds,[int]$ExitCode,[string[]]$Arguments)
    $runner = [PowerShell]::Create()
    $null = $runner.AddScript({
        param($body,$binary,$marker,$milliseconds,$exitCode,$arguments)
        Invoke-Expression $body
        $script:Receipt = [pscustomobject]@{binary=$binary;config=[pscustomobject]@{FIXTURE_PID=$marker;FIXTURE_WAIT=[string]$milliseconds;FIXTURE_EXIT=[string]$exitCode}}
        Invoke-UndoStorageCommand $arguments
    }).AddArgument($Body).AddArgument($Binary).AddArgument($Marker).AddArgument($Milliseconds).AddArgument($ExitCode).AddArgument($Arguments)
    return [pscustomobject]@{PowerShell=$runner;Async=$runner.BeginInvoke()}
}
# 仅判断记录的本次假CLI是否仍存活，不按名称搜索或停止其它进程。
function Test-StorageFixtureAlive {
    param([int]$ProcessId)
    try { $child=[Diagnostics.Process]::GetProcessById($ProcessId); try { return -not $child.HasExited } finally { $child.Dispose() } }
    catch [ArgumentException] { return $false }
}
# 验证长备份、失败及运行空间取消（Ctrl+C使用的管线停止路径）都保留清理语义。
function Test-UndoStorageWait {
    param([switch]$LongWait)
    $ErrorActionPreference='Stop'
    $script:StorageWaitAssertionCount=0
    $source=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../../部署/Windows/Undeployment/【Windows】反部署.ps1/【Windows】反部署.ps1'))
    $tokens=$null;$parseErrors=$null
    $ast=[Management.Automation.Language.Parser]::ParseFile($source,[ref]$tokens,[ref]$parseErrors)
    Assert-StorageWait (@($parseErrors).Count -eq 0) '存储被测脚本语法错误。'
    $function=$ast.Find({param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Invoke-UndoStorageCommand'},$true)
    Assert-StorageWait ($null -ne $function) '实际存储函数缺失。'
    $body=$function.Extent.Text
    $folder=Join-Path ([IO.Path]::GetTempPath()) ('repair-storage-wait-'+[Guid]::NewGuid().ToString('N'))
    $null=New-Item -ItemType Directory -Path $folder
    $runners=@();$childIds=@()
    try {
        $sdk=(& dotnet --version).Split('.')[0]
        if($LASTEXITCODE -ne 0){throw '需要已有.NET SDK，夹具不安装依赖。'}
        [IO.File]::WriteAllText((Join-Path $folder 'StorageFixture.csproj'),('<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><OutputType>Exe</OutputType><TargetFramework>net'+$sdk+'.0</TargetFramework></PropertyGroup></Project>'))
        [IO.File]::WriteAllText((Join-Path $folder 'Program.cs'),@'
using System;
using System.IO;
using System.Threading;
File.WriteAllText(Environment.GetEnvironmentVariable("FIXTURE_PID"),Environment.ProcessId.ToString());
Console.WriteLine("fixture stdout");
Console.Error.WriteLine("fixture stderr");
Thread.Sleep(int.Parse(Environment.GetEnvironmentVariable("FIXTURE_WAIT")));
return int.Parse(Environment.GetEnvironmentVariable("FIXTURE_EXIT"));
'@)
        & dotnet build (Join-Path $folder 'StorageFixture.csproj') -o (Join-Path $folder 'out') *> (Join-Path $folder 'build.log')
        Assert-StorageWait ($LASTEXITCODE -eq 0) '假CLI编译失败，仅保留隔离验证失败。'
        $binary=Join-Path $folder 'out/StorageFixture'
        if([Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT){$binary+='.exe'}
        foreach($operation in @('-backup','-restore')){
            $marker=Join-Path $folder ($operation.TrimStart('-')+'-canceled.pid')
            $run=Start-StorageWaitFixture $body $binary $marker 120000 0 @($operation,'unused.wbbak');$runners+=,$run
            $timer=[Diagnostics.Stopwatch]::StartNew()
            while(-not (Test-Path -LiteralPath $marker) -and $timer.Elapsed.TotalSeconds -lt 10){Start-Sleep -Milliseconds 20}
            Assert-StorageWait (Test-Path -LiteralPath $marker) ('假'+$operation+'进程未启动。')
            $number=[int][IO.File]::ReadAllText($marker);$childIds+=$number
            $timer.Restart();$run.PowerShell.Stop()
            Assert-StorageWait ($timer.Elapsed.TotalSeconds -lt 7) ($operation+'取消未在有界清理窗口结束。')
            Assert-StorageWait (-not (Test-StorageFixtureAlive $number)) ($operation+'取消后假CLI仍存活。')
            Assert-StorageWait ($run.PowerShell.InvocationStateInfo.State -eq 'Stopped') ($operation+'取消不能回报成功。')
        }
        $marker=Join-Path $folder 'failed.pid'
        $failed=Start-StorageWaitFixture $body $binary $marker 10 7 @('-backup','unused.wbbak');$runners+=,$failed
        try{$null=$failed.PowerShell.EndInvoke($failed.Async)}catch{}
        Assert-StorageWait ($failed.PowerShell.HadErrors) '非零假CLI被回报成功。'
        $failureText=([string]$failed.PowerShell.InvocationStateInfo.Reason)+(($failed.PowerShell.Streams.Error | ForEach-Object { $_.ToString() }) -join "`n")
        Assert-StorageWait ($failureText -match '应用数据库备份/清零失败') '假CLI非零退出没有传播预期错误。'
        Assert-StorageWait ($failureText -notmatch 'fixture (stdout|stderr)') '失败不能泄漏原始工具输出。'
        if($LongWait){
            $longTimer=[Diagnostics.Stopwatch]::StartNew()
            $longRuns=@()
            foreach($operation in @('-backup','-restore')){
                $marker=Join-Path $folder ($operation.TrimStart('-')+'-long.pid')
                $long=Start-StorageWaitFixture $body $binary $marker 61000 0 @($operation,'unused.wbbak');$runners+=,$long
                $longRuns+=,[pscustomobject]@{Operation=$operation;Run=$long}
            }
            $marker=Join-Path $folder 'clear-timeout.pid'
            $clear=Start-StorageWaitFixture $body $binary $marker 120000 0 @('-clear');$runners+=,$clear
            $timer=[Diagnostics.Stopwatch]::StartNew()
            while(-not (Test-Path -LiteralPath $marker) -and $timer.Elapsed.TotalSeconds -lt 10){Start-Sleep -Milliseconds 20}
            Assert-StorageWait (Test-Path -LiteralPath $marker) '假清零进程未启动。'
            $number=[int][IO.File]::ReadAllText($marker);$childIds+=$number
            foreach($item in $longRuns){
                $null=$item.Run.PowerShell.EndInvoke($item.Run.Async)
                Assert-StorageWait (-not $item.Run.PowerShell.HadErrors) ('超过60秒的假'+$item.Operation+'被固定总时限中断。')
            }
            try{$null=$clear.PowerShell.EndInvoke($clear.Async)}catch{}
            Assert-StorageWait ($clear.PowerShell.HadErrors) '假清零没有在60秒限时失败。'
            Assert-StorageWait ([string]$clear.PowerShell.InvocationStateInfo.Reason -match '存储工具超时') '假清零失败原因不是预期超时。'
            Assert-StorageWait (-not (Test-StorageFixtureAlive $number)) '假清零超时后CLI仍存活。'
            Assert-StorageWait ($longTimer.Elapsed.TotalSeconds -lt 68) '并行存储等待超出61秒工作及有界清理窗口。'
        }
        # 清零仍走60秒边界，限时判断没有扩展给其它命令。
        Assert-StorageWait ($body -match '\$Arguments\[0\] -in @\(''-backup'',''-restore''\)') '无总时限作用域不明确。'
        Assert-StorageWait ($body -match '-not \$largeMaintenance -and \$timer.Elapsed.TotalSeconds -ge 60') '普通存储命令失去60秒限时。'
        [pscustomobject]@{passed=$script:StorageWaitAssertionCount;scope='actual extracted function + isolated fake native CLI; no real undeployment';longBackupSeconds=$(if($LongWait){61}else{0});longRestoreSeconds=$(if($LongWait){61}else{0});clearTimeoutSeconds=$(if($LongWait){60}else{0});cancellation='backup/restore PowerShell pipeline stop; Windows console Ctrl+C untested'} | ConvertTo-Json
    } finally {
        foreach($run in $runners){try{$run.PowerShell.Stop()}finally{$run.PowerShell.Dispose()}}
        foreach($number in $childIds){if(Test-StorageFixtureAlive $number){$child=[Diagnostics.Process]::GetProcessById($number);try{$child.Kill();$null=$child.WaitForExit(5000)}finally{$child.Dispose()}}}
        if(Test-Path -LiteralPath $folder){Remove-Item -LiteralPath $folder -Recurse -Force}
    }
}
