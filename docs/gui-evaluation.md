# Optional Future GUI Thin-Wrapper Feasibility Evaluation

**Status:** Evaluation Only (`Planned` / Stage E+; **not implemented** in the current release)  
**Backend Contract:** [ClaudeCleanup.ps1](../ClaudeCleanup.ps1)  
**Current Non-Technical Entrypoint:** [ClaudeCleanupLauncher.cmd](../ClaudeCleanupLauncher.cmd) + [ClaudeCleanupLauncher.ps1](../scripts/ClaudeCleanupLauncher.ps1)  
**Project Documentation:** [README.md](../README.md) | [README_zh-CN.md](../README_zh-CN.md)

---

## 1. Purpose and Scope

This document evaluates whether an optional graphical user interface (GUI) thin wrapper should be built on top of [ClaudeCleanup.ps1](../ClaudeCleanup.ps1) in a future milestone (Stage E+), and defines the mandatory architectural, security, and maintainability constraints if one is pursued.

Core non-negotiable invariant:
- **Single Tested Backend:** All path validation, handle-bound deletion (`SetFileInformationByHandle`), registry deletion (`NtDeleteKey`), `SchemaVersion = 3` manifest signing/verification, and atomic ledger checks remain exclusively inside [ClaudeCleanup.ps1](../ClaudeCleanup.ps1). Any future GUI must act solely as a presentation and explicit-confirmation shell invoking `ClaudeCleanup.ps1` out-of-process with `-OutputFormat Json` and `-File` (never duplicating deletion logic).

---

## 2. Current Baseline vs. User Need

The repository currently provides:
1. **CLI Interface ([ClaudeCleanup.ps1](../ClaudeCleanup.ps1)):** Supports `-Audit`, `-Plan`, `-Apply -Policy ... -ApprovedManifestSha256 ... [-WhatIf]`, `-Verify`, `-Help`, and structured `-OutputFormat Json` output.
2. **Menu Launcher ([ClaudeCleanupLauncher.cmd](../ClaudeCleanupLauncher.cmd) + [ClaudeCleanupLauncher.ps1](../scripts/ClaudeCleanupLauncher.ps1)):** Covers the safe nontechnical workflow (`Audit`, `Plan`, `View Reports`, `Verify`, `Help`, `Exit`) without `-ExecutionPolicy Bypass`, without auto-UAC elevation, and without automatic `-Apply`.
3. **User-Scoped Lifecycle Scripts ([Install-ClaudeCleanup.ps1](../scripts/Install-ClaudeCleanup.ps1), [Update-ClaudeCleanup.ps1](../scripts/Update-ClaudeCleanup.ps1), [Uninstall-ClaudeCleanup.ps1](../scripts/Uninstall-ClaudeCleanup.ps1)):** Manage toolkit and optional Agent Skill files cleanly in user space.

Why a GUI might still be considered later:
- Some nontechnical desktop users prefer visual tables distinguishing `Ready`, `ReviewOnly`, and `Blocked` items, one-click `-Audit` / `-Plan` / `-Verify` tabs, and a side-by-side comparison of `AccountData` vs. `FullRemoval` rather than reading console tables or Markdown manifests.

---

## 3. Candidate Technology Evaluation

| Option | Runtime & Build Dependencies | PS 5.1 / PS 7 Compatibility | Security & Transparency | Maintenance Cost | Verdict |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **A. Console Menu Launcher (Current)** | Pure Windows 10/11 + built-in PowerShell | Native 5.1 & 7+ | Full plain-text inspectability; zero binary signing / SmartScreen friction | Very Low | **Keep as Default** |
| **B. PowerShell + WPF Thin Wrapper (`.ps1` + XAML)** | Built-in .NET PresentationFramework (Windows desktop) | PS 5.1 (`-Sta` needed) & PS 7 on Windows | Plain-text source inspectable; invokes `ClaudeCleanup.ps1 -OutputFormat Json` directly | Low–Medium | **Best Optional GUI Choice** |
| **C. WinUI 3 / .NET 8 Native Desktop App** | Requires .NET Desktop SDK / Windows App SDK build & packaging | Independent of PS host; shells out to `pwsh`/`powershell` | Compiled `.exe` triggers Windows SmartScreen without paid Authenticode signing | High | **Not Recommended Now** |
| **D. Electron / Tauri / WebView2** | WebView2 / Chromium bundle + JS build toolchain | Shells out to PowerShell | Large attack surface (IPC/XSS/local bridge), heavy footprint for a small local utility | High | **Rejected** |

### Detailed Tradeoffs

1. **PowerShell + WPF Thin Wrapper (Option B):**
   - **Pros:** Ships as inspectable PowerShell/XAML script without requiring Visual Studio, MSBuild, Node.js, or binary releases; consumes `ClaudeCleanup.ps1 -OutputFormat Json` natively; works cleanly with existing user-scoped installation.
   - **Cons:** Requires STA thread initialization (`powershell.exe -Sta -NoProfile -File ...` or `pwsh.exe -Sta ...`), careful DPI/high-contrast testing, and async runspace/process handling so the UI stays responsive while `-Audit` or `-Plan` runs.

2. **Compiled WinUI 3 / WPF `.exe` (Option C):**
   - **Pros:** Modern Fluent UI controls and smooth async progress indicators.
   - **Cons:** Introduces a compiled binary release artifact that cannot be casually inspected as plain text, increases SmartScreen warnings for unsigned community tools, and adds CI build/signing complexity.

3. **Electron / WebView2 (Option D):**
   - **Pros:** Flexible web styling.
   - **Cons:** Disproportionately heavy runtime/tooling dependency for a security-sensitive Windows utility; contradicts the project's minimal native Windows dependency posture.

---

## 4. Mandatory Security Requirements for Any Future GUI

If a thin GUI wrapper is implemented in a future stage, it **must** enforce all of the following rules:

1. **Read-Only Default:** Launching the GUI must never delete files, generate mutations automatically, or run `-Apply` on startup.
2. **No ExecutionPolicy Bypass & No Auto-Elevation:** Launch via standard `-NoProfile -Sta -File` invocation without `-ExecutionPolicy Bypass` and without auto-triggering UAC (`RunAs`).
3. **Structured Process Boundary (No Shell Interpolation):** Invoke `ClaudeCleanup.ps1` using argument arrays (`ProcessStartInfo.ArgumentList` in .NET or splatted PowerShell arguments) — never `cmd /c` string concatenation or `Invoke-Expression`.
4. **Explicit High-Friction `-Apply` Gate (If Ever Exposed):**
   - Display `PlanId`, `GeneratedUtc`, full 64-hex `ApprovedManifestSha256`, selected `Policy` (`AccountData` vs. `FullRemoval`), and explicit lists of `Ready`, `ReviewOnly`, and `Blocked` items.
   - Default to `-Apply ... -WhatIf` preview before enabling live execution.
   - Require explicit user confirmation (such as typing or confirming the policy name and manifest hash prefix/checksum acknowledgment) before invoking `ClaudeCleanup.ps1 -Apply`.
   - Never hide or auto-approve PowerShell `ConfirmImpact = 'High'` prompts silently without user intent.
5. **No Secret Exposure:** Do not display or log Credential Manager secret values, tokens, or unrelated user files (rely solely on `ClaudeCleanup.ps1 -OutputFormat Json` sanitized fields).
6. **Clean Uninstallation Separation:** GUI installation/removal must follow [Uninstall-ClaudeCleanup.ps1](../scripts/Uninstall-ClaudeCleanup.ps1) and never uninstall Claude applications or delete Claude user data when removing the toolkit.

---

## 5. Recommendation and Go / No-Go Criteria

- **Recommendation:** **Defer GUI implementation** until after Stage D (Cross-Agent Skill) and Stage F (CI, documentation, and release packaging) are complete. Keep [ClaudeCleanupLauncher.cmd](../ClaudeCleanupLauncher.cmd) + [ClaudeCleanupLauncher.ps1](../scripts/ClaudeCleanupLauncher.ps1) as the supported nontechnical entrypoint in Stage E.
- **Trigger to Revisit (Go Criteria for Stage E+):**
  1. Core backend coverage (Stages A–C), Agent Skill (Stage D), and CI matrix (Stage F) are stable and passing on both Windows PowerShell 5.1 and PowerShell 7+.
  2. Real-world user feedback indicates that the text menu launcher and generated `AUDIT.md` / `CLEANUP-PLAN.md` / `VERIFICATION.md` tables are insufficient for nontechnical users.
  3. Any prototype is scoped strictly as a PowerShell + WPF read-only/preview-first thin wrapper over `ClaudeCleanup.ps1 -OutputFormat Json`, with dedicated Pester/sandbox tests verifying zero duplicated deletion logic.
