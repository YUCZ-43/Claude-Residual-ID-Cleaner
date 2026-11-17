# Permissions, Policies, and Risk Boundaries

This reference describes the security controls, policy scopes, privilege rules, and non-goals enforced by `ClaudeCleanup.ps1` and required when operating the [claude-cleanup skill](../SKILL.md).

---

## 1. Policy Scopes (`AccountData` vs. `FullRemoval`)

| Aspect | `AccountData` | `FullRemoval` |
| :--- | :--- | :--- |
| **Target Scope** | Confirmed CLI credentials/auth cache, app caches, and diagnostic logs | Confirmed user-level Claude Code installs/configs, Desktop Roaming/Local data, VS Code extensions, MSIX package, and Chrome/Edge Native Messaging HKCU keys |
| **User Creations & Mixed Data** | Preserved (`.claude` skills/sessions, `.claude.json`, Desktop `Local Storage` / `IndexedDB` stay untouched) | Eligible when safe & `Ready` (deletes skills, plugins, MCP configs, sessions, and Cowork data) |
| **Ambiguous / Shared Items** | `buddy-tokens.json` stays `ReviewOnly` | `Claude-3p`, `pivot.claude.ai`, `.obsolete`, and MSIX `Packages\Claude_pzs8sxrjxfjjc` stay `ReviewOnly` or `Blocked` |
| **Parent-Blocked Fallback** | N/A | When a parent root (`.claude`, `%APPDATA%\Claude`) is `Blocked` or `ReviewOnly`, non-overlapping `Ready` children are evaluated separately |

### Important Limitations
- **No Backup or Rollback**: Deletions are permanent. Close running `claude` and `Code` processes before executing `-Apply`.
- **No Remote Account Effect**: Local cleanup only affects files, registry keys, and packages on the local Windows machine; it never alters server-side Claude account state.
- **Mixed Storage**: `AccountData` may leave login traces inside Desktop mixed storage (`Local Storage` / `IndexedDB`).

---

## 2. Security & Fail-Closed Invariants in `ClaudeCleanup.ps1`

The skill relies exclusively on `ClaudeCleanup.ps1` rather than reimplementing filesystem, registry, or package removal:

1. **Handle-Bound Filesystem Deletion**:
   - Targets are opened with `FILE_FLAG_OPEN_REPARSE_POINT | FILE_FLAG_BACKUP_SEMANTICS` (exclusive `FILE_SHARE_NONE` for files; `FILE_SHARE_READ | FILE_SHARE_WRITE` without `FILE_SHARE_DELETE` for directories).
   - Handles are verified via `GetFinalPathNameByHandleW`, `GetFileInformationByHandle` (`VolumeSerialNumber`, `FileIndex`, `MaxLastWriteUtcTicks`), and `GetSecurityInfo` (`OwnerSid`), then unlinked via `SetFileInformationByHandle` (`FileDispositionInfoEx` / `FileDispositionInfo`) with **zero `Remove-Item` fallback**.
   - Any junction, symbolic link, or dangling reparse point along ancestors or inside a directory tree blocks deletion (`ReparseBlocked` / `Blocked`).
   - Every node in a directory tree must be owned by the current user SID; mixed-ownership or `BUILTIN\Administrators`-owned trees remain `Blocked`.
2. **Protected Paths**:
   - Drive roots, `WINDIR`, `ProgramFiles`, `ProgramFiles(x86)`, `.codex`, `.agents`, `.gemini`, the toolkit project directory, and exact user roots (`USERPROFILE`, `APPDATA`, `LOCALAPPDATA`, `ProgramData`, `PUBLIC`, `TEMP`, `TMP`) are unconditionally rejected.
3. **Object-Bound Registry Deletion**:
   - Only exact HKCU Chrome/Edge `NativeMessagingHosts\com.anthropic.claude_browser_extension` keys are eligible.
   - Ancestors and target keys are checked against `REG_LINK`, subkey count must be `0`, `(Default)` must match the planned identity, and deletion uses `ntdll!NtDeleteKey` on the validated open handle (never `RegDeleteKeyW`).
4. **Scoped External Package Uninstallers (`FullRemoval` Only)**:
   - `Invoke-NpmClaudeUninstall`: scoped exclusively to `@anthropic-ai/claude-code` (preserves Node.js, npm, and unrelated global packages).
   - `Invoke-VsCodeExtensionUninstall`: scoped exclusively to `anthropic.claude-code` via `code --uninstall-extension`.
   - `Invoke-ClaudeAppxUninstall`: delegates MSIX removal (`Claude_pzs8sxrjxfjjc`) to Windows `Remove-AppxPackage` and never direct-deletes `WindowsApps` or `<Drive>:\WpSystem` junctions.
   - All uninstallers verify post-removal absence and fail closed if the package remains `Present`.
5. **Single-Read Manifest & Atomic Replay Guard**:
   - `-Plan` writes `CLEANUP-PLAN.md` (`SchemaVersion = 3`) with a unique `PlanId` (GUID) and SHA-256 hash.
   - `-Apply` reads `CLEANUP-PLAN.md` once into memory, verifies the exact 64-hex `-ApprovedManifestSha256` and single JSON block, and atomically records execution outcomes in `VERIFICATION.md` (`Flush($true)` + `File.Replace` / `Move`).
   - Each manifest SHA-256 can be consumed at most once across real `-Apply` runs (`-WhatIf` previews do not consume it).
6. **3-State Presence Model**:
   - `-Verify` and post-checks distinguish `Present`, `Absent`, and `Unknown`. Access errors return `Unknown` and never produce `VerifiedAbsent = $true`.

---

## 3. ExecutionPolicy and Privilege Guidance

- **Never Use `-ExecutionPolicy Bypass`**:
  - Do not run or suggest `powershell.exe -ExecutionPolicy Bypass` (or `Unrestricted`).
  - If script execution is blocked, inspect `Get-ExecutionPolicy -List`, review `ClaudeCleanup.ps1` locally, and use standard Windows trust controls (for example, `Unblock-File -LiteralPath .\ClaudeCleanup.ps1` after review, or user-scoped `RemoteSigned` policy).
- **No Auto-Elevation**:
  - Run as the standard non-elevated Windows user by default.
  - Do not automatically elevate via UAC, modify Windows ACLs, or take ownership (`takeown` / `icacls`). Paths owned by `BUILTIN\Administrators` stay `Blocked` intentionally unless managed separately by the user outside this toolkit.

---

## 4. Privacy, WSL, and Development Tooling Boundaries

- **Credential Manager**: `-Audit` reports target name counts matching Claude patterns only; secret values are never read or deleted.
- **Environment Variables**: `-Audit` and `-OutputFormat Json` emit variable `Scope` and `Name` only; secret values are omitted.
- **WSL Isolation**: Running WSL distributions and Linux-side `~/.claude` paths are reported read-only and never modified.
- **Anti-Abuse Non-Goal**: Never modify device IDs, proxies, telemetry, or remote enforcement controls.
- **REA Policy**: REA (Reverse Engineer Anything) is strictly an optional development-time static-analysis tool and is **never** a runtime dependency for `ClaudeCleanup.ps1` or this skill.
