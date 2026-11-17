[简体中文](Skills-Usage-Guide.md) | English

# claude-cleanup — Cross-Agent Skill Usage Guide

**Project:** `YUCZ-43/claude-cleanup` (`Claude Residual ID Cleaner`)  
**Canonical Skill Package:** [skills/claude-cleanup/SKILL.md](../skills/claude-cleanup/SKILL.md)  
**Related Docs:** [简体中文 README](../README.md) | [English README](../README.en.md) | [CLI Reference](./CLI-Reference.md) | [Agent Skill Security Spec](./Agent-Skill-Guide.md)

This practical guide helps Windows users and engineering teams install, verify, invoke, and maintain the `claude-cleanup` Agent Skill safely across **Antigravity (`agy` CLI & Desktop)**, **Codex CLI**, **Claude Code**, and **Gemini CLI**, including copy-pasteable natural-language prompts and strict safety guardrails.

## Desktop Studio Preview (Non-Destructive Demo Audit)

If you prefer reviewing discovered items or confirming final cleanup interactively via a desktop window, launch the standalone `Claude-Residual-ID-Cleaner.exe` bundled in the release ZIP or `dist\` folder (powered by the exact same `ClaudeCleanup.ps1` backend as the Agent Skill):

![Claude Residual ID Cleaner Desktop Studio (en-US)](images/ui-main-en.png)

---

## 1. Architecture and Non-Negotiable Safety Guarantees

Every AI Agent Skill integration in `claude-cleanup` is governed by three strict architectural invariants:

1. **Single Verified Backend (Zero Duplicated Deletion Logic)**
   - The canonical skill package under [skills/claude-cleanup/](../skills/claude-cleanup/SKILL.md) contains only Markdown instructions and safety references — **zero embedded file-deletion or registry-mutation scripts**.
   - Every AI agent delegates strictly to the single native PowerShell engine `ClaudeCleanup.ps1` (`powershell.exe -NoProfile -File ...` on Windows PowerShell 5.1 or `pwsh.exe -NoProfile -File ...` on PowerShell 7+).
   - Agents must **never** reimplement cleanup using `Remove-Item`, `rd`, `del`, `reg delete`, `Remove-AppxPackage`, `npm uninstall`, or `code --uninstall-extension`, which would bypass Win32 handle-bound validation (`FILE_FLAG_OPEN_REPARSE_POINT`, `GetFinalPathNameByHandleW`, `GetSecurityInfo`, `SetFileInformationByHandle`, and `ntdll!NtDeleteKey`).

2. **100% Read-Only Default, Strictly Without Altering Windows OS**
   - Default skill invocations are strictly read-only (`-Audit` for discovery or `-Verify` for post-checks). Without `-SaveAuditReport`, `-Audit` writes nothing to disk.
   - Cleanup targets are restricted to allowlisted local Claude residuals: the toolkit **never** touches `C:\Windows`, `Program Files`, OS registry hives, system hardware/device IDs (such as `MachineGuid`), WSL distribution files, browser user profiles, or unrelated software. Windows Credential Manager checks report matching target counts only (secrets are never read or deleted), and environment variable checks emit `Scope` and `Name` only (API key values are never read or printed).
   - Local cleanup **never** alters remote Anthropic server-side account state or quotas.

3. **64-Hex SHA-256 Hash Binding and Human Confirmation Gate**
   - Before any real `-Apply`, the user must explicitly request `-Plan` to generate a deterministic `SchemaVersion = 3` manifest (`CLEANUP-PLAN.md`) containing a unique GUID `PlanId` and exact file SHA-256 digest.
   - Executing `-Apply` requires: an explicit `-Policy` (`AccountData` or `FullRemoval`), the exact 64-hex `-ApprovedManifestSha256`, per-target review of all `Ready` entries, and PowerShell `ConfirmImpact = 'High'` confirmation.
   - Every real `-Apply` atomically updates the replay-prevention ledger in `VERIFICATION.md` via temp-file + `Flush($true)` + atomic replace. Each manifest SHA-256 can be applied at most once (`-WhatIf` dry runs do not consume authorization).

4. **Zero Policy Bypass or Privilege Escalation**
   - Never use or recommend `-ExecutionPolicy Bypass`, `-ExecutionPolicy Unrestricted`, or automatic `-Apply` without explicit user authorization for a verified manifest hash.
   - Never auto-elevate via UAC, mutate Windows ACLs, take ownership (`takeown` / `icacls`), or tamper with device IDs, proxies, or telemetry.
   - REA (Reverse Engineer Anything) is strictly an optional development-time static-analysis tool and is **never** required at runtime.

> For full policy boundaries, Win32 handle guarantees, and threat model details, see [permissions-and-risks.md](../skills/claude-cleanup/references/permissions-and-risks.md) and [Agent-Skill-Guide.md](./Agent-Skill-Guide.md).

---

## 2. Installation and Discovery Paths Across 4 AI Agent Ecosystems

The canonical skill directory `skills/claude-cleanup/` contains:

```text
skills/claude-cleanup/
├── SKILL.md
└── references/
    ├── permissions-and-risks.md
    └── agent-installation.md
```

### 2.1 Discovery Path Matrix (Project-Scoped vs. User-Scoped)

| AI Agent Ecosystem | `-SkillTarget` Flag | Project-Scoped Path (Relative to Workspace) | User-Scoped Path (Global Discovery Directory) |
| :--- | :--- | :--- | :--- |
| **Antigravity (`agy` CLI & Desktop)** | `Antigravity` | `.agents\skills\claude-cleanup\` | `%USERPROFILE%\.gemini\config\skills\claude-cleanup\` |
| **Codex CLI** | `Codex` or `Agents` | `.agents\skills\claude-cleanup\` | `%USERPROFILE%\.codex\skills\claude-cleanup\` (`Codex`) or `%USERPROFILE%\.agents\skills\claude-cleanup\` (`Agents`) |
| **Claude Code** | `Claude` | `.claude\skills\claude-cleanup\` | `%USERPROFILE%\.claude\skills\claude-cleanup\` |
| **Gemini CLI** | `Gemini` | `.gemini\skills\claude-cleanup\` (or `.agents\skills\claude-cleanup\`) | `%USERPROFILE%\.gemini\skills\claude-cleanup\` |

> **Important Separation of Concerns:** Installing or uninstalling the Skill only copies or removes these Markdown instructions and `.claude-cleanup-skill-install.json` inside the agent skills directory. It does **not** install or remove the `claude-cleanup` toolkit itself, and it does **not** modify Claude Code or Claude Desktop. Never copy `ClaudeCleanup.ps1` into `.codex`, `.agents`, `.gemini`, or `.claude` (those directories are explicitly protected against cleanup targeting).

### 2.2 Automated Installation (Recommended)

From the root of your local `claude-cleanup` clone, run [scripts/Install-ClaudeCleanup.ps1](../scripts/Install-ClaudeCleanup.ps1) (performs path normalization and reparse-point preflight checks before writing, and supports `-WhatIf`):

```powershell
# Option A: Install both the toolkit (%LOCALAPPDATA%\Programs\claude-cleanup) and the Skill
powershell.exe -NoProfile -File .\scripts\Install-ClaudeCleanup.ps1 -InstallSkill -SkillTarget Antigravity

# Option B: Install the Skill only (-SkillOnly), ideal when keeping the repo clone in place
powershell.exe -NoProfile -File .\scripts\Install-ClaudeCleanup.ps1 -SkillOnly -SkillTarget Codex
powershell.exe -NoProfile -File .\scripts\Install-ClaudeCleanup.ps1 -SkillOnly -SkillTarget Antigravity
powershell.exe -NoProfile -File .\scripts\Install-ClaudeCleanup.ps1 -SkillOnly -SkillTarget Claude
powershell.exe -NoProfile -File .\scripts\Install-ClaudeCleanup.ps1 -SkillOnly -SkillTarget Gemini

# Option C: Deploy to all supported targets (Codex, Antigravity, Gemini, Claude, Agents)
powershell.exe -NoProfile -File .\scripts\Install-ClaudeCleanup.ps1 -SkillOnly -SkillTarget All

# Option D: Dry-run preview with -WhatIf or explicit output language
powershell.exe -NoProfile -File .\scripts\Install-ClaudeCleanup.ps1 -SkillOnly -SkillTarget All -Language en-US -WhatIf
```

> If the destination skill directory already contains files, the installer fails closed by default; use `Update-ClaudeCleanup.ps1` to upgrade or pass `-Force` explicitly. See [Launcher-and-Install.md](./Launcher-and-Install.md) and [agent-installation.md](../skills/claude-cleanup/references/agent-installation.md).

### 2.3 Manual Installation & Zero-Global Project-Scoped Usage

#### Option 1: Project-Scoped Without Global Profile Changes

If you launch your AI coding agent directly inside the `claude-cleanup` repository — or copy `skills\claude-cleanup\` into a workspace's `.agents\skills\claude-cleanup\`, `.claude\skills\claude-cleanup\`, or `.gemini\skills\claude-cleanup\` folder — the skill remains scoped to that workspace without touching `%USERPROFILE%`.

#### Option 2: Manual User-Scoped Copy

Run the copy command for your chosen ecosystem from the repository root:

```powershell
# 1. Antigravity (agy CLI & Desktop)
$target = Join-Path $HOME '.gemini\config\skills\claude-cleanup'
New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
Copy-Item -LiteralPath '.\skills\claude-cleanup' -Destination $target -Recurse -Force

# 2. Codex CLI (.codex dedicated path or shared .agents path)
$target = Join-Path $HOME '.codex\skills\claude-cleanup'
New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
Copy-Item -LiteralPath '.\skills\claude-cleanup' -Destination $target -Recurse -Force

# 3. Claude Code
$target = Join-Path $HOME '.claude\skills\claude-cleanup'
New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
Copy-Item -LiteralPath '.\skills\claude-cleanup' -Destination $target -Recurse -Force

# 4. Gemini CLI
$target = Join-Path $HOME '.gemini\skills\claude-cleanup'
New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
Copy-Item -LiteralPath '.\skills\claude-cleanup' -Destination $target -Recurse -Force
```

> Note: Manually copied installs do not create `.claude-cleanup-skill-install.json`, so remove them manually using the directory-cleanup snippet in Section 4.1.

### 2.4 Ecosystem Activation Behavior & Invocation Tips

1. **Antigravity (`agy` CLI & Desktop)**
   - **Discovery Paths**: User-scoped `~/.gemini/config/skills/claude-cleanup`, project-scoped `.agents/skills/claude-cleanup`.
   - **Semantic Automatic Activation**: Antigravity evaluates the `SKILL.md` YAML frontmatter (`name: claude-cleanup` and `description` keywords covering audit, `SchemaVersion 3` plan generation, and cleanup verification) and activates the skill automatically when your request involves inspecting or cleaning local Claude leftovers.
   - **`/skills` Management**: Use `/skills` in the chat UI or CLI to verify that `claude-cleanup` is discovered and enabled.
   - **Explicit Invocation Tip**: When working outside the `claude-cleanup` repository, explicitly name `claude-cleanup` and include your local path to `ClaudeCleanup.ps1` (for example, `C:\Users\<USERNAME>\Tools\claude-cleanup\ClaudeCleanup.ps1`).

2. **Codex CLI**
   - **Discovery Paths**: User-scoped `~/.codex/skills/claude-cleanup` (`-SkillTarget Codex`) and shared `~/.agents/skills/claude-cleanup` (`-SkillTarget Agents`), plus project-scoped `.agents/skills/claude-cleanup`.
   - **Explicit `$claude-cleanup` Invocation**: Reference `$claude-cleanup` directly in your prompt — for example: `$claude-cleanup Run a read-only audit of local Claude residuals on this Windows host.`
   - **Prompt Tip**: Instruct Codex to read structured JSON via `ClaudeCleanup.ps1 -Audit -OutputFormat Json` and stop before `-Plan` or `-Apply`.

3. **Claude Code**
   - **Discovery Paths**: User-scoped `~/.claude/skills/claude-cleanup`, project-scoped `.claude/skills/claude-cleanup`.
   - **Invocation Tip**: Ask Claude Code to use the `claude-cleanup` skill and delegate exclusively to `ClaudeCleanup.ps1`.
   - **Operational Caveat**: Because `FullRemoval` can target `~/.claude` itself, exit all running `claude` and `Code` processes before executing `-Apply`, and run final cleanup from a separate standard PowerShell terminal or the standalone desktop app to avoid open file-handle locks.

4. **Gemini CLI**
   - **Discovery Paths**: User-scoped `~/.gemini/skills/claude-cleanup`, project-scoped `.gemini/skills/claude-cleanup` (or `.agents/skills/claude-cleanup`).
   - **Invocation Tip**: Mention `claude-cleanup` explicitly in your prompt along with your local path to `ClaudeCleanup.ps1` and `-OutputFormat Json`.

### 2.5 Static Verification After Install

Run the repository skill validation suite (executes exclusively inside `tests\sandbox\skill\` without reading or modifying your live global agent directories):

```powershell
powershell.exe -NoProfile -File .\tests\SkillPackage.Tests.ps1
pwsh.exe -NoProfile -File .\tests\SkillPackage.Tests.ps1
```

---

## 3. Ready-to-Copy Natural-Language Prompt Playbook

Follow these four prompts in order. If you launch your AI agent **outside** the `claude-cleanup` repository folder, replace `.\ClaudeCleanup.ps1` with your actual local path (for example, `C:\Users\<USERNAME>\Tools\claude-cleanup\ClaudeCleanup.ps1`).

### Prompt 1: Read-Only Banned-Account Residual Audit (`-Audit -OutputFormat Json`)

Use this first to inspect leftover Claude account/device metadata, auth caches, IDE extensions, shortcuts, and environment variable names. **Writes nothing to disk.**

```text
Use the claude-cleanup skill to perform a strictly read-only audit via ClaudeCleanup.ps1 (if the current working directory is not the toolkit repo, confirm or use C:\Users\<USERNAME>\Tools\claude-cleanup\ClaudeCleanup.ps1).
Requirements:
1. Run only: .\ClaudeCleanup.ps1 -Audit -OutputFormat Json -Language en-US
2. Do NOT run -Plan, do NOT run -Apply, and never use -ExecutionPolicy Bypass.
3. Summarize the JSON output grouped by AccountData vs. FullRemoval:
   - Discovered Claude Code CLI, Claude Desktop, VS Code/Cursor extensions, and browser Native Messaging keys;
   - Each candidate's Decision (Ready / ReviewOnly / Blocked) and Reason / Ownership diagnostics;
   - Credential Manager target counts, environment variable names only (never print values), and read-only WSL status.
```

> Add `-SaveAuditReport` only if you want `ClaudeCleanup.ps1` to write a localized `AUDIT.md` report to disk.

### Prompt 2: Deterministic Plan Generation & `AccountData` vs. `FullRemoval` Comparison (`-Plan`)

After reviewing the audit, explicitly instruct the agent to generate `CLEANUP-PLAN.md` (`SchemaVersion = 3`). Note that each `-Plan` run issues a new `PlanId` and invalidates any previous SHA-256 hash.

```text
I have reviewed the read-only audit. Now use the claude-cleanup skill to run:
.\ClaudeCleanup.ps1 -Plan -OutputFormat Json -Language en-US
Requirements:
1. Stop immediately after generating CLEANUP-PLAN.md; do NOT run -Apply.
2. Report the PlanPath, PlanId, full 64-hex SHA-256 hash, and counts of Ready, ReviewOnly, and Blocked entries.
3. Provide a clear comparison table showing what AccountData removes vs. preserves (.claude user creations, .claude.json, Desktop Local Storage / IndexedDB) compared to FullRemoval for the items in this plan.
```

> To preview plan item counts without writing `CLEANUP-PLAN.md`, ask the agent to run `.\ClaudeCleanup.ps1 -Plan -WhatIf` first.

### Prompt 3: Non-Destructive Dry-Run Preview (`-Apply -WhatIf`)

Preview the exact `Ready` targets for your chosen policy against the 64-hex SHA-256 before any deletion occurs. **`-WhatIf` makes zero disk changes and does not consume the single-use manifest authorization.**

```text
Use the claude-cleanup skill to run a non-destructive dry-run preview against manifest hash <64-HEX-SHA256> with policy AccountData (or FullRemoval):
.\ClaudeCleanup.ps1 -Apply -Policy AccountData -ApprovedManifestSha256 <64-HEX-SHA256> -WhatIf -Language en-US
Requirements:
1. List every Ready target (ID, Category, Kind, and full Path or package name) that would be removed, plus every ReviewOnly / Blocked item that will be skipped.
2. Confirm explicitly that nothing was deleted and that -WhatIf did not consume the manifest SHA-256 authorization.
3. Wait for my explicit confirmation of the policy, 64-hex SHA-256, and target list before proceeding.
```

### Prompt 4: Explicitly Authorized Cleanup & Independent Post-Verify (`-Apply` -> `-Verify`)

Run only after closing all `claude` and `Code` processes, reviewing the full target list, and acknowledging that **deletions are permanent without automatic backup or recycle-bin rollback**.

```text
I have closed all Claude and VS Code processes and explicitly authorize local cleanup (I understand deletions are permanent and do not alter Windows OS or remote Claude account state):
- Policy: AccountData (or FullRemoval)
- ApprovedManifestSha256: <64-HEX-SHA256>
Use the claude-cleanup skill to:
1. Execute .\ClaudeCleanup.ps1 -Apply -Policy <AccountData|FullRemoval> -ApprovedManifestSha256 <64-HEX-SHA256> -OutputFormat Json -Language en-US (follow standard high-impact confirmation).
2. Immediately afterward, run .\ClaudeCleanup.ps1 -Verify -OutputFormat Json -Language en-US.
3. Report the VERIFICATION.md ledger entry and every target's three-state result (Present / Absent / Unknown) honestly — never report Unknown as Absent.
```

---

## 4. Lifecycle Maintenance, Troubleshooting, and Safety Guardrails

### 4.1 Updating and Uninstalling the Skill (`-SkillOnly`)

Manage installed user-scoped skills cleanly without touching the `claude-cleanup` toolkit, other agent skills, or Claude installations:

```powershell
# 1. Update only the installed Skill files
powershell.exe -NoProfile -File .\scripts\Update-ClaudeCleanup.ps1 -SkillOnly -SkillTarget Antigravity
powershell.exe -NoProfile -File .\scripts\Update-ClaudeCleanup.ps1 -SkillOnly -SkillTarget All

# Or update both the installed toolkit and the Skill together
powershell.exe -NoProfile -File .\scripts\Update-ClaudeCleanup.ps1 -UpdateSkill -SkillTarget Codex

# 2. Uninstall only the installed Skill (leaves toolkit, other skills, and Claude intact)
powershell.exe -NoProfile -File .\scripts\Uninstall-ClaudeCleanup.ps1 -SkillOnly -SkillTarget Antigravity
powershell.exe -NoProfile -File .\scripts\Uninstall-ClaudeCleanup.ps1 -SkillOnly -SkillTarget All

# Or uninstall both toolkit and Skill (preserves local reports unless -RemoveReports is passed)
powershell.exe -NoProfile -File .\scripts\Uninstall-ClaudeCleanup.ps1 -UninstallSkill -SkillTarget All
```

If you installed the skill manually via `Copy-Item` (Section 2.3, without `.claude-cleanup-skill-install.json`), remove only the `claude-cleanup` folder from your chosen user-scoped path:

```powershell
$paths = @(
    (Join-Path $HOME '.agents\skills\claude-cleanup'),
    (Join-Path $HOME '.codex\skills\claude-cleanup'),
    (Join-Path $HOME '.gemini\config\skills\claude-cleanup'),
    (Join-Path $HOME '.gemini\skills\claude-cleanup'),
    (Join-Path $HOME '.claude\skills\claude-cleanup')
)
foreach ($p in $paths) {
    if (Test-Path -LiteralPath $p) {
        [IO.Directory]::Delete($p, $true)
    }
}
```

### 4.2 Troubleshooting

| Symptom | Root Cause | Recommended Resolution |
| :--- | :--- | :--- |
| **PowerShell blocks running `ClaudeCleanup.ps1`** | Default `Restricted` execution policy or downloaded file Zone.Identifier block | Inspect `Get-ExecutionPolicy -List`, review `ClaudeCleanup.ps1` locally, and run `Unblock-File -LiteralPath .\ClaudeCleanup.ps1` or set `CurrentUser` policy to `RemoteSigned`. **Never use `-ExecutionPolicy Bypass`.** |
| **Agent cannot find `ClaudeCleanup.ps1` outside repo root** | Global user-scoped `SKILL.md` intentionally contains no copy of `ClaudeCleanup.ps1` | Provide the exact path to your local clone or user install in your prompt, e.g. `C:\Users\<USERNAME>\Tools\claude-cleanup\ClaudeCleanup.ps1` (or `%LOCALAPPDATA%\Programs\claude-cleanup\ClaudeCleanup.ps1`). **Never copy `ClaudeCleanup.ps1` into `.codex`, `.agents`, `.gemini`, or `.claude`.** |
| **`-Apply` rejects the manifest SHA-256** | Re-running `-Plan` invalidated the previous hash, or the hash was already consumed in `VERIFICATION.md` | Run `.\ClaudeCleanup.ps1 -Plan` to generate a fresh `CLEANUP-PLAN.md`, review the new 64-hex SHA-256, preview with `-WhatIf`, and confirm again. |
| **Targets remain `Blocked` or `ReviewOnly`** | Junction/symlink detected (`ReparseBlocked`), `BUILTIN\Administrators` owner, or ambiguous directory (`buddy-tokens.json`, `Claude-3p`, `pivot.claude.ai`) | The engine intentionally refuses to traverse reparse points or mutate Windows ACLs/ownership. Inspect the reason in `CLEANUP-PLAN.md` and see [Troubleshooting-and-Compatibility.md](./Troubleshooting-and-Compatibility.md). |

### 4.3 Safety Guardrails Matrix

| Guardrail Area | Permitted Safe Behavior | Enforced Mechanism | Strictly Forbidden for Agents |
| :--- | :--- | :--- | :--- |
| **Default Entry** | Read-only `-Audit` and `-Verify` | `SKILL.md` workflow default; `-Audit` writes nothing unless `-SaveAuditReport` is passed | Running `-Plan` unprompted or auto-executing `-Apply` |
| **Deletion Engine** | Delegating exclusively to `ClaudeCleanup.ps1` | `ClaudeCleanup.NativeFs` open-handle checks + `ntdll!NtDeleteKey` | Inline `Remove-Item`, `rd`, `del`, `reg delete`, `Remove-AppxPackage` |
| **Execution Policy** | `Unblock-File` (after review) or user `RemoteSigned` | CI & security specification enforcement | Suggesting or passing `-ExecutionPolicy Bypass` / `Unrestricted` |
| **Authorization Gate** | Presenting `-WhatIf` list, policy, and 64-hex SHA-256 | Single-read manifest validation + `ConfirmImpact = 'High'` + atomic `VERIFICATION.md` replay guard | Bypassing confirmation, guessing hashes, or reusing a consumed SHA-256 |
| **OS & Privileges** | Standard non-elevated current user context | Allowlisted targets, protected-path blocks, full-tree `OwnerSid` & reparse checks | Auto-UAC elevation, `takeown`/`icacls`, modifying Windows OS or WSL |
| **Privacy & Remote** | Variable names and Credential Manager counts only | Redacted JSON/Markdown schemas and release privacy gate | Reading/printing secret values or tampering with device IDs, proxies, or telemetry |

---

## 5. Further Reading

- [Project Home (简体中文 README.md)](../README.md) / [English Home (README.en.md)](../README.en.md)
- [Canonical Skill Definition (skills/claude-cleanup/SKILL.md)](../skills/claude-cleanup/SKILL.md)
- [Multi-Agent Installation Reference (agent-installation.md)](../skills/claude-cleanup/references/agent-installation.md)
- [Permissions, Policies, and Risk Boundaries (permissions-and-risks.md)](../skills/claude-cleanup/references/permissions-and-risks.md)
- [CLI Reference (CLI-Reference.md)](./CLI-Reference.md)
- [Launcher & Install Guide (Launcher-and-Install.md)](./Launcher-and-Install.md)
- [Uninstallation Guide (Uninstallation-Guide.md)](./Uninstallation-Guide.md)
- [Troubleshooting & Compatibility Guide (Troubleshooting-and-Compatibility.md)](./Troubleshooting-and-Compatibility.md)
