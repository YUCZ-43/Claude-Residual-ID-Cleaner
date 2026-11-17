# Windows Claude Cleanup — Uninstallation Guide

**Project:** Windows Claude Cleanup Toolkit  
**Repository:** `YUCZ-43/Windows-Claude-Cleanup`  
**Language Navigation:** [English](../README.md) | [简体中文](../README_zh-CN.md)  
**Document Status:** Implemented (Claude Cleanup, Portable/Installed Toolkit Uninstaller, and Skill Uninstaller)

---

## 1. Overview / 概述

This guide distinguishes three completely separate uninstallation processes:
1. **Uninstalling Claude Software & Artifacts** (Claude Code CLI, Claude Desktop, VS Code extensions, and local AppData).
2. **Uninstalling the Windows Claude Cleanup Toolkit** (removing this utility from your computer).
3. **Uninstalling Optional Agent Skills** (removing skill integration from AI agent directories).

---

## 2. Uninstalling Claude Code and Claude Desktop / 卸载 Claude 软件

You can remove Claude software either using this toolkit (automated, handle-bound, cryptographically verified) or via native Windows manual mechanisms.

### Option A: Using Windows Claude Cleanup Toolkit (`FullRemoval`)
The toolkit provides verified, handle-bound removal of local Claude software, configuration files, caches, and registrations:

1. **Close Running Claude Processes**:
   Ensure `claude.exe`, `Claude.exe` (Desktop), and VS Code windows are completely closed.

2. **Generate Cleanup Plan**:
   ```powershell
   .\ClaudeCleanup.ps1 -Plan
   ```
   Open `CLEANUP-PLAN.md` and verify that the targets scheduled under `FullRemoval` match your expectations.

3. **Execute Full Removal**:
   ```powershell
   .\ClaudeCleanup.ps1 -Apply -Policy FullRemoval -ApprovedManifestSha256 <64-hex-manifest-hash>
   ```
   The engine performs:
   - Scoped npm package removal: `npm uninstall -g @anthropic-ai/claude-code`.
   - Scoped VS Code extension removal: `code --uninstall-extension anthropic.claude-code`.
   - Controlled MSIX uninstallation: `Remove-AppxPackage Claude_pzs8sxrjxfjjc`.
   - Handle-bound directory deletion of `%APPDATA%\Claude`, `%LOCALAPPDATA%\Claude`, `.claude`, and `.claude.json`.
   - Open-handle registry deletion of browser Native Messaging host keys in HKCU.

4. **Verify Clean State**:
   ```powershell
   .\ClaudeCleanup.ps1 -Verify
   ```
   Confirm that removed items report `Absent`.

---

### Option B: Manual Uninstallation (Native Windows Mechanisms)
If you prefer not to use the automated toolkit, you can uninstall Claude components manually:

1. **Claude Desktop (MSIX)**:
   - Open Windows **Settings** (`Win + I`) → **Apps** → **Installed apps**.
   - Locate **Claude**.
   - Click the three dots (`...`) and select **Uninstall**.

2. **Claude Code CLI (npm global installation)**:
   - In PowerShell or Command Prompt, run:
     ```powershell
     npm uninstall -g @anthropic-ai/claude-code
     ```

3. **Claude Code CLI (Native binary)**:
   - Delete `%USERPROFILE%\.local\bin\claude.exe` and `%USERPROFILE%\.local\share\claude`.

4. **VS Code Claude Extension**:
   - In VS Code, open the Extensions view (`Ctrl + Shift + X`).
   - Find **Claude** (Anthropic), click the gear icon, and select **Uninstall**.
   - Or run:
     ```powershell
     code --uninstall-extension anthropic.claude-code
     ```

5. **Residual Configuration & Cache Folders**:
   - Configuration & credentials: `%USERPROFILE%\.claude`, `%USERPROFILE%\.claude.json`.
   - Desktop Roaming data: `%APPDATA%\Claude`.
   - Desktop Local cache: `%LOCALAPPDATA%\Claude`.

---

## 3. Uninstalling the Windows Claude Cleanup Toolkit / 卸载本清理工具

The toolkit itself does not install background services, system drivers, or system-wide registry keys.

### Current Method: Portable Removal
1. Delete the cloned or downloaded repository directory:
   ```powershell
   Remove-Item -Recurse -Force "C:\Path\To\Windows-Claude-Cleanup"
   ```
2. Any local gitignored reports created in the repository directory (`AUDIT.md`, `CLEANUP-PLAN.md`, `VERIFICATION.md`) will be deleted along with the directory.

> **Important / 重要提示**: Deleting the Windows Claude Cleanup Toolkit does **not** delete or uninstall Claude Code or Claude Desktop.

### Dedicated User-Scoped Uninstaller (`scripts/Uninstall-ClaudeCleanup.ps1`)
Run the user-scoped uninstaller script:
```powershell
powershell.exe -NoProfile -File .\scripts\Uninstall-ClaudeCleanup.ps1
```
This script cleanly removes managed toolkit files and `.claude-cleanup-install.json` inside:
- `%LOCALAPPDATA%\Programs\Windows-Claude-Cleanup` (preserves local `AUDIT.md`, `CLEANUP-PLAN.md`, and `VERIFICATION.md` reports unless `-RemoveReports` is specified)

---

## 4. Uninstalling Optional Agent Skills / 卸载智能体技能

If you installed the canonical `claude-cleanup` skill into an AI coding agent CLI, use the dedicated `-SkillOnly` uninstaller or remove only the skill folder:

```powershell
powershell.exe -NoProfile -File .\scripts\Uninstall-ClaudeCleanup.ps1 -SkillOnly -SkillTarget Codex
```

| Agent Platform | Target Folder | Manual Removal Command |
| :--- | :--- | :--- |
| **Codex CLI (`Codex`)** | `%USERPROFILE%\.codex\skills\claude-cleanup` | `Remove-Item -Recurse -Force "$HOME\.codex\skills\claude-cleanup"` |
| **Codex CLI / Shared (`Agents`)** | `%USERPROFILE%\.agents\skills\claude-cleanup` | `Remove-Item -Recurse -Force "$HOME\.agents\skills\claude-cleanup"` |
| **Antigravity CLI (`Antigravity`)** | `%USERPROFILE%\.gemini\config\skills\claude-cleanup` | `Remove-Item -Recurse -Force "$HOME\.gemini\config\skills\claude-cleanup"` |
| **Gemini CLI (`Gemini`)** | `%USERPROFILE%\.gemini\skills\claude-cleanup` | `Remove-Item -Recurse -Force "$HOME\.gemini\skills\claude-cleanup"` |
| **Claude Code (`Claude`)** | `%USERPROFILE%\.claude\skills\claude-cleanup` | `Remove-Item -Recurse -Force "$HOME\.claude\skills\claude-cleanup"` |

Removing the skill removes only the agent prompt and tool wrapper. It does not touch your agent configuration or personal files.
