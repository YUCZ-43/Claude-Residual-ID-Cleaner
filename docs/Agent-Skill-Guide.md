# claude-cleanup — Agent Skill Integration Guide

**Project:** claude-cleanup (`Claude Residual ID Cleaner`)  
**Repository:** `YUCZ-43/claude-cleanup`  
**Language Navigation:** [简体中文](../README.md) | [English](../README.en.md)  
**Document Status:** Implemented (Stage D Cross-Agent Skill Package)

---

## 1. Overview / 概述

This guide defines the specifications, security boundaries, and usage rules for deploying the `claude-cleanup` toolkit as a canonical **Agent Skill** ([skills/claude-cleanup/](../skills/claude-cleanup/)).

The skill is designed for multi-agent ecosystems, enabling AI engineering agents to run read-only audits, verified post-checks, and explicitly user-authorized cleanup operations safely without duplicating deletion logic.

---

## 2. Target Agent Ecosystems / 目标智能体生态

The canonical Agent Skill supports four primary AI coding agent CLIs (matching `scripts/Install-ClaudeCleanup.ps1 -SkillTarget`):

| Agent Platform | Installer Target Flag | User-Scoped Skill Discovery Path |
| :--- | :--- | :--- |
| **Codex CLI** | `-SkillTarget Codex` / `Agents` | `%USERPROFILE%\.codex\skills\claude-cleanup\` or `%USERPROFILE%\.agents\skills\claude-cleanup\` |
| **Antigravity CLI** | `-SkillTarget Antigravity` | `%USERPROFILE%\.gemini\config\skills\claude-cleanup\` |
| **Gemini CLI** | `-SkillTarget Gemini` | `%USERPROFILE%\.gemini\skills\claude-cleanup\` |
| **Claude Code** | `-SkillTarget Claude` | `%USERPROFILE%\.claude\skills\claude-cleanup\` |

---

## 3. Mandatory Security Invariants for AI Agents / 智能体安全铁律

Any agent interacting with this toolkit must adhere strictly to these constraints:

### 3.1 Single Shared Backend Rule
- Agents must **never** duplicate destructive deletion, path inspection, or registry manipulation logic in Python scripts, shell one-liners, or custom skill scripts.
- All actions must be performed by executing `ClaudeCleanup.ps1` via the standard PowerShell host.

### 3.2 Read-Only Default Mode
- Invocations default strictly to read-only `-Audit` (or `-Verify` for post-checks).
- Agents must **never** run `-Plan` (which writes `CLEANUP-PLAN.md` and invalidates prior plan hashes) or `-Apply` unless the user explicitly asks.

### 3.3 Strict Human Authorization Gate for `-Apply`
- **Zero Autonomous Deletion**: Under NO circumstances may an AI agent automatically invoke `ClaudeCleanup.ps1 -Apply`.
- **Approval Protocol**:
  1. The agent runs `.\ClaudeCleanup.ps1 -Plan -OutputFormat Json`.
  2. The agent inspects `CLEANUP-PLAN.md` and reads the exact 64-hex SHA-256 manifest hash.
  3. The agent presents the proposed policy (`AccountData` or `FullRemoval`), the list of `Ready` items, and the exact SHA-256 hash to the human user.
  4. The agent prompts the human user for explicit approval.
  5. Only upon receiving explicit confirmation may the agent run `-Apply -Policy <Policy> -ApprovedManifestSha256 <Hash>`.

### 3.4 Structured JSON Interoperability
- Agents must invoke the script with `-OutputFormat Json` to receive clean, schema-validated JSON data (`SchemaVersion: 3`) rather than parsing unstructured console text.
- Example command:
  ```powershell
  powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\ClaudeCleanup.ps1 -Audit -OutputFormat Json
  ```

### 3.5 REA (Reverse Engineer Anything) Policy
- REA is strictly an optional development-time static analysis tool used during toolkit development.
- It is **never** a runtime dependency or requirement for agent skill execution.

---

## 4. Skill Package Structure / 技能包结构

The canonical skill directory is structured as follows:

```text
skills/claude-cleanup/
├── SKILL.md                          # Canonical skill definition, frontmatter, and workflow rules
└── references/
    ├── permissions-and-risks.md      # Risk disclosures, non-goals, and SHA-256 approval gates
    └── agent-installation.md         # Cross-CLI discovery paths and manual/scripted lifecycle
```

### Canonical Frontmatter (`skills/claude-cleanup/SKILL.md`)
```yaml
---
name: claude-cleanup
description: >-
  Audits, plans, verifies, and performs user-authorized local cleanup of Claude
  Code and Claude Desktop artifacts on Windows 10/11 by invoking ClaudeCleanup.ps1.
  Use when asked to inspect local Claude installations, caches, extensions, or
  residual keys, generate a SchemaVersion 3 cleanup plan, verify prior cleanup,
  or execute explicitly approved cleanup targets without duplicating deletion logic.
---
```

---

## 5. Skill Lifecycle Management / 技能生命周期管理

- **Installation**: Copies `skills/claude-cleanup/` to the target agent's skill directory. It does not alter agent global preferences, telemetry, or authentication settings.
- **Uninstallation**: Deletes the `claude-cleanup` directory from the agent's skill repository. Does not affect the underlying Windows Claude Cleanup Toolkit or Claude installations.
