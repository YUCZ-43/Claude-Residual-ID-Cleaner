@echo off
setlocal EnableExtensions

set "SCRIPT_DIR=%~dp0"
set "LAUNCHER_PS1=%SCRIPT_DIR%scripts\ClaudeCleanupLauncher.ps1"

if not exist "%LAUNCHER_PS1%" (
    echo [ERROR] Launcher script not found: "%LAUNCHER_PS1%"
    exit /b 1
)

set "PS_EXE="
where pwsh.exe >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    set "PS_EXE=pwsh.exe"
) else (
    where powershell.exe >nul 2>nul
    if %ERRORLEVEL% EQU 0 (
        set "PS_EXE=powershell.exe"
    )
)

if not defined PS_EXE (
    echo [ERROR] Neither pwsh.exe nor powershell.exe was found on PATH.
    exit /b 1
)

"%PS_EXE%" -NoProfile -File "%LAUNCHER_PS1%" %*
set "EXIT_CODE=%ERRORLEVEL%"
exit /b %EXIT_CODE%
