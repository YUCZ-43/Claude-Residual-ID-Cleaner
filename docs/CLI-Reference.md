# claude-cleanup — CLI Command Reference

**Project:** claude-cleanup (`Claude Residual ID Cleaner`)  
**Repository:** `YUCZ-43/claude-cleanup`  
**Language Navigation:** [简体中文](../README.md) | [English](../README.en.md)  
**Document Status:** Implemented for Core CLI & Stage H Bilingual Support

---

## 1. Syntax Overview / 语法概览

The primary CLI entry point is `ClaudeCleanup.ps1`. It is designed as a non-destructive Windows utility to scan and safely clean residual Claude account/device metadata, auth tokens, session caches, and leftover registrations after a Claude account ban — strictly without altering Windows OS itself:

```powershell
# Help / 帮助
.\ClaudeCleanup.ps1 -Help [-Language Auto|zh-CN|en-US]

# Audit / 只读审计
.\ClaudeCleanup.ps1 -Audit [-Language Auto|zh-CN|en-US] [-OutputFormat Text|Json] [-SaveAuditReport]

# Plan / 生成清理清单
.\ClaudeCleanup.ps1 -Plan [-Language Auto|zh-CN|en-US] [-OutputFormat Text|Json]
.\ClaudeCleanup.ps1 -Plan -WhatIf

# Apply / 执行清理 (需要预先批准的清单哈希与策略)
.\ClaudeCleanup.ps1 -Apply -Policy <AccountData|FullRemoval> -ApprovedManifestSha256 <64-Hex-Hash> [-Language Auto|zh-CN|en-US] [-OutputFormat Text|Json] -WhatIf
.\ClaudeCleanup.ps1 -Apply -Policy <AccountData|FullRemoval> -ApprovedManifestSha256 <64-Hex-Hash> [-Language Auto|zh-CN|en-US] [-OutputFormat Text|Json]

# Verify / 独立验证
.\ClaudeCleanup.ps1 -Verify [-Language Auto|zh-CN|en-US] [-OutputFormat Text|Json]
```

---

## 2. Parameter Reference / 参数说明

### 2.1 Mode Switches (Mutually Exclusive / 互斥运行模式)
Exactly one of the following primary mode switches must be specified per invocation:

| Parameter | Type | Required | Description |
| :--- | :--- | :--- | :--- |
| `-Audit` | `[switch]` | Optional | Executes a non-destructive, read-only discovery of Claude Code, Claude Desktop, VS Code extensions, MSIX packages, native host registry keys, shortcuts, and background services. |
| `-Plan` | `[switch]` | Optional | Inspects candidates, verifies ownership and reparse status, evaluates readiness (`Ready`, `ReviewOnly`, `Blocked`), and generates `CLEANUP-PLAN.md` containing a unique `PlanId` and SHA-256 hash. |
| `-Apply` | `[switch]` | Optional | Executes destructive cleanup of `Ready` items matching the approved policy. Requires `-Policy` and `-ApprovedManifestSha256`. Prompted by PowerShell `ConfirmImpact = 'High'`. |
| `-Verify` | `[switch]` | Optional | Performs an independent read-only evaluation of current host presence states (`Present`, `Absent`, `Unknown`) against `CLEANUP-PLAN.md` and displays execution records from `VERIFICATION.md`. |
| `-Help` | `[switch]` | Optional | Displays concise command usage, required arguments, and safety invariants, then exits immediately. |

### 2.2 Operational Arguments / 执行控制参数

| Parameter | Type | Valid Values | Description |
| :--- | :--- | :--- | :--- |
| `-Policy` | `[string]` | `AccountData`, `FullRemoval` | Required when `-Apply` is invoked. Specifies the boundary of items eligible for removal. |
| `-ApprovedManifestSha256` | `[string]` | 64-hex regex (`^[A-Fa-f0-9]{64}$`) | Required when `-Apply` is invoked. Must match the exact SHA-256 hash computed from `CLEANUP-PLAN.md`. Cannot be reused across executions. |
| `-OutputFormat` | `[string]` | `Text`, `Json` (Default: `Text`) | Selects the emission format. `Text` provides formatted console tables and summaries; `Json` outputs structured JSON objects with invariant schema keys regardless of `-Language`. |
| `-Language` | `[string]` | `Auto`, `zh-CN`, `en-US` (Default: `Auto`) | Selects runtime display and Markdown report language (`AUDIT.md`, `CLEANUP-PLAN.md`, `VERIFICATION.md`). `Auto` selects `zh-CN` when Windows UI culture matches `zh*`. Configures UTF-8 console encoding cleanly. |
| `-SaveAuditReport` | `[switch]` | Optional with `-Audit` | Explicitly writes localized `AUDIT.md` alongside running read-only audit (default `-Audit` writes nothing to disk). |
| `-WhatIf` | `[switch]` | PowerShell Built-in | Supported on `-Plan` and `-Apply`. Simulates execution without modifying disk files or consuming the manifest SHA-256 authorization. |
| `-Confirm` | `[switch]` | PowerShell Built-in | Overrides or confirms the high-impact interactive confirmation prompt (`-Confirm:$false` for scripted runs where authorization is explicitly established). |

---

## 3. Operational Policies / 清理策略对比

The toolkit strictly separates credential reset from total application uninstallation:

| Policy | Scope & Target Selection | Preserved Data / 安全保留 |
| :--- | :--- | :--- |
| **`AccountData`** | Confirmed CLI authentication caches, session tokens, app caches, and diagnostic logs. Designed for clearing logged-in account state. | **Preserved:** User workspace files, `.claude` custom skills/prompts, `.claude.json`, and Desktop mixed storage (`Local Storage` / `IndexedDB`). `buddy-tokens.json` remains `ReviewOnly`. |
| **`FullRemoval`** | Complete uninstallation of user-level Claude Code binaries, npm package, Desktop configurations, VS Code extensions, MSIX package (`Claude_pzs8sxrjxfjjc`), and browser native messaging keys. | If parent folders (`.claude`, `%APPDATA%\Claude`) are `Blocked` due to foreign ownership or reparse points, non-overlapping `Ready` child items are cleaned individually. |

> **Security Warning / 安全提示**: Local cleanup never modifies remote Anthropic account records or quotas. Mixed Desktop storage in `AccountData` mode may retain local UI session traces; full removal is required for total disk purging.

---

## 4. Output Format Specification / 输出格式规范

### 4.1 Text Mode (`-OutputFormat Text`)
Standard human-readable text outputting tabular sections:
- Discovered components and path locations
- Presence classification (`Present`, `Absent`, `Unknown`)
- Target evaluation status (`Ready`, `ReviewOnly`, `Blocked`)
- SHA-256 digest and plan instructions

### 4.2 JSON Mode (`-OutputFormat Json`)
Emits a structured JSON document adhering to `SchemaVersion: 3`. Suitable for programmatic consumption by scripts, CI runners, and Agent Skills (example from `-Audit -OutputFormat Json`):

```json
{
  "SchemaVersion": 3,
  "Mode": "Audit",
  "GeneratedUtc": "2026-11-16T20:00:00.0000000Z",
  "WindowsUser": "EXAMPLE-HOST\\example",
  "PowerShellVersion": "7.4.5",
  "Summary": {
    "NativeClaudeCode": {
      "Path": "C:\\Users\\example\\.local\\bin\\claude.exe",
      "Version": "2.1.0.0",
      "SignatureStatus": "Valid",
      "Company": "Anthropic PBC"
    },
    "NpmClaudePackages": [],
    "VsCode": { "ExtensionsRootState": "Present", "ExtensionDirs": [] },
    "AppDataClassification": [],
    "Shortcuts": [],
    "PathEntries": [{ "Scope": "User", "Entry": "C:\\Users\\example\\.local\\bin" }],
    "EnvironmentVariableNames": [{ "Scope": "User", "Name": "CLAUDE_CONFIG_DIR" }],
    "PathOverrides": [],
    "UninstallKeys": [],
    "ProtocolKeys": [],
    "AclDiagnostics": []
  },
  "EnvironmentLines": ["Credential Manager Claude* target count: 1"],
  "Inventory": []
}
```

> **Privacy Rule / 隐私规则**: In JSON mode, environment variables report only `Scope` and `Name`. Secret values are never extracted or emitted. Credential Manager entries report target counts only.

---

## 5. Exit Codes & Error Handling / 退出码与错误处理

| Exit Code | Condition |
| :--- | :--- |
| `0` | Successful completion of requested mode (Audit, Plan, WhatIf preview, Apply, Verify, or Help). |
| `1` | Validation error, missing required arguments, invalid hash format, schema mismatch, or operation blocked by security policy. |

The script executes under `Set-StrictMode -Version 2.0` and traps unhandled exceptions with fail-closed termination.

---

## 6. Step-by-Step CLI Workflow / 完整操作流程

### Step 1: Run Read-Only Audit
```powershell
.\ClaudeCleanup.ps1 -Audit
```
Examine identified artifacts, ACL diagnostics, and background processes. Ensure Claude Code and VS Code processes are closed before proceeding.

### Step 2: Generate Cleanup Plan
```powershell
.\ClaudeCleanup.ps1 -Plan
```
This generates `CLEANUP-PLAN.md` in the current project directory. Review the file and record the unique 64-hex SHA-256 hash printed at the end of the run.

### Step 3: Dry-Run Preview
```powershell
.\ClaudeCleanup.ps1 -Apply -Policy AccountData -ApprovedManifestSha256 <64-hex-hash> -WhatIf
```
Verifies the cryptographic digest, checks target reparse points, and previews actions without deleting files or consuming the hash.

### Step 4: Confirmed Execution
```powershell
.\ClaudeCleanup.ps1 -Apply -Policy AccountData -ApprovedManifestSha256 <64-hex-hash>
```
Confirm the high-impact prompt. Deletion executes using Win32 handle-bound APIs. The hash is recorded in `VERIFICATION.md` and cannot be reused.

### Step 5: Post-Action Verification
```powershell
.\ClaudeCleanup.ps1 -Verify
```
Independently verifies that deleted items are `Absent`, preserved items remain `Present`, and displays the immutable execution ledger.
