@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0ABRIR-SUPOCLIP-LOCAL.ps1" %*
if errorlevel 1 pause
endlocal
