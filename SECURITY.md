# Security Policy

**Project:** claude-cleanup (`Claude Residual ID Cleaner`)  
**Repository:** `YUCZ-43/claude-cleanup`  
**Language Navigation:** [简体中文](README.md) | [English](README.en.md)

The **claude-cleanup** toolkit is engineered with a strict **fail-closed**, **defense-in-depth** security architecture designed to prevent accidental data loss, path traversal, link following, privilege abuse, or replay attacks.

---

## 1. Supported Versions

| Version | Supported | Description |
| :--- | :--- | :--- |
| `0.3.x` | Yes | Active development and release candidate branch |
| `< 0.3.0` | No | Early prototypes and security remediation stages |

Security fixes and hardening enhancements are committed directly to the primary branch (`main`). Users and operators are urged to run the latest reviewed version.

---

## 2. Threat Model & Security Invariants

The toolkit operates in environments where untrusted local processes, malicious filesystem links, or concurrent file activity may exist. The following security invariants are enforced at all times:

### 2.1 Handle-Bound Filesystem Deletion
- **No `Remove-Item` Fallback**: Deletion never delegates to shell cmdlets or path-based APIs that can be redirected between path resolution and deletion.
- **Explicit Win32 Flags**: Target files and directories are opened with `FILE_FLAG_OPEN_REPARSE_POINT | FILE_FLAG_BACKUP_SEMANTICS`.
- **Identity Verification**: File identity is queried on the open handle via `GetFileInformationByHandle` (recording `VolumeSerialNumber` and 64-bit `FileIndex`) and `GetFinalPathNameByHandleW`.
- **Disposition Control**: Deletion occurs on the verified open handle via `SetFileInformationByHandle` using `FileDispositionInfoEx` (with POSIX delete semantics where supported) or `FileDispositionInfo`.

### 2.2 Reparse Point and Link Traversal Protection
- **Zero Link Following**: Directory junctions, NTFS mount points, file symbolic links, directory symbolic links, and dangling links are strictly rejected.
- **Ancestor and Tree Inspection**: Every ancestor component in a target's path and every child node within a directory hierarchy is evaluated for reparse attributes (`FILE_ATTRIBUTE_REPARSE_POINT`). If any reparse point is detected, the target is classified as `Blocked` or `ReparseBlocked` and cannot be deleted by the engine.

### 2.3 Ownership and ACL Verification
- **Current User SID Requirement**: Every filesystem node in an eligible tree must be owned by the Security Identifier (SID) of the executing user account (`OwnerSid`).
- **No Automatic Privilege Modification**: If an object is owned by `BUILTIN\Administrators` (e.g., from an elevated CLI run) or another security principal, the toolkit reports `Blocked` or `OtherOwner`. It will **never** alter Windows Access Control Lists (ACLs), take ownership (`takeown`), or grant permissions.

### 2.4 Three-State Presence Classification
- The toolkit categorizes target presence strictly into three states:
  - `Present`: Confirmed existing on disk or in the registry.
  - `Absent`: Confirmed nonexistent on disk or in the registry.
  - `Unknown`: Access denied, permission error, IO exception, or environment query failure.
- **Fail-Closed Rule**: An `Unknown` state is **never** treated as `Absent` or `VerifiedAbsent`.

### 2.5 Open-Handle Registry Deletion
- **Strict Allowlist**: Registry targets are restricted to exact user-scoped Chrome and Edge Native Messaging host registrations (`com.anthropic.claude_browser_extension`).
- **Link & Subkey Checks**: Ancestor keys and the target key are verified with `REG_OPTION_OPEN_LINK` to ensure they are not registry symbolic links (`REG_LINK`). Subkey count must be zero.
- **Direct Handle Deletion**: Deletion is performed directly on the open validated handle via `ntdll!NtDeleteKey`.

### 2.6 Cryptographic Plan Binding & Replay Prevention
- **Single-Read In-Memory Verification**: `CLEANUP-PLAN.md` is read into memory once. Its SHA-256 hash is computed and the single embedded JSON manifest block (`SchemaVersion = 3`) is parsed from the exact same byte buffer.
- **Atomic Replay Guard**: Every successful execution appends an immutable entry to `VERIFICATION.md` using atomic file replacement (`temp file` + `FileStream.Flush($true)` + `File.Replace`/`Move`). A manifest SHA-256 hash can be consumed at most once; replaying an identical hash fails closed.

### 2.7 Fail-Closed Protected Paths
The toolkit prohibits targeting or traversing protected operating system and user roots:
- Filesystem root directories (`C:\`, `D:\`)
- Windows system folders (`%WINDIR%`, `%SystemRoot%`, `C:\Windows`)
- Program Files directories (`%ProgramFiles%`, `%ProgramFiles(x86)%`)
- Exact user profile roots (`%USERPROFILE%`, `%APPDATA%`, `%LOCALAPPDATA%`, `%ProgramData%`, `%PUBLIC%`, `%TEMP%`)
- Sibling agent configuration folders (`.codex`, `.agents`, `.gemini`)
- The project repository root itself (except designated temporary fixtures in `tests/sandbox/`)

---

## 3. Explicit Non-Goals & Anti-Abuse Stance

To prevent misuse and protect platform trust:
- **No Anti-Abuse Tampering**: The toolkit does NOT modify hardware hashes, network MAC addresses, machine GUIDs, device IDs, or telemetry identifiers.
- **No Proxy or Security Circumvention**: The toolkit does NOT alter proxy configurations, firewall rules, hosts files, or TLS certificates.
- **No Server-Side Claim**: Local cleanup affects only local filesystem and registry artifacts; it does not claim to alter remote Anthropic account records, server quotas, or backend access state.
- **No Credential Harvesting**: Windows Credential Manager Claude targets are inventoried by target name count only. Secret values are never read, decrypted, or exported.

---

## 4. Reporting a Security Vulnerability

If you discover a security vulnerability, security bypass, or unsafe filesystem condition in this project, please report it privately.

### How to Report
1. **Email Disclosure**: Send a detailed report to the repository security maintainers via the security contact listed on the repository's GitHub Security page or via email to `yucz43-security@users.noreply.github.com`.
2. **Details to Include**:
   - A clear description of the vulnerability (e.g., race condition, symlink bypass, unexpected file disposition).
   - Step-by-step reproduction instructions or a minimal Proof of Concept (PoC) running inside an isolated sandbox.
   - Operating system version (Windows 10/11 build) and PowerShell version (5.1 or 7.x).
   - Potential impact and suggested mitigations.
3. **Do Not Open Public Issues**: Please do **not** disclose security vulnerabilities through public GitHub Issues, pull requests, or public discussions until a patch has been released and coordinated.

### Vulnerability Response Timeline
- **Initial Acknowledgment**: Within 48 hours of receipt.
- **Assessment & Triage**: Within 5 business days.
- **Fix & Public Advisory**: Coordinated release within 30 days of confirmed reproduction.
