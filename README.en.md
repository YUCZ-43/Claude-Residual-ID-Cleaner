[简体中文](README.md) | English | [Cross-Agent Skill Guide](docs/Skills-Usage-Guide.en.md) | [CLI Reference](docs/CLI-Reference.md)

<div align="center">
  <img src="docs/images/logo.png" width="128" alt="claude-cleanup Mascot Logo" />
  <h1>claude-cleanup</h1>
  <p><strong>Claude Residual ID Cleaner</strong></p>
  <p>A Windows post-ban Claude residual account ID & cache cleaner — standalone desktop app + AI-callable skill, 100% read-only by default, strictly never alters Windows OS itself</p>
  <p>
    <a href="https://github.com/YUCZ-43/claude-cleanup/releases/latest"><img src="https://img.shields.io/badge/Release-v0.1.0-0078D4?style=flat-square" alt="Release v0.1.0" /></a>
    <img src="https://img.shields.io/badge/Platform-Windows%2010%2F11-0078D4?style=flat-square" alt="Platform Windows 10/11" />
    <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-22C55E?style=flat-square" alt="License MIT" /></a>
    <a href="README.md"><img src="https://img.shields.io/badge/Language-%E7%AE%80%E4%BD%93%E4%B8%AD%E6%96%87%20%7C%20English-16A34A?style=flat-square" alt="Language" /></a>
  </p>
</div>

<p align="center">
  <img src="docs/images/demo-workflow.gif" width="900" alt="claude-cleanup Desktop 3-Step Safe Workflow Demo (Read-Only Scan -> Detect Residuals -> Verify Zero Leftovers)" />
</p>

---

## Core Features & Safety Matrix

| Pillar | Implementation | Safety Guarantee |
| :--- | :--- | :--- |
| **Residual Account UUID Extraction** | Parses only non-secret `accountUuid`, `organizationUuid`, `userId`, and `deviceId` metadata from local configs with one-click copy | **Never reads** OAuth tokens, refresh tokens, session keys, API keys, or Windows Credential Manager secrets |
| **Self-Process Exclusion & Safe Close** | Excludes current/parent/grandparent PIDs, cleaner executables, and repo paths so it never flags itself; targets only real Claude processes | Never kills processes silently; only closes running Claude processes after explicit user confirmation (`-CloseRunningProcesses`) |
| **On-Demand Admin Elevation (Zero Startup UAC)** | Both desktop app and setup wizard embed standard `asInvoker` manifests; routine user-profile cleanup needs no admin rights | Zero forced UAC prompts at launch; users explicitly click **"Restart as Admin"** only when ACL-protected paths require it |
| **Strict Windows OS Red Line** | All discovery, validation, Win32 handle-bound deletion, and ledger verification live solely in [ClaudeCleanup.ps1](ClaudeCleanup.ps1) with zero `Remove-Item` fallback | Never touches `C:\Windows`, `Program Files`, OS `MachineGuid`, WSL distros, or personal Edge/Chrome browser profiles |

---

## Quick Download & Launch (GitHub Releases)

Download verified Windows executables directly from [GitHub Releases Latest](https://github.com/YUCZ-43/claude-cleanup/releases/latest):

| Artifact | Best For | Footprint & Privileges | Download |
| :--- | :--- | :--- | :--- |
| **`Claude-Residual-ID-Cleaner-Setup.exe`** | **Windows Setup Wizard (Recommended)**: Creates Desktop & Start Menu shortcuts and registers clean Add/Remove Programs uninstall | Installs to `%LOCALAPPDATA%\Programs\claude-cleanup` by default (**no UAC required**) | [Download Setup Installer](https://github.com/YUCZ-43/claude-cleanup/releases/latest) |
| **`Claude-Residual-ID-Cleaner.exe`** | **Portable Single-File Executable**: Zero installation, zero Add/Remove registry footprint, double-click ready | Runs from any local folder beside toolkit scripts or inside the release ZIP | [Download Portable .exe](https://github.com/YUCZ-43/claude-cleanup/releases/latest) |
| **`claude-cleanup-0.1.0.zip`** | **Full Portable Bundle + Checksums**: Contains portable `.exe`, PowerShell backend, `skills/`, and `SHA256SUMS.txt` | Extract anywhere and verify integrity with `Get-FileHash` against `SHA256SUMS.txt` | [Download Release ZIP](https://github.com/YUCZ-43/claude-cleanup/releases/latest) |

> **Two-Policy Protection**: Default **`AccountData`** clears all Claude banned-account residuals in one click (`.credentials.json`, `.claude.json` account metadata, `buddy-tokens.json`, `mcp-needs-auth-cache.json`, `stats-cache.json`, plus Desktop `Cache`/`Network`/`Local Storage`/`IndexedDB`/logs) while preserving custom `.claude` skills/commands and `claude_desktop_config.json`. Switching to **`FullRemoval`** additionally uninstalls Claude Code/Desktop binaries, IDE extensions, MSIX package, and allowlisted HKCU browser host keys after 64-hex SHA-256 manifest approval. Local cleanup never alters remote server-side account records.

---

## AI-Callable Agent Skill

The repository ships a canonical cross-agent skill package at [skills/claude-cleanup/](skills/claude-cleanup/), exposing `claude-cleanup` as an **AI-invocable cleanup capability** (zero duplicated deletion logic; delegates strictly to [ClaudeCleanup.ps1](ClaudeCleanup.ps1) with a 100% read-only default and mandatory SHA-256 confirmation gate).

**One-command installation for Claude Code, Codex CLI, Antigravity, and Gemini CLI:**

```powershell
powershell.exe -NoProfile -File .\scripts\Install-ClaudeCleanup.ps1 -InstallSkill -SkillTarget All
```

**Copy-paste natural-language prompt:**

```text
Use the claude-cleanup skill to run a read-only audit (-Audit) on this machine, summarize any detected Claude account UUIDs, running processes, and cleanup candidates, and do not delete anything until I explicitly approve the SHA-256 manifest hash.
```

For per-agent paths and workflow examples across Antigravity, Codex CLI, Claude Code, and Gemini CLI, see [Cross-Agent Skill Usage Guide](docs/Skills-Usage-Guide.en.md) ([简体中文实战指南](docs/Skills-Usage-Guide.md)), [SKILL.md](skills/claude-cleanup/SKILL.md), and [Permissions & Risks](skills/claude-cleanup/references/permissions-and-risks.md).

---

## Desktop Studio Gallery

<table>
  <tr>
    <td align="center" width="33%">
      <img src="docs/images/ui-main-zh.png" alt="Simplified Chinese Studio Dashboard" />
      <br /><sub><b>Read-Only Studio Dashboard (zh-CN)</b></sub>
    </td>
    <td align="center" width="33%">
      <img src="docs/images/ui-scan-results-zh.png" alt="Demo Scan Results & UUID Extraction" />
      <br /><sub><b>Live Scan & Non-Secret UUID View</b></sub>
    </td>
    <td align="center" width="33%">
      <img src="docs/images/ui-main-en.png" alt="English Studio UI" />
      <br /><sub><b>Instant Live Language Toggle (en-US)</b></sub>
    </td>
  </tr>
</table>

---

## CLI Reference, Offline Build & Automated Tests

<details>
<summary><b>Expand: PowerShell CLI commands, offline compilation, and dual-PowerShell tests</b></summary>

### 1. Native PowerShell CLI Commands ([Full CLI Reference](docs/CLI-Reference.md))

| Command | Purpose | Disk Write Behavior |
| :--- | :--- | :--- |
| `.\ClaudeCleanup.ps1 -Audit [-SaveAuditReport] [-OutputFormat Json]` | Read-only scan of leftovers, non-secret UUIDs, ACL ownership, shortcuts, and env var names | None (writes `AUDIT.md` only with `-SaveAuditReport`) |
| `.\ClaudeCleanup.ps1 -Plan [-Language zh-CN\|en-US]` | Generate deterministic `CLEANUP-PLAN.md` (`SchemaVersion = 3`) with GUID `PlanId` and SHA-256 | Writes `CLEANUP-PLAN.md` only |
| `.\ClaudeCleanup.ps1 -Apply -Policy <AccountData\|FullRemoval> -ApprovedManifestSha256 <64-hex> -WhatIf` | Dry-run preview of approved targets without consuming the manifest hash | None |
| `.\ClaudeCleanup.ps1 -Apply -Policy <Policy> -ApprovedManifestSha256 <64-hex> [-CloseRunningProcesses]` | Execute Win32 handle-bound deletion after `ConfirmImpact = 'High'` confirmation | Deletes approved targets; atomically updates `VERIFICATION.md` |
| `.\ClaudeCleanup.ps1 -Verify [-OutputFormat Json]` | Independent read-only verification (`Present` / `Absent` / `Unknown`) and replay ledger check | None |

You can also launch the interactive console menu ([ClaudeCleanupLauncher.cmd](ClaudeCleanupLauncher.cmd)) or zero-compile WinForms wrapper ([ClaudeCleanupGUI.cmd](ClaudeCleanupGUI.cmd)).

### 2. Build & Package Offline From Source

```powershell
.\scripts\New-AppIcon.ps1                 # Generate mascot logo & multi-size app.ico
.\scripts\Build-DesktopApp.ps1            # Compile portable dist\Claude-Residual-ID-Cleaner.exe
.\scripts\Build-Installer.ps1             # Compile setup wizard dist\Claude-Residual-ID-Cleaner-Setup.exe
.\scripts\New-ReleasePackage.ps1          # Build release ZIP + SHA256SUMS.txt
```

### 3. Isolated Sandbox Test Suites (Windows PowerShell 5.1 & PowerShell 7+)

All tests create temporary fixtures strictly inside `tests/sandbox/` and clean up in `finally` blocks without touching live Claude data or HKCU keys (CI workflow: [.github/workflows/ci.yml](.github/workflows/ci.yml)):

```powershell
powershell.exe -NoProfile -File .\tests\ClaudeCleanup.Tests.ps1
powershell.exe -NoProfile -File .\tests\SkillPackage.Tests.ps1
powershell.exe -NoProfile -File .\tests\ToolkitInstall.Tests.ps1
powershell.exe -NoProfile -File .\tests\ToolkitCiChecks.Tests.ps1
powershell.exe -NoProfile -File .\tests\BilingualAndGui.Tests.ps1
powershell.exe -NoProfile -File .\tests\DesktopApp.Tests.ps1
```

</details>

---

## Documentation & License

- **Guides & Governance**: [Launcher & Install Guide](docs/Launcher-and-Install.md) · [Uninstallation Guide](docs/Uninstallation-Guide.md) · [Troubleshooting & Compatibility](docs/Troubleshooting-and-Compatibility.md) · [Security Policy (SECURITY.md)](SECURITY.md) · [Changelog (CHANGELOG.md)](CHANGELOG.md) · [Contributing (CONTRIBUTING.md)](CONTRIBUTING.md)
- **License & Attribution**: Released under the [MIT License](LICENSE); see [NOTICE](NOTICE) for clean-room provenance. Conceptually inspired by the macOS shell project [suyuan2022/claude-cleanup](https://github.com/suyuan2022/suyuan-skill/tree/main/claude-cleanup); implemented completely clean-room for Windows and not affiliated with Anthropic PBC.

## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=YUCZ-43/claude-cleanup&type=Date)](https://www.star-history.com/#YUCZ-43/claude-cleanup&Date)
