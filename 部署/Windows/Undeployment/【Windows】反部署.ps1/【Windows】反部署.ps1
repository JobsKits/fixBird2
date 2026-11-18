# 脚本自述：
# - 名称：【Windows】反部署.ps1；Created by Jobs on 2026年11月3日，星期二.
# - 用途：按部署前记录停止本项目进程，默认备份验证后清理源数据，恢复原有产物并移除新增依赖。
# - 范围：记录内的本项目Runtime、专属机器缓存及明确选定的数据；不清理系统或其它项目SDK。
# - 提示：正常入口先回车，再由fzf选择备份（默认）或清零；最后默认取消，空格确认执行。
# - 只读：-Check/-Plan不创建目录、不停止进程、不下载或修改数据；缺少历史记录拒绝猜测归属。
[CmdletBinding()]
param([switch]$Check, [switch]$Plan)
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
$script:RuntimeRoot = $null
$script:ReceiptDirectory = $null
$script:Receipt = $null
$script:UndoLock = $null
$script:BackupDirectory = $null
$script:HistoryFile = $null
$script:ExpectedCache = $null
$script:UndoFzfExecutable = $null

# 从脚本位置解析配置，不依赖调用工作目录。
function Resolve-UndoPath {
    param([string]$Value)
    if ([IO.Path]::IsPathRooted($Value)) { return [IO.Path]::GetFullPath($Value) }
    return [IO.Path]::GetFullPath((Join-Path $script:ProjectRoot $Value))
}
# 拒绝目录重解析及符号链接，不沿链接删除其它位置。
function Assert-NoReparsePoint {
    param([string]$Path)
    $cursor = [IO.Path]::GetFullPath($Path)
    while ($cursor) {
        if (Test-Path -LiteralPath $cursor) {
            if (((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw '目标包含链接或重解析点，已保留。' }
        }
        $parent = [IO.Path]::GetDirectoryName($cursor)
        if ($parent -eq $cursor) { break }
        $cursor = $parent
    }
}
# 只允许精确数据目录，拒绝盘根、项目根及包含Runtime/工程的上级目录。
function Assert-DataTarget {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path) -or -not [IO.Path]::IsPathRooted($Path)) { throw '数据路径必须为已解析的绝对路径。' }
    $full = [IO.Path]::GetFullPath($Path).TrimEnd('\', '/')
    if ($full -cne $Path.TrimEnd('\', '/') -or $full -eq [IO.Path]::GetPathRoot($Path).TrimEnd('\', '/')) { throw '数据路径不是规范化的专用目标。' }
    foreach ($protected in @($script:ProjectRoot, $script:RuntimeRoot, $script:ReceiptDirectory, $script:ExpectedCache)) {
        if ($protected -ieq $full -or $protected.StartsWith($full + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw '数据目标包含工程、运行原点或专属缓存，拒绝清理。' }
    }
    foreach ($protected in @($script:ProjectRoot, $script:ReceiptDirectory, $script:ExpectedCache, (Join-Path $script:RuntimeRoot 'windows-deploy'))) {
        if ($full.StartsWith($protected + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw '数据目标与源码、原点或可撤回产物重叠。' }
    }
    Assert-NoReparsePoint $full
}
# 摘要包含空目录和全部文件内容，用户或其它进程修改后不覆盖。
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
# 写锁标记不是业务内容；隔离前仅比较已备份的实际数据。
function Get-UndoDataFingerprint {
    param([string]$Path)
    if (-not $Path -or -not (Test-Path -LiteralPath $Path)) { return 'absent' }
    Assert-NoReparsePoint $Path
    $records=@('directory')
    foreach($child in @(Get-ChildItem -LiteralPath $Path -Force -Recurse | Sort-Object FullName)) {
        Assert-NoReparsePoint $child.FullName
        $relative=$child.FullName.Substring($Path.TrimEnd('\','/').Length).Replace('\','/')
        if ($relative -in @('/.writer.guard','/writer.lock')) { continue }
        if($child.PSIsContainer){$records+='d:'+$relative}else{$records+='f:'+$relative+':'+(Get-FileHash -LiteralPath $child.FullName -Algorithm SHA256).Hash}
    }
    $hash=[Security.Cryptography.SHA256]::Create()
    try{return 'tree:'+([BitConverter]::ToString($hash.ComputeHash([Text.Encoding]::UTF8.GetBytes(($records -join "`n"))))).Replace('-','')}
    finally{$hash.Dispose()}
}
# 备份含密钥及连接配置，仅当前Windows账户可读取。
function Protect-PrivateDirectory {
    param([string]$Path)
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent().User
    $acl = New-Object Security.AccessControl.DirectorySecurity
    $acl.SetOwner($identity)
    $acl.SetAccessRuleProtection($true, $false)
    $acl.AddAccessRule((New-Object Security.AccessControl.FileSystemAccessRule($identity, 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow')))
    Set-Acl -LiteralPath $Path -AclObject $acl
}
# 收据是私有恢复依据，仍须逐项验证结构、规范路径及清理范围。
function Assert-UndoReceipt {
    param($Receipt)
    if ($Receipt.schema -ne 1 -or $Receipt.project -cne $script:ProjectRoot -or $Receipt.runtime -cne $script:RuntimeRoot -or $Receipt.projectCache -cne $script:ExpectedCache) { throw '原点记录不属于当前工程或运行目录/机器缓存。' }
    foreach ($flag in @('initialRuntime','initialLock','dataExisted','keyExisted','finalized')) { if ($Receipt.$flag -isnot [bool]) { throw '原点布尔状态无效。' } }
    $names = @('WB_DATA_DIR','WB_KEY_FILE','WB_TIDB_DSN','WB_REQUIRE_DB_TLS','WB_PROJECT_ROOT','WB_RUNTIME_DIR')
    foreach ($name in $names) {
        if (@($Receipt.config.PSObject.Properties | ForEach-Object { $_.Name }) -notcontains $name) { $Receipt.config | Add-Member -MemberType NoteProperty -Name $name -Value '' }
        if ($Receipt.config.$name -isnot [string]) { throw '原点配置值必须为字符串。' }
    }
    if (@($Receipt.config.PSObject.Properties | Where-Object { $_.Name -notin $names }).Count) { throw '原点包含未登记配置，拒绝向子进程传入。' }
    $seen = @{}
    $sessionRoot = Join-Path $script:RuntimeRoot 'windows-deploy'
    foreach ($row in @($Receipt.artifacts)) {
        if (-not [IO.Path]::IsPathRooted([string]$row.path)) { throw '原点产物不是绝对路径。' }
        $full = [IO.Path]::GetFullPath([string]$row.path)
        if ($full -cne $row.path -or ($full -cne $script:ExpectedCache -and [IO.Path]::GetDirectoryName($full) -cne $sessionRoot)) { throw '原点产物不属于专属缓存或单个部署会话。' }
        if ($seen.ContainsKey($full)) { throw '原点包含重复产物。' }; $seen[$full] = $true
        Assert-NoReparsePoint $full
        if ($row.before -notin @('absent','existing') -or $row.after -notmatch '^(absent|(?:file|tree):[A-Fa-f0-9]{64})$') { throw '原点产物状态无效。' }
        if ($row.before -eq 'existing') {
            if ($row.backup -notmatch '^previous/[a-f0-9]{32}$' -or $row.beforeHash -notmatch '^(?:file|tree):[A-Fa-f0-9]{64}$') { throw '原点副本路径或摘要无效。' }
            Assert-NoReparsePoint (Join-Path $script:ReceiptDirectory $row.backup)
        } elseif ($row.beforeHash -cne 'absent' -or $row.backup) { throw '新增产物不应附带已有副本。' }
        if ($row.PSObject.Properties.Name -contains 'restore') { Assert-UndoArtifactJournal $row $Receipt }
    }
    if ($Receipt.config.WB_DATA_DIR -or $Receipt.config.WB_KEY_FILE) {
        if (-not $Receipt.config.WB_DATA_DIR -or -not $Receipt.config.WB_KEY_FILE -or $Receipt.config.WB_PROJECT_ROOT -cne $script:ProjectRoot -or $Receipt.config.WB_RUNTIME_DIR -cne $script:RuntimeRoot) { throw '原点存储配置不完整或工程归属改变。' }
        Assert-DataTarget $Receipt.config.WB_DATA_DIR
        Assert-DataTarget $Receipt.config.WB_KEY_FILE
        if ((Test-Path -LiteralPath $Receipt.config.WB_DATA_DIR) -and -not (Test-Path -LiteralPath $Receipt.config.WB_DATA_DIR -PathType Container)) { throw '数据目录被替换为文件。' }
        if ((Test-Path -LiteralPath $Receipt.config.WB_KEY_FILE) -and -not (Test-Path -LiteralPath $Receipt.config.WB_KEY_FILE -PathType Leaf)) { throw '密钥文件被替换为目录。' }
    } elseif ($Receipt.config.WB_TIDB_DSN -or $Receipt.binary -or @($Receipt.processes).Count) { throw '原点缺少存储配置，不能执行清理。' }
    if ($Receipt.binary) {
        $binary = [IO.Path]::GetFullPath([string]$Receipt.binary)
        if ($binary -cne $Receipt.binary -or [IO.Path]::GetFileName($binary) -cne 'workbench.exe' -or -not $seen.ContainsKey([IO.Path]::GetDirectoryName($binary))) { throw '原点程序不属于已登记会话。' }
    }
    foreach ($process in @($Receipt.processes)) {
        if ($process.role -notin @('backend','tunnel') -or [int]$process.pid -le 0 -or [int]$process.pid -eq $PID -or $process.started -notmatch '^\d+$' -or -not [IO.Path]::IsPathRooted([string]$process.executable)) { throw '原点进程身份无效。' }
        if ($process.role -eq 'backend' -and $process.executable -ine $Receipt.binary) { throw '后端进程不匹配本次程序。' }
    }
    $ancestorTargets = @($script:RuntimeRoot,$script:ExpectedCache) + @($Receipt.artifacts | ForEach-Object { $_.path })
    if ($Receipt.config.WB_DATA_DIR) { $ancestorTargets += $Receipt.config.WB_DATA_DIR; $ancestorTargets += [IO.Path]::GetDirectoryName($Receipt.config.WB_KEY_FILE) }
    foreach ($candidate in @($Receipt.missingParents)) {
        if (-not [IO.Path]::IsPathRooted([string]$candidate) -or [IO.Path]::GetFullPath([string]$candidate) -cne $candidate -or $candidate -eq [IO.Path]::GetPathRoot($candidate)) { throw '父目录恢复记录无效。' }
        $allowed = $false
        foreach ($target in $ancestorTargets) { if ($candidate -ieq $target -or $target.StartsWith($candidate.TrimEnd('\','/') + [IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) { $allowed = $true } }
        if (-not $allowed -or $candidate -ieq $script:ProjectRoot -or $script:ProjectRoot.StartsWith($candidate.TrimEnd('\','/') + [IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) { throw ('父目录记录越过本项目恢复范围：' + $candidate) }
        Assert-NoReparsePoint $candidate
    }
    if ($Receipt.PSObject.Properties.Name -contains 'undo') {
        if ($Receipt.undo.policy -notin @('backup','clear')) { throw '反部署重试策略无效。' }
        if ($Receipt.undo.dataHandled -isnot [bool]) { throw '反部署数据进度无效。' }
        if ($Receipt.undo.PSObject.Properties.Name -contains 'retiredPaths') {
            if (@($Receipt.undo.retiredPaths).Count -gt 2) { throw '数据隔离清单无效。' }
            $kinds=@{}
            foreach($row in @($Receipt.undo.retiredPaths)) {
                if($row.kind -notin @('data','key') -or $kinds.ContainsKey($row.kind)){throw '数据隔离对象重复或无效。'}
                $kinds[$row.kind]=$true
                $source=$(if($row.kind -eq 'data'){$Receipt.config.WB_DATA_DIR}else{$Receipt.config.WB_KEY_FILE})
                $prefix=$(if($row.kind -eq 'data'){'Data'}else{'Key'})
                if($row.source -cne $source -or [IO.Path]::GetFullPath([string]$row.quarantine) -cne $row.quarantine -or [IO.Path]::GetDirectoryName($row.quarantine) -cne [IO.Path]::GetDirectoryName($source) -or [IO.Path]::GetFileName($row.quarantine) -notmatch ('^\.RepairUndo'+$prefix+'-[a-f0-9]{32}$') -or $row.fingerprint -notmatch '^(?:file|tree):[A-Fa-f0-9]{64}$'){throw '数据隔离路径或摘要越界。'}
                Assert-NoReparsePoint $row.quarantine
            }
        }
        if ($Receipt.undo.PSObject.Properties.Name -contains 'retryFzfHash' -and $Receipt.undo.retryFzfHash -notmatch '^[A-Fa-f0-9]{64}$') { throw '反部署选择器恢复摘要无效。' }
        if ($Receipt.undo.backup) {
            if ([IO.Path]::GetFullPath([string]$Receipt.undo.backup) -cne $Receipt.undo.backup -or $Receipt.undo.fingerprint -notmatch '^tree:[A-Fa-f0-9]{64}$') { throw '备份恢复记录无效。' }
            Assert-BackupTarget $Receipt.undo.backup
        }
    }
}
# 保存反部署进度，使备份成功后中断、逐项恢复失败都可继续核对。
function Save-UndoReceipt {
    $file = Join-Path $script:ReceiptDirectory 'receipt.json'
    $temporary = Join-Path $script:ReceiptDirectory ('undo-' + [Guid]::NewGuid().ToString('N') + '.tmp')
    [IO.File]::WriteAllText($temporary, ($script:Receipt | ConvertTo-Json -Depth 12), (New-Object Text.UTF8Encoding($false)))
    Move-Item -LiteralPath $temporary -Destination $file -Force
}
# 备份必须与全部待恢复、删除路径无交集，防止恢复产物时覆盖备份。
function Assert-BackupTarget {
    param([string]$Path)
    $full = [IO.Path]::GetFullPath($Path).TrimEnd('\','/')
    foreach ($target in @($script:RuntimeRoot,$script:ExpectedCache,$script:Receipt.config.WB_DATA_DIR,$script:Receipt.config.WB_KEY_FILE)) {
        if (-not $target) { continue }
        $target = $target.TrimEnd('\','/')
        if ($full -ieq $target -or $full.StartsWith($target + [IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase) -or $target.StartsWith($full + [IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) { throw '备份与运行资料/产物/数据范围重叠。' }
    }
    Assert-NoReparsePoint $full
}
# 只读发现本项目原点，缺记录可审阅但不臆造卸载清单。
function Read-UndoReceipt {
    $script:Receipt = $null
    $base = $env:LOCALAPPDATA
    if (-not $base) { $base = Join-Path ([Environment]::GetFolderPath('UserProfile')) 'AppData\Local' }
    $runtime = $env:WB_RUNTIME_DIR
    if (-not $runtime) { $runtime = Join-Path $base 'JobsSoftwareProjects\RepairWorkbench\Runtime' }
    $script:RuntimeRoot = Resolve-UndoPath $runtime
    $script:ReceiptDirectory = Join-Path $script:RuntimeRoot 'deploy-state-Windows'
    $environmentRoot = $(if ($env:WB_ENV_ROOT) { Resolve-UndoPath $env:WB_ENV_ROOT } else { Join-Path $base 'JobsSoftwareEnvironments' })
    $hasher = [Security.Cryptography.SHA256]::Create()
    try { $projectId = ([BitConverter]::ToString($hasher.ComputeHash([Text.Encoding]::UTF8.GetBytes($script:ProjectRoot.ToLowerInvariant())))).Replace('-', '').Substring(0, 16).ToLowerInvariant() }
    finally { $hasher.Dispose() }
    $expectedCache = Join-Path $environmentRoot ('Projects\RepairWorkbench\' + $projectId)
    $script:ExpectedCache = $expectedCache
    $script:HistoryFile = Join-Path ([IO.Path]::GetDirectoryName($script:RuntimeRoot)) ('UndeploymentBackups\Windows-' + $projectId + '.json')
    Assert-NoReparsePoint $script:ReceiptDirectory
    $file = Join-Path $script:ReceiptDirectory 'receipt.json'
    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { return }
    Assert-NoReparsePoint $file
    $script:Receipt = Get-Content -LiteralPath $file -Raw -Encoding UTF8 | ConvertFrom-Json
    Assert-UndoReceipt $script:Receipt
}
# 只读计划不输出私有连接值，不执行候选工具。
function Show-UndoPlan {
    [ordered]@{ checkOnly = $true; project = $script:ProjectRoot; runtime = $script:RuntimeRoot; receiptAvailable = [bool]$script:Receipt; defaultDataPolicy = 'backup'; artifacts = @($(if ($script:Receipt) { $script:Receipt.artifacts | Select-Object path, before })); sideEffects = 'none' } | ConvertTo-Json -Depth 6
}
# 先显示自述，回车仅进入菜单，不代表授权删除。
function Confirm-UndoIntroduction {
    Write-Host '================ Windows维修工作台反部署 ================'
    Write-Host '按部署前记录停止本项目服务，恢复已有产物并删除本次新增程序/依赖/SDK。'
    Write-Host '数据默认完整备份（含匹配密钥），验证后清理源数据；可另选不备份直接清零。备份失败不删除。'
    Write-Host '不修改其它项目、系统服务、全局PATH或公共已有SDK；冲突保留并报错。'
    Write-Host '备份与脱敏结果位于Runtime外的UndeploymentBackups；Esc/Ctrl+C取消。'
    if ([Console]::IsInputRedirected -or [Console]::IsOutputRedirected) { throw '实际反部署需要交互终端，审阅请用-Check/-Plan。' }
    Write-JobsEnterChoiceText '回车进入菜单；其它输入取消：' -NoNewline
    $answer = [Console]::ReadLine()
    return $null -ne $answer -and $answer -ceq ''
}
# 复用已安装fzf，不为卸载重新下载依赖。
function Find-UndoFzf {
    $candidates = @()
    if ($script:Receipt.PSObject.Properties.Name -contains 'undo' -and $script:Receipt.undo.PSObject.Properties.Name -contains 'retryFzfHash') {
        $retry = Join-Path $script:ReceiptDirectory 'undo-fzf.exe'
        Assert-NoReparsePoint $retry
        if (-not (Test-Path -LiteralPath $retry -PathType Leaf) -or (Get-FileHash -LiteralPath $retry -Algorithm SHA256).Hash -cne $script:Receipt.undo.retryFzfHash) { throw '反部署选择器副本缺失或已改变，停止。' }
        $candidates += $retry
    }
    if ($env:WB_FZF_BIN) { $candidates += Resolve-UndoPath $env:WB_FZF_BIN }
    $command = Get-Command fzf.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($command) { $candidates += $command.Source }
    if (Test-Path -LiteralPath $script:Receipt.projectCache) { $candidates += @(Get-ChildItem -LiteralPath $script:Receipt.projectCache -Filter fzf.exe -File -Recurse | Select-Object -ExpandProperty FullName) }
    foreach ($candidate in $candidates) {
        if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) { continue }
        Assert-NoReparsePoint $candidate
        if ($candidate.StartsWith($script:ExpectedCache + [IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) {
            $row = @($script:Receipt.artifacts | Where-Object { $_.path -ceq $script:ExpectedCache })
            if ($row.Count -ne 1 -or (Get-DeploymentFingerprint $script:ExpectedCache) -cne $row[0].after) { throw '选择器所属缓存已改变，未执行其中程序。' }
        }
        $probe = New-Object Diagnostics.ProcessStartInfo
        $probe.FileName = $candidate; $probe.Arguments = '--version'; $probe.UseShellExecute = $false; $probe.CreateNoWindow = $true
        $probe.RedirectStandardOutput = $true; $probe.RedirectStandardError = $true
        $process = New-Object Diagnostics.Process; $process.StartInfo=$probe
        try {
            if (-not $process.Start()) { continue }
            $output = $process.StandardOutput.ReadToEndAsync(); $errorOutput = $process.StandardError.ReadToEndAsync()
            if (-not $process.WaitForExit(3000)) { $process.Kill(); continue }
            $version = [regex]::Match($output.GetAwaiter().GetResult(),'^(\d+\.\d+\.\d+)')
            $null = $errorOutput.GetAwaiter().GetResult()
            if ($process.ExitCode -eq 0 -and $version.Success -and [version]$version.Groups[1].Value -ge [version]'0.74.0') { $script:UndoFzfExecutable=$candidate; return $candidate }
        } finally { $process.Dispose() }
    }
    throw '缺少已安装的fzf，请用WB_FZF_BIN指定原有工具；反部署不会下载或安装。'
}
# 隔离fzf配置，返回内部枚举，空选与异常均取消。
function Select-UndoChoice {
    param([string]$Fzf, [string[]]$Items, [string]$Header)
    $saved = @{}
    try {
        foreach ($name in @('FZF_DEFAULT_OPTS', 'FZF_DEFAULT_OPTS_FILE', 'FZF_DEFAULT_COMMAND')) { $saved[$name] = [Environment]::GetEnvironmentVariable($name); [Environment]::SetEnvironmentVariable($name, $null, 'Process') }
        $result = @($Items | & $Fzf '--height=60%' '--layout=reverse' '--border' '--no-multi' '--delimiter=|' '--with-nth=2' ('--header=' + $Header))
        if ($LASTEXITCODE -in @(1, 130)) { return 'cancel' }
        if ($LASTEXITCODE -ne 0 -or $result.Count -ne 1 -or $Items -cnotcontains [string]$result[0]) { throw 'fzf选择失败，未执行反部署。' }
        return ([string]$result[0]).Split('|')[0]
    } finally { foreach ($name in $saved.Keys) { [Environment]::SetEnvironmentVariable($name, $saved[$name], 'Process') } }
}
# 校验所有PID身份后才停止，PID复用或不可核验时不终止任何进程。
function Stop-RecordedProcesses {
    $owned = @()
    foreach ($row in @($script:Receipt.processes)) {
        $process = Get-Process -Id ([int]$row.pid) -ErrorAction SilentlyContinue
        if (-not $process) { continue }
        $null = $process.Handle
        if ($process.StartTime.ToUniversalTime().Ticks.ToString() -cne $row.started -or $process.MainModule.FileName -ine $row.executable) { throw 'PID身份变化，保留进程并停止反部署。' }
        $owned += $process
    }
    foreach ($process in $owned) { $process.Kill(); if (-not $process.WaitForExit(5000)) { throw '本项目进程未停止，保留数据与依赖。' } }
}
# 服务退出后取得部署的同一把独占锁，阻止与新部署交错。
function Lock-UndoOperation {
    $file = Join-Path $script:RuntimeRoot 'windows-deploy.lock'
    $deadline = [DateTime]::UtcNow.AddSeconds(10)
    do {
        try {
            $options = $(if ($script:Receipt.initialLock) { [IO.FileOptions]::None } else { [IO.FileOptions]::DeleteOnClose })
            $script:UndoLock = New-Object IO.FileStream($file, [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None, 4096, $options)
            return
        }
        catch { if ([DateTime]::UtcNow -ge $deadline) { throw '部署锁仍被占用或不可访问，未处理数据。' }; Start-Sleep -Milliseconds 100 }
    } while ($true)
}
# 全部产物先核对摘要及原点副本，失败时不开始删除或回滚。
function Test-UndoArtifacts {
    $file = Join-Path $script:ReceiptDirectory 'receipt.json'
    Assert-NoReparsePoint $file
    $latest = Get-Content -LiteralPath $file -Raw -Encoding UTF8 | ConvertFrom-Json
    if (-not $latest.finalized) { throw '部署记录尚未封存；请在原终端停止部署并保留现场。' }
    $script:Receipt = $latest
    Assert-UndoReceipt $script:Receipt
    foreach ($row in @($script:Receipt.artifacts)) {
        if ($row.PSObject.Properties.Name -contains 'restore') {
            $null = Get-UndoArtifactRestoreState $row
            if ($row.before -eq 'existing' -and (Get-DeploymentFingerprint (Join-Path $script:ReceiptDirectory $row.backup)) -cne $row.beforeHash) { throw '原点副本缺失或已损坏，禁止回滚。' }
            continue
        }
        $current = Get-DeploymentFingerprint $row.path
        $expectedOriginal = $(if ($row.before -eq 'existing') { $row.beforeHash } else { 'absent' })
        $resuming = $script:Receipt.PSObject.Properties.Name -contains 'undo'
        if ($current -cne $row.after -and (-not $resuming -or $current -cne $expectedOriginal)) { throw '产物在部署后被修改，已保留；请核对私有原点清单。' }
        if ($row.before -eq 'existing' -and (Get-DeploymentFingerprint (Join-Path $script:ReceiptDirectory $row.backup)) -cne $row.beforeHash) { throw '原点副本缺失或已损坏，禁止回滚。' }
    }
}
# 数据与密钥按成对副本复制并逐文件验证；目标必须在清理范围之外。
function Backup-UndoData {
    $base = $env:WB_UNDEPLOY_BACKUP_DIR
    if (-not $base) { $base = Join-Path ([IO.Path]::GetDirectoryName($script:RuntimeRoot)) 'UndeploymentBackups' }
    $base = Resolve-UndoPath $base
    Assert-BackupTarget $base
    $script:BackupDirectory = Join-Path $base ((Get-Date -Format 'yyyy.MM.dd HH-mm-ss-fff') + '-' + [Guid]::NewGuid().ToString('N'))
    $null = New-Item -ItemType Directory -Path $script:BackupDirectory -Force
    Protect-PrivateDirectory $script:BackupDirectory
    $config = $script:Receipt.config
    foreach ($pair in @(@($config.WB_DATA_DIR, 'data'), @($config.WB_KEY_FILE, 'storage.key'), @($script:ReceiptDirectory, 'deployment-origin'))) {
        if ($pair[0] -and (Test-Path -LiteralPath $pair[0])) {
            $destination = Join-Path $script:BackupDirectory $pair[1]
            $before = Get-DeploymentFingerprint $pair[0]
            Copy-Item -LiteralPath $pair[0] -Destination $destination -Recurse -Force
            if ($before -cne (Get-DeploymentFingerprint $destination) -or $before -cne (Get-DeploymentFingerprint $pair[0])) { throw '备份校验失败或源正在变化，未删除源数据或依赖。' }
        }
    }
    if ($config.WB_DATA_DIR -and (Test-Path -LiteralPath (Join-Path $config.WB_DATA_DIR 'snapshot.enc')) -and -not (Test-Path -LiteralPath $config.WB_KEY_FILE)) { throw '加密数据缺少匹配密钥，备份不完整，已停止。' }
    if ($config.WB_TIDB_DSN -or ($config.WB_DATA_DIR -and (Test-Path -LiteralPath (Join-Path $config.WB_DATA_DIR 'snapshot.enc')))) {
        $backupFile = Join-Path $script:BackupDirectory 'database.wbbak'
        Invoke-UndoStorageCommand @('-backup', $backupFile)
        $manifestFile = $backupFile + '.manifest.json'
        if (-not (Test-Path -LiteralPath $manifestFile)) { throw '数据库备份摘要缺失，未清理。' }
        $manifest = Get-Content -LiteralPath $manifestFile -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($manifest.sha256 -ine (Get-FileHash -LiteralPath $backupFile -Algorithm SHA256).Hash -or $manifest.bytes -ne (Get-Item -LiteralPath $backupFile).Length) { throw '数据库备份摘要不匹配，未清理。' }
        if (-not (Test-Path -LiteralPath (Join-Path $script:BackupDirectory 'storage.key'))) { throw '数据库备份缺匹配密钥，已停止。' }
    }
    [IO.File]::WriteAllText((Join-Path $script:BackupDirectory 'verified.json'), (@{ complete = $true; dataPolicy = 'backup'; databaseScope = 'application snapshot only; no grants/topology' } | ConvertTo-Json), (New-Object Text.UTF8Encoding($false)))
}
# 仅运行记录中的本应用CLI；连接配置仅传给子进程，不输出到终端或命令行。
function Invoke-UndoStorageCommand {
    param([string[]]$Arguments)
    if (-not (Test-Path -LiteralPath $script:Receipt.binary -PathType Leaf)) { throw '原部署程序缺失，不能执行数据库备份或清零。' }
    $info = New-Object Diagnostics.ProcessStartInfo
    $info.FileName = $script:Receipt.binary
    $info.Arguments = (@($Arguments | ForEach-Object { '"' + $_.Replace('"', '\"') + '"' }) -join ' ')
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    foreach ($property in $script:Receipt.config.PSObject.Properties) { $info.EnvironmentVariables[$property.Name] = [string]$property.Value }
    $info.EnvironmentVariables['WB_BACKUP_DIR'] = ''
    $process = New-Object Diagnostics.Process
    $process.StartInfo = $info
    $started = $false
    $largeMaintenance = $Arguments.Count -gt 0 -and $Arguments[0] -in @('-backup','-restore')
    $timer = [Diagnostics.Stopwatch]::StartNew()
    try {
        if (-not $process.Start()) { throw '存储工具未启动。' }
        $started = $true
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        # 大原件维护没有总时限；短轮询保留PowerShell取消进入finally的机会。
        while (-not $process.WaitForExit(250)) {
            if (-not $largeMaintenance -and $timer.Elapsed.TotalSeconds -ge 60) { throw '存储工具超时，停止删除。' }
        }
        if ($process.ExitCode -ne 0) { throw '应用数据库备份/清零失败，已保留数据及程序；不输出连接详情。' }
        $null = $stdout.GetAwaiter().GetResult()
        $null = $stderr.GetAwaiter().GetResult()
    } finally {
        try {
            # 存储CLI不派生子进程，只回收本函数确实启动且仍活跃的程序。
            if ($started -and -not $process.HasExited) {
                $process.Kill()
                if (-not $process.WaitForExit(5000)) { throw '存储工具取消后未停止，保留数据、程序及原点记录。' }
            }
        } finally { $process.Dispose() }
    }
}
# 活写入者和不可识别的写锁均保留，不按PID盲目终止其它进程。
function Assert-NoActiveDataWriter {
    param([string]$Data)
    if(-not $Data){return}
    $marker=Join-Path $Data 'writer.lock'
    if(Test-Path -LiteralPath $marker){
        Assert-NoReparsePoint $marker
        $text=([IO.File]::ReadAllText($marker)).Trim()
        $number=0
        if(-not [int]::TryParse($text,[ref]$number) -or $number -le 0){throw '写锁PID不明确，保留源数据。'}
        if(Get-Process -Id $number -ErrorAction SilentlyContinue){throw '数据仍被其它活写入者使用，未清理。'}
    }
}
# 持有原生共享限制后先隔离key再原子改名data，后续仅删除隔离对象。
function Clear-UndoData {
    $data=$script:Receipt.config.WB_DATA_DIR; $key=$script:Receipt.config.WB_KEY_FILE
    if(-not $data -and -not $key){return}
    Assert-DataTarget $data; Assert-DataTarget $key
    Assert-NoActiveDataWriter $data
    if($script:Receipt.config.WB_TIDB_DSN -and ($script:Receipt.undo.PSObject.Properties.Name -notcontains 'databaseCleared' -or -not $script:Receipt.undo.databaseCleared)){
        $arguments=@('-clear-storage','-confirm-clear-storage')
        if($script:Receipt.undo.policy -eq 'backup'){$arguments+=@('-clear-storage-backup',(Join-Path $script:BackupDirectory 'database.wbbak'))}
        Invoke-UndoStorageCommand $arguments
        $script:Receipt.undo | Add-Member -MemberType NoteProperty -Name databaseCleared -Value $true -Force
        Save-UndoReceipt
    }
    $guard=$null; $keyHandle=$null
    try{
        $guardData=$data; $guardKey=$key
        if($script:Receipt.undo.PSObject.Properties.Name -contains 'retiredPaths'){
            foreach($row in @($script:Receipt.undo.retiredPaths)){
                if(-not (Test-Path -LiteralPath $row.source) -and (Test-Path -LiteralPath $row.quarantine)){
                    if($row.kind -eq 'data'){$guardData=$row.quarantine}else{$guardKey=$row.quarantine}
                }
            }
        }
        Assert-NoActiveDataWriter $guardData
        if(Test-Path -LiteralPath $guardData){
            $guardPath=Join-Path $guardData '.writer.guard'; Assert-NoReparsePoint $guardPath
            $guard=New-Object IO.FileStream($guardPath,[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,([IO.FileShare]::Read -bor [IO.FileShare]::Delete))
        }
        if(Test-Path -LiteralPath $guardKey){$keyHandle=New-Object IO.FileStream($guardKey,[IO.FileMode]::Open,[IO.FileAccess]::Read,([IO.FileShare]::Read -bor [IO.FileShare]::Delete))}
        if($script:Receipt.undo.PSObject.Properties.Name -notcontains 'retiredPaths'){
            $rows=@()
            foreach($pair in @(@('key',$key),@('data',$data))){
                if($pair[0] -eq 'key' -and $key.StartsWith($data.TrimEnd('\','/')+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){continue}
                if(-not (Test-Path -LiteralPath $pair[1])){continue}
                $kind=$pair[0];$source=$pair[1]
                $fingerprint=$(if($kind -eq 'data'){Get-UndoDataFingerprint $source}else{Get-DeploymentFingerprint $source})
                if($script:Receipt.undo.policy -eq 'backup'){
                    $backupPath=Join-Path $script:BackupDirectory $(if($kind -eq 'data'){'data'}else{'storage.key'})
                    $backupFingerprint=$(if($kind -eq 'data'){Get-UndoDataFingerprint $backupPath}else{Get-DeploymentFingerprint $backupPath})
                    if($fingerprint -cne $backupFingerprint){throw '数据在备份后发生变化，保留源与现有备份，未清理。'}
                }
                $prefix=$(if($kind -eq 'data'){'Data'}else{'Key'})
                $quarantine=Join-Path ([IO.Path]::GetDirectoryName($source)) ('.RepairUndo'+$prefix+'-'+[Guid]::NewGuid().ToString('N'))
                $rows+=[pscustomobject]@{kind=$kind;source=$source;quarantine=$quarantine;fingerprint=$fingerprint}
            }
            $script:Receipt.undo | Add-Member -MemberType NoteProperty -Name retiredPaths -Value $rows
            Save-UndoReceipt
        }
        foreach($row in @($script:Receipt.undo.retiredPaths)){
            $sourceExists=Test-Path -LiteralPath $row.source; $isolated=Test-Path -LiteralPath $row.quarantine
            if($sourceExists -and $isolated){throw '源路径已被重建，保留新对象及隔离资料，不继续清理。'}
            if($sourceExists){
                $actual=$(if($row.kind -eq 'data'){Get-UndoDataFingerprint $row.source}else{Get-DeploymentFingerprint $row.source})
                if($actual -cne $row.fingerprint){throw '隔离前源数据变化，保留源及备份。'}
                if($row.kind -eq 'data'){[IO.Directory]::Move($row.source,$row.quarantine)}else{[IO.File]::Move($row.source,$row.quarantine)}
            }
        }
    }finally{if($keyHandle){$keyHandle.Dispose()};if($guard){$guard.Dispose()}}
    foreach($row in @($script:Receipt.undo.retiredPaths)){
        if(-not (Test-Path -LiteralPath $row.quarantine)){continue}
        $actual=$(if($row.kind -eq 'data'){Get-UndoDataFingerprint $row.quarantine}else{Get-DeploymentFingerprint $row.quarantine})
        if($actual -cne $row.fingerprint){throw '隔离资料发生变化，保留隔离对象。'}
        Remove-Item -LiteralPath $row.quarantine -Recurse -Force
    }
}
# 后来重建的同名路径不属于本次原点，不继续递归删除。
function Assert-UndoDataRetired {
    foreach($target in @($script:Receipt.config.WB_DATA_DIR,$script:Receipt.config.WB_KEY_FILE)){
        if($target -and (Test-Path -LiteralPath $target)){throw '原路径出现后续数据或密钥，已保留；先停止新写入者并另行核对这些新资料。'}
    }
}
# 恢复暂存路径仅允许已登记产物的同父GUID名称，不能借收据增加任意删除目标。
function Assert-UndoArtifactJournal {
    param($Row, $Receipt)
    $journal = $Row.restore
    if (@($journal.PSObject.Properties).Count -ne 5 -or @($journal.PSObject.Properties | Where-Object { $_.Name -notin @('stage','retired','phase','stageHash','retiredHash') }).Count) { throw '产物恢复日志字段无效。' }
    if ($journal.phase -notin @('copying','prepared','retired','installed','done') -or ($Row.before -eq 'absent' -and $journal.phase -eq 'copying')) { throw '产物恢复阶段无效。' }
    if ($journal.stageHash -notmatch '^(absent|(?:file|tree):[A-Fa-f0-9]{64})$' -or $journal.retiredHash -notmatch '^(absent|(?:file|tree):[A-Fa-f0-9]{64})$') { throw '产物恢复摘要无效。' }
    $token = $null
    foreach ($name in @('stage','retired')) {
        $path = [string]$journal.$name
        $prefix = $(if ($name -eq 'stage') { 'Stage' } else { 'Retired' })
        if (-not [IO.Path]::IsPathRooted($path) -or [IO.Path]::GetFullPath($path) -cne $path -or [IO.Path]::GetDirectoryName($path) -cne [IO.Path]::GetDirectoryName($Row.path) -or [IO.Path]::GetFileName($path) -cnotmatch ('^\.RepairUndoArtifact' + $prefix + '-([a-f0-9]{32})$')) { throw '产物恢复临时路径越界。' }
        if ($null -eq $token) { $token = $Matches[1] } elseif ($token -cne $Matches[1]) { throw '产物恢复临时路径不属于同一操作。' }
        foreach ($target in @($Receipt.artifacts | ForEach-Object { $_.path }) + @($Receipt.config.WB_DATA_DIR,$Receipt.config.WB_KEY_FILE,$script:ReceiptDirectory)) {
            if (-not $target) { continue }
            if ($path -ieq $target -or $path.StartsWith($target.TrimEnd('\','/') + [IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase) -or $target.StartsWith($path + [IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) { throw '产物恢复临时路径与其它登记对象重叠。' }
        }
        Assert-NoReparsePoint $path
    }
}
# 原路径、准备副本及退休副本的组合必须对应可恢复的原子移动窗口。
function Get-UndoArtifactRestoreState {
    param($Row)
    $journal = $Row.restore
    $current = Get-DeploymentFingerprint $Row.path
    $stage = Get-DeploymentFingerprint $journal.stage
    $retired = Get-DeploymentFingerprint $journal.retired
    $original = $(if ($Row.before -eq 'existing') { $Row.beforeHash } else { 'absent' })
    $valid = $false
    switch ($journal.phase) {
        'copying' { $valid = $current -ceq $Row.after -and $retired -ceq 'absent' -and ($stage -ceq 'absent' -or $stage -ceq $journal.stageHash -or $stage -ceq $original) }
        'prepared' {
            $valid = $stage -ceq $original -and (($current -ceq $Row.after -and $retired -ceq 'absent') -or ($current -ceq 'absent' -and $retired -ceq $Row.after))
        }
        'retired' {
            $valid = $retired -ceq $Row.after -and (($current -ceq 'absent' -and $stage -ceq $original) -or ($current -ceq $original -and $stage -ceq 'absent'))
        }
        'installed' { $valid = $current -ceq $original -and $stage -ceq 'absent' -and ($retired -ceq 'absent' -or $retired -ceq $journal.retiredHash) }
        'done' { $valid = $current -ceq $original -and $stage -ceq 'absent' -and $retired -ceq 'absent' }
    }
    if (-not $valid) { throw '产物恢复现场与已记录阶段不符，保留原路径及暂存资料。' }
    return [pscustomobject]@{ current=$current; stage=$stage; retired=$retired; original=$original }
}
# 同卷重命名不覆盖目标；原路径被其它进程重建时立即失败。
function Move-UndoArtifact {
    param([string]$Source,[string]$Destination)
    Assert-NoReparsePoint $Source
    Assert-NoReparsePoint $Destination
    if (Test-Path -LiteralPath $Destination) { throw '恢复目标已被重新创建，已保留。' }
    if ((Get-Item -LiteralPath $Source -Force).PSIsContainer) { [IO.Directory]::Move($Source,$Destination) }
    else { [IO.File]::Move($Source,$Destination) }
}
# 只删除日志中摘要仍匹配的隔离对象；部分删除失败后保留可核对的续跑摘要。
function Remove-UndoArtifactTemporary {
    param($Row,[ValidateSet('stage','retired')][string]$Name)
    $journal = $Row.restore
    $path = [string]$journal.$Name
    $hashName = $Name + 'Hash'
    $current = Get-DeploymentFingerprint $path
    if ($current -ceq 'absent') { return }
    if ($current -cne $journal.$hashName) { throw '恢复临时对象已被修改，已保留。' }
    try { Remove-Item -LiteralPath $path -Recurse -Force }
    catch {
        $journal.$hashName = Get-DeploymentFingerprint $path
        Save-UndoReceipt
        throw
    }
}
# 先验证同父准备副本，再原子替换；失败仅清理已登记隔离路径，不递归删除原路径。
function Restore-UndoArtifacts {
    $rows = @($script:Receipt.artifacts)
    [array]::Reverse($rows)
    foreach ($row in $rows) {
        $original = $(if ($row.before -eq 'existing') { $row.beforeHash } else { 'absent' })
        $current = Get-DeploymentFingerprint $row.path
        if ($row.PSObject.Properties.Name -notcontains 'restore') {
            if ($current -ceq $original) { continue }
            if ($current -cne $row.after) { throw '恢复前产物已改变，保留当前内容及原点，不继续覆盖。' }
            $token = [Guid]::NewGuid().ToString('N')
            $parent = [IO.Path]::GetDirectoryName($row.path)
            $journal = [pscustomobject]@{ stage=(Join-Path $parent ('.RepairUndoArtifactStage-' + $token)); retired=(Join-Path $parent ('.RepairUndoArtifactRetired-' + $token)); phase=$(if ($row.before -eq 'existing') { 'copying' } else { 'prepared' }); stageHash='absent'; retiredHash=$row.after }
            $row | Add-Member -MemberType NoteProperty -Name restore -Value $journal
            Assert-UndoArtifactJournal $row $script:Receipt
            if ((Get-DeploymentFingerprint $journal.stage) -cne 'absent' -or (Get-DeploymentFingerprint $journal.retired) -cne 'absent') { throw '恢复临时位置已被占用，保留现场。' }
            Save-UndoReceipt
        }
        $journal = $row.restore
        Assert-UndoArtifactJournal $row $script:Receipt
        $state = Get-UndoArtifactRestoreState $row
        if ($journal.phase -eq 'done') { continue }
        if ($row.before -eq 'existing' -and (Get-DeploymentFingerprint (Join-Path $script:ReceiptDirectory $row.backup)) -cne $original) { throw '原点副本缺失或已损坏，禁止恢复。' }
        if ($journal.phase -eq 'copying') {
            if ($state.stage -cne $original) {
                Remove-UndoArtifactTemporary $row stage
                try { Copy-Item -LiteralPath (Join-Path $script:ReceiptDirectory $row.backup) -Destination $journal.stage -Recurse -Force }
                catch {
                    $journal.stageHash = Get-DeploymentFingerprint $journal.stage
                    Save-UndoReceipt
                    throw
                }
                $journal.stageHash = Get-DeploymentFingerprint $journal.stage
                if ($journal.stageHash -cne $original) { Save-UndoReceipt; throw '准备副本与原点不一致，原产物尚未替换。' }
            }
            $journal.stageHash = $original
            $journal.phase = 'prepared'
            Save-UndoReceipt
        }
        $state = Get-UndoArtifactRestoreState $row
        if ($journal.phase -eq 'prepared') {
            if ($state.current -ceq $row.after -and $state.retired -ceq 'absent' -and $state.current -cne 'absent') {
                Move-UndoArtifact $row.path $journal.retired
            }
            $journal.phase = 'retired'
            Save-UndoReceipt
        }
        $state = Get-UndoArtifactRestoreState $row
        if ($journal.phase -eq 'retired') {
            if ($row.before -eq 'existing' -and $state.current -ceq 'absent') { Move-UndoArtifact $journal.stage $row.path }
            $journal.phase = 'installed'
            Save-UndoReceipt
        }
        $null = Get-UndoArtifactRestoreState $row
        Remove-UndoArtifactTemporary $row retired
        $journal.stageHash = 'absent'
        $journal.retiredHash = 'absent'
        $journal.phase = 'done'
        Save-UndoReceipt
    }
}
# 无论数据选项均保留原点审计；清理后验证全部目标，再移除活动记录。
function Complete-UndoOperation {
    if (-not $script:BackupDirectory) {
        $base = Join-Path ([IO.Path]::GetDirectoryName($script:RuntimeRoot)) 'UndeploymentBackups'
        Assert-NoReparsePoint $base
        $script:BackupDirectory = Join-Path $base ('clear-' + [Guid]::NewGuid().ToString('N'))
        $null = New-Item -ItemType Directory -Force -Path $script:BackupDirectory
        Protect-PrivateDirectory $script:BackupDirectory
        Copy-Item -LiteralPath $script:ReceiptDirectory -Destination (Join-Path $script:BackupDirectory 'deployment-origin') -Recurse
    }
    foreach ($row in @($script:Receipt.artifacts)) {
        if ($row.PSObject.Properties.Name -contains 'restore') { $null = Get-UndoArtifactRestoreState $row }
        $expected = $(if ($row.before -eq 'existing') { Get-DeploymentFingerprint (Join-Path $script:ReceiptDirectory $row.backup) } else { 'absent' })
        if ((Get-DeploymentFingerprint $row.path) -cne $expected) { throw '还原结果不匹配，保留活动清单以便继续处理。' }
    }
    $historyRoot = [IO.Path]::GetDirectoryName($script:HistoryFile)
    $null = New-Item -ItemType Directory -Force -Path $historyRoot
    Protect-PrivateDirectory $historyRoot
    [IO.File]::WriteAllText($script:HistoryFile, (@{ complete = $true; project = $script:ProjectRoot; runtime = $script:RuntimeRoot; backup = $script:BackupDirectory } | ConvertTo-Json -Depth 6), (New-Object Text.UTF8Encoding($false)))
    Remove-Item -LiteralPath $script:ReceiptDirectory -Recurse -Force
    Write-Host ('反部署完成；数据/原点记录位置：' + $script:BackupDirectory)
}
# 所有选择已明确后执行可重试逆操作，失败保留活动清单及已核验备份。
function Invoke-UndoSelection {
    param([ValidateSet('backup','clear')][string]$Choice)
    try {
        Stop-RecordedProcesses
        Lock-UndoOperation
        Test-UndoArtifacts
        if ($script:Receipt.PSObject.Properties.Name -contains 'undo') {
            if ($script:Receipt.undo.policy -cne $Choice) { throw '上次反部署已开始，须保持原数据策略继续，不改写恢复意图。' }
        } else {
            $script:Receipt | Add-Member -MemberType NoteProperty -Name undo -Value ([pscustomobject]@{ policy=$Choice; backup=''; fingerprint=''; dataHandled=$false })
            Save-UndoReceipt
        }
        if ($script:UndoFzfExecutable -and $script:Receipt.undo.PSObject.Properties.Name -notcontains 'retryFzfHash') {
            $retry = Join-Path $script:ReceiptDirectory 'undo-fzf.exe'
            $sourceHash = (Get-FileHash -LiteralPath $script:UndoFzfExecutable -Algorithm SHA256).Hash
            Copy-Item -LiteralPath $script:UndoFzfExecutable -Destination $retry -Force
            if ((Get-FileHash -LiteralPath $retry -Algorithm SHA256).Hash -cne $sourceHash -or (Get-FileHash -LiteralPath $script:UndoFzfExecutable -Algorithm SHA256).Hash -cne $sourceHash) { throw '选择器恢复副本校验失败，尚未清理数据。' }
            $script:Receipt.undo | Add-Member -MemberType NoteProperty -Name retryFzfHash -Value $sourceHash
            Save-UndoReceipt
        }
        if ($Choice -eq 'backup') {
            if ($script:Receipt.undo.backup) {
                $script:BackupDirectory = $script:Receipt.undo.backup
                if ((Get-DeploymentFingerprint $script:BackupDirectory) -cne $script:Receipt.undo.fingerprint) { throw '上次备份已改变或丢失，停止清理。' }
            } else {
                Backup-UndoData
                $script:Receipt.undo.backup = $script:BackupDirectory
                $script:Receipt.undo.fingerprint = Get-DeploymentFingerprint $script:BackupDirectory
                Save-UndoReceipt
            }
        }
        if (-not $script:Receipt.undo.dataHandled) {
            Clear-UndoData
            $script:Receipt.undo.dataHandled = $true
            Save-UndoReceipt
        }
        Assert-UndoDataRetired
        Restore-UndoArtifacts
        Complete-UndoOperation
    } finally {
        if ($script:UndoLock) { $script:UndoLock.Dispose(); $script:UndoLock = $null }
    }
    foreach ($directory in @($script:Receipt.missingParents | Select-Object -Unique | Sort-Object Length -Descending)) {
        Assert-NoReparsePoint $directory
        if ((Test-Path -LiteralPath $directory -PathType Container) -and @(Get-ChildItem -LiteralPath $directory -Force).Count -eq 0) { Remove-Item -LiteralPath $directory -Force }
    }
}
# 编排只读审阅及交互逆操作；任何失败都保留非零结果与原点记录。
function Invoke-RepairUndeployment {
    if ($Check -and $Plan) { throw '-Check与-Plan不能同时使用。' }
    Read-UndoReceipt
    if ($Check -or $Plan) { Show-UndoPlan; return }
    if ($env:OS -ne 'Windows_NT') { throw '实际反部署仅支持Windows原生PowerShell；当前可只读-Check/-Plan。' }
    if (-not (Confirm-UndoIntroduction)) { return }
    if (-not $script:Receipt) {
        if (Test-Path -LiteralPath $script:HistoryFile) {
            $history = Get-Content -LiteralPath $script:HistoryFile -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($history.complete -and $history.project -ceq $script:ProjectRoot -and $history.runtime -ceq $script:RuntimeRoot) { Write-Host '此原点已完成反部署，无需重复清理。'; return }
        }
        throw '没有部署前原点记录，无法证明旧依赖归属；未删除。请先核对旧部署，不将猜测当作逆操作。'
    }
    $fzf = Find-UndoFzf
    $choice = Select-UndoChoice $fzf @('backup|数据库/文件数据备份（默认），验证后清理源数据及密钥', 'clear|数据库/文件数据直接清零，不备份（不可恢复）', 'cancel|取消') '数据策略：默认备份后清理源数据；Esc取消'
    if ($choice -eq 'cancel') { return }
    Write-Host ('目标Runtime：' + $script:RuntimeRoot)
    Write-Host ('目标专属缓存：' + $script:Receipt.projectCache)
    Write-Host ('数据目录：' + $script:Receipt.config.WB_DATA_DIR)
    Write-Host ('匹配密钥：' + $script:Receipt.config.WB_KEY_FILE)
    $confirm = Select-UndoChoice $fzf @('cancel|取消并保留当前状态', 'execute|确认停止服务并执行所选反部署') '核对以上范围；默认取消'
    if ($confirm -ne 'execute') { return }
    Write-Host '最后复核：按空格执行，任意其它键取消。'
    if ([Console]::ReadKey($true).Key -ne [ConsoleKey]::Spacebar) { return }
    Invoke-UndoSelection $choice
}

if ($MyInvocation.InvocationName -ne '.') {
    try { Invoke-RepairUndeployment }
    catch { Write-Error $_.Exception.Message; exit 1 }
}

# END JOBS_TERMINAL_STYLE_ORIGINAL_BODY
} finally {
    Stop-JobsTerminalStyle $__jobsTerminalStyleState
}
