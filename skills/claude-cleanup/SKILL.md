---
name: claude-cleanup
description: >-
  Audits, plans, verifies, and performs user-authorized local cleanup of Claude
  Code and Claude Desktop artifacts on Windows 10/11 by invoking ClaudeCleanup.ps1.
  Use when asked to inspect local Claude installations, caches, extensions, or
  residual keys, generate a SchemaVersion 3 cleanup plan, verify prior cleanup,
  or execute explicitly approved cleanup targets without duplicating deletion logic.
---

# Claude Residual ID Cleaner Skill

Use this skill to operate the native PowerShell backend (`ClaudeCleanup.ps1`) safely across **Codex CLI**, **Antigravity CLI**, **Gemini CLI**, and **Claude Code**.

**Product Positioning**: **Claude Residual ID Cleaner (`Claude 账号残余 ID 清理工具`)** — 专为清理 Claude 封号后残留在设备中的账号/设备 ID、认证 Token 与会话缓存而设计，绝不改动 Windows 系统本身 (non-destructive Windows utility to scan and safely clean leftover local Claude residuals after an account ban without altering Windows OS, hardware IDs, telemetry, or remote server state). Defaults to read-only `-Audit` and supports `-Language Auto|zh-CN|en-US`, CLI, and standalone desktop app builds (`scripts/Build-DesktopApp.ps1`).

## Non-Negotiable Safety Rules

1. **Single Backend Only (Zero Duplicated Deletion Logic)**:
   - Always invoke `ClaudeCleanup.ps1` directly (`powershell.exe -NoProfile -File ...` on Windows PowerShell 5.1 or `pwsh.exe -NoProfile -File ...` on PowerShell 7+).
   - Never reimplement cleanup, path validation, Win32 handle deletion, registry deletion, or package removal in shell commands, helper scripts, or inline PowerShell (`Remove-Item`, `rd`, `del`, `reg delete`, `Remove-AppxPackage`, `npm uninstall`, or `code --uninstall-extension`).
2. **Read-Only Default**:
   - Default to `-Audit` (or `-Verify` for post-checks). Never run `-Plan` or `-Apply` unless the user explicitly asks to create a plan or execute cleanup.
3. **Strict Authorization Gate Before `-Apply`**:
   - Never auto-run `-Apply` and never bypass interactive confirmation (`-Confirm:$false` or `-Force`) unless the user explicitly authorizes non-interactive confirmation for a specific verified manifest hash.
   - Before any real `-Apply`, you **must** obtain explicit user approval of:
     1. The exact `-Policy` (`AccountData` or `FullRemoval`),
     2. The exact 64-hex `-ApprovedManifestSha256` of the current `CLEANUP-PLAN.md`, and
     3. The per-target list of `Ready` entries (ID, category, kind, and path) shown by previewing with `-WhatIf`.
4. **Never Recommend `-ExecutionPolicy Bypass`**:
   - Never use or suggest `-ExecutionPolicy Bypass` or `-ExecutionPolicy Unrestricted`.
   - If PowerShell blocks script execution, ask the user to inspect `Get-ExecutionPolicy -List`, review `ClaudeCleanup.ps1`, and resolve policy or file blocking through standard Windows controls (`Unblock-File` after review or `RemoteSigned`).
5. **No Automatic Privilege Escalation or Security Tampering**:
   - Never auto-elevate via UAC, modify Windows ACLs or file ownership, modify WSL distributions, read or print Credential Manager secrets or environment variable values, or tamper with device IDs, proxies, or telemetry.
6. **REA Policy**:
   - REA (Reverse Engineer Anything) is strictly an optional development-time static-analysis tool and is **never** required or invoked at runtime.

---

## Locate `ClaudeCleanup.ps1` First

Before running any command, locate the repository root containing `ClaudeCleanup.ps1`:

- If your current working directory is the toolkit repository, use `.\ClaudeCleanup.ps1`.
- If the skill is installed in a user-scoped skills directory outside the repository, ask the user for their local `Claude-Residual-ID-Cleaner` path or verify the path they provided before running anything.
- Do not copy `ClaudeCleanup.ps1` into agent config folders (`.codex`, `.agents`, `.gemini`, `.claude`) or create custom deletion wrappers.

---

## Standard Safe Workflow

Follow these steps in order and stop at each authorization boundary.

### Step 1: Read-Only Audit (Default Entry Point)

Run `-Audit` with `-OutputFormat Json` (or text) to inspect the host without writing to disk:

```powershell
pwsh.exe -NoProfile -File .\ClaudeCleanup.ps1 -Audit -OutputFormat Json
```

On Windows PowerShell 5.1:

```powershell
powershell.exe -NoProfile -File .\ClaudeCleanup.ps1 -Audit -OutputFormat Json
```

Summarize for the user:
- Discovered installations and artifacts grouped by policy (`AccountData` vs. `FullRemoval`),
- Each candidate's `Decision` (`Ready`, `ReviewOnly`, or `Blocked`) and `Reason` / `Ownership` diagnostics,
- Read-only residual counts (environment variable names only, `PATH`, Credential Manager target counts, shortcuts, and read-only WSL status).

### Step 2: Generate a Plan (Only When Requested)

When the user asks to prepare a cleanup plan, preview first with `-WhatIf` or write `CLEANUP-PLAN.md` (`SchemaVersion = 3`):

```powershell
powershell.exe -NoProfile -File .\ClaudeCleanup.ps1 -Plan -WhatIf
powershell.exe -NoProfile -File .\ClaudeCleanup.ps1 -Plan -OutputFormat Json
```

Report the generated `PlanPath`, `PlanId` (or manifest metadata), exact 64-hex `Sha256`, and the counts of `Ready` vs. `ReviewOnly` / `Blocked` entries. Remind the user that each `-Plan` run invalidates any earlier SHA-256 hash.

### Step 3: Dry-Run Preview (`-WhatIf`) and Explicit Per-Target Approval

Before any real deletion, preview the selected policy against the exact manifest hash (previewing with `-WhatIf` does **not** consume the single-use authorization):

```powershell
powershell.exe -NoProfile -File .\ClaudeCleanup.ps1 -Apply -Policy AccountData -ApprovedManifestSha256 <64-hex-hash> -WhatIf
```

Present to the user and wait for explicit approval:
- Selected policy (`AccountData` or `FullRemoval`) and what it preserves vs. removes,
- Exact 64-hex `ApprovedManifestSha256`,
- Every `Ready` target (`Id`, `Category`, `Kind`, `Path`), plus every `ReviewOnly` or `Blocked` target that will be skipped,
- Explicit notice that deletions are permanent (no automatic backup/quarantine/rollback) and that running `claude` or `Code` processes should be closed first.

### Step 4: Execute Approved Cleanup (`-Apply`)

Only after the user explicitly approves the policy, 64-hex SHA-256, and listed `Ready` targets:

```powershell
powershell.exe -NoProfile -File .\ClaudeCleanup.ps1 -Apply -Policy <AccountData|FullRemoval> -ApprovedManifestSha256 <64-hex-hash>
```

Each approved manifest SHA-256 can be applied at most once across real `-Apply` runs (tracked atomically in `VERIFICATION.md`). If execution stops or needs re-running, generate a new plan with `-Plan` and obtain fresh approval.

### Step 5: Independent Post-Action Verification (`-Verify`)

Always verify independently after `-Apply` (or whenever inspecting prior runs):

```powershell
powershell.exe -NoProfile -File .\ClaudeCleanup.ps1 -Verify -OutputFormat Json
```

Report `Present`, `Absent`, and `Unknown` states plus `LedgerEntries` honestly:
- Never report `Unknown` as `Absent`.
- Never claim local cleanup modifies remote/server-side Claude account records.

---

## Reference Guides

- Policy boundaries, Win32/registry security guarantees, ExecutionPolicy guidance, and known limitations: [permissions-and-risks.md](references/permissions-and-risks.md)
- Manual user-scoped installation, multi-CLI discovery paths, and skill-only uninstallation: [agent-installation.md](references/agent-installation.md)
