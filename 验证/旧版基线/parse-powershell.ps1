param([Parameter(Mandatory = $true)][string]$Root)
$ErrorActionPreference = 'Stop'
$failed = $false
foreach ($directory in @('后端/部署', '验证/旧版基线')) {
    $files = Get-ChildItem -LiteralPath (Join-Path $Root $directory) -Recurse -Filter '*.ps1'
    foreach ($file in $files) {
        $tokens = $null
        $errors = $null
        $null = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors)
        if ($errors.Count -gt 0) {
            $failed = $true
            foreach ($item in $errors) {
                Write-Host ($file.FullName + ':' + $item.Extent.StartLineNumber + ' ' + $item.Message)
            }
        }
    }
}
if ($failed) { exit 1 }
Write-Host 'PowerShell syntax passed.'
