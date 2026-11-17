@echo off
setlocal EnableExtensions

set "SCRIPT_DIR=%~dp0"
set "GUI_PS1=%SCRIPT_DIR%scripts\ClaudeCleanupGUI.ps1"

if not exist "%GUI_PS1%" (
    echo [ERROR] Native GUI script not found: "%GUI_PS1%"
    exit /b 1
)

where pwsh.exe >nul 2>nul
if %errorlevel%==0 (
    pwsh.exe -Sta -NoProfile -File "%GUI_PS1%" %*
    exit /b %errorlevel%
)

where powershell.exe >nul 2>nul
if %errorlevel%==0 (
    powershell.exe -Sta -NoProfile -File "%GUI_PS1%" %*
    exit /b %errorlevel%
)

echo [ERROR] Neither pwsh.exe nor powershell.exe was found on PATH.
exit /b 1
