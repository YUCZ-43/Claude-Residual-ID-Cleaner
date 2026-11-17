# Sample Audit Report / 审计报告样例

> **Notice / 说明**: This is a sanitized sample report for documentation and testing purposes. All usernames, paths, SIDs, and timestamps are synthetic placeholders (`example`, `S-1-5-21-<DOMAIN-ID>-1001`). No real host data or credentials are contained in this document.

**Generated:** 2026-11-16T12:00:00.0000000Z  
**Host Platform:** Windows 11 Pro 64-bit (Build 22631)  
**Execution Scope:** Standard User (`example`, SID: `S-1-5-21-<DOMAIN-ID>-1001`)  
**PowerShell Engine:** PowerShell 7.4.5 (CoreCLR 8.0.8)

---

## 1. Discovered Applications & Extensions

### 1.1 Claude Code CLI
- **Native Executable**: `C:\Users\example\.local\bin\claude.exe`
  - Presence: `Present`
  - File Version: `2.1.311.0`
  - Authenticode Signature: `Valid` (Anthropic PBC)
  - Owner: `example` (`S-1-5-21-<DOMAIN-ID>-1001`)
- **Global npm Package**:
  - Global Prefix: `C:\Users\example\AppData\Roaming\npm`
  - Package: `@anthropic-ai/claude-code`
  - Version: `0.2.29`
  - Presence: `Present`

### 1.2 Claude Desktop (MSIX)
- **Package Full Name**: `Claude_pzs8sxrjxfjjc`
- **Install Location**: `C:\Program Files\WindowsApps\Claude_1.0.0.0_x64__pzs8sxrjxfjjc` (OS-managed)
- **Presence**: `Present`
- **Cowork Service**: Detected (`CoworkVMService` installed)

### 1.3 Development Environments (VS Code / Editors)
- **VS Code CLI**: `C:\Users\example\AppData\Local\Programs\Microsoft VS Code\bin\code.cmd`
- **Extensions Root**: `C:\Users\example\.vscode\extensions`
- **Claude Extension**: `anthropic.claude-code-0.1.15`
  - Presence: `Present`
  - Shared `.obsolete` File: Verified (contains no active reference)

---

## 2. Local Configuration & AppData Classification

| Path | Classification | Presence | ACL / Owner Status |
| :--- | :--- | :--- | :--- |
| `C:\Users\example\.claude` | UserSessionOrMixed | `Present` | `Ok` (Owned by current user) |
| `C:\Users\example\.claude.json` | UserSessionOrMixed | `Present` | `Ok` (Owned by current user) |
| `C:\Users\example\AppData\Roaming\Claude` | UserSessionOrMixed | `Present` | `Ok` (Owned by current user) |
| `C:\Users\example\AppData\Roaming\Claude\Cache` | Cache | `Present` | `Ok` (Owned by current user) |
| `C:\Users\example\AppData\Roaming\Claude\logs` | Diagnostics | `Present` | `Ok` (Owned by current user) |
| `C:\Users\example\AppData\Local\Claude` | Cache | `Present` | `Ok` (Owned by current user) |

---

## 3. Browser Integrations & Registrations

- **Google Chrome Native Messaging Host**:
  - Registry Key: `HKCU:\Software\Google\Chrome\NativeMessagingHosts\com.anthropic.claude_browser_extension`
  - Status: `Present`
  - Manifest Target: `C:\Users\example\AppData\Roaming\Claude\native_host.json`
- **Microsoft Edge Native Messaging Host**:
  - Registry Key: `HKCU:\Software\Microsoft\Edge\NativeMessagingHosts\com.anthropic.claude_browser_extension`
  - Status: `Present`

---

## 4. Residuals & Background Services

- **Start Menu / Desktop Shortcuts**:
  - `C:\Users\example\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Claude.lnk` (Target: Claude Desktop)
- **Environment Variables**:
  - User: `CLAUDE_CONFIG_DIR` (Name reported; secret values omitted by policy)
- **PATH Environment Entries**:
  - Contains `C:\Users\example\.local\bin`
  - Contains `C:\Users\example\AppData\Roaming\npm`
- **Credential Manager**:
  - Identified 1 generic target matching pattern `Claude*` (Secret value never read)
- **WSL Distributions**:
  - Running: `False`
  - Installed: `Ubuntu-22.04` (Read-only status: isolated)
