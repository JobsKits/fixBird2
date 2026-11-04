# 脚本自述：
# - 名称：【Windows】验证反部署.ps1；Created by Jobs on 2026年11月3日，星期二.
# - 用途：临时工程验证部署原点、默认备份、清零、恢复重试和越界拒绝。
# - 范围：只处理本脚本创建的隔离目录；不下载SDK、不连接真实数据库、不修改现有部署。
# - 边界：跨宿主替换Windows ACL和Go CLI；Windows原生ACL/Job Object及真实数据库须分别验收。
[CmdletBinding()]
param()

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$script:Passed = 0
$script:Fixture = $null
$script:OriginRoot = $null
$script:TemporaryRoot = $null
$script:BackupCalls = 0
$script:ClearCalls = 0
$script:StorageFails = $false
$script:CapturedPolicy = $null

# 失败时立即保留具体断言位置。
function Assert-True {
    param([bool]$Value, [string]$Message)
    if (-not $Value) { throw ('断言失败：' + $Message) }
    $script:Passed++
}
# 确认拒绝危险或不完整恢复方案。
function Assert-Throws {
    param([scriptblock]$Body, [string]$Message)
    $failed = $false
    try { & $Body } catch { $failed = $true }
    Assert-True $failed $Message
}
# 创建新的临时完整项目和独立机器环境，不读取现行业务资料。
function New-UndoFixture {
    param([switch]$ExistingData, [switch]$ExistingCache, [switch]$Database, [switch]$Cancelled)
    if ($script:DeployLock) { $script:DeployLock.Dispose(); $script:DeployLock = $null }
    if ($script:UndoLock) { $script:UndoLock.Dispose(); $script:UndoLock = $null }
    $case = Join-Path $script:TemporaryRoot ([Guid]::NewGuid().ToString('N'))
    $project = Join-Path $case '项目 带空格'
    $null = New-Item -ItemType Directory -Force -Path (Join-Path $project '部署')
    $null = New-Item -ItemType Directory -Force -Path (Join-Path $project '代码/后端/后端代码')
    [IO.File]::WriteAllText((Join-Path $project '部署/deploy-tools.lock.tsv'), 'fixture')
    [IO.File]::WriteAllText((Join-Path $project '代码/后端/后端代码/go.mod'), 'module fixture')
    $script:ProjectRoot = $project
    $env:WB_RUNTIME_DIR = Join-Path $case 'state/Runtime'
    $env:WB_ENV_ROOT = Join-Path $case 'machine-cache'
    $env:WB_UNDEPLOY_BACKUP_DIR = Join-Path $case '退役备份'
    $script:RunDirectory = $null; $script:LogFile = $null; $script:Receipt = $null; $script:MissingParents = @(); $script:Session = $null; $script:BackupDirectory = $null
    Initialize-StoragePaths
    $data = Join-Path $script:RuntimeRoot 'data'; $key = Join-Path $script:RuntimeRoot 'keys/storage.key'
    if ($ExistingData) {
        $null = New-Item -ItemType Directory -Force -Path $data, ([IO.Path]::GetDirectoryName($key))
        [IO.File]::WriteAllText((Join-Path $data 'snapshot.enc'), 'initial-business')
        [IO.File]::WriteAllBytes($key, [byte[]](1..32))
    }
    $originalCache = $null
    if ($ExistingCache) {
        $null = New-Item -ItemType Directory -Force -Path $script:ProjectCacheRoot
        [IO.File]::WriteAllText((Join-Path $script:ProjectCacheRoot '原有工具.txt'), 'original-tool')
        $originalCache = Get-DeploymentFingerprint $script:ProjectCacheRoot
    }
    Initialize-RunDirectory
    $null = New-Item -ItemType Directory -Force -Path $script:ProjectCacheRoot
    [IO.File]::WriteAllText((Join-Path $script:ProjectCacheRoot '本次SDK.txt'), 'new-sdk')
    if (-not $Cancelled) {
        $script:AppEnvironment = @{ WB_DATA_DIR=$data; WB_KEY_FILE=$key; WB_TIDB_DSN=$(if($Database){'fixture-private-dsn'}else{''}); WB_REQUIRE_DB_TLS=''; WB_PROJECT_ROOT=$project; WB_RUNTIME_DIR=$script:RuntimeRoot }
        Save-DeploymentConfiguration
        $null = New-Item -ItemType Directory -Force -Path $data, ([IO.Path]::GetDirectoryName($key))
        [IO.File]::WriteAllText((Join-Path $data 'snapshot.enc'), 'current-business')
        [IO.File]::WriteAllBytes($key, [byte[]](1..32))
        $script:Receipt.binary = Join-Path $script:RunDirectory 'workbench.exe'
        [IO.File]::WriteAllText($script:Receipt.binary, 'fixture-program')
        Save-DeploymentReceipt
    }
    Clear-OwnedDeployment
    Read-UndoReceipt
    $script:Fixture = [pscustomobject]@{ root=$case; project=$project; runtime=$script:RuntimeRoot; cache=$script:ProjectCacheRoot; data=$data; key=$key; previousCache=$originalCache }
    $script:BackupCalls = 0; $script:ClearCalls = 0; $script:StorageFails = $false
}
# 验证真实入口从无关工作目录发现自己的完整工程。
function Test-ProjectDiscovery {
    Push-Location $script:TemporaryRoot
    try { Assert-True ((Find-RepairProjectRoot ([IO.Path]::GetDirectoryName($script:DeployScript))) -ceq $script:OriginRoot) '包装入口按文件位置发现工程' }
    finally { Pop-Location }
    Assert-Throws { Find-RepairProjectRoot $script:TemporaryRoot } '不完整工程拒绝猜测'
}
# 默认备份验证成功后移除本次业务、密钥及新SDK，保留外置配对副本。
function Test-BackupAndClear {
    New-UndoFixture
    Invoke-UndoSelection backup
    Assert-True ($script:BackupCalls -eq 1) '文件模式也通过应用CLI核验备份'
    Assert-True (-not (Test-Path -LiteralPath $script:Fixture.data)) '备份后清理源业务目录'
    Assert-True (-not (Test-Path -LiteralPath $script:Fixture.key)) '备份后清理源密钥'
    Assert-True (-not (Test-Path -LiteralPath $script:Fixture.cache)) '清理本次新SDK'
    Assert-True ((Get-Content -LiteralPath (Join-Path $script:BackupDirectory 'data/snapshot.enc') -Raw) -ceq 'current-business') '完整保留当前业务副本'
    Assert-True ([Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $script:BackupDirectory 'storage.key'))) -ceq [Convert]::ToBase64String([byte[]](1..32))) '匹配密钥字节保留'
    Assert-True (Test-Path -LiteralPath $script:HistoryFile) '历史完成记录保存在Runtime外'
    Assert-True (-not (Test-Path -LiteralPath $script:Fixture.runtime)) '首次部署Runtime与锁均撤回'
    Read-UndoReceipt
    Assert-True (-not $script:Receipt) '再次发现无活动原点'
    New-UndoFixture -ExistingData -ExistingCache
    Invoke-UndoSelection backup
    Assert-True (-not (Test-Path -LiteralPath $script:Fixture.data)) '既有业务也按明确备份策略清理源'
    Assert-True ((Get-DeploymentFingerprint $script:Fixture.cache) -ceq $script:Fixture.previousCache) '原有工具恢复且新增工具移除'
    Assert-True (Test-Path -LiteralPath $script:Fixture.runtime) '部署前已有Runtime保留'
    New-UndoFixture -ExistingData
    Invoke-UndoSelection clear
    Assert-True ($script:BackupCalls -eq 0) '清零不执行业务备份'
    Assert-True (-not (Test-Path -LiteralPath $script:Fixture.data)) '清零删除源业务'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $script:BackupDirectory 'data'))) '清零仅留原点审计'
    New-UndoFixture -Cancelled
    Invoke-UndoSelection backup
    Assert-True (-not (Test-Path -LiteralPath $script:Fixture.cache)) '未进入业务即取消的依赖也可撤回'
}
# 失败保留源数据与活动记录，逐项恢复中断后复用同一已验证备份。
function Test-FailureAndResume {
    New-UndoFixture
    $script:StorageFails = $true
    Assert-Throws { Invoke-UndoSelection backup } '备份失败阻止清理'
    Assert-True (Test-Path -LiteralPath $script:Fixture.data) '备份失败保留业务'
    Assert-True (Test-Path -LiteralPath $script:ReceiptDirectory) '备份失败保留活动原点'
    $script:StorageFails = $false
    $original = ${function:Restore-UndoArtifacts}
    function script:Restore-UndoArtifacts {
        $row = @($script:Receipt.artifacts)[-1]
        if (Test-Path -LiteralPath $row.path) { Remove-Item -LiteralPath $row.path -Recurse -Force }
        throw 'fixture-interrupted-restore'
    }
    Assert-Throws { Invoke-UndoSelection backup } '产物部分恢复中断'
    $priorBackup = $script:BackupDirectory
    Set-Item -LiteralPath Function:script:Restore-UndoArtifacts -Value $original
    Read-UndoReceipt
    Assert-Throws { Invoke-UndoSelection clear } '恢复中不得更改已确认数据策略'
    Read-UndoReceipt
    Invoke-UndoSelection backup
    Assert-True ($script:BackupDirectory -ceq $priorBackup) '重试复用原已核验备份'
    Assert-True (-not (Test-Path -LiteralPath $script:Fixture.cache)) '重试完成全部产物撤回'
    Assert-True (Test-Path -LiteralPath (Join-Path $priorBackup 'database.wbbak')) '中断后业务备份仍在'
}
# 已有缓存先准备原副本再原子替换，中途失败可续跑并拒绝未知暂存修改。
function Test-ExistingRestoreFailure {
    $saveReceipt = ${function:Save-UndoReceipt}
    $moveArtifact = ${function:Move-UndoArtifact}
    try {
        New-UndoFixture -ExistingCache
        $script:RestoreCopyFails = $true
        function script:Copy-Item {
            [CmdletBinding()]
            param([string]$LiteralPath,[string]$Destination,[switch]$Recurse,[switch]$Force)
            if ($script:RestoreCopyFails -and [IO.Path]::GetFileName($Destination) -like '.RepairUndoArtifactStage-*') {
                $script:RestoreCopyFails = $false
                $null = New-Item -ItemType Directory -Path $Destination
                [IO.File]::WriteAllText((Join-Path $Destination 'partial.txt'),'fixture-partial-copy')
                throw 'fixture-interrupted-copy'
            }
            Microsoft.PowerShell.Management\Copy-Item @PSBoundParameters
        }
        Assert-Throws { Invoke-UndoSelection backup } '已有缓存准备副本复制失败'
        $row = @($script:Receipt.artifacts | Where-Object { $_.before -eq 'existing' })[0]
        $stage = $row.restore.stage
        $retired = $row.restore.retired
        Assert-True ((Get-DeploymentFingerprint $row.path) -ceq $row.after) '复制失败尚未改变原缓存'
        Assert-True ((Get-DeploymentFingerprint $stage) -ceq $row.restore.stageHash) '部分复制摘要持久登记'
        Assert-True ((Get-DeploymentFingerprint (Join-Path $script:ReceiptDirectory $row.backup)) -ceq $row.beforeHash) '复制失败保留原点副本'
        Remove-Item -LiteralPath Function:Copy-Item
        Read-UndoReceipt
        Invoke-UndoSelection backup
        Assert-True ((Get-DeploymentFingerprint $script:Fixture.cache) -ceq $script:Fixture.previousCache) '部分副本安全重建并恢复已有缓存'
        Assert-True (-not (Test-Path -LiteralPath $stage) -and -not (Test-Path -LiteralPath $retired)) '成功后无准备和退休副本遗留'

        New-UndoFixture -ExistingCache
        $script:RestoreSavePhase = 'retired'
        function script:Save-UndoReceipt {
            if (@($script:Receipt.artifacts | Where-Object { $_.before -eq 'existing' -and $_.PSObject.Properties.Name -contains 'restore' -and $_.restore.phase -eq $script:RestoreSavePhase }).Count) {
                $script:RestoreSavePhase = ''
                throw 'fixture-interrupted-journal-save'
            }
            & $script:RestoreSavedReceipt
        }
        $script:RestoreSavedReceipt = $saveReceipt
        Assert-Throws { Invoke-UndoSelection backup } '原缓存移至退休目录后日志保存中断'
        Set-Item -LiteralPath Function:script:Save-UndoReceipt -Value $saveReceipt
        Read-UndoReceipt
        $row = @($script:Receipt.artifacts | Where-Object { $_.before -eq 'existing' })[0]
        Assert-True ($row.restore.phase -eq 'prepared' -and -not (Test-Path -LiteralPath $row.path)) '重启读取移动前意图且原路径未重建'
        Assert-True ((Get-DeploymentFingerprint $row.restore.retired) -ceq $row.after) '退休副本保留本次部署内容'
        Invoke-UndoSelection backup
        Assert-True ((Get-DeploymentFingerprint $script:Fixture.cache) -ceq $script:Fixture.previousCache) '移动完成日志未写也能推断续跑'

        New-UndoFixture -ExistingCache
        $script:RestoreSavePhase = 'installed'
        function script:Save-UndoReceipt {
            if (@($script:Receipt.artifacts | Where-Object { $_.before -eq 'existing' -and $_.PSObject.Properties.Name -contains 'restore' -and $_.restore.phase -eq $script:RestoreSavePhase }).Count) {
                $script:RestoreSavePhase = ''
                throw 'fixture-interrupted-install-save'
            }
            & $script:RestoreSavedReceipt
        }
        Assert-Throws { Invoke-UndoSelection backup } '原副本已回到原路径后日志保存中断'
        Set-Item -LiteralPath Function:script:Save-UndoReceipt -Value $saveReceipt
        Read-UndoReceipt
        $row = @($script:Receipt.artifacts | Where-Object { $_.before -eq 'existing' })[0]
        Assert-True ($row.restore.phase -eq 'retired' -and (Get-DeploymentFingerprint $row.path) -ceq $row.beforeHash) '旧日志可识别已经装回原副本'
        Invoke-UndoSelection backup
        Assert-True ((Get-DeploymentFingerprint $script:Fixture.cache) -ceq $script:Fixture.previousCache) '安装移动完成日志未写可继续清退休副本'

        New-UndoFixture -ExistingCache
        $script:RestoreRemoveFails = $true
        function script:Remove-Item {
            [CmdletBinding()]
            param([string]$LiteralPath,[switch]$Recurse,[switch]$Force)
            if ($script:RestoreRemoveFails -and [IO.Path]::GetFileName($LiteralPath) -like '.RepairUndoArtifactRetired-*' -and (Test-Path -LiteralPath (Join-Path $LiteralPath '本次SDK.txt'))) {
                $script:RestoreRemoveFails = $false
                Microsoft.PowerShell.Management\Remove-Item -LiteralPath (Join-Path $LiteralPath '本次SDK.txt') -Force
                throw 'fixture-interrupted-retired-cleanup'
            }
            Microsoft.PowerShell.Management\Remove-Item @PSBoundParameters
        }
        Assert-Throws { Invoke-UndoSelection backup } '已装回旧缓存后退休副本部分删除失败'
        Microsoft.PowerShell.Management\Remove-Item -LiteralPath Function:Remove-Item
        $row = @($script:Receipt.artifacts | Where-Object { $_.before -eq 'existing' })[0]
        Assert-True ((Get-DeploymentFingerprint $row.path) -ceq $row.beforeHash) '退休副本清理失败不破坏已恢复旧缓存'
        Assert-True ((Get-DeploymentFingerprint $row.restore.retired) -ceq $row.restore.retiredHash -and $row.restore.retiredHash -cne $row.after) '部分清理摘要已登记'
        Read-UndoReceipt
        Invoke-UndoSelection backup
        Assert-True ((Get-DeploymentFingerprint $script:Fixture.cache) -ceq $script:Fixture.previousCache) '部分删除续跑只清隔离副本'

        New-UndoFixture -ExistingCache
        $script:RestoreCopyFails = $true
        function script:Copy-Item {
            [CmdletBinding()]
            param([string]$LiteralPath,[string]$Destination,[switch]$Recurse,[switch]$Force)
            if ($script:RestoreCopyFails -and [IO.Path]::GetFileName($Destination) -like '.RepairUndoArtifactStage-*') {
                $script:RestoreCopyFails = $false
                $null = New-Item -ItemType Directory -Path $Destination
                [IO.File]::WriteAllText((Join-Path $Destination 'partial.txt'),'fixture-partial-copy')
                throw 'fixture-interrupted-copy'
            }
            Microsoft.PowerShell.Management\Copy-Item @PSBoundParameters
        }
        Assert-Throws { Invoke-UndoSelection backup } '建立部分准备副本供并发修改验证'
        Remove-Item -LiteralPath Function:Copy-Item
        $row = @($script:Receipt.artifacts | Where-Object { $_.before -eq 'existing' })[0]
        [IO.File]::WriteAllText((Join-Path $row.restore.stage 'later.txt'),'later-user-change')
        $changedStage = Get-DeploymentFingerprint $row.restore.stage
        Read-UndoReceipt
        Assert-Throws { Invoke-UndoSelection backup } '未知准备副本修改拒绝删除重建'
        Assert-True ((Get-DeploymentFingerprint $row.restore.stage) -ceq $changedStage) '保留后续修改的准备副本'
        Assert-True ((Get-DeploymentFingerprint $row.path) -ceq $row.after) '冲突时保留原缓存'
        $bad = $script:Receipt | ConvertTo-Json -Depth 12 | ConvertFrom-Json
        $badRow = @($bad.artifacts | Where-Object { $_.before -eq 'existing' })[0]
        $badRow.restore.retired = Join-Path $script:Fixture.root 'unowned'
        Assert-Throws { Assert-UndoReceipt $bad } '恢复日志不能指定任意删除目标'

        New-UndoFixture -ExistingCache
        $script:RestoreMovedArtifact = $moveArtifact
        $script:RestoreRecreatePath = $script:Fixture.cache
        function script:Move-UndoArtifact {
            param([string]$Source,[string]$Destination)
            & $script:RestoreMovedArtifact $Source $Destination
            if ($Source -ceq $script:RestoreRecreatePath) {
                $null = New-Item -ItemType Directory -Path $Source
                [IO.File]::WriteAllText((Join-Path $Source 'new-owner.txt'),'later-owner')
            }
        }
        Assert-Throws { Invoke-UndoSelection backup } '原路径在退休后被重建时停止'
        Assert-True ([IO.File]::ReadAllText((Join-Path $script:Fixture.cache 'new-owner.txt')) -ceq 'later-owner') '不递归删除后续重建的原缓存路径'
        $row = @($script:Receipt.artifacts | Where-Object { $_.before -eq 'existing' })[0]
        Assert-True ((Get-DeploymentFingerprint $row.restore.retired) -ceq $row.after) '路径冲突仍保留退休副本'
    } finally {
        if (Test-Path -LiteralPath Function:Remove-Item) { Microsoft.PowerShell.Management\Remove-Item -LiteralPath Function:Remove-Item }
        if (Test-Path -LiteralPath Function:Copy-Item) { Remove-Item -LiteralPath Function:Copy-Item }
        Set-Item -LiteralPath Function:script:Save-UndoReceipt -Value $saveReceipt
        Set-Item -LiteralPath Function:script:Move-UndoArtifact -Value $moveArtifact
    }
}
# 数据库两策略只调用应用CLI，不删除数据库或共用工具。
function Test-DatabasePolicies {
    New-UndoFixture -Database
    Invoke-UndoSelection backup
    Assert-True ($script:BackupCalls -eq 1 -and $script:ClearCalls -eq 1) '数据库备份验证后清理本应用记录'
    Assert-True (-not (Test-Path -LiteralPath $script:Fixture.key)) '数据库匹配key已外置备份并撤回源'
    New-UndoFixture -Database
    $script:StorageFails=$true
    Assert-Throws { Invoke-UndoSelection clear } '数据库清理失败拒绝删除文件或依赖'
    Assert-True (Test-Path -LiteralPath $script:Fixture.data) '数据库失败保留文件上下文'
    Assert-True (Test-Path -LiteralPath $script:Fixture.key) '数据库失败保留匹配key'
}
# 全部PID身份核验成功后才允许停止，拒绝复用或身份变化的PID。
function Test-ProcessIdentity {
    if ($env:OS -eq 'Windows_NT') { $exe=(Get-Process -Id $PID).MainModule.FileName; $arguments=@('-NoLogo','-NoProfile','-Command','Start-Sleep -Seconds 30') }
    else { $exe='/bin/sleep'; $arguments=@('30') }
    $first=Start-Process -FilePath $exe -ArgumentList $arguments -PassThru
    $second=Start-Process -FilePath $exe -ArgumentList $arguments -PassThru
    try {
        $script:Receipt=[pscustomobject]@{processes=@(
            [pscustomobject]@{pid=$first.Id;started=$first.StartTime.ToUniversalTime().Ticks.ToString();executable=$first.MainModule.FileName},
            [pscustomobject]@{pid=$second.Id;started='1';executable=$second.MainModule.FileName}
        )}
        Assert-Throws { Stop-RecordedProcesses } 'PID身份改变不终止任一登记进程'
        $first.Refresh();$second.Refresh()
        Assert-True (-not $first.HasExited -and -not $second.HasExited) '批量身份核验先于终止'
        $script:Receipt.processes[1].started=$second.StartTime.ToUniversalTime().Ticks.ToString()
        Stop-RecordedProcesses
        $first.Refresh();$second.Refresh()
        Assert-True ($first.HasExited -and $second.HasExited) '只终止两个真实登记子进程'
    } finally { foreach($process in @($first,$second)){if(-not $process.HasExited){$process.Kill()};$process.Dispose()} }
}
# Go缓存全部约束于本项目，父进程显式GOPATH不被修改。
function Test-GoCacheScope {
    New-UndoFixture
    $env:GOPATH='fixture-parent-go-path'
    function script:Get-NetTCPConnection {}
    Set-WorkbenchEnvironment
    Assert-True ($script:AppEnvironment.GOPATH -ceq (Join-Path $script:ProjectCacheRoot 'GoCache/Path')) 'Go子进程使用专属GOPATH'
    Assert-True ($env:GOPATH -ceq 'fixture-parent-go-path') '保留父进程显式GOPATH'
}
# 跨宿主假fzf验证默认、取消、非法结果及SDK移除后的恢复选择器。
function Test-MenuAndRetryTool {
    if ($env:OS -eq 'Windows_NT') { return }
    New-UndoFixture
    $fzf = Join-Path $script:Fixture.cache 'fzf.exe'
    $body=@'
#!/bin/sh
if [ "$1" = '--version' ]; then echo '0.74.5'; exit 0; fi
if [ -n "$FZF_DEFAULT_OPTS" ]; then exit 41; fi
case "$REPAIR_TEST_FZF" in
    cancel) exit 130 ;;
    invalid) echo 'unknown|untrusted'; exit 0 ;;
    *) head -n 1 ;;
esac
'@
    [IO.File]::WriteAllText($fzf,$body,(New-Object Text.UTF8Encoding($false)))
    & /bin/chmod +x $fzf
    $script:Receipt.artifacts[0].after = Get-DeploymentFingerprint $script:Fixture.cache
    Save-UndoReceipt
    $selected = Find-UndoFzf
    Assert-True ($selected -ceq $fzf) '只选经过缓存摘要与版本检查的fzf'
    $env:FZF_DEFAULT_OPTS='fixture-parent-options'
    $env:REPAIR_TEST_FZF='first'
    $choice=Select-UndoChoice $selected @('backup|默认备份','clear|清零','cancel|取消') 'fixture'
    Assert-True ($choice -ceq 'backup') '默认选择备份'
    Assert-True ($env:FZF_DEFAULT_OPTS -ceq 'fixture-parent-options') '选择器父环境按原值恢复'
    $env:REPAIR_TEST_FZF='cancel'
    Assert-True ((Select-UndoChoice $selected @('backup|备份','cancel|取消') 'fixture') -ceq 'cancel') '菜单取消不返回业务选项'
    $env:REPAIR_TEST_FZF='invalid'
    Assert-Throws { Select-UndoChoice $selected @('backup|备份') 'fixture' } '未登记菜单输出拒绝执行'
    Assert-True (Test-Path -LiteralPath $script:Fixture.data) '选择阶段未动业务数据'
    $complete=${function:Complete-UndoOperation}
    function script:Complete-UndoOperation { throw 'fixture-history-write-failure' }
    Assert-Throws { Invoke-UndoSelection backup } '完成标记失败保留活动原点'
    $backup=$script:BackupDirectory
    Assert-True (-not (Test-Path -LiteralPath $script:Fixture.cache)) '故障点已撤回本次SDK'
    Set-Item -LiteralPath Function:script:Complete-UndoOperation -Value $complete
    Read-UndoReceipt
    $script:UndoFzfExecutable=$null
    $resumed=Find-UndoFzf
    Assert-True ($resumed -ceq (Join-Path $script:ReceiptDirectory 'undo-fzf.exe')) 'SDK已撤回仍可使用私有恢复fzf'
    Invoke-UndoSelection backup
    Assert-True ($script:BackupDirectory -ceq $backup) '最终重试复用同一业务备份'
    Assert-True (-not (Test-Path -LiteralPath $resumed)) '完成后清理临时恢复选择器'
    $script:UndoFzfExecutable=$null
}
# 活writer与备份后变化均保留源；隔离后同名新路径不会被递归删除。
function Test-DataRetirementBoundaries {
    New-UndoFixture
    [IO.File]::WriteAllText((Join-Path $script:Fixture.data 'writer.lock'),[string]$PID)
    Assert-Throws { Invoke-UndoSelection clear } '活writer阻止文件清零'
    Assert-True (Test-Path -LiteralPath $script:Fixture.key) '拒绝活writer时保留key'
    New-UndoFixture
    $originalBackup=${function:Backup-UndoData}
    $script:OriginalBackupAction=$originalBackup
    function script:Backup-UndoData { & $script:OriginalBackupAction; [IO.File]::WriteAllText((Join-Path $script:Fixture.data 'snapshot.enc'),'short-lived-writer') }
    Assert-Throws { Invoke-UndoSelection backup } '备份后新写入不被旧副本覆盖清理'
    Assert-True ((Get-Content -LiteralPath (Join-Path $script:Fixture.data 'snapshot.enc') -Raw) -ceq 'short-lived-writer') '保留未备份的新写入'
    $firstBackup=$script:BackupDirectory
    Set-Item -LiteralPath Function:script:Backup-UndoData -Value $originalBackup
    Read-UndoReceipt
    Assert-Throws { Invoke-UndoSelection backup } '重试不静默重做备份或清理未确认的新业务'
    Assert-True ($script:BackupDirectory -ceq $firstBackup -and (Test-Path -LiteralPath $firstBackup)) '保留原已确认备份'
    Assert-True ((Get-Content -LiteralPath (Join-Path $script:Fixture.data 'snapshot.enc') -Raw) -ceq 'short-lived-writer') '保留需另行核对的新业务'
    New-UndoFixture
    function script:Remove-Item {
        param([string]$LiteralPath,[switch]$Recurse,[switch]$Force)
        if([IO.Path]::GetFileName($LiteralPath) -like '.RepairUndoData-*'){
            $null=New-Item -ItemType Directory -Force -Path $script:Fixture.data,([IO.Path]::GetDirectoryName($script:Fixture.key))
            [IO.File]::WriteAllText((Join-Path $script:Fixture.data 'snapshot.enc'),'later-writer')
            [IO.File]::WriteAllBytes($script:Fixture.key,[byte[]](2..33))
        }
        Microsoft.PowerShell.Management\Remove-Item -LiteralPath $LiteralPath -Recurse:$Recurse -Force:$Force
    }
    try{Assert-Throws { Invoke-UndoSelection backup } '隔离后重建源路径报告冲突'}
    finally{Microsoft.PowerShell.Management\Remove-Item -LiteralPath Function:Remove-Item}
    Assert-True ((Get-Content -LiteralPath (Join-Path $script:Fixture.data 'snapshot.enc') -Raw) -ceq 'later-writer') '新建数据未被递归删除'
    Assert-True ([Convert]::ToBase64String([IO.File]::ReadAllBytes($script:Fixture.key)) -ceq [Convert]::ToBase64String([byte[]](2..33))) '新建key未被删除'
    Read-UndoReceipt
    Assert-Throws { Invoke-UndoSelection backup } '重试仍不删除后续写入者的新路径'
    New-UndoFixture
    $inside=Join-Path $script:Fixture.data 'storage.key'
    $previousKeyDirectory=[IO.Path]::GetDirectoryName($script:Fixture.key)
    [IO.File]::Move($script:Fixture.key,$inside)
    if(@(Get-ChildItem -LiteralPath $previousKeyDirectory -Force).Count -eq 0){Microsoft.PowerShell.Management\Remove-Item -LiteralPath $previousKeyDirectory -Force}
    $script:Fixture.key=$inside; $script:Receipt.config.WB_KEY_FILE=$inside
    $script:Receipt.missingParents=@($script:Receipt.missingParents | Where-Object { $_ -cne $previousKeyDirectory })
    Save-UndoReceipt
    Read-UndoReceipt
    Invoke-UndoSelection backup
    Assert-True (-not (Test-Path -LiteralPath $script:Fixture.data)) '数据内key随数据同一次原子隔离'
    Assert-True (Test-Path -LiteralPath (Join-Path $script:BackupDirectory 'storage.key')) '数据内key仍有独立匹配副本'
}
# 收据篡改、目录交叉及用户后续改动都必须在删除前被拒绝。
function Test-ReceiptBoundaries {
    New-UndoFixture
    [IO.File]::WriteAllText((Join-Path $script:Fixture.cache 'later-user-file.txt'), 'keep')
    Assert-Throws { Invoke-UndoSelection backup } '后续修改不能被旧原点覆盖'
    Assert-True (Test-Path -LiteralPath $script:Fixture.data) '冲突时未清业务'
    New-UndoFixture
    $receipt = Get-Content -LiteralPath (Join-Path $script:ReceiptDirectory 'receipt.json') -Raw | ConvertFrom-Json
    $receipt.artifacts[0].path = Join-Path $script:RuntimeRoot 'windows-deploy/../../unrelated'
    Assert-Throws { Assert-UndoReceipt $receipt } '拒绝带点段的产物路径'
    $receipt = Get-Content -LiteralPath (Join-Path $script:ReceiptDirectory 'receipt.json') -Raw | ConvertFrom-Json
    $receipt.binary = Join-Path $script:Fixture.root 'other-program.exe'
    Assert-Throws { Assert-UndoReceipt $receipt } '拒绝范围外应用程序'
    $receipt = Get-Content -LiteralPath (Join-Path $script:ReceiptDirectory 'receipt.json') -Raw | ConvertFrom-Json
    $receipt.missingParents = @((Join-Path $script:Fixture.root 'other-empty-directory'))
    Assert-Throws { Assert-UndoReceipt $receipt } '拒绝任意空目录回收'
    $receipt = Get-Content -LiteralPath (Join-Path $script:ReceiptDirectory 'receipt.json') -Raw | ConvertFrom-Json
    $receipt.config.WB_DATA_DIR = Join-Path $script:ReceiptDirectory 'inside'
    Assert-Throws { Assert-UndoReceipt $receipt } '拒绝数据与原点重叠'
    Assert-Throws { Assert-BackupTarget $script:RuntimeRoot } '拒绝原点内备份'
    Assert-Throws { Assert-BackupTarget $script:Fixture.root } '拒绝覆盖待清理产物的备份上级'
    $receipt = Get-Content -LiteralPath (Join-Path $script:ReceiptDirectory 'receipt.json') -Raw | ConvertFrom-Json
    $receipt.artifacts[0].path = Join-Path $script:Fixture.root 'outside'
    [IO.File]::WriteAllText((Join-Path $script:ReceiptDirectory 'receipt.json'), ($receipt|ConvertTo-Json -Depth 12))
    Assert-Throws { Invoke-UndoSelection backup } '锁内重读收据仍须验证范围'
    Assert-True (Test-Path -LiteralPath $script:Fixture.data) '替换收据不影响业务'
    New-UndoFixture
    $file=Join-Path $script:ReceiptDirectory 'receipt.json'
    $receipt=Get-Content -LiteralPath $file -Raw | ConvertFrom-Json
    $receipt.project='unrelated-project'
    [IO.File]::WriteAllText($file,($receipt|ConvertTo-Json -Depth 12))
    $hash=(Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash
    Assert-Throws { Initialize-RunDirectory } '部署拒绝其它项目原点'
    Clear-OwnedDeployment
    Assert-True ((Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash -ceq $hash) '失败清理不能重新封存被拒绝收据'
}
# 即使封存摘要失败也必须释放部署锁。
function Test-DeploymentLockRelease {
    New-UndoFixture
    $lock = Join-Path $script:RuntimeRoot 'windows-deploy.lock'
    $script:DeployLock = New-Object IO.FileStream($lock,[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
    $original = ${function:Complete-DeploymentReceipt}
    function script:Complete-DeploymentReceipt { throw 'fixture-finalization-error' }
    Assert-Throws { Clear-OwnedDeployment } '封存错误必须向上传播'
    Set-Item -LiteralPath Function:script:Complete-DeploymentReceipt -Value $original
    Assert-True (-not $script:DeployLock) '封存失败仍释放锁句柄'
    $probe = New-Object IO.FileStream($lock,[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
    $probe.Dispose(); $script:Passed++
}
# 建立隔离宿主，替换平台ACL与存储CLI，不调用真实服务。
function Invoke-UndeploymentRegression {
    $root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))
    $script:DeployScript = Join-Path $root '部署/Windows/Deployment/【Windows】部署.ps1/【Windows】部署.ps1'
    $undoScript = Join-Path $root '部署/Windows/Undeployment/【Windows】反部署.ps1/【Windows】反部署.ps1'
    $saved = @{}
    foreach ($name in @('WB_RUNTIME_DIR','WB_ENV_ROOT','WB_UNDEPLOY_BACKUP_DIR','WB_DATA_DIR','WB_KEY_FILE','WB_TIDB_DSN','WB_REQUIRE_DB_TLS','LOCALAPPDATA','GOPATH','FZF_DEFAULT_OPTS','REPAIR_TEST_FZF')) { $saved[$name]=[Environment]::GetEnvironmentVariable($name) }
    $temporary = [IO.Path]::GetTempPath()
    if ($env:OS -ne 'Windows_NT' -and (Test-Path -LiteralPath '/private/tmp')) { $temporary='/private/tmp' }
    $script:TemporaryRoot = Join-Path $temporary ('repair-undo-regression-' + [Guid]::NewGuid().ToString('N'))
    $null = New-Item -ItemType Directory -Path $script:TemporaryRoot
    try {
        . $script:DeployScript
        . $undoScript
        $script:OriginRoot = $script:ProjectRoot
        $names = @()
        foreach ($source in @($script:DeployScript,$undoScript)) {
            $tokens=$null; $parseErrors=$null
            $ast=[Management.Automation.Language.Parser]::ParseFile($source,[ref]$tokens,[ref]$parseErrors)
            if (@($parseErrors).Count) { throw '被测脚本解析失败。' }
            $names += @($ast.FindAll({param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst]},$true) | ForEach-Object { $_.Name })
        }
        foreach ($name in @($names | Select-Object -Unique)) {
            $body=(Get-Item -LiteralPath ('Function:'+$name)).ScriptBlock
            Remove-Item -LiteralPath ('Function:'+$name)
            Set-Item -LiteralPath ('Function:script:'+$name) -Value $body
        }
        function script:Protect-PrivateDirectory { param([string]$Path) }
        function script:Invoke-UndoStorageCommand {
            param([string[]]$Arguments)
            if ($script:StorageFails) { throw 'fixture-storage-failure' }
            if ($Arguments[0] -eq '-backup') {
                $script:BackupCalls++
                $file=$Arguments[1]
                [IO.File]::WriteAllText($file,'fixture-validated-database')
                [IO.File]::WriteAllText(($file+'.manifest.json'),(@{sha256=(Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash;bytes=(Get-Item -LiteralPath $file).Length}|ConvertTo-Json))
            } elseif ($Arguments[0] -eq '-clear-storage' -and $Arguments[1] -eq '-confirm-clear-storage') {
                if($script:Receipt.undo.policy -eq 'backup' -and ($Arguments.Count -ne 4 -or $Arguments[2] -ne '-clear-storage-backup' -or $Arguments[3] -cne (Join-Path $script:BackupDirectory 'database.wbbak'))){throw 'fixture-missing-backup-reference'}
                if($script:Receipt.undo.policy -eq 'clear' -and $Arguments.Count -ne 2){throw 'fixture-unexpected-backup-for-clear'}
                $script:ClearCalls++
            }
            else { throw 'fixture-unexpected-command' }
        }
        Test-ProjectDiscovery
        Test-BackupAndClear
        Test-FailureAndResume
        Test-ExistingRestoreFailure
        Test-ReceiptBoundaries
        Test-DeploymentLockRelease
        Test-DatabasePolicies
        Test-GoCacheScope
        Test-ProcessIdentity
        Test-MenuAndRetryTool
        Test-DataRetirementBoundaries
        [pscustomobject]@{ passed=$script:Passed; host=$PSVersionTable.OS; scope='isolated files and fixture CLI; no production data or native Windows ACL/Job Object' } | ConvertTo-Json
    } finally {
        if ($script:DeployLock) { $script:DeployLock.Dispose(); $script:DeployLock=$null }
        if ($script:UndoLock) { $script:UndoLock.Dispose(); $script:UndoLock=$null }
        foreach ($name in $saved.Keys) { [Environment]::SetEnvironmentVariable($name,$saved[$name],'Process') }
        if (Test-Path -LiteralPath $script:TemporaryRoot) { Remove-Item -LiteralPath $script:TemporaryRoot -Recurse -Force }
    }
}

Invoke-UndeploymentRegression
