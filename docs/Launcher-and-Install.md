# Windows Claude Cleanup — Launcher and Installation Guide

**Project:** Windows Claude Cleanup Toolkit  
**Repository:** `YUCZ-43/Windows-Claude-Cleanup`  
**Language Navigation:** [English](../README.md) | [简体中文](../README_zh-CN.md)  
**Document Status:** Implemented (Portable Mode, Console Launcher, and User-Scoped Installer/Updater/Uninstaller)

---

## 1. Overview / 概述

This document provides instructions for setting up and running the Windows Claude Cleanup Toolkit. The toolkit is designed with zero runtime dependencies beyond standard Windows operating system components (Windows 10/11, PowerShell 5.1 or PowerShell 7+, and .NET).

---

## 2. Current Portable Setup / 当前便携式安装 (Implemented)

In the current release, the toolkit is completely portable and requires no administrative installer or system registry modifications.

### Step-by-Step Setup
1. **Obtain the Toolkit**:
   Clone the repository or download the source code as a ZIP archive:
   ```powershell
   git clone https://github.com/YUCZ-43/Windows-Claude-Cleanup.git
   cd Windows-Claude-Cleanup
   ```
   Or extract to a dedicated user folder, such as:
   `C:\Users\<USERNAME>\Tools\Windows-Claude-Cleanup`

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

## 4. Windows Console Launcher / Windows 安全启动器

To support nontechnical users and streamline safe operations without installing an AI agent, the toolkit includes a lightweight text-menu launcher:

### Implemented Files
- **`ClaudeCleanupLauncher.cmd`**: A minimal batch launcher at the repository/install root that locates `pwsh.exe` or falls back to `powershell.exe`.
- **`scripts/ClaudeCleanupLauncher.ps1`**: An interactive text-mode menu script (also supporting `-Action` / non-interactive smoke checks).

```text
======================================================
         Windows Claude Cleanup Console Menu
======================================================
  [1] Run Audit (Read-only discovery)
  [2] Generate Cleanup Plan (CLEANUP-PLAN.md)
  [3] View Reports (Audit & Plan summaries)
  [4] Run Verification (Verify post-cleanup state)
  [5] Show Help & Safety Guidelines
  [6] Exit
======================================================
Select an option [1-6]:
```

### Enforced Safety Guardrails
- **No ExecutionPolicy Bypass**: The launcher never uses `-ExecutionPolicy Bypass` or alters system security settings.
- **No Automatic Elevation**: The launcher runs strictly in standard user context without requesting UAC Administrator privileges.
- **No Direct Destructive Execution**: Option `[2]` only generates plans (`-Plan`). Destructive `-Apply` operations cannot be triggered automatically from the menu.

---

## 5. User-Scoped Installer, Updater & Uninstaller / 用户级安装、升级与卸载脚本

Lifecycle management scripts deploy cleanly within the user's local AppData profile (`%LOCALAPPDATA%\Programs\Windows-Claude-Cleanup`) with SHA-256 managed manifests (`.claude-cleanup-install.json` and `.claude-cleanup-skill-install.json`), without modifying system `PATH`, Start Menu shortcuts, registry keys, or Claude applications:

### `scripts/Install-ClaudeCleanup.ps1`
- Installs toolkit scripts and docs into `%LOCALAPPDATA%\Programs\Windows-Claude-Cleanup` (override with `-InstallRoot`).
- Optionally installs the canonical Agent Skill (`-InstallSkill` or `-SkillOnly` alongside `-SkillTarget Codex|Antigravity|Gemini|Claude|Agents|All`).
- Validates reparse-point safety and protected paths atomically before writing any file.

### `scripts/Update-ClaudeCleanup.ps1`
- Updates managed toolkit files (`-UpdateSkill` / `-SkillOnly` supported) and prunes obsolete managed files while preserving user reports (`AUDIT.md`, `CLEANUP-PLAN.md`, `VERIFICATION.md`).

### `scripts/Uninstall-ClaudeCleanup.ps1`
- Removes managed toolkit files and manifests (keeps local reports by default unless `-RemoveReports` is specified).
- Supports independent Agent Skill removal (`-UninstallSkill` / `-SkillOnly`) and **never** deletes Claude Code or Claude Desktop applications.
- See [Uninstallation-Guide.md](Uninstallation-Guide.md) for full details.
