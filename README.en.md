[简体中文](README.md) | English | [Cross-Agent Skill Guide](docs/Skills-Usage-Guide.en.md) | [技能实战指南 (中文)](docs/Skills-Usage-Guide.md)

# claude-cleanup (`Claude Residual ID Cleaner`)

**claude-cleanup** (desktop application: **Claude Residual ID Cleaner / Claude 账号残余 ID 清理工具**) is a non-destructive Windows standalone desktop application (`Claude-Residual-ID-Cleaner.exe`) and native PowerShell toolkit designed specifically to scan and safely clean residual account/device IDs, auth tokens, and session caches left behind after a Claude account ban across Claude Code CLI, Claude Desktop, VS Code/Cursor extensions, Windows Credential Manager, and environment variables — **strictly without altering or harming Windows OS itself**.

![Claude Residual ID Cleaner Desktop Studio (zh-CN)](docs/images/ui-main-zh.png)

---

## 1. Core Positioning and Safety Boundaries

- **Focused Post-Ban Residual Cleanup**: Inventories and safely removes confirmed local Claude Code, Claude Desktop, editor extension, shortcut, and user-level registry leftovers on Windows without manual guesswork.
- **100% Read-Only by Default**: Opening the desktop app, launching the console menu, or running `-Audit` never modifies disk files or registry keys.
- **Strict Windows OS Protection**: Never touches `C:\Windows`, Program Files, OS registry hives, system hardware/device IDs (`MachineGuid`), WSL distributions, browser user profiles (Edge/Chrome), or unrelated software.
- **Single Verified Engine**: All filesystem discovery, path validation, Win32 handle-bound deletion, registry cleanup, and ledger verification live strictly inside [ClaudeCleanup.ps1](ClaudeCleanup.ps1). The standalone `.exe`, script GUI, console launcher, and cross-agent Skill delegate exclusively to `ClaudeCleanup.ps1` with zero duplicated deletion code.
- **Fail-Closed & No Unsafe Fallbacks**: Never falls back to path-based `Remove-Item` or `RegDeleteKeyW`, never auto-elevates via UAC, and creates no automatic backups or recycle-bin copies. Real `-Apply` execution always requires reviewing `CLEANUP-PLAN.md` (`SchemaVersion = 3`), specifying an explicit policy and exact 64-hex SHA-256 manifest hash, and explicit human confirmation.

> **Current Release Status**: Release Candidate (Stages A–I implemented and validated across Windows PowerShell 5.1 and PowerShell 7+). All automated tests run inside isolated `tests/sandbox/` fixtures; no live user Claude data has been modified without explicit authorization, and local cleanup never alters remote server-side account state.

---

## 2. Feature Modules and Cleanup Scope

### 2.1 Discovery & Allowlisted Targets

| Module | Inspected Scope | Policy & Protection Behavior |
| :--- | :--- | :--- |
| **Claude Code CLI Config & Account/Device IDs** | `%USERPROFILE%\.claude`, `%USERPROFILE%\.claude.json`, `%USERPROFILE%\.local\bin\claude.exe`, `%USERPROFILE%\.local\share\claude`, global npm `@anthropic-ai/claude-code` | `AccountData` clears confirmed auth/cache/diagnostics while keeping `.claude` skills and configs; `FullRemoval` removes verified user-owned leftovers (`buddy-tokens.json` defaults to `ReviewOnly`) |
| **Claude Desktop Data & MSIX Package** | `%APPDATA%\Claude`, `%LOCALAPPDATA%\Claude`, MSIX package `Claude_pzs8sxrjxfjjc` (`Remove-AppxPackage` in `FullRemoval` only) | `AccountData` clears caches/logs while preserving `Local Storage` / `IndexedDB`; MSIX external junctions remain `Blocked` or `ReviewOnly` |
| **IDE Extensions & Browser Host Keys** | VS Code / Cursor / Windsurf extension `anthropic.claude-code` plus `globalStorage` / `workspaceStorage` Claude leftovers; `HKCU` Chrome/Edge Native Messaging (`com.anthropic.claude_browser_extension` only) | Managed under approved `FullRemoval` only; non-user ownership or unexpected subkeys fail closed as `Blocked` |
| **Windows Credential Manager** | Searches matching Claude / Anthropic Credential Manager targets | **Strictly Read-Only Audit**: Reports matching target count only; **never reads or deletes secrets** |
| **User Environment Variables & PATH** | Inspects `ANTHROPIC_*` / `CLAUDE_*` variable names and `.local\bin` entries in user `PATH` | **Names Only**: Never reads or prints variable values such as API keys |
| **Shortcuts, ACLs & WSL Read-Only Diagnostics** | Start Menu/Desktop/Startup `.lnk` shortcuts, subtree `OwnerSid`, reparse points (junctions/symlinks), and WSL distribution status | Non-current-user ownership (`BUILTIN\Administrators`) is `Blocked`; WSL distros are reported read-only and never modified |

### 2.2 `AccountData` vs. `FullRemoval` Policies

| Dimension | `AccountData` | `FullRemoval` |
| :--- | :--- | :--- |
| **Target Scope** | Confirmed Claude credential files, account/app caches, and diagnostic logs | Confirmed user-level Claude Code installs/configs, Desktop Roaming/Local data, VS Code extensions, MSIX package, and HKCU browser host keys |
| **User Content & History** | Preserved (keeps `.claude` skills/sessions, `.claude.json`, and Desktop `Local Storage` / `IndexedDB`) | Eligible `Ready` paths removed cleanly once verified (`Claude-3p`, `pivot.claude.ai`, `.obsolete` stay protected) |
| **Blocked Parent Fallback** | Not applicable | If a parent folder is `Blocked` or `ReviewOnly`, non-overlapping safe `Ready` children are promoted individually |

### 2.3 Three-State Presence & Eligibility

- **Three-State Presence**: Every target is classified as `Present`, `Absent`, or `Unknown` (access denied, IO errors, or environment failures never degrade to `Absent` or `VerifiedAbsent`).
- **Decision Gate**: Targets become `Ready` only when allowlisted, non-protected, reparse-free, and 100% owned by the current user SID (`OwnerSid`); otherwise they remain `ReviewOnly` or `Blocked`.

---

## 3. Standalone Desktop App (`.exe`) and CLI Usage

### 3.1 System Requirements

- **OS**: Windows 10 (64-bit, Build 19041+) or Windows 11 (64-bit, Build 22000+) on a local NTFS volume.
- **PowerShell**: Full compatibility with **Windows PowerShell 5.1** (`powershell.exe`, built into Windows) and **PowerShell 7+** (`pwsh.exe`).
- **Dependencies**: Zero third-party PowerShell modules, external binaries, Git, or REA runtime dependencies.

### 3.2 Option 1: Standalone Windows Desktop App (`Claude-Residual-ID-Cleaner.exe`, Zero Console Window)

#### Download & Double-Click Launch (GitHub Releases / GitHub Actions Artifacts)

End users do not need to install compilers or manually run build scripts:

1. Open the repository's **GitHub Releases** page or the **Artifacts** section at the bottom of the latest **GitHub Actions** CI run:
   - **Full Release Bundle (Recommended)**: Download `claude-cleanup-release-bundle` (contains `claude-cleanup-<Version>.zip` and `SHA256SUMS.txt`). `claude-cleanup-<Version>.zip` bundles `Claude-Residual-ID-Cleaner.exe` directly at the archive root alongside `ClaudeCleanup.ps1`.
   - **Standalone Executable Artifact**: Alternatively download `claude-residual-id-cleaner-exe` (`Claude-Residual-ID-Cleaner.exe`) and place it in a toolkit folder (or `dist\`) alongside `ClaudeCleanup.ps1`.
2. Verify the archive SHA-256 digest (optional, recommended):
   ```powershell
   Get-FileHash .\claude-cleanup-0.1.0.zip -Algorithm SHA256
   ```
3. Extract `claude-cleanup-<Version>.zip` and **double-click `Claude-Residual-ID-Cleaner.exe`** to open the native WPF desktop studio with zero console window.

#### Build & Package Offline From Source

Source files under [src/Gui/](src/Gui/) compile offline with Windows' built-in `.NET Framework 4.x` C# compiler (`csc.exe`) into a single native WPF GUI executable (`IMAGE_SUBSYSTEM_WINDOWS_GUI`):

```powershell
# 1. Build standalone executable offline -> .\dist\Claude-Residual-ID-Cleaner.exe
.\scripts\Build-DesktopApp.ps1

# 2. Launch the desktop app
.\dist\Claude-Residual-ID-Cleaner.exe

# 3. (Optional) Create release ZIP bundling Claude-Residual-ID-Cleaner.exe at archive root + SHA256SUMS.txt
.\scripts\New-ReleasePackage.ps1
```

#### Desktop Studio Workflow & Preview

![Claude Residual ID Cleaner Demo Scan Results (zh-CN)](docs/images/ui-scan-results-zh.png)

Guided four-step UI workflow:
1. **Configure Scopes & Policy**: Check any of the 5 residual categories and choose `AccountData` or `FullRemoval`.
2. **`1. Scan Residuals`**: Runs read-only `ClaudeCleanup.ps1 -Audit -OutputFormat Json` and populates the status DataGrid.
3. **`2. Preview Plan`**: Generates `CLEANUP-PLAN.md` with deterministic SHA-256 digest; `3. Clean Selected` remains disabled until valid `Ready` items exist.
4. **`3. Clean Selected` & `4. Verify Clean`**: Displays an explicit confirmation dialog listing exact paths, policy, and manifest SHA-256 before running `ClaudeCleanup.ps1 -Apply`, followed by ledger verification (`VERIFICATION.md`), folder shortcut, and sanitized `AUDIT.md` export.

> Prefer zero compilation? Double-click [ClaudeCleanupGUI.cmd](ClaudeCleanupGUI.cmd) to run the companion native WinForms desktop wrapper ([scripts/ClaudeCleanupGUI.ps1](scripts/ClaudeCleanupGUI.ps1)). You can also regenerate these non-destructive `--demo-audit --capture-png` screenshots locally via [scripts/Capture-UiScreenshots.ps1](scripts/Capture-UiScreenshots.ps1).

### 3.3 Option 2: Bilingual Console Menu Launcher

Launch the interactive text menu from Command Prompt or PowerShell:

```cmd
.\ClaudeCleanupLauncher.cmd
```

Supports interactive `Audit`, `Plan`, `View Reports`, `Verify`, `Help`, `[6] Launch GUI`, and `[L] Switch Lang` without `-ExecutionPolicy Bypass`, without auto-elevation, and without one-click destructive `-Apply`. See [Launcher & Install Guide](docs/Launcher-and-Install.md).

### 3.4 Option 3: PowerShell CLI Reference

Full flag and JSON contract documentation is available in [CLI Reference](docs/CLI-Reference.md).

| Command | Purpose | Disk Write Behavior |
| :--- | :--- | :--- |
| `.\ClaudeCleanup.ps1 -Help [-Language Auto\|zh-CN\|en-US]` | Display usage and safety guarantees | None |
| `.\ClaudeCleanup.ps1 -Audit [-Language Auto\|zh-CN\|en-US] [-OutputFormat Text\|Json] [-SaveAuditReport]` | Read-only system audit, ACL/AppData classification, and candidate discovery | None (writes `AUDIT.md` only with `-SaveAuditReport`) |
| `.\ClaudeCleanup.ps1 -Plan [-Language Auto\|zh-CN\|en-US] [-OutputFormat Text\|Json]` | Generate `CLEANUP-PLAN.md` (`SchemaVersion = 3`) with GUID `PlanId` and SHA-256 | Writes `CLEANUP-PLAN.md` |
| `.\ClaudeCleanup.ps1 -Plan -WhatIf` | Preview plan item counts without writing to disk | None |
| `.\ClaudeCleanup.ps1 -Apply -Policy <Policy> -ApprovedManifestSha256 <64-hex> -WhatIf` | Dry-run preview of approved cleanup targets without consuming manifest hash | None |
| `.\ClaudeCleanup.ps1 -Apply -Policy <Policy> -ApprovedManifestSha256 <64-hex> [-OutputFormat Text\|Json]` | Execute approved `Ready` items after `ConfirmImpact = 'High'` confirmation | Deletes approved targets; updates `VERIFICATION.md` atomically |
| `.\ClaudeCleanup.ps1 -Verify [-Language Auto\|zh-CN\|en-US] [-OutputFormat Text\|Json]` | Read-only verification of current three-state status and replay ledger | None |

### 3.5 Option 4: User-Scoped Lifecycle Scripts & Cross-Agent Skill

- **User-Scoped Install / Update / Uninstall** (deploys to `%LOCALAPPDATA%\Programs\claude-cleanup` with SHA-256 managed manifests without touching system `PATH`, Start Menu shortcuts, or registry keys):
  ```powershell
  powershell.exe -NoProfile -File .\scripts\Install-ClaudeCleanup.ps1
  powershell.exe -NoProfile -File .\scripts\Update-ClaudeCleanup.ps1
  powershell.exe -NoProfile -File .\scripts\Uninstall-ClaudeCleanup.ps1
  ```
- **Cross-Agent Skill ([skills/claude-cleanup/](skills/claude-cleanup/))**: Supports Antigravity (`~/.gemini/config/skills/`), Codex CLI (`~/.codex/skills/` or `~/.agents/skills/`), Gemini CLI (`~/.gemini/skills/`), and Claude Code (`~/.claude/skills/`). **For full installation steps, activation behavior, and copy-pasteable prompts, see the [Cross-Agent Skill Usage Guide](docs/Skills-Usage-Guide.en.md)** ([简体中文技能实战指南](docs/Skills-Usage-Guide.md)), plus [SKILL.md](skills/claude-cleanup/SKILL.md), [agent-installation.md](skills/claude-cleanup/references/agent-installation.md), and [Agent Skill Guide](docs/Agent-Skill-Guide.md).

---

## 4. Live Bilingual Switching (`zh-CN` / `en-US`)

- **Standalone WPF Desktop `.exe` & WinForms GUI**: Automatically detects Chinese Windows locales (`zh-CN` default) and provides a one-click **`中文 / English`** toggle in the top header that immediately translates labels, scope descriptions, column headers, safety badges, status messages, and confirmation dialogs without restarting.
- **CLI & Console Launcher**: Supports `-Language Auto|zh-CN|en-US`; configures UTF-8 console output cleanly on both PowerShell 5.1 and 7+.
- **Localized Reports with Invariant JSON Keys**: `AUDIT.md`, `CLEANUP-PLAN.md`, and `VERIFICATION.md` adapt headings and explanations cleanly while `-OutputFormat Json` (`SchemaVersion = 3`) preserves invariant English schema keys across every locale.

![Claude Residual ID Cleaner Desktop Studio (en-US)](docs/images/ui-main-en.png)

---

## 5. Security Architecture, Verification, and License

### 5.1 Defense-in-Depth Safeguards

See [SECURITY.md](SECURITY.md) for the complete threat model:

1. **Handle-Bound Win32 Deletion (`ClaudeCleanup.NativeFs`)**: Opens handles with `FILE_FLAG_OPEN_REPARSE_POINT | FILE_FLAG_BACKUP_SEMANTICS`, verifies `GetFinalPathNameByHandleW`, `GetFileInformationByHandle` (`VolumeSerialNumber` / `FileIndex`), and subtree `OwnerSid` via `GetSecurityInfo`, then deletes on the open handle via `SetFileInformationByHandle` (`FileDispositionInfoEx` / `FileDispositionInfo`). Zero `Remove-Item` fallback.
2. **Reparse-Point & Protected-Path Blocks**: Ancestor and subtree junctions, symbolic links, and dangling links fail closed. Drive roots, `WINDIR`, `ProgramFiles`, `.codex`, `.agents`, `.gemini`, the toolkit root, and exact user roots are permanently protected.
3. **Open-Handle Registry Deletion**: Inspects ancestors with `REG_OPTION_OPEN_LINK` (rejects `REG_LINK`), enforces zero subkeys and allowlisted HKCU browser host keys only, and deletes via `ntdll!NtDeleteKey`.
4. **Single-Read Manifest & Atomic Replay Guard**: `CLEANUP-PLAN.md` is read once into memory (`ReadAllBytes`) to verify SHA-256 and parse its single `SchemaVersion = 3` JSON manifest; `VERIFICATION.md` uses temp-file + `Flush($true)` + atomic `File.Replace`/`Move`, refusing corrupted/truncated ledgers and forbidding SHA-256 replay.
5. **Local-Only Privacy**: Zero network calls or telemetry. Redacted examples live in [AUDIT.sample.md](docs/examples/AUDIT.sample.md), [CLEANUP-PLAN.sample.md](docs/examples/CLEANUP-PLAN.sample.md), and [VERIFICATION.sample.md](docs/examples/VERIFICATION.sample.md). Local reports, secrets, and sandbox directories are strictly ignored by [.gitignore](.gitignore) and blocked by [New-ReleasePackage.ps1](scripts/New-ReleasePackage.ps1).

### 5.2 Automated Test Suites

All test fixtures are created strictly inside `tests/sandbox/` and cleaned in `finally` blocks without touching live Claude folders or live HKCU keys. Run sequentially under both Windows PowerShell 5.1 and PowerShell 7+ (CI definition: [.github/workflows/ci.yml](.github/workflows/ci.yml)):

```powershell
powershell.exe -NoProfile -File .\tests\ClaudeCleanup.Tests.ps1
powershell.exe -NoProfile -File .\tests\SkillPackage.Tests.ps1
powershell.exe -NoProfile -File .\tests\ToolkitInstall.Tests.ps1
powershell.exe -NoProfile -File .\tests\ToolkitCiChecks.Tests.ps1
powershell.exe -NoProfile -File .\tests\BilingualAndGui.Tests.ps1
powershell.exe -NoProfile -File .\tests\DesktopApp.Tests.ps1
```

> Privileged symlink cases skip (`SKIP`) when `SeCreateSymbolicLinkPrivilege` or reparse creation is unavailable, and live registry/npm/VS Code/AppX/cross-SID tests are explicitly reported as `NotExecuted` — neither is ever counted as `Passed`.

### 5.3 Troubleshooting, Uninstallation, and Contributing

- **Troubleshooting**: [Troubleshooting & Compatibility Guide](docs/Troubleshooting-and-Compatibility.md)
- **Uninstalling Claude or the Toolkit**: [Uninstallation Guide](docs/Uninstallation-Guide.md) (uninstalling this toolkit never uninstalls Claude)
- **Contributing & Architecture**: [CONTRIBUTING.md](CONTRIBUTING.md), [CHANGELOG.md](CHANGELOG.md), and [docs/gui-evaluation.md](docs/gui-evaluation.md)

### 5.4 License and Attribution

- **License**: Released under the [MIT License](LICENSE).
- **Notice**: See [NOTICE](NOTICE). Conceptually inspired by the macOS shell script project [suyuan2022/claude-cleanup](https://github.com/suyuan2022/suyuan-skill/tree/main/claude-cleanup); implemented completely clean-room for Windows (automatic backup, trash-move, and device-identity rotation features were intentionally **not** ported). Not affiliated with Anthropic PBC.
