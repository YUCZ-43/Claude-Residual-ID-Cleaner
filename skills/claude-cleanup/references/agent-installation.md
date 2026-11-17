# Cross-Agent Skill Installation and Uninstallation

This guide explains how to manually install, verify, and cleanly uninstall the canonical `claude-cleanup` skill package (`skills/claude-cleanup/`) for **Codex CLI**, **Antigravity CLI**, **Gemini CLI**, and **Claude Code**.

> **Important Separation of Concerns**
> - Installing or uninstalling this skill only adds or removes agent skill Markdown instructions (`SKILL.md` and `references/`).
> - It does **not** install or uninstall the `claude-cleanup` toolkit itself (`ClaudeCleanup.ps1`), and it does **not** remove Claude Code or Claude Desktop.
> - See [SKILL.md](../SKILL.md) and [permissions-and-risks.md](permissions-and-risks.md) for runtime safety rules.

---

## 1. Prerequisites

1. Clone or download `claude-cleanup` to a local folder (for example, `C:\Users\<USERNAME>\Tools\claude-cleanup`).
2. Confirm `ClaudeCleanup.ps1` and `skills\claude-cleanup\SKILL.md` are present in that folder.
3. Keep `ClaudeCleanup.ps1` in its toolkit directory; do **not** copy `ClaudeCleanup.ps1` into `~/.codex`, `~/.agents`, `~/.gemini`, or `~/.claude` (those directories are protected against cleanup targeting).
4. Never use `-ExecutionPolicy Bypass` when running PowerShell commands.

---

## 2. Discovery Paths Across Supported CLIs

Choose either **Project-Scoped** (when working inside a workspace) or **User-Scoped** (manual installation into your user profile):

| Agent CLI | Project-Scoped Path (Relative to Workspace) | User-Scoped Path (`-SkillTarget` Target) |
| :--- | :--- | :--- |
| **Codex CLI** | `.agents\skills\claude-cleanup\` | `%USERPROFILE%\.codex\skills\claude-cleanup\` (`Codex`) or `%USERPROFILE%\.agents\skills\claude-cleanup\` (`Agents`) |
| **Antigravity CLI** | `.agents\skills\claude-cleanup\` | `%USERPROFILE%\.gemini\config\skills\claude-cleanup\` (`Antigravity`) |
| **Gemini CLI** | `.gemini\skills\claude-cleanup\` (or `.agents\skills\claude-cleanup\`) | `%USERPROFILE%\.gemini\skills\claude-cleanup\` (`Gemini`) |
| **Claude Code** | `.claude\skills\claude-cleanup\` | `%USERPROFILE%\.claude\skills\claude-cleanup\` (`Claude`) |

> **Note on Project-Scoped Use Without Global Install**: If you run an agent CLI directly inside the `claude-cleanup` repository (or copy `skills\claude-cleanup\` into a project's `.agents\skills\` folder), the skill stays local to that project without modifying your user profile directories.

---

## 3. Manual User-Scoped Installation

Run these commands from the root of your local `claude-cleanup` folder after inspecting the files. Choose **only** the target CLI directory you use.

### Option A: Shared `.agents` User Scope (Codex CLI & Shared Agent Discovery)

```powershell
$target = Join-Path $HOME '.agents\skills\claude-cleanup'
New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
Copy-Item -LiteralPath '.\skills\claude-cleanup' -Destination $target -Recurse -Force
```

### Option B: Antigravity CLI User Scope

```powershell
$target = Join-Path $HOME '.gemini\config\skills\claude-cleanup'
New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
Copy-Item -LiteralPath '.\skills\claude-cleanup' -Destination $target -Recurse -Force
```

### Option C: Gemini CLI User Scope

```powershell
$target = Join-Path $HOME '.gemini\skills\claude-cleanup'
New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
Copy-Item -LiteralPath '.\skills\claude-cleanup' -Destination $target -Recurse -Force
```

### Option D: Claude Code User Scope

```powershell
$target = Join-Path $HOME '.claude\skills\claude-cleanup'
New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
Copy-Item -LiteralPath '.\skills\claude-cleanup' -Destination $target -Recurse -Force
```

### How the Skill Finds `ClaudeCleanup.ps1` After User-Scoped Install

When invoked from another working directory, the agent will need the full path to your local `ClaudeCleanup.ps1` (for example, `C:\Users\<USERNAME>\Tools\claude-cleanup\ClaudeCleanup.ps1`). Provide that path in your prompt or run the CLI from your `claude-cleanup` folder.

---

## 4. Verifying Discovery

1. **Automated Static Check (No Global Side Effects)**:
   Run the repository skill package tests in Windows PowerShell 5.1 or PowerShell 7:
   ```powershell
   powershell.exe -NoProfile -File .\tests\SkillPackage.Tests.ps1
   pwsh.exe -NoProfile -File .\tests\SkillPackage.Tests.ps1
   ```
   This validates frontmatter, internal links, safety rules, and simulated discovery inside `tests\sandbox\skill\` without touching your real `~/.codex`, `~/.agents`, `~/.gemini`, or `~/.claude` directories.

2. **Live CLI Discovery Check (Manual, Environment-Dependent)**:
   Live CLI discovery is not executed by automated tests because each CLI manages its own runtime environment. After manual installation, open your target CLI and confirm `claude-cleanup` appears in its available skills list, then test a read-only audit prompt such as:
   - `"Use the claude-cleanup skill to run a read-only audit with ClaudeCleanup.ps1 -Audit."`

---

## 5. Clean User-Scoped Uninstallation (Skill Only)

To remove **only** the installed `claude-cleanup` skill without affecting other skills, the `claude-cleanup` toolkit, or Claude installations, delete only the `claude-cleanup` folder from whichever user-scoped path you chose:

```powershell
# Remove whichever user-scoped skill folder you installed:
$paths = @(
    (Join-Path $HOME '.agents\skills\claude-cleanup'),
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

- Removing the `claude-cleanup` skill folder leaves all other agent customizations intact.
- If you also want to remove the `claude-cleanup` toolkit itself, delete your local `claude-cleanup` directory separately.
