**English** | [简体中文](README_zh-CN.md)

# Windows Claude Cleanup Toolkit (`Claude Residual ID Cleaner`)

**Claude 账号残余 ID 清理工具 (Claude Residual ID Cleaner)** — A non-destructive standalone Windows desktop `.exe` and PowerShell toolkit specifically designed to scan and safely clean residual account/device IDs, auth tokens, and session caches left behind after a Claude account ban, **strictly without altering or harming Windows OS itself**.

---

## 1. Project Overview

Windows Claude Cleanup inspects known local installations, configurations, caches, logs, VS Code/Cursor extensions, MSIX packages, environment variable names, Credential Manager target counts, and browser Native Messaging registrations left behind by Claude Code and Claude Desktop on Windows. It separates read-only discovery (`-Audit`), manifest generation (`-Plan`), previewable/confirmed execution (`-Apply`), and independent post-action checking (`-Verify`), **without altering Windows OS system files, unrelated apps, browser profiles, OS hardware/device IDs, or WSL distributions**.

All operations execute through a single tested PowerShell engine ([ClaudeCleanup.ps1](ClaudeCleanup.ps1)) supporting seamless **Simplified Chinese / English (`-Language Auto|zh-CN|en-US`)** switching. You can build and launch the **standalone zero-console Windows Desktop `.exe`** (`dist/Claude-Residual-ID-Cleaner.exe` compiled cleanly via [scripts/Build-DesktopApp.ps1](scripts/Build-DesktopApp.ps1) from [src/Gui/](src/Gui/)), use the script-based WinForms GUI ([ClaudeCleanupGUI.cmd](ClaudeCleanupGUI.cmd)), the text-mode menu launcher ([ClaudeCleanupLauncher.cmd](ClaudeCleanupLauncher.cmd)), the PowerShell CLI, or the cross-agent Skill ([skills/claude-cleanup/SKILL.md](skills/claude-cleanup/SKILL.md)).

## 2. Current Release Status

- **Stage**: Release Candidate (Stages A–H implemented and verified across Windows PowerShell 5.1 and PowerShell 7+).
- **Real Cleanup Status**: No real Claude data cleanup has been authorized or executed during development. Default mode is strictly read-only Audit; all deletions require explicit user confirmation of the manifest SHA-256 hash and policy.
- **Repository Visibility**: Private development repository (`main` branch).

## 3. Features and Limitations

### Implemented Capabilities
- **Post-Ban Residual Scanning & Safe Cleanup Scope**: Targets allowlisted Claude Code CLI configs/IDs (`.claude`, `.claude.json`, `.local\bin\claude.exe`, npm `@anthropic-ai/claude-code`), Claude Desktop local storage/MSIX (`%APPDATA%\Claude`, `%LOCALAPPDATA%\Claude`, `Claude_pzs8sxrjxfjjc`), VS Code / Cursor / Windsurf extensions (`anthropic.claude-code`) and browser Native Messaging HKCU keys, Start Menu / Desktop / Startup `.lnk` shortcuts, Windows services/scheduled tasks, environment variable **names only** (`Scope` + `Name`, never secret values), `PATH` entries, Credential Manager target counts (no secret values read or deleted), AppData role classification, path ACL/owner/reparse diagnostics, and read-only WSL reporting.
- **Seamless Bilingual Runtime (`-Language Auto|zh-CN|en-US`)**: Automatically selects `zh-CN` on Chinese Windows locales (`zh*`) or switches manually between Simplified Chinese and English with UTF-8 console encoding and localized Markdown reports (`AUDIT.md`, `CLEANUP-PLAN.md`, `VERIFICATION.md`) while keeping JSON schema keys invariant.
- **Standalone Windows Desktop Application (`Claude-Residual-ID-Cleaner.exe`)**: Native .NET Framework 4.x WPF single-file zero-console `.exe` compiled offline via [scripts/Build-DesktopApp.ps1](scripts/Build-DesktopApp.ps1) from [src/Gui/Program.cs](src/Gui/Program.cs) & [src/Gui/Localization.cs](src/Gui/Localization.cs). Features live **中文 / English** toggling (defaulting to `zh-CN` on Chinese Windows locales), green safety banner (*"仅清理 Claude 封号残余数据 · 绝不改动 Windows 系统"*), 5 interactive target-scope checkboxes, 4-step workflow buttons (`Scan Residuals`, `Preview Plan`, disabled-until-scanned `Clean Selected` with explicit path-listing confirmation modal, `Verify Clean`), results DataGrid (`Select | Category | Path | Status | Details`), and log/report quick buttons — strictly delegating to [ClaudeCleanup.ps1](ClaudeCleanup.ps1).
- **Zero-Dependency Script GUI ([ClaudeCleanupGUI.cmd](ClaudeCleanupGUI.cmd))**: Companion WinForms entrypoint ([scripts/ClaudeCleanupGUI.ps1](scripts/ClaudeCleanupGUI.ps1)) for script-only execution without compiling.
- **Structured JSON Output (`-OutputFormat Json`)**: Supports machine-readable JSON output (`SchemaVersion = 3`) alongside text reports across `-Audit`, `-Plan`, `-Verify`, and `-Apply`.
- **Deterministic Cleanup Plan (`-Plan`) & Win32 Handle-Bound Deletion**: Generates `CLEANUP-PLAN.md` with GUID `PlanId` and SHA-256 binding; deletes filesystem nodes via `SetFileInformationByHandle` (`FILE_FLAG_OPEN_REPARSE_POINT | FILE_FLAG_BACKUP_SEMANTICS`), enforcing current user `OwnerSid` on every node, rejecting reparse points, and zero `Remove-Item` fallback.
- **Controlled Package Uninstallers (`FullRemoval`)**: Strictly scoped handlers for npm (`@anthropic-ai/claude-code`), VS Code (`code --uninstall-extension anthropic.claude-code`), and MSIX (`Remove-AppxPackage Claude_pzs8sxrjxfjjc`), each with fail-closed post-verification.
- **Cross-Agent Skill (`skills/claude-cleanup/`)**: Canonical multi-agent skill package ([SKILL.md](skills/claude-cleanup/SKILL.md)) compatible with Codex CLI, Antigravity CLI, Gemini CLI, and Claude Code, enforcing read-only `-Audit` default and SHA-256 authorization gates.
- **Safe Menu Launcher & User-Scoped Lifecycle**: [ClaudeCleanupLauncher.cmd](ClaudeCleanupLauncher.cmd) and [scripts/ClaudeCleanupLauncher.ps1](scripts/ClaudeCleanupLauncher.ps1) (supporting bilingual switching and `[6] Launch GUI`), plus [scripts/Install-ClaudeCleanup.ps1](scripts/Install-ClaudeCleanup.ps1), [scripts/Update-ClaudeCleanup.ps1](scripts/Update-ClaudeCleanup.ps1), and [scripts/Uninstall-ClaudeCleanup.ps1](scripts/Uninstall-ClaudeCleanup.ps1).
- **Release Packaging, CI Matrix & Documentation**: Release packaging ([scripts/New-ReleasePackage.ps1](scripts/New-ReleasePackage.ps1)), GitHub Actions workflow ([.github/workflows/ci.yml](.github/workflows/ci.yml)), guides in [docs/](docs/), [SECURITY.md](SECURITY.md), [CONTRIBUTING.md](CONTRIBUTING.md), [CHANGELOG.md](CHANGELOG.md), [LICENSE](LICENSE), and [NOTICE](NOTICE).

### Planned (Not Yet Implemented)
- **Real-World Live Execution (Stage G)**: Separately authorized real-data cleanup on live host systems.

## 4. Supported Windows Versions

- Windows 10 (64-bit, Build 19041+)
- Windows 11 (64-bit, Build 22000+)
- Designed primarily for local NTFS volumes (non-NTFS or network volumes fail closed when handle identity primitives are unsupported).

## 5. PowerShell Compatibility

- **Windows PowerShell 5.1** (`powershell.exe`, default on Windows 10 & 11)
- **PowerShell 7+** (`pwsh.exe`, cross-platform PowerShell Core)
- Embedded C# 5 P/Invoke layer (`ClaudeCleanup.NativeFs`) compiles at runtime on both .NET Framework 4.8 and modern .NET.

## 6. Installation Instructions

Choose either portable setup or user-scoped installation (see [Launcher & Install Guide](docs/Launcher-and-Install.md)):

### Option A: Portable Setup (Default)
1. Clone or download this repository to a user directory (for example, `C:\Users\<USERNAME>\Tools\Windows-Claude-Cleanup`).
2. Review [ClaudeCleanup.ps1](ClaudeCleanup.ps1) and [SECURITY.md](SECURITY.md) before execution.
3. No external modules, AI agents, Git, or REA runtime dependencies are required.

### Option B: User-Scoped Installation
Run the dedicated installer to place the toolkit in `%LOCALAPPDATA%\Programs\Windows-Claude-Cleanup`:
```powershell
powershell.exe -NoProfile -File .\scripts\Install-ClaudeCleanup.ps1
```
To install the optional Agent Skill simultaneously for a specific agent CLI:
```powershell
powershell.exe -NoProfile -File .\scripts\Install-ClaudeCleanup.ps1 -InstallSkill -SkillTarget Codex
```

## 7. Quick Start

### Building & Launching the Standalone Desktop `.exe` (Zero Console Window)
Build `dist/Claude-Residual-ID-Cleaner.exe` using stock Windows tools (zero external SDK or NuGet downloads required):
```powershell
.\scripts\Build-DesktopApp.ps1
.\dist\Claude-Residual-ID-Cleaner.exe
```

### Using the Script-Based GUI Without Compiling
Double-click [ClaudeCleanupGUI.cmd](ClaudeCleanupGUI.cmd) or run from PowerShell:
```cmd
.\ClaudeCleanupGUI.cmd
```

### Using the Safe Console Menu Launcher
Run from Command Prompt or PowerShell:
```cmd
.\ClaudeCleanupLauncher.cmd
```
The menu supports switching languages (`[L]`), launching the native Desktop GUI (`[6]`), running read-only audits, generating cleanup plans, viewing local reports, and verifying system state without command-line flags.

### Using the PowerShell CLI Directly
Run from the repository root (auto-detects Chinese Windows locales or accepts `-Language zh-CN|en-US`):
```powershell
.\ClaudeCleanup.ps1 -Help -Language Auto
.\ClaudeCleanup.ps1 -Audit -Language zh-CN
.\ClaudeCleanup.ps1 -Plan
```
Review `AUDIT.md` (optional `-SaveAuditReport`) and the generated `CLEANUP-PLAN.md` plus its SHA-256 hash before previewing any deletion.

## 8. CLI Command Reference

See [CLI Command Reference](docs/CLI-Reference.md) for full syntax and JSON schema details.

| Command | Purpose | Writes to Disk |
| :--- | :--- | :--- |
| `.\ClaudeCleanup.ps1 -Help [-Language Auto\|zh-CN\|en-US]` | Show usage and safety boundaries | None |
| `.\ClaudeCleanup.ps1 -Audit [-Language Auto\|zh-CN\|en-US] [-OutputFormat Text\|Json] [-SaveAuditReport]` | Read-only environment, ACL/AppData diagnostics, and candidate inventory | None (unless `-SaveAuditReport` writes `AUDIT.md`) |
| `.\ClaudeCleanup.ps1 -Plan [-Language Auto\|zh-CN\|en-US] [-OutputFormat Text\|Json]` | Generate `CLEANUP-PLAN.md` (`SchemaVersion = 3`) | `CLEANUP-PLAN.md` only |
| `.\ClaudeCleanup.ps1 -Plan -WhatIf` | Preview plan generation without writing | None |
| `.\ClaudeCleanup.ps1 -Apply -Policy <Policy> -ApprovedManifestSha256 <64-hex> [-Language Auto\|zh-CN\|en-US] [-OutputFormat Text\|Json] -WhatIf` | Dry-run preview of authorized targets | None |
| `.\ClaudeCleanup.ps1 -Apply -Policy <Policy> -ApprovedManifestSha256 <64-hex> [-Language Auto\|zh-CN\|en-US] [-OutputFormat Text\|Json]` | Execute approved `Ready` targets after confirmation | Deletes approved targets + updates `VERIFICATION.md` ledger |
| `.\ClaudeCleanup.ps1 -Verify [-Language Auto\|zh-CN\|en-US] [-OutputFormat Text\|Json]` | Inspect current state vs. `CLEANUP-PLAN.md` and `VERIFICATION.md` | None |

## 9. Audit / Plan / Apply / Verify Workflow

1. **Audit (`-Audit`)**: Collects read-only host observations and prints candidate decisions without mutating anything.
2. **Plan (`-Plan`)**: Measures safe targets and writes `CLEANUP-PLAN.md` with a unique `PlanId` (GUID) and SHA-256 hash. Every `-Plan` run invalidates previous hashes.
3. **Preview (`-Apply ... -WhatIf`)**: Verifies the SHA-256 hash and target metadata without deleting files or consuming the authorization hash.
4. **Apply (`-Apply`)**: Requires explicit user approval of **one policy** and the **exact 64-hex SHA-256** of `CLEANUP-PLAN.md`, plus PowerShell `ConfirmImpact = 'High'` confirmation. A manifest hash can be consumed at most once across real `-Apply` runs.
5. **Verify (`-Verify`)**: Independently checks whether planned targets are `Present`, `Absent`, or `Unknown`, and displays recorded ledger outcomes.

## 10. AccountData vs FullRemoval

| Aspect | `AccountData` | `FullRemoval` |
| :--- | :--- | :--- |
| **Scope** | Confirmed CLI credentials/auth cache, app caches, and diagnostic logs | Confirmed user-level Claude Code installs, config, Desktop data, VS Code extensions, MSIX package, and browser native host keys |
| **User Creations / History** | Preserved (`.claude` skills/sessions, `.claude.json`, Desktop `Local Storage` / `IndexedDB` remain) | Removes `.claude` / `.claude.json` / Desktop Roaming & Local if safe & `Ready` (deletes skills, plugins, MCP config, sessions, Cowork data) |
| **Unverified / Shared Items** | `buddy-tokens.json` defaults to `ReviewOnly` | `Claude-3p`, `pivot.claude.ai`, `.obsolete`, and MSIX `Packages\Claude_pzs8sxrjxfjjc` remain `ReviewOnly` or `Blocked` |
| **Fallback Behavior** | N/A | If a parent root (`.claude`, `%APPDATA%\Claude`) is `Blocked` or `ReviewOnly`, non-overlapping `Ready` children are listed safely |

> **Important**: `AccountData` may not clear every login trace stored in mixed Desktop storage (`Local Storage` / `IndexedDB`). Local cleanup never modifies remote server-side account status.

## 11. Security and Authorization

See [SECURITY.md](SECURITY.md) for threat modeling and security invariants.

- **Handle-Bound Deletion**: Filesystem targets are opened with `FILE_FLAG_OPEN_REPARSE_POINT | FILE_FLAG_BACKUP_SEMANTICS` (exclusive `FILE_SHARE_NONE` for files; `FILE_SHARE_READ | FILE_SHARE_WRITE` without `FILE_SHARE_DELETE` for directories), verified via `GetFinalPathNameByHandleW`, `GetFileInformationByHandle`, and `GetSecurityInfo`, and deleted via `SetFileInformationByHandle` (`FileDispositionInfoEx` / `FileDispositionInfo`) — **no `Remove-Item` fallback**.
- **Reparse Points & Mixed Ownership**: Any junction, symlink, or dangling reparse point along ancestors or inside a tree blocks execution. Every node in a directory tree must be owned by the current user SID (`OwnerSid`); mixed-ownership trees are marked `Blocked`.
- **Protected Locations**: Drive roots, `WINDIR`, `ProgramFiles`, `ProgramFiles(x86)`, `.codex`, `.agents`, `.gemini`, the project directory, and exact user roots (`USERPROFILE`, `APPDATA`, `LOCALAPPDATA`, `ProgramData`, `PUBLIC`, `TEMP`, `TMP`) are protected.
- **Registry Safety**: Only exact HKCU Chrome/Edge `com.anthropic.claude_browser_extension` keys are eligible; ancestors and target are checked against `REG_LINK`, subkeys must be `0`, `(Default)` must match plan identity, and deletion uses `ntdll!NtDeleteKey` on the validated open handle.
- **Single-Read Manifest & Atomic Replay Ledger**: `CLEANUP-PLAN.md` is read once into memory for SHA-256 and JSON parsing (`SchemaVersion = 3`, single JSON block check). `VERIFICATION.md` uses temp-file + `Flush($true)` + atomic `File.Replace`/`Move` for its execution ledger; truncated or corrupted ledgers fail closed.
- **No Backup / No Rollback**: Deletions are permanent. Do not run with running `claude` or `Code` processes.

## 12. Data Privacy and Local-Only Processing Boundaries

- All operations run locally on your machine; no telemetry or network upload occurs.
- Credential Manager targets are counted by name pattern only; secret values are never read or deleted by this version.
- Browser profiles, site storage, and WSL distributions are never modified.
- `AUDIT.md`, `CLEANUP-PLAN.md`, and `VERIFICATION.md` contain local paths, SIDs, and hashes and are excluded by `.gitignore` so they are not committed to Git.
- Sanitized sample reports are available in [docs/examples/AUDIT.sample.md](docs/examples/AUDIT.sample.md), [docs/examples/CLEANUP-PLAN.sample.md](docs/examples/CLEANUP-PLAN.sample.md), and [docs/examples/VERIFICATION.sample.md](docs/examples/VERIFICATION.sample.md).

## 13. Troubleshooting

See [Troubleshooting and Compatibility Guide](docs/Troubleshooting-and-Compatibility.md) for expanded diagnostic steps.

- **`Unsupported manifest schema version (SchemaVersion 3 required)`**: Re-run `.\ClaudeCleanup.ps1 -Plan` to generate a new `SchemaVersion = 3` manifest and use its new SHA-256.
- **`Target is not owned by the current user` (`BUILTIN\Administrators`)**: Files created during elevated sessions may be owned by Administrators. This version intentionally blocks them rather than modifying ACLs or taking ownership.
- **Access errors during `-Audit` / `-Verify` in restricted shells**: Restricted environments block queries and cause targets to appear as `Blocked` or `Unknown` (never falsely reported as `Absent`).
- **ExecutionPolicy errors**: Avoid bypassing policy blindly; inspect `Get-ExecutionPolicy -List` and ensure you review local scripts before unblocking files you downloaded.

## 14. Testing and Verification

Tests create and clean up isolated fixtures **only** inside `tests/sandbox/` (and never write to real Claude data or real HKCU registry keys):

```powershell
# Core cleanup engine tests
powershell.exe -NoProfile -File .\tests\ClaudeCleanup.Tests.ps1
pwsh.exe -NoProfile -File .\tests\ClaudeCleanup.Tests.ps1

# Cross-agent skill package tests
powershell.exe -NoProfile -File .\tests\SkillPackage.Tests.ps1
pwsh.exe -NoProfile -File .\tests\SkillPackage.Tests.ps1

# Launcher and installation lifecycle tests
powershell.exe -NoProfile -File .\tests\ToolkitInstall.Tests.ps1
pwsh.exe -NoProfile -File .\tests\ToolkitInstall.Tests.ps1

# CI workflow, packaging, and release tests
powershell.exe -NoProfile -File .\tests\ToolkitCiChecks.Tests.ps1
pwsh.exe -NoProfile -File .\tests\ToolkitCiChecks.Tests.ps1

# Bilingual locale switching & WinForms GUI validation
powershell.exe -NoProfile -File .\tests\BilingualAndGui.Tests.ps1
pwsh.exe -NoProfile -File .\tests\BilingualAndGui.Tests.ps1

# Standalone WPF Desktop .exe compilation, subsystem, and self-test suite
powershell.exe -NoProfile -File .\tests\DesktopApp.Tests.ps1
pwsh.exe -NoProfile -File .\tests\DesktopApp.Tests.ps1
```

- **Permission & Authorization Note**: Creating Windows symbolic links requires Administrator or Developer Mode privileges (`SeCreateSymbolicLinkPrivilege`); unprivileged sessions explicitly report those symlink creation cases as `SKIP` (and restricted app-container sandboxes may also block `FSCTL_SET_REPARSE_POINT` junction creation). Live HKCU write/delete, cross-SID mixed-ownership disk tests, and live `npm` / `code` / `Remove-AppxPackage` uninstall calls remain explicitly reported as `NotExecuted` during sandboxed testing.
- Automated testing across all suites is configured in [.github/workflows/ci.yml](.github/workflows/ci.yml).

## 15. Known Issues and Unsupported Operations

- **MSIX Data Junctions**: `%LOCALAPPDATA%\Packages\Claude_pzs8sxrjxfjjc` contains junctions (for example, pointing to `<Drive>:\WpSystem`); never delete directly. Authorized MSIX removal delegates to `Remove-AppxPackage`, which may remove package-managed data and `CoworkVMService`.
- **Win32 Handle Pre-Open Window & Hardlinks**: User-mode path resolution still occurs in the brief instant before `CreateFileW` opens the root/child handle; `SetFileInformationByHandle` unlinks only the addressed directory entry and does not remove external NTFS hardlinks.
- **Non-Filesystem OS APIs**: `AppxPackage` removal relies on Windows AppX deployment services.
- **WSL Isolation**: WSL distributions (and Linux-side `~/.claude` files) are reported read-only when running and are never modified.
- **Not Supported**: Device-identity spoofing, anti-abuse bypasses, Credential Manager secret removal, and automatic ACL/ownership changes.

## 16. Cross-Agent Skills Integration

The canonical `claude-cleanup` skill package is located at [skills/claude-cleanup/](skills/claude-cleanup/):
- **Skill Specification**: [SKILL.md](skills/claude-cleanup/SKILL.md)
- **Permissions and Risks**: [references/permissions-and-risks.md](skills/claude-cleanup/references/permissions-and-risks.md)
- **Multi-Agent Installation Guide**: [references/agent-installation.md](skills/claude-cleanup/references/agent-installation.md)
- **Architecture & Ecosystem Guide**: [docs/Agent-Skill-Guide.md](docs/Agent-Skill-Guide.md)

Supported agent CLIs include Codex CLI (`~/.codex/skills/` or shared `~/.agents/skills/`), Antigravity CLI (`~/.gemini/config/skills/`), Gemini CLI (`~/.gemini/skills/`), and Claude Code (`~/.claude/skills/`). The skill strictly delegates to `ClaudeCleanup.ps1` with zero duplicated deletion code, defaults to read-only `-Audit`, and enforces human authorization before `-Apply`.

## 17. Native Windows Desktop GUI and Architecture Notes

- **Native Desktop GUI ([ClaudeCleanupGUI.cmd](ClaudeCleanupGUI.cmd) + [scripts/ClaudeCleanupGUI.ps1](scripts/ClaudeCleanupGUI.ps1))**: Zero-dependency WinForms desktop utility with live **中 / EN** toggle, target scope checklist, read-only default scanning, disabled-until-ready cleanup button, and explicit SHA-256 + path confirmation dialog before invoking [ClaudeCleanup.ps1](ClaudeCleanup.ps1).
- **Console Menu Launcher ([ClaudeCleanupLauncher.cmd](ClaudeCleanupLauncher.cmd) + [scripts/ClaudeCleanupLauncher.ps1](scripts/ClaudeCleanupLauncher.ps1))**: Provides interactive bilingual text menus plus direct `[6] Launch GUI` integration (see [Launcher & Install Guide](docs/Launcher-and-Install.md)).
- **GUI Design & Security Record**: Detailed architecture and security boundaries are recorded in [docs/gui-evaluation.md](docs/gui-evaluation.md).

## 18. How to Uninstall Claude

This utility does **not** automatically uninstall Claude without your explicit plan approval. See [Uninstallation Guide](docs/Uninstallation-Guide.md) for full options:
- User-level `claude.exe` and `.local\share\claude` / Desktop MSIX / VS Code extensions are inventoried under `FullRemoval` (items owned by `BUILTIN\Administrators` remain `Blocked`).
- For MSIX Claude Desktop, you can also uninstall via Windows **Settings → Apps → Installed apps** or approved `FullRemoval` (`Remove-AppxPackage`).
- Removing this cleanup toolkit does **not** uninstall Claude.

## 19. How to Uninstall the Toolkit

See [Uninstallation Guide](docs/Uninstallation-Guide.md) for detailed instructions:
- **Portable Removal**: Delete the cloned or downloaded repository folder.
- **Installed Toolkit Removal**: Run `powershell.exe -File .\scripts\Uninstall-ClaudeCleanup.ps1` to cleanly remove `%LOCALAPPDATA%\Programs\Windows-Claude-Cleanup` (preserves local reports by default; pass `-RemoveReports` for complete removal).
- **Skill-Only Removal**: Run `.\scripts\Uninstall-ClaudeCleanup.ps1 -SkillOnly -SkillTarget <Agent>` to remove agent skill folders without touching the toolkit or Claude applications.

## 20. GitHub Development and Contribution Workflow

See [CONTRIBUTING.md](CONTRIBUTING.md) for contribution guidelines, coding conventions, and pull request requirements. Security issues should be reported according to [SECURITY.md](SECURITY.md). Project version history is tracked in [CHANGELOG.md](CHANGELOG.md).
- Development follows strict staged authorization on `main`: inspect `git status` -> minimal scoped edits -> Windows PowerShell 5.1 & PowerShell 7 regression checks -> `git diff` privacy audit -> Conventional Commit.
- Never commit `AUDIT.md`, `CLEANUP-PLAN.md`, `VERIFICATION.md`, `tests/sandbox/`, `dist/`, credentials, SIDs, or local logs.

## 21. License and Attribution Status

- **License**: Released under the [MIT License](LICENSE).
- **Attribution & Notice**: See [NOTICE](NOTICE). Inspired conceptually by [suyuan2022/claude-cleanup](https://github.com/suyuan2022/suyuan-skill/tree/main/claude-cleanup) (macOS-oriented upstream; backup, trash, and identity-rotation behaviors were intentionally **not** ported to this Windows clean-room utility). Not affiliated with Anthropic PBC.
