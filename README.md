**English** | [简体中文](README_zh-CN.md)

# Windows Claude Cleanup Toolkit

A native Windows PowerShell utility for **read-only auditing**, **cryptographically bound planning**, and **user-authorized local cleanup** of Claude Code and Claude Desktop artifacts.

---

## 1. Project Overview

Windows Claude Cleanup inspects known local installations, configurations, caches, logs, VS Code extensions, MSIX packages, and browser Native Messaging registrations associated with Claude Code and Claude Desktop on Windows. It separates read-only discovery (`-Audit`), manifest generation (`-Plan`), previewable/confirmed execution (`-Apply`), and independent post-action checking (`-Verify`), without modifying device IDs, proxies, telemetry, browser profiles, or WSL distributions.

## 2. Current Release Status

- **Stage**: Pre-release / Active Security Hardening (P0 security remediation completed and undergoing acceptance review).
- **Real Cleanup Status**: No real Claude data cleanup has been authorized or executed during development.
- **Repository Visibility**: Private development repository (`main` branch).

## 3. Features and Limitations

### Implemented Capabilities
- Read-only system audit (`-Audit`) across Claude Code CLI, Claude Desktop, VS Code extensions, MSIX packages, Windows services/scheduled tasks, environment variables, `PATH`, Credential Manager target counts (no secret values read), and read-only WSL reporting.
- Deterministic `SchemaVersion = 3` cleanup plan (`-Plan`) outputting `CLEANUP-PLAN.md` with per-entry `Ready` / `ReviewOnly` / `Blocked` decisions, NTFS `VolumeSerialNumber` / `FileIndex`, and subtree `MaxLastWriteUtcTicks`.
- Win32 handle-bound filesystem deletion (`SetFileInformationByHandle`) with strict reparse-point rejection, child ownership enforcement, single-read SHA-256 verification, and atomic execution-ledger replay protection.
- Structured failure reporting (`Removed`, `AlreadyAbsent`, `Skipped`, `Blocked`, `Failed`, `NotExecuted`, `PartialRemoval`, `PresenceState`: `Present` / `Absent` / `Unknown`).

### Planned (Not Yet Implemented)
- Extended Windows coverage (ACL diagnostics, `code --uninstall-extension` integration, npm prefix resolution, ambiguous folder attribution).
- Cross-agent Skill (`claude-cleanup`) for Codex CLI, Antigravity CLI, Gemini CLI, and Claude Code.
- Nontechnical Windows launcher, user-scoped installer/uninstaller, CI workflows, and optional GUI evaluation.

## 4. Supported Windows Versions

- Windows 10 (64-bit)
- Windows 11 (64-bit)
- Designed primarily for local NTFS volumes (non-NTFS/network volumes fail closed when handle identity primitives are unsupported).

## 5. PowerShell Compatibility

- **Windows PowerShell 5.1** (`powershell.exe`, tested on 5.1.26100.x)
- **PowerShell 7+** (`pwsh.exe`, tested on 7.6.x)
- Embedded C# 5 P/Invoke layer (`ClaudeCleanup.NativeFs`) compiles at load time on both .NET Framework 4.x and modern .NET.

## 6. Installation Instructions

1. Clone or download this repository to a local folder (for example, `C:\Users\<USERNAME>\Tools\Windows-Claude-Cleanup`).
2. Review `ClaudeCleanup.ps1` before running.
3. No external modules, AI agents, Git, or REA runtime dependencies are required.
4. *(Planned)* A dedicated user-scoped `Install-ClaudeCleanup.ps1` will be added in a later phase.

## 7. Quick Start

Run from the repository root in PowerShell:

```powershell
.\ClaudeCleanup.ps1 -Help
.\ClaudeCleanup.ps1 -Audit
.\ClaudeCleanup.ps1 -Plan
```

Review `AUDIT.md` (if saved) and the generated `CLEANUP-PLAN.md` plus its SHA-256 hash before previewing any action.

## 8. CLI Command Reference

| Command | Purpose | Writes to Disk |
| :--- | :--- | :--- |
| `.\ClaudeCleanup.ps1 -Help` | Show usage and safety boundaries | None |
| `.\ClaudeCleanup.ps1 -Audit` | Read-only environment & candidate inventory | None |
| `.\ClaudeCleanup.ps1 -Plan` | Generate `CLEANUP-PLAN.md` (`SchemaVersion = 3`) | `CLEANUP-PLAN.md` only |
| `.\ClaudeCleanup.ps1 -Plan -WhatIf` | Preview plan generation without writing | None |
| `.\ClaudeCleanup.ps1 -Apply -Policy <Policy> -ApprovedManifestSha256 <64-hex> -WhatIf` | Dry-run preview of authorized targets | None |
| `.\ClaudeCleanup.ps1 -Apply -Policy <Policy> -ApprovedManifestSha256 <64-hex>` | Execute approved `Ready` targets after confirmation | Deletes approved targets + updates `VERIFICATION.md` ledger |
| `.\ClaudeCleanup.ps1 -Verify` | Inspect current state vs. `CLEANUP-PLAN.md` and `VERIFICATION.md` | None |

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

## 13. Troubleshooting

- **`Unsupported manifest schema version (SchemaVersion 3 required)`**: Re-run `.\ClaudeCleanup.ps1 -Plan` to generate a new `SchemaVersion = 3` manifest and use its new SHA-256.
- **`Target is not owned by the current user` (`BUILTIN\Administrators`)**: Files created during elevated sessions may be owned by Administrators. This version intentionally blocks them rather than modifying ACLs or taking ownership.
- **Access errors during `-Audit` / `-Verify` in restricted shells**: Restricted environments block queries and cause targets to appear as `Blocked` or `Unknown` (never falsely reported as `Absent`).
- **ExecutionPolicy errors**: Avoid bypassing policy blindly; inspect `Get-ExecutionPolicy -List` and ensure you review local scripts before unblocking files you downloaded.

## 14. Testing and Verification

Tests create and clean up isolated fixtures **only** inside `tests/sandbox/` (and never write to real Claude data or real HKCU registry keys):

```powershell
powershell.exe -NoProfile -File .\tests\ClaudeCleanup.Tests.ps1
pwsh.exe -NoProfile -File .\tests\ClaudeCleanup.Tests.ps1
```

- Covers path boundaries, ADS/trailing-dot/space rejection, no `Remove-Item` / `CheckOwner $false` / `RegDeleteKeyW` invariants, 3-state `Present` / `Absent` / `Unknown` detection, junctions, dangling junctions, parent-path substitution, conditional symlink tests, nested same-size tampering (`MaxLastWriteUtcTicks`), `FileIndex` swap detection, manifest tampering, replay blocking, atomic ledger corruption recovery, mocked registry verification, and partial-failure reporting.
- **Permission Note**: Creating Windows symbolic links requires Administrator or Developer Mode privileges (`SeCreateSymbolicLinkPrivilege`); unprivileged sessions explicitly report those symlink creation cases as `SKIP` (and restricted app-container sandboxes may also block `FSCTL_SET_REPARSE_POINT` junction creation). Live HKCU write/delete and cross-SID mixed-ownership disk tests are explicitly reported as `NotExecuted` when restricted by authorization.

## 15. Known Issues and Unsupported Operations

- **MSIX Data Junctions**: `%LOCALAPPDATA%\Packages\Claude_pzs8sxrjxfjjc` contains junctions (for example, pointing to `<Drive>:\WpSystem`); never delete directly. Authorized MSIX removal delegates to `Remove-AppxPackage`, which may remove package-managed data and `CoworkVMService`.
- **Win32 Handle Pre-Open Window & Hardlinks**: User-mode path resolution still occurs in the brief instant before `CreateFileW` opens the root/child handle; `SetFileInformationByHandle` unlinks only the addressed directory entry and does not remove external NTFS hardlinks.
- **Non-Filesystem OS APIs**: `AppxPackage` removal relies on Windows AppX deployment services.
- **WSL Isolation**: WSL distributions (and Linux-side `~/.claude` files) are reported read-only when running and are never modified.
- **Not Supported**: Device-identity spoofing, anti-abuse bypasses, Credential Manager secret removal, and automatic ACL/ownership changes.

## 16. Planned Agent Skills Integration *(Planned)*

A cross-agent `claude-cleanup` skill (compatible with Codex CLI, Antigravity CLI, Gemini CLI, and Claude Code) is planned for a future phase after backend Windows coverage is finalized. It will strictly wrap `ClaudeCleanup.ps1`, default to read-only `-Audit`, never auto-invoke `-Apply`, and keep REA purely as an optional development-time tool.

## 17. Planned Windows Launcher and GUI *(Planned)*

A simple Windows launcher (`ClaudeCleanupLauncher.cmd` + menu script for Audit / Plan / View Reports / Verify / Help / Exit, without ExecutionPolicy bypass or auto-elevation) and a future optional GUI evaluation are planned for later phases. Neither is implemented in the current release.

## 18. How to Uninstall Claude

This utility does **not** automatically uninstall Claude without your explicit plan approval. Currently:
- User-level `claude.exe` and `.local\share\claude` / Desktop MSIX / VS Code extensions are inventoried under `FullRemoval` (items owned by `BUILTIN\Administrators` remain `Blocked`).
- For MSIX Claude Desktop, you can also uninstall via Windows **Settings → Apps → Installed apps** or approved `FullRemoval` (`Remove-AppxPackage`).
- Removing this cleanup toolkit does **not** uninstall Claude.

## 19. How to Uninstall the Toolkit

- Current installation is portable: simply delete the cloned/downloaded repository folder (for example, `Windows-Claude-Cleanup`).
- *(Planned)* Future phases will provide separate user-scoped `Uninstall-ClaudeCleanup.ps1` workflows for removing the toolkit and removing optional Agent Skill integrations independently.

## 20. GitHub Development and Contribution Workflow

- Development follows strict staged authorization on `main`: inspect `git status` → minimal scoped edits → Windows PowerShell 5.1 & PowerShell 7 regression checks → `git diff` privacy audit → Conventional Commit.
- Never commit `AUDIT.md`, `CLEANUP-PLAN.md`, `VERIFICATION.md`, `tests/sandbox/`, credentials, SIDs, or local logs.

## 21. License and Attribution Status

- **License**: Pending final selection in the public-release milestone (MIT License recommended; no `LICENSE` file has been finalized or committed yet).
- **Design Attribution**: Inspired conceptually by [suyuan2022/claude-cleanup](https://github.com/suyuan2022/suyuan-skill/tree/main/claude-cleanup) (macOS-oriented upstream; backup, trash, and identity-rotation behaviors were intentionally **not** ported to this Windows utility).
