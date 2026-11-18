# Claude Residual ID Cleaner — Launcher and Installation Guide

**Project:** Claude Residual ID Cleaner (`Claude 账号残余 ID 清理工具`)  
**Repository:** `YUCZ-43/Claude-Residual-ID-Cleaner`  
**Language Navigation:** [简体中文](../README.md) | [English](../README.en.md)  
**Document Status:** Implemented (Portable Mode, 3-View Modern Dark Studio WPF Desktop App, Bilingual Console Launcher, and User-Scoped Installer/Updater/Uninstaller)

---

## 1. Overview / 概述

This document provides instructions for setting up and running **Claude Residual ID Cleaner**. The toolkit is designed with zero runtime dependencies beyond standard Windows operating system components (Windows 10/11, PowerShell 5.1 or PowerShell 7+, and .NET).

---

## 2. Current Portable Setup / 当前便携式安装 (Implemented)

In the current release, the toolkit is completely portable and requires no administrative installer or system registry modifications.

### Step-by-Step Setup
1. **Obtain the Toolkit**:
   Clone the repository or download the release bundle (`Claude-Residual-ID-Cleaner-0.1.0-x64-bundle.zip`):
   ```powershell
   git clone https://github.com/YUCZ-43/Claude-Residual-ID-Cleaner.git
   cd Claude-Residual-ID-Cleaner
   ```
   Or extract to a dedicated user folder, such as:
   `C:\Users\<USERNAME>\Tools\Claude-Residual-ID-Cleaner`

2. **Inspect the Source Code**:
   Review [ClaudeCleanup.ps1](../ClaudeCleanup.ps1) and [SECURITY.md](../SECURITY.md) before execution.

3. **Check Windows Execution Policy**:
   Windows restricts PowerShell script execution by default. Check your current configuration:
   ```powershell
   Get-ExecutionPolicy -List
   ```
   If script execution is `Restricted`, configure `RemoteSigned` for your current user account without modifying machine-wide settings:
   ```powershell
   Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
   ```
   Alternatively, run the script within an isolated process scope:
   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\ClaudeCleanup.ps1 -Help
   ```

4. **Unblock Downloaded Scripts**:
   If the script was downloaded via a web browser, Windows may attach an NTFS Zone.Identifier alternate data stream. Unblock it before running:
   ```powershell
   Unblock-File .\ClaudeCleanup.ps1
   ```

5. **Run Initial Audit**:
   ```powershell
   .\ClaudeCleanup.ps1 -Audit
   ```

---

## 3. PowerShell Compatibility Matrix / PowerShell 兼容性

| Shell Environment | Binary | Runtime | Status | Notes |
| :--- | :--- | :--- | :--- | :--- |
| **Windows PowerShell 5.1** | `powershell.exe` | .NET Framework 4.8 | **Supported** | Default on Windows 10 & 11; uses C# 5 P/Invoke compilation. |
| **PowerShell 7.x+** | `pwsh.exe` | .NET 8 / 9 | **Supported** | High-performance cross-platform PowerShell; native support on Windows. |
| **PowerShell 2.0 / 3.0** | Legacy | .NET 2.0 / 3.5 | **Unsupported** | Lacks modern Win32 SafeHandle and security APIs. |

---

## 4. Native Windows Desktop GUI & Bilingual Console Launcher / 原生桌面 GUI 与安全启动器

To support nontechnical users without installing an AI agent, the toolkit provides both a zero-dependency **WinForms Desktop GUI** and a lightweight **bilingual text-menu launcher**, supporting seamless `zh-CN` / `en-US` switching (`-Language Auto|zh-CN|en-US`) for cleaning Claude banned-account local residuals without altering Windows OS itself:

### Implemented Entrypoints
- **Standalone WPF Desktop `.exe` (`scripts/Build-DesktopApp.ps1` -> `dist/Claude-Residual-ID-Cleaner-0.1.0-x64-portable.exe`)**: Compiles [src/Gui/Program.cs](../src/Gui/Program.cs) + [src/Gui/Localization.cs](../src/Gui/Localization.cs) into a zero-console native Windows WPF desktop executable (`IMAGE_SUBSYSTEM_WINDOWS_GUI`) using Windows 10/11 built-in `.NET Framework 4.x csc.exe`. Features a 3-view `ModernDarkStudio` layout (`1. Scan & Clean`, `2. Reports & Export`, `3. Safety & About`), default `zh-CN` launch with live **中文 / English** toggle, real-time `@@PROGRESS@@` cleaning progress + automatic post-verify 0-remaining summary banner, on-demand Admin elevation (`asInvoker`), and safe process close prompts.
- **Standalone Setup Wizard (`scripts/Build-Installer.ps1` -> `dist/Claude-Residual-ID-Cleaner-0.1.0-x64-setup.exe`)**: User-scoped Setup installer deploying to `%LOCALAPPDATA%\Programs\Claude-Residual-ID-Cleaner` without UAC.
- **`ClaudeCleanupGUI.cmd` + `scripts/ClaudeCleanupGUI.ps1`**: Companion script-based WinForms GUI for running without building the `.exe`.
- **`ClaudeCleanupLauncher.cmd`**: A minimal batch launcher at the repository/install root that locates `pwsh.exe` or falls back to `powershell.exe`.
- **`scripts/ClaudeCleanupLauncher.ps1`**: An interactive bilingual text-mode menu script (supporting `-Language Auto|zh-CN|en-US`, `-Action`, `-Exit` smoke mode, and `[6] Launch GUI`).

```text
======================================================
 Claude Residual ID Cleaner - Safe Console Menu
======================================================
  [1] Audit        - Read-only Claude residual discovery
  [2] Plan         - Generate CLEANUP-PLAN.md (SchemaVersion 3)
  [3] View Reports - Inspect local AUDIT / PLAN / VERIFICATION
  [4] Verify       - Check residual state and execution ledger
  [5] Help         - CLI usage and safety boundaries
  [6] Launch GUI   - Launch native Windows Desktop GUI (中/EN)
  [7] Exit         - Close launcher
  [L] Switch Lang  - Switch interface (zh-CN <-> en-US)
======================================================
```

### Enforced Safety Guardrails
- **No ExecutionPolicy Bypass**: The launcher never uses `-ExecutionPolicy Bypass` or alters system security settings.
- **No Automatic Elevation**: The launcher runs strictly in standard user context without requesting UAC Administrator privileges.
- **No Direct Destructive Execution**: Option `[2]` only generates plans (`-Plan`). Destructive `-Apply` operations cannot be triggered automatically from the menu.

---

## 5. User-Scoped Installer, Updater & Uninstaller / 用户级安装、升级与卸载脚本

Lifecycle management scripts deploy cleanly within the user's local AppData profile (`%LOCALAPPDATA%\Programs\Claude-Residual-ID-Cleaner`) with SHA-256 managed manifests (`.claude-cleanup-install.json` and `.claude-cleanup-skill-install.json`), without modifying system `PATH`, Start Menu shortcuts, registry keys, or Claude applications:

### `scripts/Install-ClaudeCleanup.ps1`
- Installs toolkit scripts and docs into `%LOCALAPPDATA%\Programs\Claude-Residual-ID-Cleaner` (override with `-InstallRoot`).
- Optionally installs the canonical Agent Skill (`-InstallSkill` or `-SkillOnly` alongside `-SkillTarget Codex|Antigravity|Gemini|Claude|Agents|All`).
- Validates reparse-point safety and protected paths atomically before writing any file.

### `scripts/Update-ClaudeCleanup.ps1`
- Updates managed toolkit files (`-UpdateSkill` / `-SkillOnly` supported) and prunes obsolete managed files while preserving user reports (`AUDIT.md`, `CLEANUP-PLAN.md`, `VERIFICATION.md`).

### `scripts/Uninstall-ClaudeCleanup.ps1`
- Removes managed toolkit files and manifests (keeps local reports by default unless `-RemoveReports` is specified).
- Supports independent Agent Skill removal (`-UninstallSkill` / `-SkillOnly`) and **never** deletes Claude Code or Claude Desktop applications.
- See [Uninstallation-Guide.md](Uninstallation-Guide.md) for full details.
