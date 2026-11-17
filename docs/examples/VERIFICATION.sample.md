# Sample Verification Report / 验证与账本样例

> **Notice / 说明**: This is a sanitized sample verification report and execution ledger for documentation and testing. All IDs, hashes, paths, and timestamps are synthetic placeholders (`PlanId: 00000000-0000-4000-8000-000000000001`, `example`). No real machine data or audit traces are contained in this document.

# Execution verification log

**Verified Timestamp:** 2026-11-16T12:05:00.0000000Z  
**Active Plan ID:** `00000000-0000-4000-8000-000000000001`  
**Manifest SHA-256:** `0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef`  
**Applied Policy:** `FullRemoval`  
**Execution Outcome:** `Succeeded`

---

## 1. Post-Execution Target Verification

| Policy | Item ID | Category | Target Path / Identifier | Prior Decision | Post-Check State | Verified Absent |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| FullRemoval | `cli-native-bin` | Claude Code CLI | `C:\Users\example\.local\bin\claude.exe` | Ready | `Absent` | **True** |
| FullRemoval | `npm-global-pkg` | npm global package | `@anthropic-ai/claude-code` | Ready | `Absent` | **True** |
| FullRemoval | `appdata-roaming` | Desktop AppData | `C:\Users\example\AppData\Roaming\Claude` | Ready | `Absent` | **True** |
| FullRemoval | `msix-package` | AppX Package | `Claude_pzs8sxrjxfjjc` | Ready | `Absent` | **True** |
| FullRemoval | `vscode-extension` | VS Code extension | `anthropic.claude-code` | Ready | `Absent` | **True** |
| FullRemoval | `native-host-chrome` | Browser Native Host | `HKCU:\Software\Google\Chrome\NativeMessagingHosts\...` | Ready | `Absent` | **True** |
| FullRemoval | `admin-owned-tool` | Utility binary | `C:\ProgramData\Claude-Helper\helper.exe` | Blocked | `Present` | **False** (Protected) |

---

## 2. Summary of Verification States

- **Confirmed Deleted (`Absent`)**: 6 targets successfully removed via handle-bound Win32 disposition and official uninstallation handlers.
- **Protected Preserved (`Present`)**: 1 target preserved due to security policy (`BUILTIN\Administrators` ownership; protected from unprivileged mutation).
- **Indeterminate / Access Denied (`Unknown`)**: 0 targets.

---

<!-- EXECUTION-LEDGER-BEGIN -->
[
  {
    "PlanId": "00000000-0000-4000-8000-000000000001",
    "ManifestSha256": "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
    "Policy": "FullRemoval",
    "StartedUtc": "2026-11-16T12:04:30.0000000Z",
    "CompletedUtc": "2026-11-16T12:04:35.0000000Z",
    "Outcome": "Succeeded",
    "Results": [
      {
        "Id": "cli-native-bin",
        "Policy": "FullRemoval",
        "Kind": "Filesystem",
        "Path": "C:\\Users\\example\\.local\\bin\\claude.exe",
        "Status": "Removed",
        "ItemsRemoved": 1,
        "ItemsFailed": 0,
        "PartialRemoval": false,
        "RemainingExists": false,
        "PresenceState": "Absent",
        "VerifiedAbsent": true,
        "Error": ""
      },
      {
        "Id": "npm-global-pkg",
        "Policy": "FullRemoval",
        "Kind": "NpmPackage",
        "Path": "@anthropic-ai/claude-code",
        "Status": "Removed",
        "ItemsRemoved": 1,
        "ItemsFailed": 0,
        "PartialRemoval": false,
        "RemainingExists": false,
        "PresenceState": "Absent",
        "VerifiedAbsent": true,
        "Error": ""
      },
      {
        "Id": "appdata-roaming",
        "Policy": "FullRemoval",
        "Kind": "Filesystem",
        "Path": "C:\\Users\\example\\AppData\\Roaming\\Claude",
        "Status": "Removed",
        "ItemsRemoved": 142,
        "ItemsFailed": 0,
        "PartialRemoval": false,
        "RemainingExists": false,
        "PresenceState": "Absent",
        "VerifiedAbsent": true,
        "Error": ""
      },
      {
        "Id": "msix-package",
        "Policy": "FullRemoval",
        "Kind": "AppxPackage",
        "Path": "Claude_pzs8sxrjxfjjc",
        "Status": "Removed",
        "ItemsRemoved": 1,
        "ItemsFailed": 0,
        "PartialRemoval": false,
        "RemainingExists": false,
        "PresenceState": "Absent",
        "VerifiedAbsent": true,
        "Error": ""
      },
      {
        "Id": "vscode-extension",
        "Policy": "FullRemoval",
        "Kind": "VsCodeExtension",
        "Path": "anthropic.claude-code",
        "Status": "Removed",
        "ItemsRemoved": 1,
        "ItemsFailed": 0,
        "PartialRemoval": false,
        "RemainingExists": false,
        "PresenceState": "Absent",
        "VerifiedAbsent": true,
        "Error": ""
      },
      {
        "Id": "native-host-chrome",
        "Policy": "FullRemoval",
        "Kind": "RegistryKey",
        "Path": "HKCU:\\Software\\Google\\Chrome\\NativeMessagingHosts\\com.anthropic.claude_browser_extension",
        "Status": "Removed",
        "ItemsRemoved": 1,
        "ItemsFailed": 0,
        "PartialRemoval": false,
        "RemainingExists": false,
        "PresenceState": "Absent",
        "VerifiedAbsent": true,
        "Error": ""
      }
    ]
  }
]
<!-- EXECUTION-LEDGER-END -->
