@echo off
setlocal
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\%~n0.ps1\%~n0.ps1" %*
set "deploy_exit=%errorlevel%"
if "%~1"=="" if not "%deploy_exit%"=="0" pause
exit /b %deploy_exit%
