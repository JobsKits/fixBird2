@echo off
rem Undeployment shortcut: forward to the unique packaged PowerShell implementation.
setlocal DisableDelayedExpansion
set "shortcut_target="
set "shortcut_count=0"
for /d %%D in ("%~dp0Undeployment\*.ps1") do (
  if exist "%%~fD\%%~nxD" (
    set /a shortcut_count+=1 >nul
    set "shortcut_target=%%~fD\%%~nxD"
  )
)
if not "%shortcut_count%"=="1" goto shortcut_missing
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%shortcut_target%" %*
set "shortcut_result=%errorlevel%"
if not "%shortcut_result%"=="0" pause
endlocal & exit /b %shortcut_result%
:shortcut_missing
>&2 echo Expected exactly one matching PowerShell script package next to this shortcut.
pause
endlocal & exit /b 1
