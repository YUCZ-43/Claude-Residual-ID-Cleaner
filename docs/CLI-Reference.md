# Claude Residual ID Cleaner — CLI Command Reference

**Project:** Claude Residual ID Cleaner (`Claude 账号残余 ID 清理工具`)  
**Repository:** `YUCZ-43/Claude-Residual-ID-Cleaner`  
**Language Navigation:** [简体中文](../README.md) | [English](../README.en.md)

---

## 1. Syntax Overview / 语法概览

[ClaudeCleanup.ps1](../ClaudeCleanup.ps1) is the single shared PowerShell backend for scanning and safely removing leftover Windows Claude account/device metadata, auth tokens, and caches without altering Windows OS:

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
.\ClaudeCleanup.ps1 -Apply -Policy <AccountData|FullRemoval> -ApprovedManifestSha256 <64-Hex-Hash> [-CloseRunningProcesses] [-EmitProgress] [-Language Auto|zh-CN|en-US] [-OutputFormat Text|Json]

# Verify / 独立验证
.\ClaudeCleanup.ps1 -Verify [-Language Auto|zh-CN|en-US] [-OutputFormat Text|Json]
```

---

## 2. Parameter Reference / 参数说明

### 2.1 Mode Switches (Mutually Exclusive / 互斥运行模式)

| Parameter | Type | Description |
| :--- | :--- | :--- |
| `-Audit` | `[switch]` | Non-destructive, read-only discovery of Claude Code, Claude Desktop, VS Code/Cursor extensions, MSIX packages, browser host keys, shortcuts, running processes, and non-secret UUIDs. |
| `-Plan` | `[switch]` | Evaluates ownership and reparse safety (`Ready`, `ReviewOnly`, `Blocked`) and generates `CLEANUP-PLAN.md` (`SchemaVersion = 3`) with a unique `PlanId` and SHA-256 hash. |
| `-Apply` | `[switch]` | Executes handle-bound cleanup of `Ready` items matching `-Policy`. Requires `-ApprovedManifestSha256` and `ConfirmImpact = 'High'` confirmation. |
| `-Verify` | `[switch]` | Independently evaluates current host presence (`Present`, `Absent`, `Unknown`) against `CLEANUP-PLAN.md` and displays `VERIFICATION.md` ledger records. |
| `-Help` | `[switch]` | Displays concise usage, parameters, and safety boundaries, then exits. |

### 2.2 Operational Arguments / 执行控制参数

| Parameter | Type | Valid Values | Description |
| :--- | :--- | :--- | :--- |
| `-Policy` | `[string]` | `AccountData`, `FullRemoval` | Required for `-Apply`. Controls which `Ready` targets are eligible for deletion. |
| `-ApprovedManifestSha256` | `[string]` | 64-hex (`^[A-Fa-f0-9]{64}$`) | Required for `-Apply`. Must match `CLEANUP-PLAN.md` SHA-256; single-use per real `-Apply`. |
| `-OutputFormat` | `[string]` | `Text`, `Json` (Default: `Text`) | `Json` emits invariant schema keys regardless of `-Language`. |
| `-Language` | `[string]` | `Auto`, `zh-CN`, `en-US` (Default: `Auto`) | Controls runtime console text and localized Markdown reports with clean UTF-8 output. |
| `-SaveAuditReport` | `[switch]` | Optional with `-Audit` | Writes localized `AUDIT.md` (default `-Audit` writes nothing to disk). |
| `-CloseRunningProcesses` | `[switch]` | Optional with `-Apply` | Gracefully closes confirmed Claude processes (excluding this cleaner and its parent chain) before handle-bound deletion. |
| `-EmitProgress` | `[switch]` | Optional with `-Apply` | Streams structured `@@PROGRESS@@` JSON lines to StdErr for live desktop UI progress tracking while keeping StdOut JSON clean. |
| `-WhatIf` | `[switch]` | Built-in | Previews `-Plan` or `-Apply` without modifying disk or consuming the manifest SHA-256. |
| `-Confirm` | `[switch]` | Built-in | Confirms high-impact execution (`-Confirm:$false` only when explicitly authorized after review). |

---

## 3. Operational Policies / 清理策略对比

| Policy | Scope & Target Selection | Preserved Data / 安全保留 |
| :--- | :--- | :--- |
| **`AccountData`** | Clears Claude banned-account residuals: `.credentials.json`, `.claude.json` account metadata, `buddy-tokens.json`, `mcp-needs-auth-cache.json`, `stats-cache.json`, and Desktop caches/logs/`Local Storage`/`IndexedDB`. | **Preserved:** Custom `.claude` skills/commands/settings and `claude_desktop_config.json`. |
| **`FullRemoval`** | Complete user-level uninstallation of Claude Code binaries, `@anthropic-ai/claude-code` npm package, Claude Desktop configs/data, IDE extensions, MSIX package (`Claude_pzs8sxrjxfjjc`), and HKCU browser host keys. | When a parent folder is `Blocked` due to foreign ownership or reparse points, non-overlapping `Ready` children are evaluated individually. |

> **Note / 提示**: Local cleanup never alters remote Anthropic account records or quotas.

---

## 4. Output Format & Exit Codes / 输出规范与退出码

- **Text Mode (`-OutputFormat Text`)**: Tabular discovery, three-state presence (`Present` / `Absent` / `Unknown`), evaluation status (`Ready` / `ReviewOnly` / `Blocked`), and SHA-256 summary.
- **JSON Mode (`-OutputFormat Json`)**: Emits `SchemaVersion: 3` structured JSON for scripts, CI, and Agent Skills:

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

> **Privacy Rule / 隐私规则**: Environment variables report `Scope` and `Name` only; Credential Manager entries report target counts only.

| Exit Code | Condition |
| :--- | :--- |
| `0` | Successful completion of requested mode (`Audit`, `Plan`, `-WhatIf`, `Apply`, `Verify`, or `Help`). |
| `1` | Validation error, missing arguments, invalid SHA-256 format, replay violation, or policy block. |

---

## 5. Standard 5-Step CLI Workflow / 完整操作流程

```powershell
# 1. Read-only Audit (close Claude / VS Code processes if detected)
.\ClaudeCleanup.ps1 -Audit

# 2. Generate deterministic CLEANUP-PLAN.md and copy the 64-hex SHA-256 hash
.\ClaudeCleanup.ps1 -Plan

# 3. Non-destructive dry-run preview (does not consume the SHA-256 hash)
.\ClaudeCleanup.ps1 -Apply -Policy AccountData -ApprovedManifestSha256 <64-hex-hash> -WhatIf

# 4. Execute approved handle-bound cleanup (writes immutable entry to VERIFICATION.md)
.\ClaudeCleanup.ps1 -Apply -Policy AccountData -ApprovedManifestSha256 <64-hex-hash>

# 5. Independent post-cleanup verification
.\ClaudeCleanup.ps1 -Verify
```
