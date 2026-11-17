[CmdletBinding()]
param(
    [ValidateSet('Audit', 'Plan', 'ViewReports', 'Verify', 'Help', 'Exit')]
    [string]$Action,
    [switch]$Exit,
    [ValidateSet('Text', 'Json')]
    [string]$OutputFormat = 'Text',
    [string]$ToolkitRoot
)

Set-StrictMode -Version 2.0

function Resolve-LauncherToolkitRoot {
    param([string]$CandidateRoot)

    $rawRoot = if ([string]::IsNullOrWhiteSpace($CandidateRoot)) {
        Split-Path -Parent $PSScriptRoot
    } else {
        $CandidateRoot
    }
    if ([string]::IsNullOrWhiteSpace($rawRoot)) {
        throw 'ToolkitRoot could not be resolved.'
    }
    $fullRoot = [System.IO.Path]::GetFullPath($rawRoot)
    if (-not (Test-Path -LiteralPath $fullRoot -PathType Container)) {
        throw "ToolkitRoot does not exist: $fullRoot"
    }
    $backendPath = Join-Path $fullRoot 'ClaudeCleanup.ps1'
    if (-not (Test-Path -LiteralPath $backendPath -PathType Leaf)) {
        throw "Backend script ClaudeCleanup.ps1 not found under ToolkitRoot: $fullRoot"
    }
    return $fullRoot
}

function Get-FileSha256Hex {
    param([Parameter(Mandatory = $true)][string]$Path)

    $bytes = [System.IO.File]::ReadAllBytes($Path)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $hashBytes = $sha.ComputeHash($bytes)
        return ([System.BitConverter]::ToString($hashBytes).Replace('-', '').ToLowerInvariant())
    } finally {
        $sha.Dispose()
    }
}

function Get-ReportSummaryList {
    param([Parameter(Mandatory = $true)][string]$Root)

    $reportNames = @('AUDIT.md', 'CLEANUP-PLAN.md', 'VERIFICATION.md')
    $items = New-Object 'System.Collections.Generic.List[object]'

    foreach ($name in $reportNames) {
        $fullPath = Join-Path $Root $name
        if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
            $items.Add([pscustomobject]@{
                Name = $name
                Path = $fullPath
                Exists = $false
                SizeBytes = $null
                LastWriteUtc = $null
                Sha256 = $null
                PlanId = $null
                PreviewLines = @()
            })
            continue
        }

        $info = Get-Item -LiteralPath $fullPath
        $sha256 = Get-FileSha256Hex -Path $fullPath
        $lines = @([System.IO.File]::ReadAllLines($fullPath))
        $planId = $null
        foreach ($line in $lines) {
            if ($line -match '^Plan ID:\s*(.+)$') {
                $planId = $Matches[1].Trim()
                break
            }
        }
        $previewCount = [Math]::Min($lines.Count, 20)
        $preview = if ($previewCount -gt 0) { @($lines[0..($previewCount - 1)]) } else { @() }

        $items.Add([pscustomobject]@{
            Name = $name
            Path = $fullPath
            Exists = $true
            SizeBytes = [int64]$info.Length
            LastWriteUtc = $info.LastWriteTimeUtc.ToString('o')
            Sha256 = $sha256
            PlanId = $planId
            PreviewLines = $preview
        })
    }

    return $items.ToArray()
}

function Show-LauncherHelp {
    param(
        [Parameter(Mandatory = $true)][string]$BackendPath,
        [Parameter(Mandatory = $true)][string]$Root
    )

    Invoke-BackendScript -BackendPath $BackendPath -BackendArgs @('-Help')
    Write-Output ''
    Write-Output 'Launcher Safety Notice:'
    Write-Output "  Toolkit Root: $Root"
    Write-Output '  - This launcher exposes read-only/planning actions only (Audit, Plan, ViewReports, Verify, Help, Exit).'
    Write-Output '  - It never runs -Apply automatically, never overrides execution policy, and never requests UAC elevation.'
    Write-Output '  - To apply a reviewed plan, run ClaudeCleanup.ps1 -Apply -Policy <Policy> -ApprovedManifestSha256 <64-hex> directly in PowerShell.'
    Write-Output '  - Uninstalling this cleanup toolkit does NOT uninstall Claude or modify Claude user data.'
}

function Invoke-ViewReports {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][ValidateSet('Text', 'Json')][string]$Format
    )

    $reports = @(Get-ReportSummaryList -Root $Root)
    if ($Format -eq 'Json') {
        [pscustomobject]@{
            SchemaVersion = 1
            Mode = 'ViewReports'
            ToolkitRoot = $Root
            GeneratedUtc = [DateTime]::UtcNow.ToString('o')
            Reports = $reports
        } | ConvertTo-Json -Depth 6 | Write-Output
        return
    }

    Write-Output "Local Reports in $Root (read-only view):"
    foreach ($rep in $reports) {
        if (-not $rep.Exists) {
            Write-Output ("  - {0}: Absent" -f $rep.Name)
            continue
        }
        $planText = if ($rep.PlanId) { " PlanId=$($rep.PlanId)" } else { '' }
        Write-Output ("  - {0}: Present ({1} bytes, UTC {2}, SHA256={3}{4})" -f $rep.Name, $rep.SizeBytes, $rep.LastWriteUtc, $rep.Sha256, $planText)
    }

    $presentReports = @($reports | Where-Object { $_.Exists })
    if ($presentReports.Count -eq 0) {
        Write-Output 'No local reports found yet. Run Audit or Plan first.'
        return
    }

    foreach ($rep in $presentReports) {
        Write-Output ''
        Write-Output ("--- {0} (first {1} lines) ---" -f $rep.Name, @($rep.PreviewLines).Count)
        foreach ($line in @($rep.PreviewLines)) {
            Write-Output $line
        }
    }
}

function Invoke-BackendScript {
    param(
        [Parameter(Mandatory = $true)][string]$BackendPath,
        [Parameter(Mandatory = $true)][string[]]$BackendArgs
    )

    $psExe = (Get-Process -Id $PID).Path
    & $psExe -NoProfile -File $BackendPath @BackendArgs
    if ($LASTEXITCODE -ne 0) {
        throw "Backend script exited with code $LASTEXITCODE."
    }
}

function Invoke-LauncherAction {
    param(
        [Parameter(Mandatory = $true)][string]$SelectedAction,
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$BackendPath,
        [Parameter(Mandatory = $true)][ValidateSet('Text', 'Json')][string]$Format
    )

    switch ($SelectedAction) {
        'Audit' {
            Invoke-BackendScript -BackendPath $BackendPath -BackendArgs @('-Audit', '-OutputFormat', $Format)
        }
        'Plan' {
            Invoke-BackendScript -BackendPath $BackendPath -BackendArgs @('-Plan', '-OutputFormat', $Format)
        }
        'ViewReports' {
            Invoke-ViewReports -Root $Root -Format $Format
        }
        'Verify' {
            Invoke-BackendScript -BackendPath $BackendPath -BackendArgs @('-Verify', '-OutputFormat', $Format)
        }
        'Help' {
            Show-LauncherHelp -BackendPath $BackendPath -Root $Root
        }
        'Exit' {
            Write-Output 'Exiting Windows Claude Cleanup Launcher.'
        }
        default {
            throw "Unsupported launcher action: $SelectedAction"
        }
    }
}

function Show-LauncherMenu {
    param([Parameter(Mandatory = $true)][string]$Root)

    Write-Output ''
    Write-Output '============================================================'
    Write-Output ' Windows Claude Cleanup Toolkit - Safe Menu Launcher'
    Write-Output '============================================================'
    Write-Output "Toolkit Root : $Root"
    Write-Output 'Safety Mode  : Audit / Plan / View Reports / Verify / Help'
    Write-Output '               (No -Apply, no Policy bypass, no UAC elevation)'
    Write-Output '------------------------------------------------------------'
    Write-Output '  [1] Audit        - Read-only Claude environment discovery'
    Write-Output '  [2] Plan         - Generate CLEANUP-PLAN.md (SchemaVersion 3)'
    Write-Output '  [3] View Reports - Inspect local AUDIT / PLAN / VERIFICATION'
    Write-Output '  [4] Verify       - Check current state vs. plan and ledger'
    Write-Output '  [5] Help         - CLI usage and safety boundaries'
    Write-Output '  [6] Exit         - Close launcher'
    Write-Output '------------------------------------------------------------'
}

try {
    $resolvedRoot = Resolve-LauncherToolkitRoot -CandidateRoot $ToolkitRoot
    $backendPath = Join-Path $resolvedRoot 'ClaudeCleanup.ps1'

    $hasAction = $PSBoundParameters.ContainsKey('Action') -and -not [string]::IsNullOrWhiteSpace($Action)
    if ($hasAction -or $Exit) {
        $effectiveAction = if ($hasAction) { $Action } else { 'Exit' }
        Invoke-LauncherAction -SelectedAction $effectiveAction -Root $resolvedRoot -BackendPath $backendPath -Format $OutputFormat
        exit 0
    }

    $choiceMap = @{
        '1' = 'Audit'
        'audit' = 'Audit'
        '2' = 'Plan'
        'plan' = 'Plan'
        '3' = 'ViewReports'
        'view' = 'ViewReports'
        'viewreports' = 'ViewReports'
        'reports' = 'ViewReports'
        '4' = 'Verify'
        'verify' = 'Verify'
        '5' = 'Help'
        'help' = 'Help'
        '6' = 'Exit'
        'exit' = 'Exit'
        'q' = 'Exit'
        'quit' = 'Exit'
    }

    while ($true) {
        Show-LauncherMenu -Root $resolvedRoot
        $rawInput = Read-Host 'Select an option [1-6]'
        if ($null -eq $rawInput) {
            break
        }
        $key = $rawInput.Trim().ToLowerInvariant()
        if (-not $choiceMap.ContainsKey($key)) {
            Write-Output "Invalid selection '$rawInput'. Enter 1-6 or Exit."
            continue
        }

        $selected = $choiceMap[$key]
        if ($selected -eq 'Exit') {
            Invoke-LauncherAction -SelectedAction 'Exit' -Root $resolvedRoot -BackendPath $backendPath -Format $OutputFormat
            break
        }

        Write-Output ''
        try {
            Invoke-LauncherAction -SelectedAction $selected -Root $resolvedRoot -BackendPath $backendPath -Format $OutputFormat
        } catch {
            Write-Output ("[ERROR] Action '{0}' failed: {1}" -f $selected, $_.Exception.Message)
        }
    }
    exit 0
} catch {
    Write-Error $_.Exception.Message
    exit 1
}
