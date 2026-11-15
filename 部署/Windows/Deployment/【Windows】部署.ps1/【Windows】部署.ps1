# 脚本自述：
# - 名称：【Windows】部署.ps1；Created by Jobs on 2026年11月2日，星期一.
# - 用途：fzf选择本机受限穿透演示或正常服务器运行，构建当前维修工作台。
# - 范围：仅本项目独立运行目录、机器公共工具缓存与本次子进程；不改系统服务、PATH、防火墙或业务源码。
# - 提示：正常入口先回车确认；Esc取消，子菜单左键返回；Ctrl+C停止本次服务和隧道。
# - 网页：启动成功后显示各端URL和离线二维码；fzf可打开公网／本机地址或扫码页，终端与服务保持运行。
# - 只读：-Check与-Plan不联网、不写入、不启动工具或服务；-Mode仅配合-Plan审阅。
[CmdletBinding()]
param(
    [switch]$Check,
    [switch]$Plan,
    [ValidateSet('local', 'server')]
    [string]$Mode
)
# Jobs enter-choice emphasis is display-only; input and business decisions stay with callers.
# BEGIN JOBS_TERMINAL_STYLE_V1 - session-only colors; no profile or registry changes.
function New-JobsTerminalStyleState {
    if ($PSVersionTable.PSVersion.Major -lt 5) { return @{ JobsTerminalPlainFallback = $true; Before = @{} } }
    if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT -or $Host.Name -ne 'ConsoleHost') { return $null }
    if ([Console]::IsInputRedirected -or [Console]::IsOutputRedirected -or [Console]::IsErrorRedirected) { return $null }
    if ((Test-Path Env:NO_COLOR) -or $env:TERM -ieq 'dumb' -or $env:PLAIN_OUTPUT -eq '1') { return $null }
    foreach ($key in [Environment]::GetEnvironmentVariables().Keys) {
        if ([string]$key -match '^(?i:SOURCE_?TREE)') { return $null }
    }
    if (-not ('Jobs.TerminalStyleV1.Native' -as [type])) {
        try {
        Add-Type -ErrorAction Stop -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Text.RegularExpressions;
namespace Jobs.TerminalStyleV1 {
    public static class Native {
        [StructLayout(LayoutKind.Explicit, Size=20, CharSet=CharSet.Unicode)]
        public struct InputRecord {
            [FieldOffset(0)] public ushort Kind;
            [FieldOffset(4)] public int Down;
            [FieldOffset(8)] public ushort Repeat;
            [FieldOffset(10)] public ushort Key;
            [FieldOffset(12)] public ushort Scan;
            [FieldOffset(14)] public char Character;
            [FieldOffset(16)] public uint Modifiers;
        }
        [DllImport("kernel32.dll")] static extern IntPtr GetStdHandle(int n);
        [DllImport("kernel32.dll")] static extern IntPtr GetConsoleWindow();
        [DllImport("kernel32.dll")] static extern bool GetConsoleMode(IntPtr h, out uint mode);
        [DllImport("kernel32.dll")] static extern bool SetConsoleMode(IntPtr h, uint mode);
        [DllImport("kernel32.dll")] static extern uint WaitForSingleObject(IntPtr h, uint milliseconds);
        [DllImport("kernel32.dll")] static extern bool GetNumberOfConsoleInputEvents(IntPtr h, out uint count);
        [DllImport("kernel32.dll", CharSet=CharSet.Unicode, ExactSpelling=true)] static extern bool ReadConsoleInputW(IntPtr h, [Out] InputRecord[] records, uint count, out uint read);
        [DllImport("kernel32.dll", CharSet=CharSet.Unicode, ExactSpelling=true)] static extern bool WriteConsoleInputW(IntPtr h, InputRecord[] records, uint count, out uint written);
        const string OwnerName = "JOBS_TERMINAL_STYLE_WINDOWS_OWNER";
        static readonly string[] Keys = { "10", "11", "4;0", "4;1", "4;2", "4;3", "4;4", "4;5", "4;6", "4;7", "4;8", "4;9", "4;10", "4;11", "4;12", "4;13", "4;14", "4;15" };
        static readonly string[] Hex = { "000000", "ff5f56", "5fd787", "ffd75f", "5fafff", "d787ff", "5fd7ff", "eeeeee", "9e9e9e", "ff8787", "87ffaf", "ffff87", "87bfff", "ffafff", "afffff", "ffffff" };
        static readonly Regex Reply = new Regex("\\x1b\\](?<key>10|11|4;[0-9]{1,2});(?<rgb>rgb:[0-9a-f]{1,4}/[0-9a-f]{1,4}/[0-9a-f]{1,4})(?:\\x07|\\x1b\\\\)", RegexOptions.IgnoreCase);
        public sealed class State {
            public IntPtr Input, Output;
            public uint OutputMode;
            public ConsoleColor Foreground, Background;
            public Dictionary<string,string> Original, Applied;
            public string Owner, PreviousOwner, Recovery;
            public bool Active, ModeChanged, Fallback;
            public Dictionary<string,string> EnvironmentBefore = new Dictionary<string,string>();
        }
        static string Escape(string key, string value) { return "\x1b]" + key + ";" + value + "\x07"; }
        static string Rgb(string hex) { return "rgb:" + hex.Substring(0,2) + "/" + hex.Substring(2,2) + "/" + hex.Substring(4,2); }
        static string Normal(string rgb) {
            string[] parts = rgb.Substring(4).Split('/');
            for (int n=0; n<3; n++) {
                int maximum = (1 << (4 * parts[n].Length)) - 1;
                int value = Convert.ToInt32(parts[n],16);
                parts[n] = ((value * 65535L + maximum/2) / maximum).ToString("x4");
            }
            return String.Join("/",parts);
        }
        // Preserve unrelated key/window records instead of consuming user input during color queries.
        static Dictionary<string,string> Query(State state) {
            uint pending;
            if (!GetNumberOfConsoleInputEvents(state.Input,out pending) || pending != 0) { return null; }
            StringBuilder commands = new StringBuilder();
            foreach (string key in Keys) { commands.Append(Escape(key,"?")); }
            Console.Write(commands.ToString());
            List<InputRecord> records = new List<InputRecord>();
            List<int> characterIndices = new List<int>();
            StringBuilder text = new StringBuilder();
            Dictionary<string,string> result = new Dictionary<string,string>();
            Stopwatch timer = Stopwatch.StartNew();
            try {
                while (timer.ElapsedMilliseconds < 600) {
                    if (result.Count == Keys.Length && GetNumberOfConsoleInputEvents(state.Input,out pending) && pending == 0) { break; }
                    if (WaitForSingleObject(state.Input,20) != 0) { continue; }
                    InputRecord[] item = new InputRecord[1]; uint read;
                    if (!ReadConsoleInputW(state.Input,item,1,out read) || read != 1) { break; }
                    int index = -1;
                    if (item[0].Kind == 1 && item[0].Character != '\0') {
                        if (item[0].Down != 0) { index = text.Length; text.Append(item[0].Character); }
                        else if (text.Length != 0 && text[text.Length-1] == item[0].Character) { index = text.Length-1; }
                    }
                    records.Add(item[0]); characterIndices.Add(index);
                    foreach (Match match in Reply.Matches(text.ToString())) {
                        string key = match.Groups["key"].Value;
                        if (Array.IndexOf(Keys,key) >= 0) { result[key] = match.Groups["rgb"].Value; }
                    }
                }
            } finally {
                bool[] used = new bool[text.Length];
                foreach (Match match in Reply.Matches(text.ToString())) {
                    for (int n=match.Index; n<match.Index+match.Length; n++) { used[n] = true; }
                }
                List<InputRecord> replay = new List<InputRecord>();
                for (int n=0; n<records.Count; n++) {
                    int index = characterIndices[n];
                    if (index < 0 || !used[index]) { replay.Add(records[n]); }
                }
                if (replay.Count != 0) {
                    uint written;
                    if (!WriteConsoleInputW(state.Input,replay.ToArray(),(uint)replay.Count,out written) || written != replay.Count) {
                        Console.Error.WriteLine("[Jobs] Could not replay terminal input; color protection is unavailable.");
                        result.Clear();
                    }
                }
            }
            return result.Count == Keys.Length ? result : null;
        }
        static void Plain(State state) {
            foreach (string key in new string[] { "NO_COLOR", "PLAIN_OUTPUT", "FORCE_COLOR", "CLICOLOR", "ANSI_COLORS_DISABLED" }) {
                state.EnvironmentBefore[key] = Environment.GetEnvironmentVariable(key);
                Environment.SetEnvironmentVariable(key, key == "FORCE_COLOR" || key == "CLICOLOR" ? "0" : "1");
            }
            state.Fallback = true;
        }
        public static void Enter(State state) {
            try {
                state.Input = GetStdHandle(-10); state.Output = GetStdHandle(-11);
                uint inputMode;
                if (!GetConsoleMode(state.Input,out inputMode) || !GetConsoleMode(state.Output,out state.OutputMode)) { Plain(state); return; }
                IntPtr window = GetConsoleWindow();
                if (window == IntPtr.Zero) { Plain(state); return; }
                string identity = window.ToInt64().ToString("x");
                state.PreviousOwner = Environment.GetEnvironmentVariable(OwnerName);
                if (!String.IsNullOrEmpty(state.PreviousOwner)) {
                    string[] owner = state.PreviousOwner.Split(':');
                    int pid; long started;
                    if (owner.Length == 3 && owner[0] == identity && Int32.TryParse(owner[1],out pid) && Int64.TryParse(owner[2],out started)) {
                        try { if (Process.GetProcessById(pid).StartTime.ToUniversalTime().Ticks == started) { return; } } catch {}
                    }
                }
                state.Foreground = Console.ForegroundColor; state.Background = Console.BackgroundColor;
                if ((state.OutputMode & 4) == 0) {
                    if (!SetConsoleMode(state.Output,state.OutputMode | 4)) { Plain(state); return; }
                    state.ModeChanged = true;
                }
                state.Original = Query(state);
                if (state.Original == null) { Restore(state); Plain(state); return; }
                state.Applied = new Dictionary<string,string>();
                state.Applied["10"] = "rgb:ff/ff/ff"; state.Applied["11"] = "rgb:00/00/00";
                for (int n=0; n<16; n++) { state.Applied["4;"+n] = Rgb(Hex[n]); }
                StringBuilder restore = new StringBuilder();
                foreach (string key in Keys) { restore.Append(Escape(key,state.Original[key])); }
                string encoded = Convert.ToBase64String(Encoding.UTF8.GetBytes(restore.ToString()));
                state.Recovery = Path.Combine(Path.GetTempPath(),"JobsTerminalStyle-"+Process.GetCurrentProcess().Id+"-"+Guid.NewGuid().ToString("N")+".ps1");
                string manual = "# Restore only the session colors saved by this Jobs script.\r\n"+
                    "if ([Console]::IsOutputRedirected) { throw 'Run in the original console.' }\r\n"+
                    "Add-Type -Namespace Jobs -Name RecoveryConsole -MemberDefinition '[System.Runtime.InteropServices.DllImport(\"kernel32.dll\")] public static extern System.IntPtr GetStdHandle(int n); [System.Runtime.InteropServices.DllImport(\"kernel32.dll\")] public static extern bool GetConsoleMode(System.IntPtr h, out uint m); [System.Runtime.InteropServices.DllImport(\"kernel32.dll\")] public static extern bool SetConsoleMode(System.IntPtr h, uint m);'\r\n"+
                    "$h = [Jobs.RecoveryConsole]::GetStdHandle(-11); [uint32]$m = 0\r\n"+
                    "if (-not [Jobs.RecoveryConsole]::GetConsoleMode($h, [ref]$m)) { throw 'Run in the original console.' }\r\n"+
                    "try {\r\nif (-not [Jobs.RecoveryConsole]::SetConsoleMode($h, ($m -bor 4))) { throw 'Cannot enable terminal recovery.' }\r\n"+
                    "[Console]::Write([Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('"+encoded+"')))\r\n"+
                    "[Console]::ForegroundColor = [ConsoleColor]"+((int)state.Foreground)+"\r\n"+
                    "[Console]::BackgroundColor = [ConsoleColor]"+((int)state.Background)+"\r\n"+
                    "[Console]::Write([string][char]27 + '[39;49m')\r\n"+
                    "} finally { [void][Jobs.RecoveryConsole]::SetConsoleMode($h, $m) }\r\n";
                File.WriteAllText(state.Recovery,manual,new UTF8Encoding(false));
                state.Owner = identity+":"+Process.GetCurrentProcess().Id+":"+Process.GetCurrentProcess().StartTime.ToUniversalTime().Ticks;
                Environment.SetEnvironmentVariable(OwnerName,state.Owner);
                state.Active = true;
                foreach (string key in Keys) { Console.Write(Escape(key,state.Applied[key])); }
                Console.ForegroundColor = ConsoleColor.White; Console.BackgroundColor = ConsoleColor.Black;
                Dictionary<string,string> check = Query(state);
                foreach (string key in Keys) {
                    if (check == null || Normal(check[key]) != Normal(state.Applied[key])) { Restore(state); Plain(state); return; }
                }
            } catch (Exception error) {
                Restore(state); Plain(state);
                Console.Error.WriteLine("[Jobs] Terminal style unavailable: " + error.Message);
            }
        }
        public static void Restore(State state) {
            if (state == null) { return; }
            try {
                if (state.Active) {
                    Dictionary<string,string> current = Query(state);
                    bool complete = current != null;
                    if (current != null) {
                        bool restoreForeground = Console.ForegroundColor == ConsoleColor.White && Normal(current["10"]) == Normal(state.Applied["10"]) && Normal(current["4;15"]) == Normal(state.Applied["4;15"]);
                        bool restoreBackground = Console.BackgroundColor == ConsoleColor.Black && Normal(current["11"]) == Normal(state.Applied["11"]) && Normal(current["4;0"]) == Normal(state.Applied["4;0"]);
                        foreach (string key in Keys) {
                            if (Normal(current[key]) == Normal(state.Applied[key])) { Console.Write(Escape(key,state.Original[key])); }
                            else if (Normal(current[key]) != Normal(state.Original[key])) {
                                complete = false; Console.Error.WriteLine("[Jobs] Kept a concurrent color change: " + key);
                            }
                        }
                        if (restoreForeground) { Console.ForegroundColor = state.Foreground; Console.Write("\x1b[39m"); }
                        if (restoreBackground) { Console.BackgroundColor = state.Background; Console.Write("\x1b[49m"); }
                    }
                    if (complete) {
                        Dictionary<string,string> check = Query(state);
                        foreach (string key in Keys) { if (check == null || Normal(check[key]) != Normal(state.Original[key])) { complete = false; } }
                    }
                    if (complete) { File.Delete(state.Recovery); }
                    else { Console.Error.WriteLine("[Jobs] Color restore needs review. Manual recovery: powershell -NoProfile -File \""+state.Recovery+"\""); }
                }
            } catch (Exception error) {
                Console.Error.WriteLine("[Jobs] Color restore failed: "+error.Message+"; recovery: "+state.Recovery);
            } finally {
                if (state.Owner != null && Environment.GetEnvironmentVariable(OwnerName) == state.Owner) { Environment.SetEnvironmentVariable(OwnerName,state.PreviousOwner); }
                state.Active = false;
                uint currentMode;
                if (state.ModeChanged && GetConsoleMode(state.Output,out currentMode) && currentMode == (state.OutputMode | 4)) { SetConsoleMode(state.Output,state.OutputMode); }
                state.ModeChanged = false;
                if (state.Fallback) {
                    foreach (KeyValuePair<string,string> pair in state.EnvironmentBefore) {
                        string applied = pair.Key == "FORCE_COLOR" || pair.Key == "CLICOLOR" ? "0" : "1";
                        if (Environment.GetEnvironmentVariable(pair.Key) == applied) { Environment.SetEnvironmentVariable(pair.Key,pair.Value); }
                    }
                    state.Fallback = false;
                }
            }
        }
    }
}
'@
        } catch {
            [Console]::Error.WriteLine('[Jobs] Terminal style setup failed; using plain output: ' + $_.Exception.Message)
            return @{ JobsTerminalPlainFallback = $true; Before = @{} }
        }
    }
    return New-Object Jobs.TerminalStyleV1.Native+State
}
# Guard setup is optional; failure keeps business behavior and the user's original terminal settings.
function Start-JobsTerminalStyle {
    param($State)
    if ($State -is [Collections.IDictionary] -and $State.Contains('JobsTerminalPlainFallback')) {
        foreach ($key in @('NO_COLOR', 'PLAIN_OUTPUT', 'FORCE_COLOR', 'CLICOLOR', 'ANSI_COLORS_DISABLED')) {
            $State.Before[$key] = [Environment]::GetEnvironmentVariable($key)
            [Environment]::SetEnvironmentVariable($key, $(if (@('FORCE_COLOR', 'CLICOLOR') -contains $key) { '0' } else { '1' }))
        }
        return
    }
    if ($null -ne $State) { [Jobs.TerminalStyleV1.Native]::Enter($State) }
}
# A finally block also runs for script exit and Ctrl+C; direct .NET calls avoid stopped pipelines.
function Stop-JobsTerminalStyle {
    param($State)
    if ($State -is [Collections.IDictionary] -and $State.Contains('JobsTerminalPlainFallback')) {
        foreach ($key in $State.Before.Keys) {
            $applied = if (@('FORCE_COLOR', 'CLICOLOR') -contains $key) { '0' } else { '1' }
            if ([Environment]::GetEnvironmentVariable($key) -ceq $applied) { [Environment]::SetEnvironmentVariable($key, $State.Before[$key]) }
        }
        return
    }
    if ($null -ne $State) { [Jobs.TerminalStyleV1.Native]::Restore($State) }
}
# END JOBS_TERMINAL_STYLE_V1

$__jobsTerminalStyleState = $null
try {
    if ($MyInvocation.InvocationName -ne '.') {
        $__jobsTerminalStyleState = New-JobsTerminalStyleState
        Start-JobsTerminalStyle $__jobsTerminalStyleState
    }
# BEGIN JOBS_TERMINAL_STYLE_ORIGINAL_BODY
function Test-JobsEnterChoiceColor {
    if ((Test-Path Env:NO_COLOR) -or $env:TERM -ieq 'dumb' -or $env:PLAIN_OUTPUT -eq '1') { return $false }
    $consoleType = [Console]
    if ($null -eq $consoleType.GetProperty('IsInputRedirected') -or $null -eq $consoleType.GetProperty('IsOutputRedirected')) { return $false }
    return ($Host.Name -ceq 'ConsoleHost' -and -not [Console]::IsInputRedirected -and -not [Console]::IsOutputRedirected)
}
# Older hosts keep native colors without sending unsupported bold escape sequences.
function Test-JobsEnterChoiceBold {
    $property = $Host.UI.PSObject.Properties['SupportsVirtualTerminal']
    return ($null -ne $property -and [bool]$property.Value)
}
# Separate ordinary question text from Enter and arbitrary-input options without changing words.
function Get-JobsEnterChoiceParts {
    param([string]$Text)
    $red = '(?:(?:\u8f93\u5165)?(?:\u4efb\u610f(?:\u975e\u7a7a)?(?:\u5b57\u7b26|\u5185\u5bb9|\u6587\u5b57|\u8f93\u5165)?|\u975e\u7a7a(?:\u8f93\u5165|\u5b57\u7b26|\u5185\u5bb9)?|(?:\u5176\u5b83|\u5176\u4ed6)(?:\u975e\u7a7a)?(?:\u8f93\u5165|\u5185\u5bb9|\u5b57\u7b26)?))|(?:any\s+(?:(?:other|non[- ]empty)\s+)?(?:input|text|characters?)|non[- ]empty\s+input)'
    $green = '(?:(?:\u76f4\u63a5|\u53ea\u9700|\u4ec5(?:\u9700)?|\u6309(?:\u4e0b)?|\u7a7a)?\s*\u56de\u8f66|(?:press\s+)?\bEnter\b(?!\s+(?:YES|REPAIR|CLEAN|CONTINUE)\b))'
    $pattern = '(?is)(?<red>(?:' + $red + ')[^;\uFF1B\r\n]*?(?=[;\uFF1B\r\n]|\z))|(?<green>(?:' + $green + ')[^;\uFF1B\r\n]*?(?=(?:' + $red + ')|[;\uFF1B\r\n]|\z))'
    $offset = 0
    foreach ($match in [regex]::Matches($Text, $pattern)) {
        if ($match.Index -gt $offset) { [pscustomobject]@{ Text = $Text.Substring($offset, $match.Index - $offset); Color = '' } }
        $prefix = [regex]::Split($Text.Substring(0, $match.Index), '[;\uFF1B\r\n]')[-1]
        $typed = $prefix -match '(?i)(?:\u8f93\u5165|\u952e\u5165|type|enter)\s*(?:\u5927\u5199\s*)?(?:YES|REPAIR|CLEAN|CONTINUE)\b|\u7cbe\u786e\u8f93\u5165|\u8f93\u5165[^;\uFF1B\r\n]*[\u540e\u518d]\s*$'
        $color = if ($match.Groups['red'].Success) { 'Red' } elseif ($typed) { '' } else { 'Green' }
        [pscustomobject]@{ Text = $match.Value; Color = $color }
        $offset = $match.Index + $match.Length
    }
    if ($offset -lt $Text.Length) { [pscustomobject]@{ Text = $Text.Substring($offset); Color = '' } }
}
# Native host text remains plain in information streams and logs; bold control is console-only.
function Write-JobsEnterChoiceText {
    [CmdletBinding()]
    param([Parameter(Position=0)][AllowNull()][object]$Object, [switch]$NoNewline, [ConsoleColor]$ForegroundColor, [ConsoleColor]$BackgroundColor, [object]$Separator = ' ')
    $text = if ($Object -is [array]) { $Object -join [string]$Separator } else { [string]$Object }
    if (-not (Test-JobsEnterChoiceColor)) {
        Write-Host $Object -NoNewline:$NoNewline -Separator $Separator
        return
    }
    $normal = @{}
    if ($PSBoundParameters.ContainsKey('ForegroundColor')) { $normal.ForegroundColor = $ForegroundColor }
    if ($PSBoundParameters.ContainsKey('BackgroundColor')) { $normal.BackgroundColor = $BackgroundColor }
    foreach ($part in @(Get-JobsEnterChoiceParts $text)) {
        if (-not $part.Color) { Write-Host $part.Text -NoNewline @normal; continue }
        $bold = Test-JobsEnterChoiceBold
        if ($bold) { [Console]::Write(([string][char]27) + '[1m') }
        try { Write-Host $part.Text -ForegroundColor $part.Color -NoNewline }
        finally { if ($bold) { [Console]::Write(([string][char]27) + '[0m') } }
    }
    if (-not $NoNewline) { Write-Host }
}
# Delegate the original reader, including secure input and EOF behavior, after prompt display.
function Read-JobsEnterChoiceHost {
    [CmdletBinding()]
    param([Parameter(Position=0)][string]$Prompt, [switch]$AsSecureString, [switch]$MaskInput)
    if ($AsSecureString -or $MaskInput -or -not (Test-JobsEnterChoiceColor) -or @((Get-JobsEnterChoiceParts $Prompt) | Where-Object { $_.Color }).Count -eq 0) {
        return (Read-Host @PSBoundParameters)
    }
    Write-JobsEnterChoiceText ($Prompt + ': ') -NoNewline
    return (Read-Host)
}



Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$script:EntryPath = $PSCommandPath
# 从自身逐级发现完整工程，包装层数或调用目录变化不会改变工程归属。
function Find-RepairProjectRoot {
    param([string]$Start)
    $cursor = [IO.Path]::GetFullPath($Start)
    while ($cursor) {
        if ((Test-Path -LiteralPath (Join-Path $cursor '部署/deploy-tools.lock.tsv') -PathType Leaf) -and (Test-Path -LiteralPath (Join-Path $cursor '代码/后端/后端代码/go.mod') -PathType Leaf)) { return $cursor }
        $parent = [IO.Path]::GetDirectoryName($cursor)
        if ($parent -eq $cursor) { break }
        $cursor = $parent
    }
    throw '找不到本入口所属完整维修工程，请保留源码与部署锁清单。'
}
$script:ProjectRoot = Find-RepairProjectRoot $PSScriptRoot
$script:ManifestPath = Join-Path $script:ProjectRoot '部署\deploy-tools.lock.tsv'
$script:EnvironmentRoot = $null
$script:RuntimeRoot = $null
$script:RunDirectory = $null
$script:LogFile = $null
$script:Session = $null
$script:DeployLock = $null
$script:ToolArch = $null
$script:Selection = $null
$script:AllowedMail = $null
$script:PublicDemo = $false
$script:AppEnvironment = @{}
$script:Backend = $null
$script:Tunnel = $null
$script:FzfExecutable = $null
$script:DependencyResolver = $null
$script:BrowserMenu = $null
$script:BrowserMenuPaused = $false
$script:BrowserItems = @()
$script:QrBinary = $null
$script:QrPage = $null
$script:QrGeneration = 0
$script:ProjectCacheRoot = $null
$script:Receipt = $null
$script:ReceiptDirectory = $null
$script:MissingParents = @()

# 只读解析目标机架构，不把64位模拟器当作ARM64原生工具。
function Get-TargetArchitecture {
    $native = [Environment]::GetEnvironmentVariable('PROCESSOR_ARCHITEW6432')
    if ([string]::IsNullOrWhiteSpace($native)) {
        $native = [Environment]::GetEnvironmentVariable('PROCESSOR_ARCHITECTURE')
    }
    switch -Regex ($native) {
        '^(ARM64|aarch64)$' { return 'arm64' }
        '^(AMD64|x86_64)$' { return 'amd64' }
        default { throw '当前入口仅支持Windows amd64或arm64，未识别架构不自动猜测。' }
    }
}
# 从脚本位置解析完整工程，所有相对配置均以工程根为基准。
function Resolve-ProjectPath {
    param([string]$Value)
    if ([IO.Path]::IsPathRooted($Value)) {
        return [IO.Path]::GetFullPath($Value)
    }
    return [IO.Path]::GetFullPath((Join-Path $script:ProjectRoot $Value))
}
# 仅解析当前用户机器目录，检查和计划不创建任何文件。
function Initialize-StoragePaths {
    $base = $env:LOCALAPPDATA
    if ([string]::IsNullOrWhiteSpace($base)) { $base = Join-Path ([Environment]::GetFolderPath('UserProfile')) 'AppData\Local' }
    $environment = $env:WB_ENV_ROOT
    if ([string]::IsNullOrWhiteSpace($environment)) { $environment = Join-Path $base 'JobsSoftwareEnvironments' }
    $runtime = $env:WB_RUNTIME_DIR
    if ([string]::IsNullOrWhiteSpace($runtime)) { $runtime = Join-Path $base 'JobsSoftwareProjects\RepairWorkbench\Runtime' }
    $script:EnvironmentRoot = Resolve-ProjectPath $environment
    $script:RuntimeRoot = Resolve-ProjectPath $runtime
    $hasher = [Security.Cryptography.SHA256]::Create()
    try { $projectId = ([BitConverter]::ToString($hasher.ComputeHash([Text.Encoding]::UTF8.GetBytes($script:ProjectRoot.ToLowerInvariant())))).Replace('-', '').Substring(0, 16).ToLowerInvariant() }
    finally { $hasher.Dispose() }
    $script:ProjectCacheRoot = Join-Path $script:EnvironmentRoot ('Projects\RepairWorkbench\' + $projectId)
    if ($script:EnvironmentRoot -eq $script:ProjectRoot -or $script:EnvironmentRoot.StartsWith($script:ProjectRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw '公共工具环境不能位于项目源码目录。'
    }
}
# 只读检查源码和锁清单，不创建运行目录或执行候选工具。
function Test-DeploymentLayout {
    foreach ($relative in @('代码\后端\后端代码\go.mod', '代码\后端\后端代码\cmd\workbench\main.go', '代码\前端\PC端\Web\维修工作台\index.html')) {
        if (-not (Test-Path -LiteralPath (Join-Path $script:ProjectRoot $relative) -PathType Leaf)) {
            throw "缺少工程文件：$relative；请保留完整项目。"
        }
    }
    if (-not (Test-Path -LiteralPath $script:ManifestPath -PathType Leaf)) {
        throw '缺少部署/deploy-tools.lock.tsv，拒绝不带校验值下载工具。'
    }
    $rows = @(Import-Csv -LiteralPath $script:ManifestPath -Delimiter ([char]9) -Encoding UTF8)
    if ($rows.Count -eq 0) { throw '工具锁清单为空。' }
    $seen = @{}
    foreach ($row in $rows) {
        if ($row.tool -notin @('fzf', 'go', 'cloudflared') -or $row.os -notin @('windows', 'darwin', 'linux', 'freebsd') -or $row.arch -notin @('amd64', 'arm64') -or $row.kind -notin @('zip', 'tar.gz', 'binary')) {
            throw '工具锁清单含未知工具、平台、架构或归档格式。'
        }
        if ($row.sha256 -notmatch '^[a-fA-F0-9]{64}$' -or $row.url -notmatch '^https://' -or $row.filename -match '[/\\:]' -or $row.version -notmatch '^\d+\.\d+\.\d+$') {
            throw '工具锁清单含无效摘要或非HTTPS地址。'
        }
        $key = $row.tool + '/' + $row.os + '/' + $row.arch
        if ($seen.ContainsKey($key)) { throw '工具锁清单含重复平台资产，拒绝不确定选择。' }
        $seen[$key] = $true
    }
    return $rows
}
# 输出不执行的计划，允许在非交互环境审阅。
function Show-ReadOnlyPlan {
    param([object[]]$Rows, [string]$SelectedMode)
    $hostWindows = $env:OS -eq 'Windows_NT'
    $architecture = 'unknown'
    try { $architecture = Get-TargetArchitecture } catch { }
    [ordered]@{
        checkOnly = $true
        project = $script:ProjectRoot
        environmentRoot = $script:EnvironmentRoot
        runtimeRoot = $script:RuntimeRoot
        hostIsWindows = $hostWindows
        targetArchitecture = $architecture
        mode = $(if ($SelectedMode) { $SelectedMode } else { 'interactive-fzf-required' })
        listen = $(if ($env:WB_ADDR) { $env:WB_ADDR } else { '127.0.0.1:8098' })
        build = '代码/后端/后端代码: go build ./cmd/workbench'
        defaultStorage = '本地加密文件快照，已有WB_TIDB_DSN显式配置除外'
        localAccess = '默认浏览器访问：打开公网链接后，用允许的邮箱收取并填写验证码；App/API合成联调可选无邮箱验证的公开演示，须PUBLIC确认'
        browserMenu = '启动后fzf选择本次公网或本机地址，默认浏览器打开后可继续选择；Esc收起保留服务，回车再选；Ctrl+C停止本次进程'
        tools = @($Rows | Where-Object { $_.os -eq 'windows' -and $_.arch -eq $architecture } | Select-Object tool, version, filename, sha256)
        localNativeTunnelDownloadAvailable = $architecture -eq 'amd64'
        arm64LocalRequirement = '仅可复用明确提供且健康的原生ARM64 cloudflared；不下载x64替代'
        sideEffects = 'none: 不联网、不写配置或日志、不执行版本探针、不启动进程'
    } | ConvertTo-Json -Depth 5
}
# 脱敏后同步写终端与本次日志，不记录邮箱、令牌或数据库连接串。
function Write-DeployLog {
    param([string]$Message, [string]$Level = 'INFO', [switch]$Emphasize)
    $safe = [regex]::Replace($Message, '(?i)(https?://)[^/\s|]+@', '$1[凭据已隐藏]@')
    $safe = [regex]::Replace($safe, '(?i)[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}', '[邮箱已隐藏]')
    $safe = [regex]::Replace($safe, '(?i)(password|authtoken|token|secret|dsn)\s*[=:]\s*\S+', '$1=[已隐藏]')
    $line = ('[{0}] {1}' -f $Level, $safe)
    $colorAllowed = -not [Console]::IsOutputRedirected -and -not (Test-Path Env:NO_COLOR) -and $env:TERM -ne 'dumb'
    if ($Emphasize -and $colorAllowed -and $Host.UI.PSObject.Properties['SupportsVirtualTerminal'] -and $Host.UI.SupportsVirtualTerminal) {
        Write-Host (([string][char]27) + '[1;31m' + $line + ([string][char]27) + '[0m')
    } elseif ($Emphasize -and $colorAllowed) {
        Write-Host $line -ForegroundColor Red
    } elseif ($Emphasize) {
        [Console]::WriteLine($line)
    } else {
        Write-Host $line
    }
    if ($script:LogFile) {
        [IO.File]::AppendAllText($script:LogFile, $line + [Environment]::NewLine, (New-Object Text.UTF8Encoding($false)))
    }
}
# 在任何写入前显示用途并等待回车，EOF与非交互输入均不作为同意。
function Confirm-Introduction {
    Write-Host '================ Windows维修工作台部署 ================' -ForegroundColor Red
    Write-Host '1、fzf选择：本地部署＋内网穿透 / 正常服务器部署。'
    Write-Host '2、菜单以健康fzf/Go引导；选定模式后查询官方最新稳定工具，校验下载至本项目机器缓存。'
    Write-Host '3、只管理本次进程；Ctrl+C关闭本次后端和隧道，保留业务数据、密钥和备份。'
    Write-Host '4、服务器模式仍仅回环监听；当前固定账号是合成演示，不等于生产公网服务。'
    Write-Host '5、默认浏览器访问：打开公网链接→输入允许的邮箱→收取并填写验证码→进入。'
    Write-Host '   邮箱只验证公网访问者身份，与维修业务无关；原生App/API请选择公开演示，仅用合成数据并输入PUBLIC确认。'
    Write-Host '6、旧版本不因健康而跳过；网络故障持续重试可取消，来源/摘要错误停止；不改系统PATH或全局工具。'
    Write-JobsEnterChoiceText '7、启动后fzf列出公网／本机地址，回车用默认浏览器打开；打开后继续选，服务保持运行。'
    Write-JobsEnterChoiceText '   网页菜单Esc仅收起，在原终端按回车再次显示；Ctrl+C停止本次服务。'
    Write-Host '   业务Go库只检查并列出更新，升级需单独回归；源码依赖锁与客户端工具链保留。'
    Write-Host '========================================================'
    if ([Console]::IsInputRedirected -or [Console]::IsOutputRedirected) {
        throw '正常入口需要交互终端；自动检查请使用-Check或-Plan。'
    }
    Write-JobsEnterChoiceText '已了解用途与影响，直接回车继续；输入其它内容或Ctrl+C取消：' -NoNewline
    $answer = [Console]::ReadLine()
    if ($null -eq $answer -or $answer.Length -ne 0) { return $false }
    return $true
}
# 拒绝缓存、产物或锁路径中的链接，避免写到工程外部。
function Assert-NoReparsePoint {
    param([string]$Path)
    $cursor = [IO.Path]::GetFullPath($Path)
    while ($cursor) {
        if (Test-Path -LiteralPath $cursor) {
            $item = Get-Item -LiteralPath $cursor -Force
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw "拒绝链接或重解析路径：$cursor"
            }
        }
        $parent = [IO.Path]::GetDirectoryName($cursor)
        if ($parent -eq $cursor) { break }
        $cursor = $parent
    }
}
# 把本次运行资料的访问范围限定为当前Windows账户。
function Protect-PrivateDirectory {
    param([string]$Path)
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent().User
    $acl = New-Object Security.AccessControl.DirectorySecurity
    $acl.SetOwner($identity)
    $acl.SetAccessRuleProtection($true, $false)
    $rule = New-Object Security.AccessControl.FileSystemAccessRule($identity, 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow')
    $acl.AddAccessRule($rule)
    Set-Acl -LiteralPath $Path -AclObject $acl
}
# 初始化本项目用户目录日志与独占部署锁，不触碰已有业务存储。
function Initialize-RunDirectory {
    $runtime = $script:RuntimeRoot
    Assert-NoReparsePoint $runtime
    $initialRuntime = Test-Path -LiteralPath $runtime
    $initialLock = Test-Path -LiteralPath (Join-Path $runtime 'windows-deploy.lock')
    foreach ($start in @($runtime, $script:ProjectCacheRoot)) {
        $cursor = $start
        while ($cursor -and -not (Test-Path -LiteralPath $cursor)) { $script:MissingParents += $cursor; $cursor = [IO.Path]::GetDirectoryName($cursor) }
    }
    $null = New-Item -ItemType Directory -Force -Path $runtime
    $lockPath = Join-Path $runtime 'windows-deploy.lock'
    Assert-NoReparsePoint $lockPath
    try {
        $script:DeployLock = New-Object IO.FileStream($lockPath, [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
    } catch {
        throw '本工程已有Windows部署入口在运行，或锁文件无法访问；不停止其它实例。'
    }
    Initialize-DeploymentReceipt $initialRuntime $initialLock
    $script:RunDirectory = Join-Path $runtime ('windows-deploy\' + (Get-Date -Format 'yyyy.MM.dd HH-mm-ss-fff') + '-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
    Assert-NoReparsePoint $script:RunDirectory
    Register-DeploymentArtifact $script:RunDirectory
    $null = New-Item -ItemType Directory -Force -Path $script:RunDirectory
    Protect-PrivateDirectory $script:RunDirectory
    $script:LogFile = Join-Path $script:RunDirectory 'deployment.log'
    Write-DeployLog '运行资料仅当前账户可读；所有子进程输出在写入前脱敏。'
    Write-DeployLog ("日志：" + $script:LogFile)
}
# 对文件和目录逐文件计算摘要，拒绝链接及并发内容变化后的盲目回滚。
function Get-DeploymentFingerprint {
    param([string]$Path)
    Assert-NoReparsePoint $Path
    if (-not (Test-Path -LiteralPath $Path)) { return 'absent' }
    $item = Get-Item -LiteralPath $Path -Force
    if (-not $item.PSIsContainer) { return 'file:' + (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
    $records = @('directory')
    foreach ($child in @(Get-ChildItem -LiteralPath $Path -Force -Recurse | Sort-Object FullName)) {
        Assert-NoReparsePoint $child.FullName
        $relative = $child.FullName.Substring($Path.TrimEnd('\', '/').Length).Replace('\', '/')
        if ($child.PSIsContainer) { $records += 'd:' + $relative }
        else { $records += 'f:' + $relative + ':' + (Get-FileHash -LiteralPath $child.FullName -Algorithm SHA256).Hash }
    }
    $hash = [Security.Cryptography.SHA256]::Create()
    try { return 'tree:' + ([BitConverter]::ToString($hash.ComputeHash([Text.Encoding]::UTF8.GetBytes(($records -join "`n"))))).Replace('-', '') }
    finally { $hash.Dispose() }
}
# 原子保存最小部署凭据，目录ACL限制当前账户，禁止日志输出连接串。
function Save-DeploymentReceipt {
    if (-not $script:Receipt) { return }
    $file = Join-Path $script:ReceiptDirectory 'receipt.json'
    $temporary = Join-Path $script:ReceiptDirectory ('receipt-' + [Guid]::NewGuid().ToString('N') + '.tmp')
    [IO.File]::WriteAllText($temporary, ($script:Receipt | ConvertTo-Json -Depth 12), (New-Object Text.UTF8Encoding($false)))
    Move-Item -LiteralPath $temporary -Destination $file -Force
}
# 首次部署保存原点，多次部署沿用同一记录，不能把后来的状态冒充原始环境。
function Initialize-DeploymentReceipt {
    param([bool]$InitialRuntime, [bool]$InitialLock)
    $script:ReceiptDirectory = Join-Path $script:RuntimeRoot 'deploy-state-Windows'
    Assert-NoReparsePoint $script:ReceiptDirectory
    $file = Join-Path $script:ReceiptDirectory 'receipt.json'
    if (Test-Path -LiteralPath $file) {
        try {
            $script:Receipt = Get-Content -LiteralPath $file -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($script:Receipt.schema -ne 1 -or $script:Receipt.project -cne $script:ProjectRoot -or $script:Receipt.runtime -cne $script:RuntimeRoot -or $script:Receipt.projectCache -cne $script:ProjectCacheRoot) {
                throw '已有部署原点记录与当前工程或目录不符，拒绝覆盖。'
            }
            if ($script:Receipt.PSObject.Properties.Name -contains 'undo') { throw '反部署已开始，请先完成原点恢复，不覆盖活动记录。' }
            if (-not $script:Receipt.finalized) { throw '上次部署记录未封存，请先核对失败现场，不覆盖恢复依据。' }
            foreach ($row in @($script:Receipt.artifacts)) {
                $full = [IO.Path]::GetFullPath([string]$row.path)
                $sessionRoot = Join-Path $script:RuntimeRoot 'windows-deploy'
                if ($full -cne $row.path -or ($full -cne $script:ProjectCacheRoot -and [IO.Path]::GetDirectoryName($full) -cne $sessionRoot)) { throw '已有原点产物越界，拒绝部署。' }
                if ((Get-DeploymentFingerprint $full) -cne $row.after) { throw '已有部署产物发生后续修改，先核对原点记录。' }
                if ($row.before -eq 'existing') {
                    if ($row.backup -notmatch '^previous/[a-f0-9]{32}$' -or (Get-DeploymentFingerprint (Join-Path $script:ReceiptDirectory $row.backup)) -cne $row.beforeHash) { throw '已有原点副本无效，拒绝覆盖。' }
                }
            }
            $script:Receipt.finalized = $false
            Save-DeploymentReceipt
            return
        } catch {
            $script:Receipt = $null
            throw
        }
    }
    if (Test-Path -LiteralPath $script:ReceiptDirectory) { throw '部署原点目录不完整，保留现场并停止。' }
    $null = New-Item -ItemType Directory -Path $script:ReceiptDirectory
    Protect-PrivateDirectory $script:ReceiptDirectory
    $script:Receipt = [pscustomobject]@{ schema = 1; project = $script:ProjectRoot; runtime = $script:RuntimeRoot; projectCache = $script:ProjectCacheRoot; initialRuntime = $InitialRuntime; initialLock = $InitialLock; missingParents = $script:MissingParents; artifacts = @(); processes = @(); config = @{}; binary = ''; dataExisted = $true; keyExisted = $true; finalized = $false }
    Save-DeploymentReceipt
    Register-DeploymentArtifact $script:ProjectCacheRoot
}
# 在首次写入前保存当前路径，所有可撤回产物限定到本项目Runtime或专属缓存。
function Register-DeploymentArtifact {
    param([string]$Path)
    if (-not $script:Receipt) { return }
    $Path = [IO.Path]::GetFullPath($Path)
    foreach ($row in @($script:Receipt.artifacts)) { if ($row.path -ceq $Path) { return } }
    Assert-NoReparsePoint $Path
    $exists = Test-Path -LiteralPath $Path
    $beforeHash = Get-DeploymentFingerprint $Path
    $cursor = [IO.Path]::GetDirectoryName($Path)
    while ($cursor -and -not (Test-Path -LiteralPath $cursor)) { $script:Receipt.missingParents = @($script:Receipt.missingParents) + $cursor; $cursor = [IO.Path]::GetDirectoryName($cursor) }
    $relative = ''
    if ($exists) {
        $relative = 'previous/' + [Guid]::NewGuid().ToString('N')
        $backup = Join-Path $script:ReceiptDirectory $relative
        $null = New-Item -ItemType Directory -Force -Path ([IO.Path]::GetDirectoryName($backup))
        Copy-Item -LiteralPath $Path -Destination $backup -Recurse -Force
        if ((Get-DeploymentFingerprint $Path) -cne $beforeHash -or (Get-DeploymentFingerprint $backup) -cne $beforeHash) { throw '部署前原点副本校验失败或源发生变化，停止写入。' }
    }
    $row = [pscustomobject]@{ path = $Path; before = $(if ($exists) { 'existing' } else { 'absent' }); beforeHash = $beforeHash; backup = $relative; after = $beforeHash }
    $script:Receipt.artifacts = @($script:Receipt.artifacts) + $row
    Save-DeploymentReceipt
}
# 记录进程创建时间与实际程序位置，反部署拒绝PID复用和同名进程。
function Register-DeploymentProcess {
    param([Diagnostics.Process]$Process, [string]$Role)
    $script:Receipt.processes = @($script:Receipt.processes | Where-Object { $_.role -ne $Role }) + [pscustomobject]@{ role = $Role; pid = $Process.Id; started = $Process.StartTime.ToUniversalTime().Ticks.ToString(); executable = $Process.MainModule.FileName }
    Save-DeploymentReceipt
}
# 保存实际子进程的必要数据配置，不转储整个环境，密钥/连接资料只进私有记录。
function Save-DeploymentConfiguration {
    $configuration = @{}
    foreach ($name in @('WB_DATA_DIR', 'WB_KEY_FILE', 'WB_TIDB_DSN', 'WB_REQUIRE_DB_TLS', 'WB_PROJECT_ROOT', 'WB_RUNTIME_DIR')) {
        $configuration[$name] = $(if ($script:AppEnvironment.ContainsKey($name)) { $script:AppEnvironment[$name] } else { '' })
    }
    if (@($script:Receipt.config.PSObject.Properties).Count -eq 0 -or $script:Receipt.config -is [hashtable] -and $script:Receipt.config.Count -eq 0) {
        $script:Receipt.dataExisted = Test-Path -LiteralPath $configuration.WB_DATA_DIR
        $script:Receipt.keyExisted = Test-Path -LiteralPath $configuration.WB_KEY_FILE
    } else {
        foreach ($name in @('WB_DATA_DIR', 'WB_KEY_FILE', 'WB_TIDB_DSN')) {
            if ([string]$script:Receipt.config.$name -cne [string]$configuration[$name]) { throw '数据/密钥/存储路线改变；先按原部署清单反部署，不能覆盖最初原点。' }
        }
    }
    $script:Receipt.config = $configuration
    foreach ($start in @($configuration.WB_DATA_DIR, [IO.Path]::GetDirectoryName($configuration.WB_KEY_FILE))) {
        $cursor = $start
        while ($cursor -and -not (Test-Path -LiteralPath $cursor)) { $script:Receipt.missingParents = @($script:Receipt.missingParents) + $cursor; $cursor = [IO.Path]::GetDirectoryName($cursor) }
    }
    Save-DeploymentReceipt
}
# 会话结束才封存产物摘要，反部署检查任何后续修改并保留冲突文件。
function Complete-DeploymentReceipt {
    if (-not $script:Receipt) { return }
    foreach ($row in @($script:Receipt.artifacts)) { $row.after = Get-DeploymentFingerprint $row.path }
    $script:Receipt.finalized = $true
    Save-DeploymentReceipt
}
# 导入原生进程管理器，Job Object保证仅回收本次启动的进程树。
function Initialize-OwnedProcessSession {
    if ($script:Session) { return }
    if (-not ('JobsRepairDeploySession' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Text;
using System.Collections.Generic;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text.RegularExpressions;
public sealed class JobsRepairDeploySession : IDisposable {
    [StructLayout(LayoutKind.Sequential)] struct Basic {
        public long A, B; public uint Flags; public UIntPtr Min, Max;
        public uint Active; public UIntPtr Affinity; public uint Priority, Scheduling;
    }
    [StructLayout(LayoutKind.Sequential)] struct Io {
        public ulong A, B, C, D, E, F;
    }
    [StructLayout(LayoutKind.Sequential)] struct Extended {
        public Basic Basic; public Io Io;
        public UIntPtr ProcessMemory, JobMemory, PeakProcess, PeakJob;
    }
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
    static extern IntPtr CreateJobObject(IntPtr attributes, string name);
    [DllImport("kernel32.dll", SetLastError=true)]
    static extern bool SetInformationJobObject(IntPtr job, int info, IntPtr data, uint size);
    [DllImport("kernel32.dll", SetLastError=true)]
    static extern bool AssignProcessToJobObject(IntPtr job, IntPtr process);
    [DllImport("kernel32.dll", SetLastError=true)]
    static extern bool TerminateJobObject(IntPtr job, uint code);
    [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr value);
    IntPtr job;
    readonly List<Process> owned = new List<Process>();
    readonly Dictionary<Process,System.Threading.ManualResetEvent[]> drained = new Dictionary<Process,System.Threading.ManualResetEvent[]>();
    readonly object gate = new object();
    Exception logError;
    public JobsRepairDeploySession() {
        job = CreateJobObject(IntPtr.Zero, null);
        if(job == IntPtr.Zero) throw new InvalidOperationException("Cannot create deployment Job Object.");
        Extended value = new Extended(); value.Basic.Flags = 0x2000;
        int size = Marshal.SizeOf(typeof(Extended));
        IntPtr data = Marshal.AllocHGlobal(size);
        try {
            Marshal.StructureToPtr(value, data, false);
            if(!SetInformationJobObject(job, 9, data, (uint)size)) throw new InvalidOperationException("Cannot configure deployment Job Object.");
        } catch { CloseHandle(job); job=IntPtr.Zero; throw; }
        finally { Marshal.FreeHGlobal(data); }
    }
    public static string Quote(string value) {
        StringBuilder result = new StringBuilder("\""); int slashes=0;
        foreach(char ch in value) {
            if(ch=='\\') { slashes++; continue; }
            if(ch=='"') { result.Append('\\', slashes*2+1); result.Append(ch); slashes=0; continue; }
            result.Append('\\', slashes); slashes=0; result.Append(ch);
        }
        result.Append('\\', slashes*2); result.Append('"'); return result.ToString();
    }
    static string Safe(string value) {
        string output=Regex.Replace(value, @"(?i)(https?://)[^/\s|]+@", "$1[凭据已隐藏]@");
        output=Regex.Replace(output, @"(?i)[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}", "[邮箱已隐藏]");
        output=Regex.Replace(output, @"(?i)(password|authtoken|token|secret|dsn)\s*[=:]\s*\S+", "$1=[已隐藏]");
        output=Regex.Replace(output, @"(https?://[^\s?]+)\?[^\s]+", "$1?[参数已隐藏]");
        return output;
    }
    void Write(string path, string value) {
        if(value==null) return;
        lock(gate) {
            try { File.AppendAllText(path, Safe(value)+Environment.NewLine, new UTF8Encoding(false)); }
            catch(Exception error) { if(logError==null) logError=error; }
        }
    }
    public void CheckLogHealth() {
        lock(gate) { if(logError!=null) throw new IOException("Deployment output log cannot be written; stopping owned processes.",logError); }
    }
    static void Signal(System.Threading.ManualResetEvent handle) {
        try { handle.Set(); } catch(ObjectDisposedException) {}
    }
    public Process Start(string file, string[] args, string directory, Dictionary<string,string> environment, string output) {
        CheckLogHealth();
        ProcessStartInfo info = new ProcessStartInfo(file);
        List<string> quoted=new List<string>();
        foreach(string arg in args) quoted.Add(Quote(arg));
        info.Arguments=String.Join(" ", quoted.ToArray());
        info.WorkingDirectory=directory; info.UseShellExecute=false; info.CreateNoWindow=true;
        info.RedirectStandardOutput=true; info.RedirectStandardError=true;
        info.StandardOutputEncoding=new UTF8Encoding(false); info.StandardErrorEncoding=new UTF8Encoding(false);
        foreach(KeyValuePair<string,string> pair in environment) {
            if(pair.Value==null) info.EnvironmentVariables.Remove(pair.Key);
            else info.EnvironmentVariables[pair.Key]=pair.Value;
        }
        Process process=new Process(); process.StartInfo=info;
        System.Threading.ManualResetEvent[] eof = {
            new System.Threading.ManualResetEvent(false), new System.Threading.ManualResetEvent(false)
        };
        process.OutputDataReceived+=(sender,eventArgs)=> { if(eventArgs.Data==null) Signal(eof[0]); else Write(output,eventArgs.Data); };
        process.ErrorDataReceived+=(sender,eventArgs)=> { if(eventArgs.Data==null) Signal(eof[1]); else Write(output,eventArgs.Data); };
        if(!process.Start()) throw new InvalidOperationException("Cannot start owned process.");
        if(!AssignProcessToJobObject(job,process.Handle)) {
            try { process.Kill(); process.WaitForExit(2000); } catch {}
            foreach(System.Threading.ManualResetEvent handle in eof) handle.Dispose();
            process.Dispose();
            throw new InvalidOperationException("Cannot assign owned process to deployment Job Object; stopped without process-name fallback.");
        }
        owned.Add(process);
        drained.Add(process,eof);
        process.BeginOutputReadLine(); process.BeginErrorReadLine();
        return process;
    }
    public bool FlushOutput(Process process, int milliseconds) {
        CheckLogHealth();
        System.Threading.ManualResetEvent[] eof;
        if(!drained.TryGetValue(process,out eof)) return false;
        DateTime deadline=DateTime.UtcNow.AddMilliseconds(milliseconds);
        foreach(System.Threading.ManualResetEvent handle in eof) {
            int remaining=Math.Max(0,(int)(deadline-DateTime.UtcNow).TotalMilliseconds);
            if(!handle.WaitOne(remaining)) return false;
        }
        CheckLogHealth();
        return true;
    }
    // fzf inherits the current console for its UI; only choices and results are redirected.
    public Process StartMenu(string file, string[] args, string directory, Dictionary<string,string> environment, string input, string output) {
        CheckLogHealth();
        ProcessStartInfo info = new ProcessStartInfo(file);
        List<string> quoted=new List<string>();
        foreach(string arg in args) quoted.Add(Quote(arg));
        info.Arguments=String.Join(" ", quoted.ToArray());
        info.WorkingDirectory=directory; info.UseShellExecute=false; info.CreateNoWindow=false;
        info.RedirectStandardInput=true; info.RedirectStandardOutput=true;
        info.StandardOutputEncoding=new UTF8Encoding(false);
        foreach(KeyValuePair<string,string> pair in environment) {
            if(pair.Value==null) info.EnvironmentVariables.Remove(pair.Key);
            else info.EnvironmentVariables[pair.Key]=pair.Value;
        }
        Process process=new Process(); process.StartInfo=info;
        System.Threading.ManualResetEvent[] eof = {
            new System.Threading.ManualResetEvent(false), new System.Threading.ManualResetEvent(true)
        };
        process.OutputDataReceived+=(sender,eventArgs)=> { if(eventArgs.Data==null) Signal(eof[0]); else Write(output,eventArgs.Data); };
        if(!process.Start()) throw new InvalidOperationException("Cannot start browser menu.");
        if(!AssignProcessToJobObject(job,process.Handle)) {
            try { process.Kill(); process.WaitForExit(2000); } catch {}
            foreach(System.Threading.ManualResetEvent handle in eof) handle.Dispose();
            process.Dispose();
            throw new InvalidOperationException("Cannot assign browser menu to this deployment Job Object.");
        }
        owned.Add(process); drained.Add(process,eof);
        process.BeginOutputReadLine();
        byte[] choices=File.ReadAllBytes(input);
        process.StandardInput.BaseStream.Write(choices,0,choices.Length);
        process.StandardInput.BaseStream.Flush(); process.StandardInput.Close();
        return process;
    }
    public void ReleaseMenu(Process process) {
        if(!process.HasExited || !FlushOutput(process,2000)) throw new IOException("Browser menu output was not fully received.");
        System.Threading.ManualResetEvent[] eof;
        if(drained.TryGetValue(process,out eof)) {
            foreach(System.Threading.ManualResetEvent handle in eof) handle.Dispose();
            drained.Remove(process);
        }
        owned.Remove(process); process.Dispose();
    }
    public void Dispose() {
        if(job==IntPtr.Zero) return;
        foreach(Process process in owned) {
            try { if(!process.HasExited) process.CloseMainWindow(); } catch {}
        }
        DateTime deadline=DateTime.UtcNow.AddSeconds(2);
        while(DateTime.UtcNow<deadline) {
            bool running=false;
            foreach(Process process in owned) {
                try { if(!process.HasExited) running=true; } catch {}
            }
            if(!running) break;
            System.Threading.Thread.Sleep(50);
        }
        TerminateJobObject(job,130);
        CloseHandle(job); job=IntPtr.Zero;
        foreach(Process process in owned) {
            try { process.WaitForExit(2000); FlushOutput(process,2000); process.Dispose(); } catch {}
        }
        foreach(System.Threading.ManualResetEvent[] eof in drained.Values) {
            foreach(System.Threading.ManualResetEvent handle in eof) handle.Dispose();
        }
        drained.Clear();
        owned.Clear();
    }
}
'@
    }
    $script:Session = New-Object JobsRepairDeploySession
}
# 以原生参数引用与受控环境启动属于本次的子进程。
function Start-OwnedProcess {
    param([string]$File, [string[]]$Arguments, [hashtable]$Environment = @{}, [string]$LogName = 'process.log')
    $variables = New-Object 'Collections.Generic.Dictionary[string,string]'
    foreach ($key in $Environment.Keys) { $variables.Add([string]$key, $Environment[$key]) }
    $path = Join-Path $script:RunDirectory $LogName
    return $script:Session.Start($File, $Arguments, $script:ProjectRoot, $variables, $path)
}
# 获取工具的锁定资产并验证其官方来源。
function Get-LockedAsset {
    param([object[]]$Rows, [string]$Tool)
    $matches = @($Rows | Where-Object { $_.tool -eq $Tool -and $_.os -eq 'windows' -and $_.arch -eq $script:ToolArch })
    if ($matches.Count -ne 1) { throw "未提供 $Tool / windows / $($script:ToolArch) 的锁定成品，不使用其它架构冒充支持。" }
    $asset = $matches[0]
    $expected = if ($Tool -eq 'go') { 'https://go.dev/dl/' + $asset.filename } else {
        $repo = if ($Tool -eq 'fzf') { 'junegunn/fzf' } else { 'cloudflare/cloudflared' }
        $tag = if ($Tool -eq 'fzf') { 'v' + $asset.version } else { $asset.version }
        'https://github.com/' + $repo + '/releases/download/' + $tag + '/' + $asset.filename
    }
    if ($asset.url -cne $expected -or $asset.filename -match '[/\\:]') { throw '工具锁清单来源不符合官方固定版本路径。' }
    return $asset
}
# 下载至独立暂存文件，任何HTTP错误或超时均不采用部分产物。
function Save-VerifiedDownloadOnce {
    param([object]$Asset, [string]$Destination)
    Write-DeployLog ("来源｜" + $Asset.tool + ' windows/' + $Asset.arch + ' ' + $Asset.version)
    Write-DeployLog ("下载｜" + $Asset.url)
    Write-DeployLog ("目标｜" + $Destination)
    Write-DeployLog ("SHA256｜" + $Asset.sha256)
    $oldProtocol = [Net.ServicePointManager]::SecurityProtocol
    $response = $null
    $inputStream = $null
    $outputStream = $null
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $request = [Net.HttpWebRequest]::Create($Asset.url)
        $request.Timeout = 30000
        $request.ReadWriteTimeout = 30000
        $request.UserAgent = 'Jobs-Repair-Deployment'
        $response = $request.GetResponse()
        if ($response.ResponseUri.Scheme -ne 'https') { throw '下载重定向离开HTTPS，已拒绝。' }
        $inputStream = $response.GetResponseStream()
        $outputStream = New-Object IO.FileStream($Destination, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
        $buffer = New-Object byte[] 65536
        $timer = [Diagnostics.Stopwatch]::StartNew()
        while (($read = $inputStream.Read($buffer, 0, $buffer.Length)) -gt 0) {
            if ($timer.Elapsed.TotalSeconds -gt 180) { throw (New-Object TimeoutException -ArgumentList '本次下载超过180秒，不使用未完成文件。') }
            $outputStream.Write($buffer, 0, $read)
        }
    } finally {
        if ($outputStream) { $outputStream.Dispose() }
        if ($inputStream) { $inputStream.Dispose() }
        if ($response) { $response.Dispose() }
        [Net.ServicePointManager]::SecurityProtocol = $oldProtocol
    }
    $actual = (Get-FileHash -LiteralPath $Destination -Algorithm SHA256).Hash
    if ($actual -ine $Asset.sha256) { throw '下载产物SHA256与锁清单不符，拒绝解压和执行。' }
}
# 网络故障持续退避；权限、来源、摘要或本机写入错误不重试。
function Save-VerifiedDownload {
    param([object]$Asset, [string]$Destination)
    Assert-NoReparsePoint $Destination
    if (Test-Path -LiteralPath $Destination) { throw '下载暂存目标已存在，拒绝覆盖。' }
    $delay = 1
    while ($true) {
        try { Save-VerifiedDownloadOnce $Asset $Destination; return }
        catch {
            $retry = $false
            $exception = $_.Exception
            while ($exception) {
                if ($exception -is [TimeoutException]) { $retry = $true }
                if ($exception -is [Net.WebException]) {
                    if ($exception.Status -in @([Net.WebExceptionStatus]::Timeout,[Net.WebExceptionStatus]::ConnectFailure,[Net.WebExceptionStatus]::NameResolutionFailure,[Net.WebExceptionStatus]::ReceiveFailure,[Net.WebExceptionStatus]::SendFailure,[Net.WebExceptionStatus]::ConnectionClosed,[Net.WebExceptionStatus]::KeepAliveFailure)) { $retry = $true }
                    if ($exception.Response -is [Net.HttpWebResponse]) {
                        $status = [int]$exception.Response.StatusCode
                        if ($status -eq 408 -or $status -eq 429 -or $status -ge 500 -and $status -le 599 -or $status -eq 403 -and $exception.Response.Headers['X-RateLimit-Remaining'] -eq '0') { $retry = $true }
                    }
                }
                if ($exception -is [Net.Sockets.SocketException] -and $exception.SocketErrorCode -in @([Net.Sockets.SocketError]::TimedOut,[Net.Sockets.SocketError]::ConnectionReset,[Net.Sockets.SocketError]::ConnectionAborted,[Net.Sockets.SocketError]::NetworkDown,[Net.Sockets.SocketError]::NetworkUnreachable)) { $retry = $true }
                $exception = $exception.InnerException
            }
            if (-not $retry) { throw }
            if (Test-Path -LiteralPath $Destination -PathType Leaf) { Assert-NoReparsePoint $Destination; Remove-Item -LiteralPath $Destination -Force }
            Write-DeployLog ("官方归档暂未获取完成；${delay}秒后继续，Ctrl+C可取消。") 'WARN'
            Start-Sleep -Seconds $delay
            $delay = [Math]::Min(15, $delay * 2)
        }
    }
}
# 仅解压已验摘要的安全相对路径，拒绝绝对路径、父级跳转及链接。
function Expand-VerifiedZip {
    param([string]$Archive, [string]$Destination, [string]$Tool)
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [IO.Compression.ZipFile]::OpenRead($Archive)
    try {
        foreach ($entry in $zip.Entries) {
            $name = $entry.FullName.Replace('\', '/')
            $modeType = ($entry.ExternalAttributes -shr 16) -band 61440
            if ($name -match '(^/|^[A-Za-z]:|(^|/)\.\.(/|$)|:)' -or $modeType -eq 40960) {
                throw '归档包含路径跳转、绝对路径或符号链接，已拒绝。'
            }
            if (($Tool -eq 'fzf' -and $name -ne 'fzf.exe') -or ($Tool -eq 'go' -and $name -notmatch '^go/')) {
                throw '归档目录与预期工具布局不符，已拒绝。'
            }
            $target = [IO.Path]::GetFullPath((Join-Path $Destination $name))
            $prefix = [IO.Path]::GetFullPath($Destination).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
            if (-not $target.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { throw '归档路径逃逸。' }
            if ($name.EndsWith('/')) {
                $null = New-Item -ItemType Directory -Force -Path $target
            } else {
                $null = New-Item -ItemType Directory -Force -Path ([IO.Path]::GetDirectoryName($target))
                [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $target, $false)
            }
        }
    } finally { $zip.Dispose() }
}
# 检查已存在的原生工具，损坏或版本条件不满足时不视为健康。
function Get-ToolProbeEnvironment {
    param([string]$Tool)
    $variables = @{}
    if ($Tool -eq 'fzf') {
        foreach ($key in @('FZF_DEFAULT_OPTS', 'FZF_DEFAULT_OPTS_FILE', 'FZF_DEFAULT_COMMAND')) { $variables[$key] = $null }
    }
    if ($Tool -eq 'go') {
        $variables['GOTOOLCHAIN'] = 'local'
        $variables['GOTELEMETRY'] = 'off'
        $variables['GOROOT'] = $null
    }
    if ($Tool -eq 'cloudflared') {
        foreach ($key in [Environment]::GetEnvironmentVariables('Process').Keys) {
            if ([string]$key -match '^TUNNEL_') { $variables[[string]$key] = $null }
        }
    }
    return $variables
}
# 读取PE机器类型，不把模拟执行的x64程序标为ARM64原生支持。
function Test-NativeExecutable {
    param([string]$Path)
    $stream = $null
    $reader = $null
    try {
        $stream = [IO.File]::OpenRead($Path)
        $reader = New-Object IO.BinaryReader($stream)
        if ($stream.Length -lt 64 -or $reader.ReadUInt16() -ne 23117) { return $false }
        $stream.Position = 60
        $peOffset = $reader.ReadInt32()
        if ($peOffset -lt 64 -or $peOffset -gt $stream.Length - 6) { return $false }
        $stream.Position = $peOffset
        if ($reader.ReadUInt32() -ne 17744) { return $false }
        $machine = $reader.ReadUInt16()
        return ($script:ToolArch -eq 'amd64' -and $machine -eq 34404) -or ($script:ToolArch -eq 'arm64' -and $machine -eq 43620)
    } catch { return $false }
    finally {
        if ($reader) { $reader.Dispose() } elseif ($stream) { $stream.Dispose() }
    }
}
# 健康探针只运行明确原生可执行文件，所有等待均有上限。
function Test-ToolHealth {
    param([string]$Path, [string]$Tool)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $false }
    if ([IO.Path]::GetExtension($Path) -ine '.exe') { return $false }
    if (-not (Test-NativeExecutable $Path)) { return $false }
    try {
        $flag = if ($Tool -eq 'go') { 'version' } else { '--version' }
        $logName = 'health-' + $Tool + '-' + [Guid]::NewGuid().ToString('N') + '.log'
        $probeEnvironment = Get-ToolProbeEnvironment $Tool
        $process = Start-OwnedProcess $Path @($flag) $probeEnvironment $logName
        if (-not $process.WaitForExit(5000)) {
            $process.Kill()
            $null = $process.WaitForExit(2000)
            return $false
        }
        if ($process.ExitCode -ne 0 -or -not $script:Session.FlushOutput($process, 2000)) { return $false }
        $outputPath = Join-Path $script:RunDirectory $logName
        $version = if (Test-Path -LiteralPath $outputPath -PathType Leaf) { [IO.File]::ReadAllText($outputPath).Trim() } else { '' }
        switch ($Tool) {
            'go' { return $version -match 'go1\.(\d+)(?:\.|[a-z ])' -and [int]$Matches[1] -ge 24 }
            'fzf' { return $version -match '^(\d+)\.(\d+)\.' -and ([int]$Matches[1] -gt 0 -or [int]$Matches[2] -ge 74) }
            'cloudflared' {
                if ($version -notmatch '^cloudflared version \d+\.\d+\.\d+') { return $false }
                $helpName = 'health-cloudflared-help-' + [Guid]::NewGuid().ToString('N') + '.log'
                $helpProcess = Start-OwnedProcess $Path @('tunnel', '--help') $probeEnvironment $helpName
                if (-not $helpProcess.WaitForExit(5000)) {
                    $helpProcess.Kill()
                    $null = $helpProcess.WaitForExit(2000)
                    return $false
                }
                if ($helpProcess.ExitCode -ne 0 -or -not $script:Session.FlushOutput($helpProcess, 2000)) { return $false }
                $helpPath = Join-Path $script:RunDirectory $helpName
                if (-not (Test-Path -LiteralPath $helpPath -PathType Leaf)) { return $false }
                $helpText = [IO.File]::ReadAllText($helpPath)
                return $helpText.Contains('--url') -and $helpText.Contains('--no-autoupdate') -and $helpText.Contains('--config') -and ($script:PublicDemo -or $helpText.Contains('--allowed-mail'))
            }
        }
    } catch { return $false }
    return $false
}
# 优先复用显式配置与PATH健康工具，缺失后仅写工程内缓存。
function Ensure-DeploymentTool {
    param([object[]]$Rows, [string]$Tool, [object]$RequiredAsset = $null)
    if ($RequiredAsset) { $asset = $RequiredAsset } else {
    $explicitName = switch ($Tool) { 'go' { 'GO_BIN' } 'fzf' { 'WB_FZF_BIN' } 'cloudflared' { 'WB_CLOUDFLARED_BIN' } }
    $explicit = [Environment]::GetEnvironmentVariable($explicitName)
    if ($explicit) {
        $candidate = Resolve-ProjectPath $explicit
        if (-not (Test-ToolHealth $candidate $Tool)) { throw "$explicitName 指定的工具不可用或版本不匹配，请修正该配置。" }
        Write-DeployLog ("复用健康工具｜" + $Tool + '（显式配置）')
        return $candidate
    }
    $command = Get-Command ($Tool + '.exe') -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($command -and (Test-ToolHealth $command.Source $Tool)) {
        Write-DeployLog ("复用健康工具｜" + $Tool + '（PATH）')
        return $command.Source
    }
    if ($Tool -eq 'go') {
        $goRoot = Join-Path $script:EnvironmentRoot 'Go'
        if (Test-Path -LiteralPath $goRoot -PathType Container) {
            foreach ($versionRoot in @(Get-ChildItem -LiteralPath $goRoot -Directory -Filter 'go*' | Sort-Object Name -Descending)) {
                $bundled = Join-Path $versionRoot.FullName ('Windows-' + $script:ToolArch + '\go\bin\go.exe')
                if (Test-ToolHealth $bundled 'go') { return $bundled }
            }
        }
    }
    $asset = Get-LockedAsset $Rows $Tool
    }
    $toolDirectory = @{ go = 'Go'; fzf = 'Fzf'; cloudflared = 'Cloudflared' }[$Tool]
    $versionDirectory = $(if ($Tool -eq 'go') { 'go' + $asset.version } else { $asset.version })
    $sharedCache = Join-Path $script:EnvironmentRoot ($toolDirectory + '\' + $versionDirectory + '\Windows-' + $script:ToolArch)
    $cache = Join-Path $script:ProjectCacheRoot ('Tools\' + $toolDirectory + '\' + $versionDirectory + '\Windows-' + $script:ToolArch)
    Assert-NoReparsePoint $cache
    $relativeExe = if ($Tool -eq 'go') { 'go\bin\go.exe' } elseif ($Tool -eq 'fzf') { 'fzf.exe' } else { 'cloudflared.exe' }
    $sharedExecutable = Join-Path $sharedCache $relativeExe
    if ((Test-ToolHealth $sharedExecutable $Tool) -and (-not $RequiredAsset -or (Test-DeploymentToolVersion $sharedExecutable $Tool $asset.version))) { return $sharedExecutable }
    $executable = Join-Path $cache $relativeExe
    $stamp = Join-Path $cache 'artifact.sha256'
    $binaryStamp = Join-Path $cache 'executable.sha256'
    if ((Test-Path -LiteralPath $stamp -PathType Leaf) -and (Test-Path -LiteralPath $binaryStamp -PathType Leaf) -and (Test-Path -LiteralPath $executable -PathType Leaf)) {
        Assert-NoReparsePoint $executable
        $recorded = [IO.File]::ReadAllText($stamp).Trim()
        $recordedBinary = [IO.File]::ReadAllText($binaryStamp).Trim()
        if ($recorded -ieq $asset.sha256 -and $recordedBinary -ieq (Get-FileHash -LiteralPath $executable -Algorithm SHA256).Hash -and (Test-ToolHealth $executable $Tool) -and (-not $RequiredAsset -or (Test-DeploymentToolVersion $executable $Tool $asset.version))) {
            Write-DeployLog ("复用已校验缓存｜" + $Tool + ' ' + $asset.version)
            return $executable
        }
    }
    $downloads = Join-Path $script:ProjectCacheRoot 'Downloads'
    Assert-NoReparsePoint $downloads
    $workspace = Join-Path $downloads ($Tool + '-' + $asset.version + '-Windows-' + $script:ToolArch + '-' + [Guid]::NewGuid().ToString('N'))
    $null = New-Item -ItemType Directory -Force -Path $workspace
    $staging = Join-Path $workspace 'Extract'
    $null = New-Item -ItemType Directory -Path $staging
    $archive = Join-Path $workspace $asset.filename
    Save-VerifiedDownload $asset $archive
    if ($asset.kind -eq 'zip') { Expand-VerifiedZip $archive $staging $Tool }
    elseif ($asset.kind -eq 'binary') { Copy-Item -LiteralPath $archive -Destination (Join-Path $staging $relativeExe) }
    else { throw 'Windows工具归档类型不受支持。' }
    $stagedExe = Join-Path $staging $relativeExe
    if (-not (Test-ToolHealth $stagedExe $Tool) -or ($RequiredAsset -and -not (Test-DeploymentToolVersion $stagedExe $Tool $asset.version))) { throw "下载校验成功但 $Tool 运行复检失败；停止下游操作。" }
    [IO.File]::WriteAllText((Join-Path $staging 'artifact.sha256'), $asset.sha256)
    [IO.File]::WriteAllText((Join-Path $staging 'executable.sha256'), (Get-FileHash -LiteralPath $stagedExe -Algorithm SHA256).Hash)
    $null = New-Item -ItemType Directory -Force -Path ([IO.Path]::GetDirectoryName($cache))
    if (Test-Path -LiteralPath $cache) {
        Move-Item -LiteralPath $cache -Destination ($cache + '.invalid-' + [Guid]::NewGuid().ToString('N'))
    }
    Move-Item -LiteralPath $staging -Destination $cache
    Write-DeployLog ("工具就绪｜" + $Tool + ' ' + $asset.version + '，官方来源与SHA256校验通过。')
    return $executable
}
# 使用本次Job Object启动解析器/探针，输出只保留在本轮私有日志。
function Invoke-DependencyCapture {
    param([string]$File, [string[]]$Arguments, [hashtable]$Environment = @{}, [int]$TimeoutSeconds = 90, [int]$TimeoutCode = 75)
    $name = 'dependency-' + [Guid]::NewGuid().ToString('N') + '.log'
    $process = Start-OwnedProcess $File $Arguments $Environment $name
    if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
        $process.Kill()
        $null = $process.WaitForExit(2000)
        return [pscustomobject]@{ code = $TimeoutCode; text = '本次依赖查询/工具探针超时。' }
    }
    if (-not $script:Session.FlushOutput($process, 2000)) { throw '依赖查询日志无法完整封存。' }
    return [pscustomobject]@{ code = $process.ExitCode; text = [IO.File]::ReadAllText((Join-Path $script:RunDirectory $name)).TrimEnd([char[]]"`r`n") }
}
# 原源码锁只读，查询与构建使用本轮普通文件副本。
function New-ModuleManifestCopy {
    param([string]$Source, [string]$Name)
    $directory = Join-Path $script:RunDirectory ('module-manifests\' + $Name)
    Assert-NoReparsePoint $directory
    $null = New-Item -ItemType Directory -Force -Path $directory
    $original = Join-Path $Source 'go.mod'
    if (-not (Test-Path -LiteralPath $original -PathType Leaf)) { throw '缺少源模块go.mod。' }
    Copy-Item -LiteralPath $original -Destination (Join-Path $directory 'module.mod') -Force
    if (Test-Path -LiteralPath (Join-Path $Source 'go.sum') -PathType Leaf) { Copy-Item -LiteralPath (Join-Path $Source 'go.sum') -Destination (Join-Path $directory 'module.sum') -Force }
    return (Join-Path $directory 'module.mod')
}
# 标准库解析器由引导Go构建；只读检查和计划不会进入此步骤。
function Initialize-DependencyResolver {
    param([string]$Go)
    $source = Join-Path $script:ProjectRoot '部署\公共组件\依赖版本'
    $modfile = New-ModuleManifestCopy $source 'resolver'
    $script:DependencyResolver = Join-Path $script:RunDirectory 'dependency-versions.exe'
    $environment = @{}
    foreach ($key in $script:AppEnvironment.Keys) { $environment[$key] = $script:AppEnvironment[$key] }
    $environment['GOWORK'] = 'off'
    Write-DeployLog '准备本轮官方稳定版本解析器；不修改源码或全局工具。'
    $process = Start-OwnedProcess $Go @('-C', $source, 'build', '-mod=readonly', ('-modfile=' + $modfile), '-o', $script:DependencyResolver, '.') $environment 'dependency-build.log'
    Wait-OwnedBuild $process
    if (-not (Test-Path -LiteralPath $script:DependencyResolver -PathType Leaf)) { throw '版本解析器未生成。' }
}
# 提取实际稳定版号，不把开发版或预发布版算作达标。
function Get-DeploymentToolVersion {
    param([string]$Path, [string]$Tool)
    $flag = if ($Tool -eq 'go') { 'version' } else { '--version' }
    $reply = Invoke-DependencyCapture $Path @($flag) (Get-ToolProbeEnvironment $Tool) 8
    if ($reply.code -ne 0) { return '' }
    $pattern = switch ($Tool) {
        'go' { '^go version go(\d+\.\d+(?:\.\d+)?)(?:\s|$)' }
        'fzf' { '^(\d+\.\d+(?:\.\d+)?)(?:\s|$)' }
        'cloudflared' { '^cloudflared version (\d+\.\d+(?:\.\d+)?)(?:\s|$)' }
    }
    if ($reply.text -match $pattern) { return $Matches[1] }
    return ''
}
# >=与旧版是正常比较结果，非法输入或解析器故障才停止。
function Test-DependencyVersionAtLeast {
    param([string]$Installed, [string]$Target)
    $reply = Invoke-DependencyCapture $script:DependencyResolver @('--compare', $Installed, '--at-least', $Target)
    if ($reply.code -eq 0 -and $reply.text -ceq '1') { return $true }
    if ($reply.code -eq 1 -and $reply.text -ceq '0') { return $false }
    throw '无法可靠比较工具版本，停止部署。'
}
# 功能和实际稳定版本都满足官方目标才复用候选工具。
function Test-DeploymentToolVersion {
    param([string]$Path, [string]$Tool, [string]$Target)
    if (-not (Test-ToolHealth $Path $Tool)) { return $false }
    $version = Get-DeploymentToolVersion $Path $Tool
    return $version -and (Test-DependencyVersionAtLeast $version $Target)
}
# 每次正常部署查官方最新稳定发行版，仅75类网络故障持续退避。
function Get-OfficialDependencyAsset {
    param([string]$Tool)
    $delay = 1
    $arguments = @('--tool', $Tool, '--os', 'windows', '--arch', $script:ToolArch, '--locked-manifest', $script:ManifestPath)
    if ($Tool -eq 'go') { $arguments += @('--minimum-go', '1.24.0') }
    while ($true) {
        $reply = Invoke-DependencyCapture $script:DependencyResolver $arguments
        if ($reply.code -eq 0) { break }
        if ($reply.code -ne 75) { throw ("官方$Tool 版本/摘要无法确认，停止部署。" + $reply.text) }
        Write-DeployLog ("官方$Tool 查询暂未完成；${delay}秒后继续，Ctrl+C可取消。") 'WARN'
        Start-Sleep -Seconds $delay
        $delay = [Math]::Min(15, $delay * 2)
    }
    $fields = $reply.text.Split([char]9)
    if ($fields.Length -ne 8 -or $reply.text.Contains("`n") -or $fields[0] -cne $Tool -or $fields[1] -cne 'windows' -or $fields[2] -cne $script:ToolArch -or $fields[3] -notmatch '^\d+\.\d+(?:\.\d+)?$') { throw '官方资产解析行无效或平台架构不匹配。' }
    $asset = [pscustomobject]@{ tool=$fields[0]; os=$fields[1]; arch=$fields[2]; version=$fields[3]; filename=$fields[4]; sha256=$fields[5]; url=$fields[6]; kind=$fields[7] }
    if ($asset.kind -eq 'unsupported') {
        if ($asset.filename -cne '-' -or $asset.sha256 -cne '-' -or $asset.url -cne '-') { throw '不支持的平台资产返回格式异常。' }
    } else {
        $repo = if ($Tool -eq 'fzf') { 'junegunn/fzf' } else { 'cloudflare/cloudflared' }
        $tag = if ($Tool -eq 'fzf') { 'v' + $asset.version } else { $asset.version }
        $expected = if ($Tool -eq 'go') { 'https://go.dev/dl/' + $asset.filename } else { 'https://github.com/' + $repo + '/releases/download/' + $tag + '/' + $asset.filename }
        if ($asset.url -cne $expected -or $asset.sha256 -notmatch '^[a-fA-F0-9]{64}$' -or $asset.filename -match '[/\\:]' -or $asset.kind -notin @('zip','binary')) { throw '官方资产来源、摘要或归档格式不匹配。' }
    }
    return $asset
}
# 从显式、PATH和全部版本缓存择新，不覆盖显式或系统工具。
function Resolve-LatestDeploymentTool {
    param([object[]]$Rows, [string]$Tool)
    $asset = Get-OfficialDependencyAsset $Tool
    $explicitName = switch ($Tool) { 'go' { 'GO_BIN' } 'fzf' { 'WB_FZF_BIN' } 'cloudflared' { 'WB_CLOUDFLARED_BIN' } }
    $explicit = [Environment]::GetEnvironmentVariable($explicitName)
    $command = Get-Command ($Tool + '.exe') -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    $initial = if ($explicit) { Resolve-ProjectPath $explicit } elseif ($command) { $command.Source } else { '' }
    $current = if ($initial -and (Test-NativeExecutable $initial)) { Get-DeploymentToolVersion $initial $Tool } else { '' }
    Write-DeployLog ("工具版本｜$Tool｜当前 " + $(if ($current) { $current } else { '未安装或不可识别' }) + '｜官方稳定目标 ' + $asset.version)
    $selected = ''; $selectedVersion = ''
    if ($explicit) {
        if (-not (Test-DeploymentToolVersion $initial $Tool $asset.version)) { throw "显式$Tool 未达到官方稳定目标$($asset.version)或功能不兼容；请更新显式配置，原文件保留。" }
        $selected = $initial
    } else {
        if ($asset.kind -eq 'unsupported') { throw "官方$Tool $($asset.version)未提供windows/$($script:ToolArch)成品；仅可显式指定匹配的原生新版工具。" }
        $directory = @{ go='Go'; fzf='Fzf'; cloudflared='Cloudflared' }[$Tool]
        $relative = if ($Tool -eq 'go') { 'go\bin\go.exe' } else { $Tool + '.exe' }
        $candidates = @()
        if ($command) { $candidates += $command.Source }
        if ($Tool -eq 'fzf' -and $script:FzfExecutable) { $candidates += $script:FzfExecutable }
        foreach ($base in @((Join-Path $script:EnvironmentRoot $directory), (Join-Path $script:ProjectCacheRoot ('Tools\' + $directory)))) {
            if (Test-Path -LiteralPath $base -PathType Container) {
                foreach ($versionRoot in @(Get-ChildItem -LiteralPath $base -Directory)) { $candidates += Join-Path $versionRoot.FullName ('Windows-' + $script:ToolArch + '\' + $relative) }
            }
        }
        foreach ($candidate in $candidates) {
            if (-not (Test-DeploymentToolVersion $candidate $Tool $asset.version)) { continue }
            if ($candidate.StartsWith($script:ProjectCacheRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
                $cacheRoot = if ($Tool -eq 'go') { [IO.Path]::GetDirectoryName([IO.Path]::GetDirectoryName([IO.Path]::GetDirectoryName($candidate))) } else { [IO.Path]::GetDirectoryName($candidate) }
                $stamp = Join-Path $cacheRoot 'executable.sha256'
                if (-not (Test-Path -LiteralPath $stamp -PathType Leaf) -or [IO.File]::ReadAllText($stamp).Trim() -ine (Get-FileHash -LiteralPath $candidate -Algorithm SHA256).Hash) { continue }
            }
            $version = Get-DeploymentToolVersion $candidate $Tool
            if (-not $selected -or (Test-DependencyVersionAtLeast $version $selectedVersion)) { $selected=$candidate; $selectedVersion=$version }
        }
        if (-not $selected) { $selected = Ensure-DeploymentTool $Rows $Tool $asset }
        if (-not (Test-DeploymentToolVersion $selected $Tool $asset.version)) { throw "$Tool 采用版本复检未达到官方目标。" }
    }
    $version = Get-DeploymentToolVersion $selected $Tool
    Write-DeployLog ("采用工具｜$Tool $version｜$selected")
    return $selected
}
# 业务库仅检查当前模块路径，超时或查询失败不伪称已是最新。
function Test-BusinessModuleUpdates {
    param([string]$Go)
    $seconds = 30
    if ($env:WB_DEPENDENCY_CHECK_TIMEOUT_SECONDS) {
        if ($env:WB_DEPENDENCY_CHECK_TIMEOUT_SECONDS -notmatch '^\d+$') { throw 'WB_DEPENDENCY_CHECK_TIMEOUT_SECONDS须为1..300秒。' }
        $seconds = [int]$env:WB_DEPENDENCY_CHECK_TIMEOUT_SECONDS
    }
    if ($seconds -lt 1 -or $seconds -gt 300) { throw '业务依赖检查超时须为1..300秒。' }
    foreach ($entry in @(@('backend','代码\后端\后端代码'), @('qr','部署\公共组件\地址二维码'))) {
        $source = Join-Path $script:ProjectRoot $entry[1]
        $modfile = New-ModuleManifestCopy $source ($entry[0] + '-check')
        $environment = Get-ModuleBuildEnvironment $Go
        Write-DeployLog ("业务依赖检查｜$($entry[0])｜最多${seconds}秒，仅检查当前模块路径；源码锁保持不变。")
        $reply = Invoke-DependencyCapture $script:DependencyResolver @('--module-report','--go-bin',$Go,'--module-dir',$source,'--modfile',$modfile,'--timeout-seconds',([string]$seconds)) $environment ($seconds + 8) 3
        if ($reply.code -eq 0) {
            if ($reply.text) { Write-DeployLog ('业务库可更新｜' + $entry[0] + '｜需单独升级与回归：' + [Environment]::NewLine + $reply.text) 'WARN' }
            else { Write-DeployLog ('业务依赖检查完成｜' + $entry[0] + '当前模块路径未报告更新；未检查换路径的新主版本。') }
        } elseif ($reply.code -eq 3) { Write-DeployLog ('业务依赖检查未完成或超时｜' + $entry[0] + '｜按现有锁构建，不视为已确认最新。' + $reply.text) 'WARN' }
        elseif ($reply.code -ge 128) { throw (New-Object OperationCanceledException -ArgumentList '已取消本次业务依赖检查。') }
        else { throw ('业务依赖检查参数、路径或源码锁校验失败，停止核对。' + $reply.text) }
    }
}
# 保留显式模块源含空值/off；用户Go配置存在时不擅自覆盖。
function Get-ModuleBuildEnvironment {
    param([string]$Go)
    $environment = @{}
    foreach ($key in $script:AppEnvironment.Keys) { $environment[$key] = $script:AppEnvironment[$key] }
    $environment['GOWORK'] = 'off'
    if (Test-Path Env:GOPROXY) { $environment['GOPROXY'] = $env:GOPROXY; return $environment }
    $reply = Invoke-DependencyCapture $Go @('env','GOPROXY','GOENV') $environment 8
    if ($reply.code -ne 0) { throw '无法读取Go模块下载源配置。' }
    $values = $reply.text -split '\r?\n'
    if ($values.Length -lt 2) { throw 'Go模块来源配置不完整。' }
    $configured = $values[1] -ne 'off' -and (Test-Path -LiteralPath $values[1] -PathType Leaf) -and (Select-String -LiteralPath $values[1] -Pattern '^GOPROXY=' -Quiet)
    if (-not $configured -and $values[0] -ceq 'https://proxy.golang.org,direct') { $environment['GOPROXY'] = 'https://goproxy.cn|https://proxy.golang.org|direct' }
    return $environment
}

# 临时隔离fzf默认参数与编码，严格返回内部ID或取消。
function Invoke-DeploymentMenu {
    param([string]$Fzf, [string[]]$Items, [string[]]$AllowedIds, [string]$Header, [switch]$CanGoBack)
    $names = @('FZF_DEFAULT_OPTS', 'FZF_DEFAULT_OPTS_FILE', 'FZF_DEFAULT_COMMAND')
    $saved = @{}
    $oldOutput = $OutputEncoding
    $oldConsole = [Console]::OutputEncoding
    try {
        foreach ($name in $names) {
            $saved[$name] = [Environment]::GetEnvironmentVariable($name)
            [Environment]::SetEnvironmentVariable($name, $null, 'Process')
        }
        $OutputEncoding = New-Object Text.UTF8Encoding($false)
        [Console]::OutputEncoding = New-Object Text.UTF8Encoding($false)
        $options = @('--height=60%', '--layout=reverse', '--border', '--no-multi', '--delimiter=|', '--with-nth=2', '--prompt=部署> ', ('--header=' + $Header))
        if ($CanGoBack) { $options += '--expect=left' }
        $result = @($Items | & $Fzf @options)
        $code = $LASTEXITCODE
        $nonempty = @($result | ForEach-Object { ([string]$_).Trim() } | Where-Object { $_ })
        if ($CanGoBack -and $code -in @(0, 1) -and $nonempty.Count -gt 0 -and $nonempty[0] -eq 'left') {
            if ($nonempty.Count -gt 2 -or ($nonempty.Count -eq 2 -and $Items -cnotcontains $nonempty[1])) { throw 'fzf返回非法返回结果，已停止。' }
            return 'back'
        }
        if ($code -eq 130 -or ($code -eq 1 -and $nonempty.Count -eq 0)) { return 'cancel' }
        if ($code -ne 0) { throw "fzf选择失败，退出码$code；没有启动部署。" }
        if ($nonempty.Count -ne 1 -or $Items -cnotcontains $nonempty[0]) { throw 'fzf返回空或非法选择，已停止。' }
        $id = $nonempty[0].Split('|')[0]
        if ($AllowedIds -cnotcontains $id) { throw 'fzf返回未识别模式，已停止。' }
        return $id
    } finally {
        foreach ($name in $names) { [Environment]::SetEnvironmentVariable($name, $saved[$name], 'Process') }
        $OutputEncoding = $oldOutput
        [Console]::OutputEncoding = $oldConsole
    }
}
# 通过二级选择确定公网范围，返回根菜单时不启动或构建业务。
function Select-DeploymentMode {
    param([string]$Fzf)
    while ($true) {
        $selected = Invoke-DeploymentMenu $Fzf @('local|本地部署＋内网穿透', 'server|正常服务器部署（回环服务，无隧道）') @('local', 'server') '回车选择；Esc取消'
        if ($selected -eq 'cancel') { return $false }
        if ($selected -eq 'server') { $script:Selection = 'server'; return $true }
        Write-DeployLog '关闭此运行终端，服务将结束' 'WARN' -Emphasize
        if ($script:ToolArch -ne 'amd64') {
            Write-DeployLog '当前锁清单没有Windows ARM64原生cloudflared；仅可复用已提供的健康原生客户端，否则在启动后端前停止，不使用x64替代。' 'WARN'
        }
        $accessHeader = "默认浏览器：打开公网链接→输入允许的邮箱→收取并填写验证码。`n邮箱只验证访问者身份，与维修业务无关。`n原生App/API无法完成网页验证码，请选公开演示，仅用合成数据。`n左方向键返回部署模式；Esc取消。"
        $access = Invoke-DeploymentMenu $Fzf @('mail|浏览器访问（指定邮箱收验证码）', 'public|公开演示／App联调（隧道不验证邮箱）') @('mail', 'public') $accessHeader -CanGoBack
        if ($access -eq 'back') { continue }
        if ($access -eq 'cancel') { return $false }
        if ($access -eq 'public') {
            Write-Host '已选择公开演示／App联调：隧道不验证邮箱，任何取得链接的人都能到达服务入口。'
            Write-Host '固定演示账号会被公网访问。只允许合成资料；确认公开联调请输入PUBLIC，其它输入取消：' -ForegroundColor Yellow
            if ([Console]::ReadLine() -cne 'PUBLIC') { return $false }
            $script:PublicDemo = $true
            $script:AllowedMail = $null
        } else {
            Write-Host '已选择浏览器访问：邮箱只用于公网入口身份验证，与维修业务无关。'
            Write-Host '访问者打开HTTPS链接后，输入允许的邮箱，再收取并填写一次性验证码才能进入。'
            Write-Host '原生App/API无法完成网页验证码；联调请选择公开演示。'
            $mail = $env:WB_TUNNEL_ALLOWED_MAIL
            if ([string]::IsNullOrWhiteSpace($mail)) {
                Write-Host '输入允许访问者的邮箱（本人或受邀者，多个用英文逗号分隔）；空行取消：' -NoNewline
                $mail = [Console]::ReadLine()
            }
            $emails = @()
            if ($null -ne $mail) { $emails = @($mail.Split(',') | ForEach-Object { $_.Trim() }) }
            if ($emails.Count -eq 0 -or @($emails | Where-Object { $_ -notmatch '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$' }).Count -gt 0) {
                Write-DeployLog '邮箱为空或格式无效，取消本次部署。' 'WARN'
                return $false
            }
            $script:AllowedMail = (@($emails | Select-Object -Unique) -join ',')
            $script:PublicDemo = $false
        }
        $script:Selection = 'local'
        return $true
    }
}
# 配置本次子进程环境，不修改调用者环境或现有数据。
function Set-WorkbenchEnvironment {
    $defaults = @{
        WB_ADDR = '127.0.0.1:8098'
        WB_DATA_DIR = (Join-Path $script:RuntimeRoot 'data')
        WB_PROJECT_ROOT = $script:ProjectRoot
        WB_RUNTIME_DIR = $script:RuntimeRoot
        WB_WEB_DIR = '代码\前端\PC端\Web\维修工作台'
        WB_ADMIN_DIR = '代码\前端\后台管理端\Web'
        WB_ADMIN_FLUTTER_DIR = '代码\前端\后台管理端\Flutter\Dist\Web'
        WB_CLIENT_FLUTTER_DIR = '代码\前端\移动端\Flutter\Dist\Web'
        WB_ADMIN_CONTRACT_DIR = '代码\前端\后台管理端\共享契约'
    }
    foreach ($key in $defaults.Keys) {
        $value = [Environment]::GetEnvironmentVariable($key)
        if ([string]::IsNullOrWhiteSpace($value)) { $value = $defaults[$key] }
        if ($key -ne 'WB_ADDR') { $value = Resolve-ProjectPath $value }
        $script:AppEnvironment[$key] = $value
    }
    $keyFile = $env:WB_KEY_FILE
    if ([string]::IsNullOrWhiteSpace($keyFile)) {
        $keyFile = Join-Path ([IO.Path]::GetDirectoryName($script:AppEnvironment.WB_DATA_DIR)) 'keys\storage.key'
    }
    $script:AppEnvironment['WB_KEY_FILE'] = Resolve-ProjectPath $keyFile
    foreach ($key in @('WB_BACKUP_DIR', 'WB_BACKUP_INTERVAL_MINUTES', 'WB_TIDB_DSN', 'WB_REQUIRE_DB_TLS')) {
        $value = [Environment]::GetEnvironmentVariable($key)
        if ($value) {
            if ($key -eq 'WB_BACKUP_DIR') { $value = Resolve-ProjectPath $value }
            $script:AppEnvironment[$key] = $value
        }
    }
    $address = $script:AppEnvironment.WB_ADDR
    if ($address -notmatch '^(127\.0\.0\.1|localhost|\[::1\]):([0-9]{1,5})$') { throw 'WB_ADDR只允许回环主机及有效端口。' }
    $port = [int]$Matches[2]
    if ($port -lt 1 -or $port -gt 65535) { throw '端口必须在1..65535。' }
    $script:AppEnvironment['GOOS'] = 'windows'
    $script:AppEnvironment['GOARCH'] = $script:ToolArch
    $script:AppEnvironment['GOTOOLCHAIN'] = 'local'
    $script:AppEnvironment['GOTELEMETRY'] = 'off'
    $script:AppEnvironment['GOMODCACHE'] = Join-Path $script:ProjectCacheRoot 'GoCache\Modules'
    $script:AppEnvironment['GOCACHE'] = Join-Path $script:ProjectCacheRoot 'GoCache\Build'
    $script:AppEnvironment['GOPATH'] = Join-Path $script:ProjectCacheRoot 'GoCache\Path'
    $script:AppEnvironment['GOROOT'] = $null
    if (-not (Get-Command Get-NetTCPConnection -ErrorAction SilentlyContinue)) {
        throw '缺少Windows NetTCPIP/Get-NetTCPConnection，无法核实监听进程归属；停止部署。'
    }
}
# 端口已有监听时停止，不复用旧服务，也不按进程名关闭它。
function Assert-ListeningPortFree {
    $address = $script:AppEnvironment.WB_ADDR
    $port = [int]($address -replace '^.*:', '')
    $listeners = @([Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties().GetActiveTcpListeners() | Where-Object { $_.Port -eq $port })
    if ($listeners.Count -gt 0) { throw "端口$port已有监听，请确认已有程序并选择其它回环端口；本入口没有停止它。" }
}
# 等待本次构建结束，失败不使用旧产物，及时保留退出状态。
function Wait-OwnedBuild {
    param([Diagnostics.Process]$Process)
    $deadline = [DateTime]::UtcNow.AddMinutes(10)
    while (-not $Process.HasExited) {
        if ([DateTime]::UtcNow -gt $deadline) { throw '构建超过10分钟，停止本次进程树；不会启动旧产物。' }
        Start-Sleep -Milliseconds 150
    }
    $null = $Process.WaitForExit(2000)
    $script:Session.CheckLogHealth()
    if ($Process.ExitCode -ne 0) { throw "Go构建失败，退出码$($Process.ExitCode)；查看本次脱敏build.log，不启动旧产物。" }
}
# 构建当前源码至本次运行目录，成功后才启动。
function Build-Workbench {
    param([string]$Go)
    $binary = Join-Path $script:RunDirectory 'workbench.exe'
    $buildEnvironment = Get-ModuleBuildEnvironment $Go
    Write-DeployLog '正在按源码依赖锁构建；模块源仅对子进程有效，不修改全局Go配置。'
    $source = Join-Path $script:ProjectRoot '代码\后端\后端代码'
    $modfile = New-ModuleManifestCopy $source 'backend-build'
    $arguments = @('-C', $source, 'build', '-mod=readonly', ('-modfile=' + $modfile), '-o', $binary, './cmd/workbench')
    $process = Start-OwnedProcess $Go $arguments $buildEnvironment 'build.log'
    Wait-OwnedBuild $process
    if (-not (Test-Path -LiteralPath $binary -PathType Leaf)) { throw '构建退出成功但没有本次程序，停止。' }
    return $binary
}
# HTTP健康成功仍须核实监听归本次进程所有，拒绝旧服务误应答。
function Wait-WorkbenchHealth {
    param([Diagnostics.Process]$Process)
    $port = [int]($script:AppEnvironment.WB_ADDR -replace '^.*:', '')
    $url = 'http://' + $script:AppEnvironment.WB_ADDR + '/api/v38/healthz'
    $deadline = [DateTime]::UtcNow.AddSeconds(30)
    while ([DateTime]::UtcNow -lt $deadline) {
        if ($Process.HasExited) {
            $null = $Process.WaitForExit(2000)
            throw "本次后端在健康前退出，退出码$($Process.ExitCode)；没有启动穿透。"
        }
        try {
            $response = Invoke-WebRequest -UseBasicParsing -Uri $url -TimeoutSec 2 -ErrorAction Stop
            $owners = @(Get-NetTCPConnection -State Listen -LocalPort $port -ErrorAction SilentlyContinue | Select-Object -ExpandProperty OwningProcess)
            if ($response.StatusCode -eq 200 -and $owners -contains $Process.Id -and -not $Process.HasExited) {
                Write-DeployLog '本次后端健康检查通过，监听PID已核对。'
                return
            }
        } catch { }
        Start-Sleep -Milliseconds 250
    }
    throw '30秒内未确认本次后端健康，拒绝启动公网隧道。'
}
# 使用部署已准备的Go构建独立锁定模块，二维码辅助失败不阻止业务启动。
function Build-AccessQr {
    param([string]$Go)
    try {
        $binary = Join-Path $script:RunDirectory 'qr-access.exe'
        $source = Join-Path $script:ProjectRoot '部署\公共组件\地址二维码'
        $environment = Get-ModuleBuildEnvironment $Go
        $modfile = New-ModuleManifestCopy $source 'qr-build'
        Write-DeployLog '二维码依赖来源｜github.com/skip2/go-qrcode；固定版本与校验见部署/公共组件/地址二维码/go.mod、go.sum。'
        $process = Start-OwnedProcess $Go @('-C', $source, 'build', '-mod=readonly', ('-modfile=' + $modfile), '-o', $binary, '.') $environment 'qr-build.log'
        Wait-OwnedBuild $process
        if (-not (Test-Path -LiteralPath $binary -PathType Leaf)) { throw '未生成二维码工具。' }
        $script:QrBinary = $binary
    } catch {
        $script:QrBinary = $null
        Write-DeployLog '二维码工具构建失败；保留完整URL，后端和隧道继续按原流程运行，详见qr-build.log。' 'WARN'
    }
}
# 使旧二维码页失效，退出或地址变化后不能继续当作有效入口。
function Expire-AccessQr {
    if ($script:QrPage -and $script:QrBinary) {
        try {
            $null = & $script:QrBinary --expire --output-dir ([IO.Path]::GetDirectoryName($script:QrPage)) 2>&1
            if ($LASTEXITCODE -ne 0) { throw '失效标记失败。' }
        } catch { Write-DeployLog '旧二维码页失效标记失败，请停止使用之前的码。' 'WARN' }
    }
    $script:QrPage = $null
}
# 原文URL与二维码使用相同入口，终端不足宽时打开本地HTML或SVG扫码。
function Show-AccessQr {
    param([string]$PublicAddress)
    Expire-AccessQr
    $base = $PublicAddress.TrimEnd('/')
    if ($base) {
        Write-DeployLog ('公网地址｜用户／工程师工作台｜' + $base + '/')
        Write-DeployLog ('公网地址｜管理端｜' + $base + '/admin/')
    }
    $local = 'http://' + $script:AppEnvironment.WB_ADDR
    Write-DeployLog ('仅本机地址｜用户／工程师工作台｜' + $local + '/')
    Write-DeployLog ('仅本机地址｜管理端｜' + $local + '/admin/；手机不可通过回环地址访问。')
    if (-not $script:QrBinary) { return }
    try {
        $script:QrGeneration += 1
        $output = Join-Path $script:RunDirectory ('access-qr-' + $script:QrGeneration)
        $arguments = @('--output-dir', $output, '--title', '维修平台访问入口')
        if ($base) { $arguments += @('--entry', ('公网｜用户／工程师工作台|' + $base + '/'), '--entry', ('公网｜管理端|' + $base + '/admin/')) }
        $arguments += @('--entry', ('仅本机，手机不可用｜用户／工程师工作台|' + $local + '/'), '--entry', ('仅本机，手机不可用｜管理端|' + $local + '/admin/'))
        $width = 0
        if (-not [Console]::IsOutputRedirected -and -not (Test-Path Env:NO_COLOR) -and $env:TERM -ne 'dumb' -and $Host.UI.PSObject.Properties['SupportsVirtualTerminal'] -and $Host.UI.SupportsVirtualTerminal) {
            try { $width = [Console]::WindowWidth } catch { $width = 0 }
            $arguments += '--ansi'
        }
        $arguments += @('--terminal-width', [string]$width)
        $lines = @(& $script:QrBinary @arguments 2>&1)
        if ($LASTEXITCODE -ne 0) { throw '二维码工具返回失败。' }
        foreach ($line in $lines) {
            Write-Host ([string]$line)
            $plain = [regex]::Replace([string]$line, ([string][char]27) + '\[[0-9;]*m', '')
            [IO.File]::AppendAllText($script:LogFile, $plain + [Environment]::NewLine, (New-Object Text.UTF8Encoding($false)))
        }
        $page = Join-Path $output 'index.html'
        if (-not (Test-Path -LiteralPath $page -PathType Leaf)) { throw '二维码页面不存在。' }
        $script:QrPage = $page
        Write-DeployLog ('扫码页面｜' + $page + '；终端显示不完整时，用菜单打开此页；页面内SVG可离线查看。')
    } catch {
        $script:QrPage = $null
        Write-DeployLog '二维码生成失败；保留完整URL，服务继续运行，请勿使用之前的码。' 'WARN'
    }
}

# 只展示已脱敏日志中本次生成的实际HTTPS地址。
function Show-QuickTunnelAddress {
    $path = Join-Path $script:RunDirectory 'tunnel.log'
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $null }
    $tail = (Get-Content -LiteralPath $path -Encoding UTF8 -Tail 80) -join [Environment]::NewLine
    $matches = [regex]::Matches($tail, 'https://[a-zA-Z0-9-]+\.trycloudflare\.com')
    if ($matches.Count -gt 0) { return $matches[$matches.Count - 1].Value }
    return $null
}
# 以当前控制台运行地址选择器，主循环继续监控本次服务。
function Start-BrowserMenu {
    param([string]$PublicAddress)
    $script:BrowserItems = @()
    if ($PublicAddress) { $script:BrowserItems += 'public|公网地址｜' + $PublicAddress }
    $script:BrowserItems += 'local|本机地址｜http://' + $script:AppEnvironment.WB_ADDR + '/'
    if ($script:QrPage) { $script:BrowserItems += 'qr|打开扫码页面（各端二维码与原始URL）' }
    $script:BrowserItems += 'pause|收起菜单（服务继续运行，回车再选）'
    $inputPath = Join-Path $script:RunDirectory 'browser-links.txt'
    $outputPath = Join-Path $script:RunDirectory 'browser-selection.txt'
    [IO.File]::WriteAllLines($inputPath, [string[]]$script:BrowserItems, (New-Object Text.UTF8Encoding($false)))
    [IO.File]::WriteAllText($outputPath, '', (New-Object Text.UTF8Encoding($false)))
    $header = "回车：用默认浏览器打开；打开后可继续选择。`n本机地址只供这台电脑访问。"
    if ($PublicAddress) {
        $header += $(if ($script:PublicDemo) { '公网地址已公开，仅用合成数据。' } else { '公网地址需先完成邮箱验证码。' })
    }
    $header += "`nEsc收起菜单，服务继续；回车重新打开。Ctrl+C停止服务。"
    $options = @('--height=60%', '--layout=reverse', '--border', '--no-multi', '--delimiter=|', '--with-nth=2', '--prompt=打开网页> ', '--expect=esc,ctrl-c', ('--header=' + $header))
    $variables = New-Object 'Collections.Generic.Dictionary[string,string]'
    foreach ($name in @('FZF_DEFAULT_OPTS', 'FZF_DEFAULT_OPTS_FILE', 'FZF_DEFAULT_COMMAND')) { $variables.Add($name, $null) }
    $script:BrowserMenu = $script:Session.StartMenu($script:FzfExecutable, $options, $script:ProjectRoot, $variables, $inputPath, $outputPath)
}
# 取消只收起菜单；打开请求失败仍保留服务及后续选择。
function Complete-BrowserMenu {
    param([string]$PublicAddress)
    $process = $script:BrowserMenu
    $null = $process.WaitForExit(2000)
    if (-not $script:Session.FlushOutput($process, 2000)) { throw '网页菜单输出未在时限内完成，停止本次会话。' }
    $code = $process.ExitCode
    $script:Session.ReleaseMenu($process)
    $script:BrowserMenu = $null
    $text = [IO.File]::ReadAllText((Join-Path $script:RunDirectory 'browser-selection.txt'), [Text.Encoding]::UTF8)
    $lines = @($text -split '\r?\n')
    $key = $lines[0]
    if ($key -eq 'ctrl-c') { throw (New-Object OperationCanceledException('已停止本次菜单、后端和隧道，保留数据。')) }
    if ($key -eq 'esc' -or $code -in @(1, 130) -or [string]::IsNullOrEmpty($text)) {
        $script:BrowserMenuPaused = $true
        Write-DeployLog '网页菜单已收起，服务继续运行；在原终端按回车重新选择，Ctrl+C停止。'
        return
    }
    if ($code -ne 0 -or $key -ne '' -or $lines.Count -lt 2 -or $script:BrowserItems -cnotcontains $lines[1]) {
        $script:BrowserMenuPaused = $true
        Write-DeployLog ("网页选择器退出或返回无效结果（退出码$code），没有打开网页；服务继续运行，回车重试。") 'WARN'
        return
    }
    $choice = $lines[1].Split('|')[0]
    if ($choice -eq 'pause') {
        $script:BrowserMenuPaused = $true
        Write-DeployLog '网页菜单已收起，服务继续运行；在原终端按回车重新选择，Ctrl+C停止。'
        return
    }
    $url = $(if ($choice -eq 'public') { $PublicAddress } elseif ($choice -eq 'qr') { $script:QrPage } else { 'http://' + $script:AppEnvironment.WB_ADDR + '/' })
    try {
        Start-Process -FilePath $url -ErrorAction Stop
        Write-DeployLog ('已交给默认浏览器打开：' + $url + '；可继续选择其它地址。')
    } catch {
        Write-DeployLog ('未能打开网页：' + $url + '；服务继续运行，可在菜单中重选。') 'WARN'
    }
}
# 监测服务与异步网页菜单，服务退出由finally回收本次进程树。
function Watch-Deployment {
    $shownAddress = $null
    $timeout = 45
    if ($env:WB_TUNNEL_START_TIMEOUT_SECONDS) {
        $parsed = 0
        if (-not [int]::TryParse($env:WB_TUNNEL_START_TIMEOUT_SECONDS, [ref]$parsed) -or $parsed -lt 5 -or $parsed -gt 300) {
            throw 'WB_TUNNEL_START_TIMEOUT_SECONDS必须是5..300秒的整数。'
        }
        $timeout = $parsed
    }
    $addressDeadline = [DateTime]::UtcNow.AddSeconds($timeout)
    while ($true) {
        $script:Session.CheckLogHealth()
        if ($script:Backend.HasExited) {
            $null = $script:Backend.WaitForExit(2000)
            throw "本次后端已退出，退出码$($script:Backend.ExitCode)；停止本次隧道。"
        }
        if ($script:Tunnel) {
            if ($script:Tunnel.HasExited) {
                $null = $script:Tunnel.WaitForExit(2000)
                throw "本次隧道已退出，退出码$($script:Tunnel.ExitCode)；停止本次后端。"
            }
            $currentAddress = Show-QuickTunnelAddress
            if ($currentAddress -and $currentAddress -cne $shownAddress) {
                if ($script:BrowserMenu) {
                    try { if (-not $script:BrowserMenu.HasExited) { $script:BrowserMenu.Kill() }; $null = $script:BrowserMenu.WaitForExit(2000) } catch { }
                    $script:Session.ReleaseMenu($script:BrowserMenu)
                    $script:BrowserMenu = $null
                }
                $shownAddress = $currentAddress
                Write-DeployLog ("公网地址｜" + $shownAddress)
                Show-AccessQr $shownAddress
                Write-DeployLog '关闭此运行终端，服务将结束' 'WARN' -Emphasize
                Write-DeployLog '随机地址会变化；先用手机移动网络完成真实登录、写操作、刷新重读及文件权限验证。'
            }
            if (-not $shownAddress -and [DateTime]::UtcNow -gt $addressDeadline) {
                throw "隧道在$timeout秒内未生成实际公网地址；停止本次后端和隧道，查看tunnel.log。"
            }
        }
        if (-not $script:Tunnel -or $shownAddress) {
            if ($script:BrowserMenu) {
                if ($script:BrowserMenu.HasExited) { Complete-BrowserMenu $shownAddress }
            } elseif ($script:BrowserMenuPaused) {
                if (-not [Console]::IsInputRedirected -and [Console]::KeyAvailable) {
                    $pressed = [Console]::ReadKey($true)
                    if ($pressed.Key -eq [ConsoleKey]::Enter) { $script:BrowserMenuPaused = $false }
                }
            } else {
                Start-BrowserMenu $shownAddress
            }
        }
        Start-Sleep -Milliseconds 250
    }
}
# 确保两模式都只运行本次新程序；local在确认健康后再创建隧道。
function Start-SelectedDeployment {
    param([object[]]$Rows)
    Set-WorkbenchEnvironment
    Save-DeploymentConfiguration
    Assert-ListeningPortFree
    $bootstrapGo = Ensure-DeploymentTool $Rows 'go'
    Initialize-OwnedProcessSession
    Initialize-DependencyResolver $bootstrapGo
    $go = Resolve-LatestDeploymentTool $Rows 'go'
    $script:FzfExecutable = Resolve-LatestDeploymentTool $Rows 'fzf'
    $cloudflared = $null
    if ($script:Selection -eq 'local') { $cloudflared = Resolve-LatestDeploymentTool $Rows 'cloudflared' }
    Test-BusinessModuleUpdates $go
    $binary = Build-Workbench $go
    Build-AccessQr $go
    $script:Receipt.binary = $binary
    Save-DeploymentReceipt
    Assert-ListeningPortFree
    $script:Backend = Start-OwnedProcess $binary @() $script:AppEnvironment 'backend.log'
    Register-DeploymentProcess $script:Backend 'backend'
    Wait-WorkbenchHealth $script:Backend
    Show-AccessQr ''
    if ($script:Selection -eq 'local') {
        $configFile = Join-Path $script:RunDirectory 'quick-empty.yml'
        [IO.File]::WriteAllText($configFile, '{}' + [Environment]::NewLine, (New-Object Text.UTF8Encoding($false)))
        $arguments = @('tunnel', '--config', $configFile, '--no-autoupdate', '--url', ('http://' + $script:AppEnvironment.WB_ADDR))
        if (-not $script:PublicDemo) { $arguments += @('--allowed-mail', $script:AllowedMail) }
        $script:Tunnel = Start-OwnedProcess $cloudflared $arguments (Get-ToolProbeEnvironment 'cloudflared') 'tunnel.log'
        Register-DeploymentProcess $script:Tunnel 'tunnel'
        Write-DeployLog $(if ($script:PublicDemo) { '已按PUBLIC确认启用合成数据公开联调；禁止真实资料。' } else { '已启用邮箱PIN受限浏览器演示；原生App不适用。' })
    } else {
        Write-DeployLog '服务器模式未创建隧道，仅回环运行；可信HTTPS反向代理与生产安全条件另行配置。'
    }
    Write-DeployLog '停止按Ctrl+C；本次后端、隧道或入口异常退出均回收本次进程树，保留数据和密钥。'
    Watch-Deployment
}
# 清理仅属于本次的进程句柄与独占锁，不删除数据或修改其它部署。
function Clear-OwnedDeployment {
    try {
        Expire-AccessQr
        if ($script:Session) { $script:Session.Dispose() }
    } finally {
        $script:Session = $null
        $script:BrowserMenu = $null
        $script:BrowserItems = @()
        $script:BrowserMenuPaused = $false
        $script:AllowedMail = $null
        try { Complete-DeploymentReceipt }
        finally {
            if ($script:DeployLock) {
                try { $script:DeployLock.Dispose() }
                finally { $script:DeployLock = $null }
            }
        }
    }
}
# 编排只读检查、自述选择和实际部署，所有失败均保留非零退出。
function Invoke-RepairDeployment {
    param([switch]$CheckOnly, [switch]$PlanOnly, [string]$ReviewMode)
    if ($CheckOnly -and $PlanOnly) { throw '-Check与-Plan不能同时使用。' }
    if ($ReviewMode -and -not $PlanOnly) { throw '-Mode仅允许配合-Plan审阅，不能绕过fzf启动服务。' }
    Initialize-StoragePaths
    $rows = @(Test-DeploymentLayout)
    if ($CheckOnly -or $PlanOnly) {
        Show-ReadOnlyPlan $rows $ReviewMode
        return
    }
    if ($env:OS -ne 'Windows_NT') { throw '此入口仅在Windows原生PowerShell 5.1或更新版本执行；当前系统可只运行-Check/-Plan。' }
    if (-not (Confirm-Introduction)) { Write-Host '已取消，没有启动后端或隧道。'; return }
    try {
        $script:ToolArch = Get-TargetArchitecture
        Initialize-RunDirectory
        Initialize-OwnedProcessSession
        $fzf = Ensure-DeploymentTool $rows 'fzf'
        $script:FzfExecutable = $fzf
        if (-not (Select-DeploymentMode $fzf)) { Write-DeployLog '已取消，没有构建或启动业务。'; return }
        Start-SelectedDeployment $rows
    } catch {
        Write-DeployLog $_.Exception.Message 'ERROR'
        throw
    } finally {
        Clear-OwnedDeployment
    }
}
# 脚本直启统一出口；点载仅供隔离验证，不隐式运行。
if ($MyInvocation.InvocationName -ne '.') {
    try {
        Invoke-RepairDeployment -CheckOnly:$Check -PlanOnly:$Plan -ReviewMode $Mode
    } catch {
        if (-not $script:Receipt -or -not $script:Receipt.finalized) { Write-DeployLog $_.Exception.Message 'ERROR' }
        else { Write-Host '部署未完成；已封存当前原点，请查看本次脱敏日志并使用反部署入口核对。' }
        if ($_.Exception -is [OperationCanceledException]) { exit 130 }
        exit 1
    }
}

# END JOBS_TERMINAL_STYLE_ORIGINAL_BODY
} finally {
    Stop-JobsTerminalStyle $__jobsTerminalStyleState
}
