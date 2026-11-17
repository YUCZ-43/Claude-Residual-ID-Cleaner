**English** | [简体中文](README_zh-CN.md)

# Windows Claude Cleanup Toolkit

A native Windows PowerShell utility for **read-only auditing**, **cryptographically bound planning**, and **user-authorized local cleanup** of Claude Code and Claude Desktop artifacts.

---

## 1. Project Overview

Windows Claude Cleanup inspects known local installations, configurations, caches, logs, VS Code extensions, MSIX packages, and browser Native Messaging registrations associated with Claude Code and Claude Desktop on Windows. It separates read-only discovery (`-Audit`), manifest generation (`-Plan`), previewable/confirmed execution (`-Apply`), and independent post-action checking (`-Verify`), without modifying device IDs, proxies, telemetry, browser profiles, or WSL distributions.

All operations execute through a single tested PowerShell engine ([ClaudeCleanup.ps1](ClaudeCleanup.ps1)). The toolkit can be operated via CLI, through the text-mode Windows menu launcher ([ClaudeCleanupLauncher.cmd](ClaudeCleanupLauncher.cmd)), or via the cross-agent Skill ([skills/claude-cleanup/SKILL.md](skills/claude-cleanup/SKILL.md)).

## 2. Current Release Status

- **Stage**: Release Candidate (Stages A–F implemented and verified across Windows PowerShell 5.1 and PowerShell 7+).
- **Real Cleanup Status**: No real Claude data cleanup has been authorized or executed during development. All deletions require explicit user confirmation of the manifest SHA-256 hash and policy.
- **Repository Visibility**: Private development repository (`main` branch).

## 3. Features and Limitations

### Implemented Capabilities
- **Read-Only System Audit (`-Audit`)**: Discovers native and npm Claude Code CLI installations (npm global prefix resolution via `npm`, `.npmrc`, `NPM_CONFIG_PREFIX`, `%APPDATA%\npm`), Claude Desktop, VS Code / Cursor / Windsurf Claude extensions, MSIX packages, Start Menu / Desktop / Startup `.lnk` shortcuts, Windows services/scheduled tasks, environment variable **names only** (`Scope` + `Name`, never secret values), `PATH` entries, Credential Manager target counts (no secret values read), AppData role classification, path ACL/owner/reparse diagnostics, and read-only WSL reporting.
- **Structured JSON Output (`-OutputFormat Json`)**: Supports machine-readable JSON output (`SchemaVersion = 3`) alongside text reports across `-Audit`, `-Plan`, `-Verify`, and `-Apply` for automation and agent skill integration.
- **Deterministic Cleanup Plan (`-Plan`)**: Generates `CLEANUP-PLAN.md` with a unique GUID `PlanId`, SHA-256 integrity hash, per-entry `Ready` / `ReviewOnly` / `Blocked` decisions, NTFS `VolumeSerialNumber` / `FileIndex`, and subtree `MaxLastWriteUtcTicks`.
- **Win32 Handle-Bound Deletion**: Deletes filesystem nodes via `SetFileInformationByHandle` on validated handles opened with `FILE_FLAG_OPEN_REPARSE_POINT | FILE_FLAG_BACKUP_SEMANTICS`, enforcing current user `OwnerSid` on every node, with strict reparse-point rejection and zero `Remove-Item` fallback.
- **Controlled Package Uninstallers (`FullRemoval`)**: Strictly scoped uninstallation handlers for npm (`@anthropic-ai/claude-code`), VS Code (`code --uninstall-extension anthropic.claude-code`), and MSIX (`Remove-AppxPackage Claude_pzs8sxrjxfjjc`), each with fail-closed post-verification.
- **Cross-Agent Skill (`skills/claude-cleanup/`)**: Canonical multi-agent skill package ([SKILL.md](skills/claude-cleanup/SKILL.md)) compatible with Codex CLI, Antigravity CLI, Gemini CLI, and Claude Code, enforcing read-only `-Audit` default, explicit plan SHA-256 authorization gate, zero duplicated deletion code, and optional dev-only REA stance.
- **Safe Menu Launcher**: Command batch wrapper ([ClaudeCleanupLauncher.cmd](ClaudeCleanupLauncher.cmd)) and interactive text menu ([scripts/ClaudeCleanupLauncher.ps1](scripts/ClaudeCleanupLauncher.ps1)) supporting Audit, Plan, View Reports, Verify, and Help without `-ExecutionPolicy Bypass`, without auto-elevation, and without automatic `-Apply`.
- **User-Scoped Lifecycle Management**: Scripts for installation ([scripts/Install-ClaudeCleanup.ps1](scripts/Install-ClaudeCleanup.ps1)), updating ([scripts/Update-ClaudeCleanup.ps1](scripts/Update-ClaudeCleanup.ps1)), and uninstallation ([scripts/Uninstall-ClaudeCleanup.ps1](scripts/Uninstall-ClaudeCleanup.ps1)) cleanly separating toolkit files, optional Agent Skills, and Claude application presence.
- **Release Packaging & CI Matrix**: Release packaging script ([scripts/New-ReleasePackage.ps1](scripts/New-ReleasePackage.ps1)) and GitHub Actions workflow ([.github/workflows/ci.yml](.github/workflows/ci.yml)) testing Windows PowerShell 5.1 and PowerShell 7 on `windows-latest`.
- **Detailed Documentation**: Comprehensive guides covering [CLI Reference](docs/CLI-Reference.md), [Launcher & Install](docs/Launcher-and-Install.md), [Agent Skill Guide](docs/Agent-Skill-Guide.md), [Uninstallation Guide](docs/Uninstallation-Guide.md), [Troubleshooting & Compatibility](docs/Troubleshooting-and-Compatibility.md), sample reports in [docs/examples/](docs/examples/), [SECURITY.md](SECURITY.md), [CONTRIBUTING.md](CONTRIBUTING.md), [CHANGELOG.md](CHANGELOG.md), [LICENSE](LICENSE), and [NOTICE](NOTICE).

### Planned (Not Yet Implemented)
- **GUI Thin Wrapper**: Evaluated in [docs/gui-evaluation.md](docs/gui-evaluation.md); deferred to future milestone Stage E+.
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

### Using the Safe Menu Launcher (Recommended for Nontechnical Users)
Run from Command Prompt or PowerShell:
```cmd
.\ClaudeCleanupLauncher.cmd
```
The menu allows running read-only audits, generating cleanup plans, viewing local reports, and verifying system state without command-line flags.

### Using the PowerShell CLI Directly
Run from the repository root:
```powershell
.\ClaudeCleanup.ps1 -Help
.\ClaudeCleanup.ps1 -Audit
.\ClaudeCleanup.ps1 -Plan
```
Review `AUDIT.md` (if saved) and the generated `CLEANUP-PLAN.md` plus its SHA-256 hash before previewing any deletion.

## 8. CLI Command Reference

See [CLI Command Reference](docs/CLI-Reference.md) for full syntax and JSON schema details.

| Command | Purpose | Writes to Disk |
| :--- | :--- | :--- |
| `.\ClaudeCleanup.ps1 -Help` | Show usage and safety boundaries | None |
| `.\ClaudeCleanup.ps1 -Audit [-OutputFormat Text\|Json]` | Read-only environment, ACL/AppData diagnostics, and candidate inventory | None |
| `.\ClaudeCleanup.ps1 -Plan [-OutputFormat Text\|Json]` | Generate `CLEANUP-PLAN.md` (`SchemaVersion = 3`) | `CLEANUP-PLAN.md` only |
| `.\ClaudeCleanup.ps1 -Plan -WhatIf` | Preview plan generation without writing | None |
| `.\ClaudeCleanup.ps1 -Apply -Policy <Policy> -ApprovedManifestSha256 <64-hex> [-OutputFormat Text\|Json] -WhatIf` | Dry-run preview of authorized targets | None |
| `.\ClaudeCleanup.ps1 -Apply -Policy <Policy> -ApprovedManifestSha256 <64-hex> [-OutputFormat Text\|Json]` | Execute approved `Ready` targets after confirmation | Deletes approved targets + updates `VERIFICATION.md` ledger |
| `.\ClaudeCleanup.ps1 -Verify [-OutputFormat Text\|Json]` | Inspect current state vs. `CLEANUP-PLAN.md` and `VERIFICATION.md` | None |

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

## 17. Windows Launcher and GUI Evaluation

- **Console Menu Launcher**: [ClaudeCleanupLauncher.cmd](ClaudeCleanupLauncher.cmd) and [scripts/ClaudeCleanupLauncher.ps1](scripts/ClaudeCleanupLauncher.ps1) provide an interactive text menu for nontechnical users (see [Launcher & Install Guide](docs/Launcher-and-Install.md)).
- **GUI Thin Wrapper Evaluation**: Feasibility of an optional future WPF/XAML thin wrapper is documented in [docs/gui-evaluation.md](docs/gui-evaluation.md). Implementation is deferred to future milestone Stage E+ to keep dependencies minimal.

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
