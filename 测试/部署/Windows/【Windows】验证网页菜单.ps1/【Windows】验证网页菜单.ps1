# 脚本自述：
# - 名称：【Windows】验证网页菜单.ps1；Created by Jobs on 2026年11月3日，星期二.
# - 用途：隔离验证真实部署函数的地址菜单、连续选择、打开失败与服务退出处理。
# - 范围：只在系统临时目录写夹具；假Session/fzf和假浏览器，不联网、不调用Windows Job Object或真实服务。
# - 运行：普通运行先回车确认，自动化显式传-Run；失败保留夹具，成功清理本次临时目录。
[CmdletBinding()]
param([switch]$Run)
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
    Write-JobsEnterChoiceText '按回车开始；其它输入取消：' -NoNewline
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

# END JOBS_TERMINAL_STYLE_ORIGINAL_BODY
} finally {
    Stop-JobsTerminalStyle $__jobsTerminalStyleState
}
