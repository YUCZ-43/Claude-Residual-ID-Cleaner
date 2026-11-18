[CmdletBinding()]
param(
    [ValidateSet('Audit', 'Plan', 'ViewReports', 'Verify', 'Help', 'LaunchGui', 'Exit')]
    [string]$Action,
    [switch]$Exit,
    [ValidateSet('Text', 'Json')]
    [string]$OutputFormat = 'Text',
    [ValidateSet('Auto', 'zh-CN', 'en-US')]
    [string]$Language = 'Auto',
    [string]$ToolkitRoot
)

Set-StrictMode -Version 2.0

function Initialize-LauncherUtf8Encoding {
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    $script:OutputEncoding = $utf8NoBom
    $global:OutputEncoding = $utf8NoBom
    try { [Console]::OutputEncoding = $utf8NoBom } catch {}
    try { [Console]::InputEncoding = $utf8NoBom } catch {}
}

function Resolve-LauncherLanguage {
    param([string]$Requested = $Language)

    if ($Requested -eq 'zh-CN' -or $Requested -eq 'en-US') {
        return $Requested
    }
    try {
        if ([System.Globalization.CultureInfo]::CurrentUICulture.Name -like 'zh*') {
            return 'zh-CN'
        }
    } catch {}
    return 'en-US'
}

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
        $lines = @([System.IO.File]::ReadAllLines($fullPath, [System.Text.Encoding]::UTF8))
        $planId = $null
        foreach ($line in $lines) {
            if ($line -match '^(?:Plan ID|计划 ID):\s*(.+)$') {
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
        [Parameter(Mandatory = $true)][string]$Root,
        [string]$Lang = 'en-US'
    )

    Invoke-BackendScript -BackendPath $BackendPath -BackendArgs @('-Help', '-Language', $Lang)
    Write-Output ''
    if ($Lang -eq 'zh-CN') {
        Write-Output '启动器安全提示:'
        Write-Output "  工具根目录: $Root"
        Write-Output '  - 专用于扫描与清理 Claude 账号封禁后的本地残余数据，绝不改动或损害 Windows 操作系统本身。'
        Write-Output '  - 本启动器仅提供只读/方案菜单 (Audit、Plan、ViewReports、Verify、Help、LaunchGui、Exit)。'
        Write-Output '  - 绝不自动执行 -Apply，不使用 ExecutionPolicy Bypass，不自动请求 UAC 提权。'
        Write-Output '  - 卸载本清理工具绝不会卸载 Claude 软件或删除您的正常用户数据。'
    } else {
        Write-Output 'Launcher Safety Notice:'
        Write-Output "  Toolkit Root: $Root"
        Write-Output '  - Designed to scan and clean Claude banned-account local residuals without altering Windows OS.'
        Write-Output '  - This launcher exposes safe menu actions only (Audit, Plan, ViewReports, Verify, Help, LaunchGui, Exit).'
        Write-Output '  - It never runs -Apply automatically, never overrides execution policy, and never requests UAC elevation.'
        Write-Output '  - Uninstalling this cleanup toolkit does NOT uninstall Claude or modify Claude user data.'
    }
}

function Invoke-ViewReports {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][ValidateSet('Text', 'Json')][string]$Format,
        [string]$Lang = 'en-US'
    )

    $reports = @(Get-ReportSummaryList -Root $Root)
    if ($Format -eq 'Json') {
        [pscustomobject]@{
            SchemaVersion = 1
            Mode = 'ViewReports'
            Language = $Lang
            ToolkitRoot = $Root
            GeneratedUtc = [DateTime]::UtcNow.ToString('o')
            Reports = $reports
        } | ConvertTo-Json -Depth 6 | Write-Output
        return
    }

    $isZh = ($Lang -eq 'zh-CN')
    if ($isZh) { Write-Output "$Root 中的本地报告（只读查看）:" }
    else { Write-Output "Local Reports in $Root (read-only view):" }

    foreach ($rep in $reports) {
        if (-not $rep.Exists) {
            if ($isZh) { Write-Output ("  - {0}: 未生成 (Absent)" -f $rep.Name) }
            else { Write-Output ("  - {0}: Absent" -f $rep.Name) }
            continue
        }
        $planText = if ($rep.PlanId) { " PlanId=$($rep.PlanId)" } else { '' }
        Write-Output ("  - {0}: Present ({1} bytes, UTC {2}, SHA256={3}{4})" -f $rep.Name, $rep.SizeBytes, $rep.LastWriteUtc, $rep.Sha256, $planText)
    }

    $presentReports = @($reports | Where-Object { $_.Exists })
    if ($presentReports.Count -eq 0) {
        if ($isZh) { Write-Output '暂未找到本地报告，请先运行“扫描审计 (Audit)”或“生成清理方案 (Plan)”。' }
        else { Write-Output 'No local reports found yet. Run Audit or Plan first.' }
        return
    }

    foreach ($rep in $presentReports) {
        Write-Output ''
        Write-Output ("--- {0} (preview {1} lines) ---" -f $rep.Name, @($rep.PreviewLines).Count)
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

function Invoke-LaunchGuiAction {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$Lang,
        [switch]$DryExitOnly
    )

    $guiScript = Join-Path $Root 'scripts\ClaudeCleanupGUI.ps1'
    if (-not (Test-Path -LiteralPath $guiScript -PathType Leaf)) {
        throw "Native GUI script not found: $guiScript"
    }
    $psExe = (Get-Process -Id $PID).Path
    if ($DryExitOnly) {
        if ($Lang -eq 'zh-CN') {
            Write-Output ("图形界面就绪 (-Exit 冒烟跳过弹窗): $psExe -Sta -NoProfile -File `"$guiScript`" -Language $Lang")
        } else {
            Write-Output ("Native GUI ready (-Exit dry smoke): $psExe -Sta -NoProfile -File `"$guiScript`" -Language $Lang")
        }
        return
    }
    & $psExe -Sta -NoProfile -File $guiScript -Language $Lang
    if ($LASTEXITCODE -ne 0) {
        throw "GUI process exited with code $LASTEXITCODE."
    }
}

function Invoke-LauncherAction {
    param(
        [Parameter(Mandatory = $true)][string]$SelectedAction,
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$BackendPath,
        [Parameter(Mandatory = $true)][ValidateSet('Text', 'Json')][string]$Format,
        [string]$Lang = 'en-US',
        [switch]$NonInteractiveExit
    )

    switch ($SelectedAction) {
        'Audit' {
            Invoke-BackendScript -BackendPath $BackendPath -BackendArgs @('-Audit', '-Language', $Lang, '-OutputFormat', $Format)
        }
        'Plan' {
            Invoke-BackendScript -BackendPath $BackendPath -BackendArgs @('-Plan', '-Language', $Lang, '-OutputFormat', $Format)
        }
        'ViewReports' {
            Invoke-ViewReports -Root $Root -Format $Format -Lang $Lang
        }
        'Verify' {
            Invoke-BackendScript -BackendPath $BackendPath -BackendArgs @('-Verify', '-Language', $Lang, '-OutputFormat', $Format)
        }
        'Help' {
            Show-LauncherHelp -BackendPath $BackendPath -Root $Root -Lang $Lang
        }
        'LaunchGui' {
            Invoke-LaunchGuiAction -Root $Root -Lang $Lang -DryExitOnly:$NonInteractiveExit
        }
        'Exit' {
            if ($Lang -eq 'zh-CN') { Write-Output '正在退出 Claude Residual ID Cleaner 启动器。' }
            else { Write-Output 'Exiting Claude Residual ID Cleaner Launcher.' }
        }
        default {
            throw "Unsupported launcher action: $SelectedAction"
        }
    }
}

function Show-LauncherMenu {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$Lang
    )

    Write-Output ''
    Write-Output '============================================================'
    if ($Lang -eq 'zh-CN') {
        Write-Output ' Claude Residual ID Cleaner (Claude 账号残余 ID 清理工具) - 安全菜单启动器 [zh-CN]'
        Write-Output '============================================================'
        Write-Output "工具根目录 : $Root"
        Write-Output '定位声明   : 仅扫描并清理 Claude 封号残余 · 绝不改动 Windows OS'
        Write-Output '安全边界   : 不自动 -Apply · 不绕过执行策略 · 不自动提权'
        Write-Output '------------------------------------------------------------'
        Write-Output '  [1] Audit        - 仅扫描体检 (只读环境与 Claude 残余检测)'
        Write-Output '  [2] Plan         - 生成清理方案 CLEANUP-PLAN.md (SchemaVersion 3)'
        Write-Output '  [3] View Reports - 查看本地 AUDIT / PLAN / VERIFICATION 报告'
        Write-Output '  [4] Verify       - 核验清理后残余与执行账本'
        Write-Output '  [5] Help         - 查看用法、语言参数与安全边界'
        Write-Output '  [6] Launch GUI   - 启动图形界面 (中/EN 实时切换)'
        Write-Output '  [7] Exit         - 退出启动器'
        Write-Output '  [L] Switch Lang  - 切换语言为 English (en-US)'
    } else {
        Write-Output ' Claude Residual ID Cleaner - Safe Console Launcher [en-US]'
        Write-Output '============================================================'
        Write-Output "Toolkit Root : $Root"
        Write-Output 'Positioning  : Post-Ban Claude Residuals Only · Never Alters Windows OS'
        Write-Output 'Safety Mode  : No -Apply, no ExecutionPolicy bypass, no UAC elevation'
        Write-Output '------------------------------------------------------------'
        Write-Output '  [1] Audit        - Read-only Claude residual discovery'
        Write-Output '  [2] Plan         - Generate CLEANUP-PLAN.md (SchemaVersion 3)'
        Write-Output '  [3] View Reports - Inspect local AUDIT / PLAN / VERIFICATION'
        Write-Output '  [4] Verify       - Check current state vs. plan and ledger'
        Write-Output '  [5] Help         - CLI usage and safety boundaries'
        Write-Output '  [6] Launch GUI   - Launch native Windows Desktop GUI (中/EN)'
        Write-Output '  [7] Exit         - Close launcher'
        Write-Output '  [L] Switch Lang  - Switch interface to 简体中文 (zh-CN)'
    }
    Write-Output '------------------------------------------------------------'
}

try {
    Initialize-LauncherUtf8Encoding
    $activeLang = Resolve-LauncherLanguage -Requested $Language
    $resolvedRoot = Resolve-LauncherToolkitRoot -CandidateRoot $ToolkitRoot
    $backendPath = Join-Path $resolvedRoot 'ClaudeCleanup.ps1'

    $hasAction = $PSBoundParameters.ContainsKey('Action') -and -not [string]::IsNullOrWhiteSpace($Action)
    if ($hasAction -or $Exit) {
        $effectiveAction = if ($hasAction) { $Action } else { 'Exit' }
        Invoke-LauncherAction -SelectedAction $effectiveAction -Root $resolvedRoot -BackendPath $backendPath -Format $OutputFormat -Lang $activeLang -NonInteractiveExit:$Exit
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
        '6' = 'LaunchGui'
        'gui' = 'LaunchGui'
        'launchgui' = 'LaunchGui'
        '7' = 'Exit'
        'exit' = 'Exit'
        'q' = 'Exit'
        'quit' = 'Exit'
        'l' = 'SwitchLang'
        'lang' = 'SwitchLang'
    }

    while ($true) {
        Show-LauncherMenu -Root $resolvedRoot -Lang $activeLang
        $prompt = if ($activeLang -eq 'zh-CN') { '请选择操作 [1-7 或 L 切换语言]' } else { 'Select an option [1-7 or L to toggle language]' }
        $rawInput = Read-Host $prompt
        if ($null -eq $rawInput) {
            break
        }
        $key = $rawInput.Trim().ToLowerInvariant()
        if (-not $choiceMap.ContainsKey($key)) {
            Write-Output "Invalid selection '$rawInput'. Enter 1-7, L, or Exit."
            continue
        }

        $selected = $choiceMap[$key]
        if ($selected -eq 'SwitchLang') {
            $activeLang = if ($activeLang -eq 'zh-CN') { 'en-US' } else { 'zh-CN' }
            continue
        }
        if ($selected -eq 'Exit') {
            Invoke-LauncherAction -SelectedAction 'Exit' -Root $resolvedRoot -BackendPath $backendPath -Format $OutputFormat -Lang $activeLang
            break
        }

        Write-Output ''
        try {
            Invoke-LauncherAction -SelectedAction $selected -Root $resolvedRoot -BackendPath $backendPath -Format $OutputFormat -Lang $activeLang
        } catch {
            Write-Output ("[ERROR] Action '{0}' failed: {1}" -f $selected, $_.Exception.Message)
        }
    }
    exit 0
} catch {
    Write-Error $_.Exception.Message
    exit 1
}
