# Sample Cleanup Plan / 清理计划样例

> **Notice / 说明**: This is a sanitized sample cleanup plan for documentation, architecture reference, and testing. All IDs, SIDs, paths, and timestamps are synthetic placeholders (`PlanId: 00000000-0000-4000-8000-000000000001`, `example`). No real machine data or user tokens are present.

# Windows Claude cleanup plan

Plan ID: 00000000-0000-4000-8000-000000000001
Generated: 2026-11-16T12:00:00.0000000Z
No deletion has been performed. Only Decision=Ready entries can be applied after explicit approval of this exact file hash and one policy.
ReviewOnly and Blocked entries are excluded. Missing paths are omitted. WSL and browser site data are excluded.

| Policy | ID | Category | Path or package | Size (bytes) | Decision | Reason / warning |
| --- | --- | --- | --- | ---: | --- | --- |
| AccountData | appdata-cache | Desktop application cache | `C:\Users\example\AppData\Roaming\Claude\Cache` | 14820412 | Ready | Verified user-owned directory cache. |
| AccountData | appdata-logs | Diagnostic log files | `C:\Users\example\AppData\Roaming\Claude\logs` | 524288 | Ready | Verified diagnostic logs. |
| AccountData | config-dir | User configuration root | `C:\Users\example\.claude` | 2097152 | ReviewOnly | Contains custom user sessions and prompts; preserved under AccountData policy. |
| AccountData | unverified-token | Ambiguous credentials file | `C:\Users\example\AppData\Roaming\Claude\buddy-tokens.json` | 1024 | ReviewOnly | Unverified token format; requires manual user review. |
| FullRemoval | cli-native-bin | Claude Code native executable | `C:\Users\example\.local\bin\claude.exe` | 8912896 | Ready | Verified single-link user executable. |
| FullRemoval | npm-global-pkg | Global npm package | `@anthropic-ai/claude-code` | unknown | Ready | Validated npm package candidate. |
| FullRemoval | appdata-roaming | Desktop configuration root | `C:\Users\example\AppData\Roaming\Claude` | 45000000 | Ready | Verified tree owned by current user. |
| FullRemoval | msix-package | Claude Desktop AppX package | `Claude_pzs8sxrjxfjjc` | unknown | Ready | Verified MSIX package installed for current user. |
| FullRemoval | vscode-extension | VS Code extension | `anthropic.claude-code` | unknown | Ready | Verified VS Code extension. |
| FullRemoval | native-host-chrome | Browser native messaging host | `HKCU:\Software\Google\Chrome\NativeMessagingHosts\com.anthropic.claude_browser_extension` | 0 | Ready | Verified single key with 0 subkeys. |
| FullRemoval | admin-owned-tool | Elevated utility binary | `C:\ProgramData\Claude-Helper\helper.exe` | 409600 | Blocked | Target is not owned by the current user (Owner: BUILTIN\Administrators). |

<!-- MANIFEST-JSON-BEGIN -->
{
  "SchemaVersion": 3,
  "PlanId": "00000000-0000-4000-8000-000000000001",
  "GeneratedUtc": "2026-11-16T12:00:00.0000000Z",
  "UserSid": "S-1-5-21-<DOMAIN-ID>-1001",
  "UserProfile": "C:\\Users\\example",
  "Records": [
    {
      "Policy": "AccountData",
      "Id": "appdata-cache",
      "Category": "Desktop application cache",
      "Path": "C:\\Users\\example\\AppData\\Roaming\\Claude\\Cache",
      "Kind": "Filesystem",
      "SizeBytes": 14820412,
      "Decision": "Ready",
      "Reason": "Verified user-owned directory cache.",
      "Warning": "",
      "Ownership": "Current user verified"
    },
    {
      "Policy": "AccountData",
      "Id": "appdata-logs",
      "Category": "Diagnostic log files",
      "Path": "C:\\Users\\example\\AppData\\Roaming\\Claude\\logs",
      "Kind": "Filesystem",
      "SizeBytes": 524288,
      "Decision": "Ready",
      "Reason": "Verified diagnostic logs.",
      "Warning": "",
      "Ownership": "Current user verified"
    },
    {
      "Policy": "AccountData",
      "Id": "config-dir",
      "Category": "User configuration root",
      "Path": "C:\\Users\\example\\.claude",
      "Kind": "Filesystem",
      "SizeBytes": 2097152,
      "Decision": "ReviewOnly",
      "Reason": "Contains custom user sessions and prompts; preserved under AccountData policy.",
      "Warning": "",
      "Ownership": "Current user verified"
    },
    {
      "Policy": "AccountData",
      "Id": "unverified-token",
      "Category": "Ambiguous credentials file",
      "Path": "C:\\Users\\example\\AppData\\Roaming\\Claude\\buddy-tokens.json",
      "Kind": "Filesystem",
      "SizeBytes": 1024,
      "Decision": "ReviewOnly",
      "Reason": "Unverified token format; requires manual user review.",
      "Warning": "",
      "Ownership": "Current user verified"
    },
    {
      "Policy": "FullRemoval",
      "Id": "cli-native-bin",
      "Category": "Claude Code native executable",
      "Path": "C:\\Users\\example\\.local\\bin\\claude.exe",
      "Kind": "Filesystem",
      "SizeBytes": 8912896,
      "Decision": "Ready",
      "Reason": "Verified single-link user executable.",
      "Warning": "",
      "Ownership": "Current user verified"
    },
    {
      "Policy": "FullRemoval",
      "Id": "npm-global-pkg",
      "Category": "Global npm package",
      "Path": "@anthropic-ai/claude-code",
      "Kind": "NpmPackage",
      "SizeBytes": null,
      "Decision": "Ready",
      "Reason": "Validated npm package candidate.",
      "Warning": "",
      "Ownership": "Current user verified"
    },
    {
      "Policy": "FullRemoval",
      "Id": "appdata-roaming",
      "Category": "Desktop configuration root",
      "Path": "C:\\Users\\example\\AppData\\Roaming\\Claude",
      "Kind": "Filesystem",
      "SizeBytes": 45000000,
      "Decision": "Ready",
      "Reason": "Verified tree owned by current user.",
      "Warning": "",
      "Ownership": "Current user verified"
    },
    {
      "Policy": "FullRemoval",
      "Id": "msix-package",
      "Category": "Claude Desktop AppX package",
      "Path": "Claude_pzs8sxrjxfjjc",
      "Kind": "AppxPackage",
      "SizeBytes": null,
      "Decision": "Ready",
      "Reason": "Verified MSIX package installed for current user.",
      "Warning": "",
      "Ownership": "Current user verified"
    },
    {
      "Policy": "FullRemoval",
      "Id": "vscode-extension",
      "Category": "VS Code extension",
      "Path": "anthropic.claude-code",
      "Kind": "VsCodeExtension",
      "SizeBytes": null,
      "Decision": "Ready",
      "Reason": "Verified VS Code extension.",
      "Warning": "",
      "Ownership": "Current user verified"
    },
    {
      "Policy": "FullRemoval",
      "Id": "native-host-chrome",
      "Category": "Browser native messaging host",
      "Path": "HKCU:\\Software\\Google\\Chrome\\NativeMessagingHosts\\com.anthropic.claude_browser_extension",
      "Kind": "RegistryKey",
      "SizeBytes": 0,
      "Decision": "Ready",
      "Reason": "Verified single key with 0 subkeys.",
      "Warning": "",
      "Ownership": "Current user verified"
    },
    {
      "Policy": "FullRemoval",
      "Id": "admin-owned-tool",
      "Category": "Elevated utility binary",
      "Path": "C:\\ProgramData\\Claude-Helper\\helper.exe",
      "Kind": "Filesystem",
      "SizeBytes": 409600,
      "Decision": "Blocked",
      "Reason": "Target is not owned by the current user (Owner: BUILTIN\\Administrators).",
      "Warning": "",
      "Ownership": "Suspected / mixed"
    }
  ]
}
<!-- MANIFEST-JSON-END -->
