@echo off
setlocal DisableDelayedExpansion
powershell.exe -NoLogo -NoProfile -File "%~dpn0.ps1"
exit /b %errorlevel%
