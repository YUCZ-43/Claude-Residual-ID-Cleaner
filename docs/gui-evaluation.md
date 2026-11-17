# Native Windows Desktop GUI Architecture & Security Record

**Status:** Implemented in Stage H ([ClaudeCleanupGUI.cmd](../ClaudeCleanupGUI.cmd) + [ClaudeCleanupGUI.ps1](../scripts/ClaudeCleanupGUI.ps1))  
**Backend Contract:** [ClaudeCleanup.ps1](../ClaudeCleanup.ps1)  
**Console Entrypoint:** [ClaudeCleanupLauncher.cmd](../ClaudeCleanupLauncher.cmd) + [ClaudeCleanupLauncher.ps1](../scripts/ClaudeCleanupLauncher.ps1)  
**Project Documentation:** [README.md](../README.md) (简体中文) | [README.en.md](../README.en.md) (English)

---

## 1. Purpose and Scope

This document defines the architectural rationale and mandatory security constraints for the **zero-dependency native Windows Desktop GUI** ([ClaudeCleanupGUI.cmd](../ClaudeCleanupGUI.cmd) / [scripts/ClaudeCleanupGUI.ps1](../scripts/ClaudeCleanupGUI.ps1)) designed for scanning and safely removing residual local Claude account/device metadata, auth tokens, session caches, and extension state left behind after a Claude account ban — **strictly without altering or harming Windows OS itself**.

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

## 5. Stage H Implementation Summary

- **Chosen Implementation:** Native .NET WinForms desktop UI ([ClaudeCleanupGUI.cmd](../ClaudeCleanupGUI.cmd) + [scripts/ClaudeCleanupGUI.ps1](../scripts/ClaudeCleanupGUI.ps1)), avoiding compiled binaries, WebView2/Electron runtimes, and SmartScreen friction while running cleanly on stock Windows 10/11 under both Windows PowerShell 5.1 and PowerShell 7+.
- **Mandatory Security Verification:** Verified via [tests/BilingualAndGui.Tests.ps1](../tests/BilingualAndGui.Tests.ps1) that `scripts/ClaudeCleanupGUI.ps1` duplicates zero deletion APIs (`Remove-Item`, `SetFileInformationByHandle`, `NtDeleteKey` remain strictly in [ClaudeCleanup.ps1](../ClaudeCleanup.ps1)), starts `Clean Selected` disabled until `Scan` + `Preview Plan` complete, mandates `-WhatIf` preview + explicit confirmation dialog, and toggles cleanly between `zh-CN` and `en-US`.
