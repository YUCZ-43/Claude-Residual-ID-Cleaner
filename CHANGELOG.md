# Changelog

All notable changes to the Windows Claude Cleanup Toolkit project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Added
- **Stage H (Desktop `.exe` Upgrade) — Standalone Zero-Console Windows WPF Desktop Application**:
  - Added native .NET Framework 4.x WPF C# desktop app ([src/Gui/Program.cs](src/Gui/Program.cs), [src/Gui/Localization.cs](src/Gui/Localization.cs)) and offline single-file build script ([scripts/Build-DesktopApp.ps1](scripts/Build-DesktopApp.ps1)) producing `dist/Claude-Residual-ID-Cleaner.exe` (`IMAGE_SUBSYSTEM_WINDOWS_GUI`, zero console window).
  - Positioned clearly as *"Claude 账号残余 ID 清理工具 (Claude Residual ID Cleaner) — 专为清理 Claude 封号后残留在设备中的账号/设备 ID、认证 Token 与会话缓存而设计，绝不改动 Windows 系统本身"*.
  - Added CI build + `--headless --self-test` verification in [.github/workflows/ci.yml](.github/workflows/ci.yml) and dedicated [tests/DesktopApp.Tests.ps1](tests/DesktopApp.Tests.ps1).
- **Stage H — Native Desktop GUI, Bilingual Runtime (`zh-CN`/`en-US`), & Post-Ban Residual Positioning**:
  - Added zero-dependency native WinForms Desktop GUI ([ClaudeCleanupGUI.cmd](ClaudeCleanupGUI.cmd) + [scripts/ClaudeCleanupGUI.ps1](scripts/ClaudeCleanupGUI.ps1)) with live **中 / EN** switching, OS-safety badge, 5-category scope checklist, disabled-until-ready cleanup button, explicit `-WhatIf` + SHA-256 confirmation dialog, and report viewer.
  - Added `-Language Auto|zh-CN|en-US` (with Chinese locale auto-detection and UTF-8 console output) plus `-SaveAuditReport` across [ClaudeCleanup.ps1](ClaudeCleanup.ps1), [scripts/ClaudeCleanupLauncher.ps1](scripts/ClaudeCleanupLauncher.ps1) (adding `[6] Launch GUI` & `[L] Switch Lang`), and [Install/Update/Uninstall-ClaudeCleanup.ps1](scripts/Install-ClaudeCleanup.ps1), while keeping JSON schema keys strictly invariant.
  - Added bilingual and GUI validation test suite [tests/BilingualAndGui.Tests.ps1](tests/BilingualAndGui.Tests.ps1).
- **Stage D — Cross-Agent Skill Package**: Added canonical [skills/claude-cleanup/](skills/claude-cleanup/) (`SKILL.md`, `references/permissions-and-risks.md`, `references/agent-installation.md`) and `tests/SkillPackage.Tests.ps1` supporting Codex CLI, Antigravity CLI, Gemini CLI, and Claude Code with read-only `-Audit` default and SHA-256 authorization gates.
- **Stage E — Windows Console Launcher & User-Scoped Lifecycle Scripts**: Added `ClaudeCleanupLauncher.cmd`, `scripts/ClaudeCleanupLauncher.ps1`, `scripts/Install-ClaudeCleanup.ps1`, `scripts/Update-ClaudeCleanup.ps1`, `scripts/Uninstall-ClaudeCleanup.ps1`, `docs/gui-evaluation.md`, and sandboxed `tests/ToolkitInstall.Tests.ps1`.
- **Stage F — Documentation, CI, and Sanitized Release Packaging**: Added `docs/` guides and sanitized `docs/examples/*.sample.md`, `SECURITY.md`, `CONTRIBUTING.md`, `CHANGELOG.md`, `LICENSE` (MIT), `NOTICE`, `.github/workflows/ci.yml`, `scripts/New-ReleasePackage.ps1`, and `tests/ToolkitCiChecks.Tests.ps1`.
- **CI Sandbox Hardening**: Wrapped `Get-ScheduledTask` in `try/catch` inside `ClaudeCleanup.ps1` `Get-EnvironmentReport` for restricted CI/sandbox environments.

### Deferred / Future
- **Stage E+**: Optional WPF/XAML GUI thin-wrapper evaluation (`docs/gui-evaluation.md`).
- **Stage G (Live Target Run)**: Separately authorized execution against real user Claude installations remains excluded from automated CI and unapproved runs.

---

## [0.3.0] - 2026-11-16

### Added
- **Structured JSON Output**: Added `-OutputFormat Text|Json` parameter across `-Audit`, `-Plan`, `-Verify`, and `-Apply` modes, enabling scriptable automation and structured data parsing.
- **Windows ACL and Ownership Diagnostics**: Implemented `Get-PathAclDiagnostics` to inspect path security and classify status (`Ok`, `AdminOwned`, `OtherOwner`, `AccessDenied`, `ReparseBlocked`, `Absent`) without modifying system ACLs or taking ownership.
- **Scoped npm Package Uninstallation**: Added `Get-NpmPrefixCandidates` and `Get-NpmClaudePackageInstallations` (scanning `.npmrc`, `NPM_CONFIG_PREFIX`, `%APPDATA%\npm`, and `npm prefix -g`), with `Invoke-NpmClaudeUninstall` strictly targeting `@anthropic-ai/claude-code`.
- **VS Code Extension Discovery & CLI Integration**: Added `Get-VsCodeClaudeDiscovery` for VS Code, Cursor, and Windsurf extensions, and `Invoke-VsCodeExtensionUninstall` targeting `anthropic.claude-code` via `code --uninstall-extension`.
- **MSIX Package Uninstallation Wrapper**: Added `Invoke-ClaudeAppxUninstall` to safely invoke Windows `Remove-AppxPackage` for `Claude_pzs8sxrjxfjjc` with fail-closed post-verification.
- **AppData Role Classification**: Implemented `Get-AppDataClassification` to categorize folders into `Cache`, `Diagnostics`, `AuthReview`, `UserSessionOrMixed`, and `AmbiguousLegacy`.
- **Residual Discovery**: Added Start Menu/Desktop/Startup `.lnk` shortcut scanning (`Get-ClaudeShortcutResiduals`), environment variable name-only enumeration (`Get-WindowsResidualSummary`), and Credential Manager target counting.
- **Expanded Test Suite**: Added 12 new automated test cases covering npm discovery, VS Code extension uninstallation mocks, AppX uninstallation guards, ACL diagnostics, and JSON schema privacy validation (84 passing tests).

---

## [0.2.0] - 2026-11-16

### Added
- **Three-State Target Presence**: Replaced binary presence checks with explicit `Present`, `Absent`, and `Unknown` classification; permission and access errors return `Unknown` and never produce `VerifiedAbsent = $true`.
- **Atomic Execution Ledger**: Implemented atomic persistence in `Save-ExecutionLedgerEntry` using temp-file writing, explicit `FileStream.Flush($true)`, and `File.Replace` / `File.Move` to guarantee ledger integrity.
- **Open-Handle Registry Deletion**: Hardened registry deletion to inspect ancestor keys for `REG_LINK` symbolic links and delete directly on the open validated handle via `ntdll!NtDeleteKey`.
- **Subtree Owner SID Enforcement**: Enforced current-user SID matching across every node in recursive directory snapshots (`Get-SafeTreeSnapshot` and `Invoke-HandleTreeDeletion`).
- **Reparse Point Test Fixtures**: Added automated sandbox tests for directory symlinks, file symlinks, dangling links, and parent reparse points.
- **Bilingual Documentation**: Published comprehensive, symmetrically aligned English [README.md](README.md) and Simplified Chinese [README_zh-CN.md](README_zh-CN.md).

---

## [0.1.0] - 2026-11-15

### Added
- **Handle-Bound Filesystem Deletion Engine**: Embedded C# 5 Win32 P/Invoke layer (`ClaudeCleanup.NativeFs`) using `FILE_FLAG_OPEN_REPARSE_POINT | FILE_FLAG_BACKUP_SEMANTICS` and `SetFileInformationByHandle` with zero `Remove-Item` fallback.
- **Cryptographic Plan Manifest**: Deterministic `SchemaVersion = 3` cleanup manifest generation (`CLEANUP-PLAN.md`) with unique GUID `PlanId`, SHA-256 integrity binding, and per-target `Ready`/`ReviewOnly`/`Blocked` evaluation.
- **High-Impact Confirmation**: Enforced PowerShell `ConfirmImpact = 'High'` requiring explicit interactive confirmation or `-Confirm:$false` alongside `-ApprovedManifestSha256`.
- **Two Cleanup Policies**: Defined `AccountData` (clearing credentials and caches while protecting user configurations and session data) and `FullRemoval` (comprehensive user-level uninstallation).
- **Independent Verification**: Implemented `-Verify` mode to inspect current host status against manifest and ledger states.
- **Dual PowerShell Compatibility**: Full compatibility across Windows PowerShell 5.1 and PowerShell 7+.
