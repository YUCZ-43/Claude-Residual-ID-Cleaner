# Contributing to claude-cleanup

**Project:** claude-cleanup (`Claude Residual ID Cleaner`)  
**Repository:** `YUCZ-43/claude-cleanup`  
**Language Navigation:** [简体中文](README.md) | [English](README.en.md)

Thank you for your interest in contributing to **claude-cleanup**. This document provides development principles, coding standards, safety boundaries, and the required pull request checklist.

---

## 1. Core Engineering Principles

Every contribution must adhere to these foundational architectural invariants:

1. **Single Shared Backend**: All filesystem discovery, reparse-point inspection, Win32 handle-bound deletion, registry verification, manifest parsing, and execution ledger logic must reside within [ClaudeCleanup.ps1](ClaudeCleanup.ps1). Never duplicate destructive deletion logic in wrappers, launchers, installers, or Agent Skills.
2. **Dual PowerShell Compatibility**: Code must run identically and pass tests on both:
   - **Windows PowerShell 5.1** (`powershell.exe`, Desktop edition, CLR 4.0)
   - **PowerShell 7+** (`pwsh.exe`, Core edition, .NET 8+)
   - Adhere to C# 5 compilation standards in `Add-Type` blocks (e.g., no C# 6+ expression-bodied members or interpolated strings).
   - Ensure explicit array wrapping `@(...)` for single-element or null collections under `Set-StrictMode -Version 2.0`.
3. **Fail-Closed & Defense-in-Depth**:
   - Never fall back to path-based `Remove-Item` or `RegDeleteKeyW`.
   - Never treat `Unknown` presence or permission errors as `Absent` or `VerifiedAbsent`.
   - Never bypass errors with empty `catch` blocks or unqualified `-ErrorAction SilentlyContinue`.
4. **Strict Isolation & Privacy**:
   - Never create or modify live registry keys (`HKCU` or `HKLM`) during automated tests.
   - Never touch real user installations or real Claude configuration folders during test runs.
   - All test fixtures must be created inside `tests/sandbox/` and reliably cleaned up in a `finally` block.
   - Never commit or log real usernames, local host paths, Windows SIDs, or secret tokens.

---

## 2. Development Setup

### Prerequisites
- Windows 10 (64-bit) or Windows 11 (64-bit) with an NTFS primary volume.
- Windows PowerShell 5.1 (built into Windows).
- PowerShell 7.4+ (`pwsh`).
- Git for Windows.

### Recommended Workspace
Clone the repository locally:
```powershell
git clone https://github.com/YUCZ-43/claude-cleanup.git
cd claude-cleanup
```

---

## 3. Coding & Documentation Standards

- **Source Code & Identifiers**: Write all script functions, parameter names, C# P/Invoke structs, and technical comments in **English**.
- **User Documentation**: Maintain bilingual alignment between [README.md](README.md) (Simplified Chinese primary) and [README.en.md](README.en.md) (English). Substantive feature additions, parameter changes, and safety modifications must be updated in both documents simultaneously.
- **Markdown Links**: Use relative Markdown links between repository documentation files. Verify that all links resolve correctly without broken anchors.
- **Conventional Commits**: Use clear Conventional Commit prefixes:
  - `feat(...)`: New capability (e.g., structured JSON output, diagnostic checks)
  - `fix(...)`: Bug fix or security hardening
  - `docs(...)`: Documentation updates or sample reports
  - `test(...)`: Test suite additions or sandbox coverage improvements
  - `refactor(...)`: Non-functional code improvements

---

## 4. Testing & Verification Requirements

Before submitting changes or proposing commits, execute the full test suite under both PowerShell engines:

### Step 1: Script Syntax Validation
```powershell
# Windows PowerShell 5.1
powershell.exe -NoProfile -Command "
    \$errors = \$null
    [System.Management.Automation.Language.Parser]::ParseFile('.\ClaudeCleanup.ps1', [ref]\$null, [ref]\$errors)
    if (\$errors.Count -gt 0) { throw 'Syntax errors in ClaudeCleanup.ps1' }
"

# PowerShell 7+
pwsh.exe -NoProfile -Command "
    \$errors = \$null
    [System.Management.Automation.Language.Parser]::ParseFile('.\ClaudeCleanup.ps1', [ref]\$null, [ref]\$errors)
    if (\$errors.Count -gt 0) { throw 'Syntax errors in ClaudeCleanup.ps1' }
"
```

### Step 2: Automated Sandbox Test Suite
```powershell
# Windows PowerShell 5.1
powershell.exe -NoProfile -File .\tests\ClaudeCleanup.Tests.ps1

# PowerShell 7+
pwsh.exe -NoProfile -File .\tests\ClaudeCleanup.Tests.ps1
```

### Step 3: Honest Test Accounting
When documenting or submitting test results, never count `Skipped`, `NotExecuted`, or `Blocked` tests as `Passed`. Test reports must accurately distinguish:
- **Passed**: Directly asserted and verified in the test run.
- **Skipped**: Environmental privilege constraints (e.g., `SeCreateSymbolicLinkPrivilege` requiring Developer Mode or elevation).
- **NotExecuted**: Live mutating actions excluded by test isolation rules (e.g., live registry deletion, live package uninstallation).
- **Failed**: Any assertion failure (must be zero for acceptance).

### Step 4: Privacy & Git Exclusion Check
Ensure that temporary and sensitive files remain untracked:
```powershell
git status --short --ignored
```
- Verify that `AUDIT.md`, `CLEANUP-PLAN.md`, `VERIFICATION.md`, and `tests/sandbox/` are ignored by `.gitignore`.
- Never use `git add .` or `git add -A`. Stage explicit paths only:
  ```powershell
  git add ClaudeCleanup.ps1 docs/CLI-Reference.md
  ```

---

## 5. Security & Boundary Guardrails

1. **No Destructive Automation**: Automatic execution of `-Apply` is strictly forbidden. Neither tests, nor scripts, nor AI agents may run `-Apply` without explicit, interactive human confirmation of the manifest SHA-256 hash.
2. **Reverse Engineer Anything (REA)**: REA is an optional development-time static analysis tool only. It must never be introduced as a runtime dependency.
3. **No Account Bypass or Tampering**: PRs introducing MAC address spoofing, hardware ID spoofing, telemetry suppression, proxy redirection, or anti-abuse tampering will be closed immediately.
