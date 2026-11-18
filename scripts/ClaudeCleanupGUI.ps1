[CmdletBinding()]
param(
    [ValidateSet('Auto', 'zh-CN', 'en-US')]
    [string]$Language = 'Auto',
    [string]$ToolkitRoot,
    [switch]$Headless,
    [switch]$DryRun
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function Initialize-GuiUtf8Encoding {
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    $script:OutputEncoding = $utf8NoBom
    $global:OutputEncoding = $utf8NoBom
    try { [Console]::OutputEncoding = $utf8NoBom } catch {}
}

function Resolve-GuiLanguage {
    param([string]$Requested = $Language)

    if ($Requested -in @('zh-CN', 'en-US')) { return $Requested }
    try { if ([System.Globalization.CultureInfo]::CurrentUICulture.Name -like 'zh*') { return 'zh-CN' } } catch {}
    return 'en-US'
}

function Resolve-GuiToolkitRoot {
    param([string]$CandidateRoot)

    $raw = if ([string]::IsNullOrWhiteSpace($CandidateRoot)) { Split-Path -Parent $PSScriptRoot } else { $CandidateRoot }
    $full = [System.IO.Path]::GetFullPath($raw)
    $backend = Join-Path $full 'ClaudeCleanup.ps1'
    if (-not (Test-Path -LiteralPath $backend -PathType Leaf)) {
        throw "ClaudeCleanup.ps1 backend not found under: $full"
    }
    return $full
}

function Format-QuotedProcessArgument {
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Value)

    if ($Value -eq '') { return '""' }
    if ($Value -notmatch '[\s"]') { return $Value }
    $escaped = [regex]::Replace($Value, '(\\*)"', '$1$1\"')
    $escaped = [regex]::Replace($escaped, '(\\+)$', '$1$1')
    return ('"' + $escaped + '"')
}

function Invoke-GuiBackendCommand {
    param(
        [Parameter(Mandatory = $true)][string]$BackendPath,
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [switch]$PumpEvents
    )

    $psExe = (Get-Process -Id $PID).Path
    $argList = New-Object 'System.Collections.Generic.List[string]'
    $argList.Add('-NoProfile')
    $argList.Add('-NonInteractive')
    $argList.Add('-File')
    $argList.Add($BackendPath)
    foreach ($a in $Arguments) { $argList.Add($a) }

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $psExe
    $psi.Arguments = (($argList | ForEach-Object { Format-QuotedProcessArgument -Value $_ }) -join ' ')
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
    $psi.StandardErrorEncoding = [System.Text.Encoding]::UTF8

    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo = $psi
    [void]$proc.Start()

    $outTask = $proc.StandardOutput.ReadToEndAsync()
    $errTask = $proc.StandardError.ReadToEndAsync()
    while (-not $proc.WaitForExit(40)) {
        if ($PumpEvents) {
            [System.Windows.Forms.Application]::DoEvents()
        }
    }
    $proc.WaitForExit()
    $stdout = $outTask.GetAwaiter().GetResult()
    $stderr = $errTask.GetAwaiter().GetResult()
    $code = $proc.ExitCode
    $proc.Dispose()

    return [pscustomobject]@{
        ExitCode = $code
        StdOut = $stdout
        StdErr = $stderr
    }
}

function ConvertFrom-BackendJsonOutput {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        throw 'Backend returned empty JSON output.'
    }
    $idx = $Text.IndexOf('{')
    if ($idx -lt 0) {
        throw ('Backend did not return JSON payload: ' + $Text)
    }
    $jsonText = $Text.Substring($idx)
    return ($jsonText | ConvertFrom-Json -ErrorAction Stop)
}

function Get-GuiStrings {
    param([Parameter(Mandatory = $true)][string]$Lang)

    if ($Lang -eq 'zh-CN') {
        return @{
            WindowTitle = 'Claude Residual ID Cleaner — Claude 账号残余 ID 清理工具 (仅清理封号残余 · 绝不改系统)'
            HeaderTitle = 'Claude Residual ID Cleaner — Claude 账号残余 ID 清理工具'
            SafetyBadge = '仅清理 Claude 封号残余数据 · 绝不改动 Windows 系统本身'
            Subtitle = '专用于扫描并清理账号封禁后遗留的本地账号/设备元数据、授权缓存、会话与扩展状态 · 默认只读安全'
            LangToggle = '中 / EN (当前: 中文)'
            ScopeGroup = '扫描与清理目标范围 (基于 ClaudeCleanup.ps1 严格白名单)'
            ChkCode = 'Claude Code CLI 配置与残余元数据 (.claude, .claude.json, npm)'
            ChkDesktop = 'Claude Desktop 本地存储与会话缓存 (%APPDATA%\Claude, %LOCALAPPDATA%\Claude, MSIX)'
            ChkVsCode = 'VS Code / Cursor Claude 扩展与浏览器宿主注册 (anthropic.claude-code)'
            ChkCred = 'Windows 凭据管理器 Claude 条目 (仅只读审计计数，不读取或删除密码)'
            ChkEnv = 'Claude 相关环境变量与 PATH 残留 (仅报告 Scope 与 Name，不修改系统)'
            TipCode = '扫描并按所选策略处理 ~/.claude、~/.claude.json、claude.exe 及 @anthropic-ai/claude-code npm 包（AccountData 保留自建技能/会话）。'
            TipDesktop = '扫描 Desktop 缓存、日志、Local Storage 与 MSIX 包；AccountData 仅清认证与缓存，FullRemoval 包含彻底移除。'
            TipVsCode = '扫描 VS Code / Cursor / Windsurf 的 anthropic.claude-code 扩展及 HKCU NativeMessagingHosts 键值。'
            TipCred = '遵循最小权限原则：仅统计 Credential Manager 中匹配的 Claude 目标数量，绝不读取秘密或擅自删除。'
            TipEnv = '仅列举变量作用域和名称，绝不采集秘密值，也不会改动 Windows 系统全局 PATH 或注册表。'
            PolicyGroup = '清理策略'
            PolicyAccount = 'AccountData (保守清账号/缓存，保留 .claude 自建配置)'
            PolicyFull = 'FullRemoval (彻底清理用户级 Claude 应用/扩展与数据)'
            BtnScan = '1. 仅扫描体检 (Audit)'
            BtnPlan = '2. 生成清理方案 (Plan)'
            BtnClean = '3. 执行安全清理 (Clean Selected)'
            BtnVerify = '4. 核验清理结果 (Verify)'
            BtnOpenAudit = '导出/打开 AUDIT.md'
            BtnOpenPlan = '打开 CLEANUP-PLAN.md'
            ColCategory = '类别 / Category'
            ColPath = '目标路径或包名 / Path or Package'
            ColStatus = '状态 / Status'
            ColDecision = '决策 / Decision'
            ColReason = '说明 / Details'
            StatusFound = '已发现 (Found)'
            StatusClean = '无残留 (Clean)'
            StatusSkipped = '已跳过/受保护 (Skipped)'
            ReadyStatusIdle = '就绪：请先点击“1. 仅扫描体检”执行只读检查（绝不自动修改系统）。'
            ReadyStatusScanned = '扫描完成：发现 {0} 条候选记录。若需清理请点击“2. 生成清理方案”。'
            ReadyStatusPlanned = '清理方案已就绪 (Ready={0}, SHA256={1}...)。确认后可点击“3. 执行安全清理”。'
            DryRunNotice = '当前为 DryRun 预览模式：已阻止真实清理，仅展示了 -WhatIf 预览结果。'
            NoReadyTargets = '当前策略或已勾选范围下没有可执行的 Ready 清理项（凭据/环境变量为只读审计项，ReviewOnly/Blocked 项已受保护）。'
            ConfirmTitle = '最终清理授权确认（不可撤销）'
            ConfirmBody = "工具即将调用 ClaudeCleanup.ps1 永久移除以下 {0} 项白名单内的 Claude 封号残余数据（绝不改动 Windows OS 文件、WSL 或无关软件）：`r`n`r`n策略: {1}`r`n清单 SHA-256: {2}`r`n`r`n待清理目标:`r`n{3}`r`n`r`n注意：删除操作不可恢复且无回收站。确认执行安全清理吗？"
            CleanSuccess = '清理执行完成 ({0})，已自动运行独立核验。请查看上方状态表及 VERIFICATION.md。'
            VerifyDone = '核验完成：共检查 {0} 项清单记录，当前本地扫描项 {1} 条。'
            ReportMissingPlan = '尚未生成 CLEANUP-PLAN.md，请先点击“2. 生成清理方案”。'
        }
    }
    return @{
        WindowTitle = 'Claude Residual ID Cleaner (Post-Ban Residuals Only · OS-Safe)'
        HeaderTitle = 'Claude Residual ID Cleaner'
        SafetyBadge = 'Cleans Claude Banned-Account Residuals Only · Never Alters Windows OS'
        Subtitle = 'Scans and safely cleans leftover local account/device metadata, auth tokens, session caches, and extension state · Read-only default'
        LangToggle = '中 / EN (Active: EN)'
        ScopeGroup = 'Target Scope Checklist (Guarded by ClaudeCleanup.ps1 Allowlist)'
        ChkCode = 'Claude Code CLI Configs & Metadata (.claude, .claude.json, npm)'
        ChkDesktop = 'Claude Desktop Storage & Session State (%APPDATA%\Claude, %LOCALAPPDATA%\Claude, MSIX)'
        ChkVsCode = 'VS Code / Cursor Claude Extensions & Browser Host Keys (anthropic.claude-code)'
        ChkCred = 'Windows Credential Manager Claude Entries (Read-only count audit only)'
        ChkEnv = 'Claude Environment Variables & PATH Residuals (Reports Scope + Name only)'
        TipCode = 'Audits ~/.claude, ~/.claude.json, native claude.exe, and @anthropic-ai/claude-code npm installs (AccountData keeps user .claude files).'
        TipDesktop = 'Audits Desktop caches, logs, Local Storage, and MSIX packages; AccountData clears caches/logs, FullRemoval removes full app data.'
        TipVsCode = 'Audits VS Code / Cursor / Windsurf anthropic.claude-code extension and HKCU NativeMessagingHosts keys.'
        TipCred = 'Least-privilege boundary: counts matching Claude* Credential Manager targets only; secret values are never read or deleted.'
        TipEnv = 'Reports variable Scope and Name only; never extracts secret values and never modifies Windows OS PATH automatically.'
        PolicyGroup = 'Cleanup Policy'
        PolicyAccount = 'AccountData (Auth caches & logs; preserves user .claude files)'
        PolicyFull = 'FullRemoval (Removes user-level Claude apps, extensions & data)'
        BtnScan = '1. Scan (Read-Only Audit)'
        BtnPlan = '2. Preview Plan (CLEANUP-PLAN.md)'
        BtnClean = '3. Clean Selected (Confirm Required)'
        BtnVerify = '4. Verify Residual State'
        BtnOpenAudit = 'Export / Open AUDIT.md'
        BtnOpenPlan = 'Open CLEANUP-PLAN.md'
        ColCategory = 'Category'
        ColPath = 'Target Path or Package'
        ColStatus = 'Status'
        ColDecision = 'Decision'
        ColReason = 'Details'
        StatusFound = 'Found'
        StatusClean = 'Clean'
        StatusSkipped = 'Skipped / Protected'
        ReadyStatusIdle = 'Ready: Click "1. Scan" for a read-only audit (zero system changes).'
        ReadyStatusScanned = 'Scan finished: {0} item(s) inspected. Click "2. Preview Plan" to build CLEANUP-PLAN.md.'
        ReadyStatusPlanned = 'Plan ready (Ready={0}, SHA256={1}...). Review carefully before "3. Clean Selected".'
        DryRunNotice = 'DryRun mode active: real deletion is blocked; only -WhatIf preview was evaluated.'
        NoReadyTargets = 'No eligible Ready targets under the selected policy and checked scopes (Credential Manager / Env Vars are read-only audit items).'
        ConfirmTitle = 'Final Cleanup Confirmation (Permanent)'
        ConfirmBody = "ClaudeCleanup.ps1 will permanently remove the following {0} allowlisted Claude residual item(s) (Windows OS files, WSL, and unrelated apps are untouched):`r`n`r`nPolicy: {1}`r`nManifest SHA-256: {2}`r`n`r`nTargets:`r`n{3}`r`n`r`nWarning: No backup or recycle bin is used. Proceed with cleanup?"
        CleanSuccess = 'Cleanup finished ({0}) and independent Verify completed. Inspect results table and VERIFICATION.md.'
        VerifyDone = 'Verification finished: {0} planned item(s) checked; {1} current inventory item(s).'
        ReportMissingPlan = 'CLEANUP-PLAN.md does not exist yet. Run "2. Preview Plan" first.'
    }
}

function Get-GuiTargetCategory {
    param([Parameter(Mandatory = $true)][object]$Record)

    $id = if ($Record.PSObject.Properties['Id']) { [string]$Record.Id } else { '' }
    $cat = if ($Record.PSObject.Properties['Category']) { [string]$Record.Category } else { '' }
    $path = if ($Record.PSObject.Properties['Path']) { [string]$Record.Path } else { '' }
    if ($id -match 'vscode|native-host|cursor|windsurf|browser' -or $cat -match '(?i)VS Code|Extension|Native Messaging|Browser' -or $path -match '(?i)anthropic\.claude-code|NativeMessagingHosts') {
        return 'VsCodeExtensions'
    }
    if ($id -match 'desktop|appdata|msix|appx|local-claude|roaming' -or $cat -match '(?i)Desktop|AppX|MSIX|AppData|Cache|Log' -or $path -match '(?i)\\AppData\\|\\Packages\\Claude_|^Claude_') {
        return 'ClaudeDesktop'
    }
    return 'ClaudeCode'
}

Initialize-GuiUtf8Encoding
$resolvedRoot = Resolve-GuiToolkitRoot -CandidateRoot $ToolkitRoot
$backendPath = Join-Path $resolvedRoot 'ClaudeCleanup.ps1'

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$state = [pscustomobject]@{
    Language = Resolve-GuiLanguage -Requested $Language
    HasScanned = $false
    HasPlan = $false
    PlanSha256 = ''
    LastAuditReport = $null
    LastVerifyReport = $null
    ReadyTargetCount = 0
}

$form = New-Object System.Windows.Forms.Form
$form.Size = New-Object System.Drawing.Size(1020, 740)
$form.MinimumSize = New-Object System.Drawing.Size(880, 640)
$form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
$form.BackColor = [System.Drawing.Color]::FromArgb(245, 247, 250)
$form.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 9)

$toolTip = New-Object System.Windows.Forms.ToolTip
$toolTip.AutoPopDelay = 12000
$toolTip.InitialDelay = 300

# Header Panel
$headerPanel = New-Object System.Windows.Forms.Panel
$headerPanel.Dock = [System.Windows.Forms.DockStyle]::Top
$headerPanel.Height = 96
$headerPanel.BackColor = [System.Drawing.Color]::FromArgb(23, 37, 64)
$headerPanel.Padding = New-Object System.Windows.Forms.Padding(16, 10, 16, 10)

$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Location = New-Object System.Drawing.Point(16, 10)
$lblTitle.Size = New-Object System.Drawing.Size(600, 28)
$lblTitle.ForeColor = [System.Drawing.Color]::White
$lblTitle.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 14, [System.Drawing.FontStyle]::Bold)

$lblBadge = New-Object System.Windows.Forms.Label
$lblBadge.Location = New-Object System.Drawing.Point(16, 40)
$lblBadge.Size = New-Object System.Drawing.Size(730, 22)
$lblBadge.ForeColor = [System.Drawing.Color]::FromArgb(134, 239, 172)
$lblBadge.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 9.5, [System.Drawing.FontStyle]::Bold)

$lblSubtitle = New-Object System.Windows.Forms.Label
$lblSubtitle.Location = New-Object System.Drawing.Point(16, 65)
$lblSubtitle.Size = New-Object System.Drawing.Size(760, 22)
$lblSubtitle.ForeColor = [System.Drawing.Color]::FromArgb(203, 213, 225)
$lblSubtitle.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 8.5)

function New-GuiCheckBox {
    param([int]$Y)
    $chk = New-Object System.Windows.Forms.CheckBox
    $chk.Location = New-Object System.Drawing.Point(14, $Y)
    $chk.Size = New-Object System.Drawing.Size(670, 22)
    $chk.Checked = $true
    return $chk
}

function New-GuiFlatButton {
    param(
        [int]$Width,
        [int]$Height = 36,
        [int[]]$Rgb = $null,
        [bool]$Bold = $false
    )
    $btn = New-Object System.Windows.Forms.Button
    $btn.Size = New-Object System.Drawing.Size($Width, $Height)
    if ($null -ne $Rgb) {
        $btn.BackColor = [System.Drawing.Color]::FromArgb($Rgb[0], $Rgb[1], $Rgb[2])
        $btn.ForeColor = [System.Drawing.Color]::White
        $btn.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
        $btn.FlatAppearance.BorderSize = 0
    }
    if ($Bold) {
        $btn.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 9.5, [System.Drawing.FontStyle]::Bold)
    }
    return $btn
}

function Add-GuiResultRow {
    param(
        [string]$Category,
        [string]$PathOrName,
        [string]$StatusText,
        [string]$DecisionText,
        [string]$DetailsText
    )
    $lvi = New-Object System.Windows.Forms.ListViewItem($Category)
    foreach ($sub in @($PathOrName, $StatusText, $DecisionText, $DetailsText)) {
        [void]$lvi.SubItems.Add($sub)
    }
    [void]$lvResults.Items.Add($lvi)
}

$btnLangToggle = New-GuiFlatButton -Width 175 -Height 40 -Rgb @(37, 99, 235) -Bold $true
$btnLangToggle.Location = New-Object System.Drawing.Point(810, 22)
$btnLangToggle.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Right

$headerPanel.Controls.AddRange(@($lblTitle, $lblBadge, $lblSubtitle, $btnLangToggle))

# Target Scope Checklist Panel
$scopeGroup = New-Object System.Windows.Forms.GroupBox
$scopeGroup.Location = New-Object System.Drawing.Point(14, 106)
$scopeGroup.Size = New-Object System.Drawing.Size(700, 160)
$scopeGroup.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right

$chkCode = New-GuiCheckBox -Y 22
$chkDesktop = New-GuiCheckBox -Y 48
$chkVsCode = New-GuiCheckBox -Y 74
$chkCred = New-GuiCheckBox -Y 100
$chkEnv = New-GuiCheckBox -Y 126

$scopeGroup.Controls.AddRange(@($chkCode, $chkDesktop, $chkVsCode, $chkCred, $chkEnv))

# Policy Selector Panel
$policyGroup = New-Object System.Windows.Forms.GroupBox
$policyGroup.Location = New-Object System.Drawing.Point(726, 106)
$policyGroup.Size = New-Object System.Drawing.Size(266, 160)
$policyGroup.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Right

$rbAccountData = New-Object System.Windows.Forms.RadioButton
$rbAccountData.Location = New-Object System.Drawing.Point(12, 26)
$rbAccountData.Size = New-Object System.Drawing.Size(244, 52)
$rbAccountData.Checked = $true

$rbFullRemoval = New-Object System.Windows.Forms.RadioButton
$rbFullRemoval.Location = New-Object System.Drawing.Point(12, 86)
$rbFullRemoval.Size = New-Object System.Drawing.Size(244, 58)

$policyGroup.Controls.AddRange(@($rbAccountData, $rbFullRemoval))

# Action Control Bar
$actionPanel = New-Object System.Windows.Forms.FlowLayoutPanel
$actionPanel.Location = New-Object System.Drawing.Point(14, 274)
$actionPanel.Size = New-Object System.Drawing.Size(978, 44)
$actionPanel.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right

$btnScan = New-GuiFlatButton -Width 175 -Rgb @(37, 99, 235)
$btnPlan = New-GuiFlatButton -Width 185 -Rgb @(15, 118, 110)
$btnClean = New-GuiFlatButton -Width 205 -Rgb @(185, 28, 28)
$btnClean.Enabled = $false
$btnVerify = New-GuiFlatButton -Width 165 -Rgb @(71, 85, 105)
$btnOpenAudit = New-GuiFlatButton -Width 112
$btnOpenPlan = New-GuiFlatButton -Width 112

$actionPanel.Controls.AddRange(@($btnScan, $btnPlan, $btnClean, $btnVerify, $btnOpenAudit, $btnOpenPlan))

# Results ListView + Log Viewer
$splitMain = New-Object System.Windows.Forms.SplitContainer
$splitMain.Location = New-Object System.Drawing.Point(14, 326)
$splitMain.Size = New-Object System.Drawing.Size(978, 340)
$splitMain.Orientation = [System.Windows.Forms.Orientation]::Horizontal
$splitMain.SplitterDistance = 215
$splitMain.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right

$lvResults = New-Object System.Windows.Forms.ListView
$lvResults.Dock = [System.Windows.Forms.DockStyle]::Fill
$lvResults.View = [System.Windows.Forms.View]::Details
$lvResults.FullRowSelect = $true
$lvResults.GridLines = $true
$colCat = $lvResults.Columns.Add('Category', 175)
$colPath = $lvResults.Columns.Add('Path', 360)
$colStatus = $lvResults.Columns.Add('Status', 130)
$colDecision = $lvResults.Columns.Add('Decision', 95)
$colReason = $lvResults.Columns.Add('Reason', 200)
$splitMain.Panel1.Controls.Add($lvResults)

$txtLog = New-Object System.Windows.Forms.TextBox
$txtLog.Dock = [System.Windows.Forms.DockStyle]::Fill
$txtLog.Multiline = $true
$txtLog.ReadOnly = $true
$txtLog.ScrollBars = [System.Windows.Forms.ScrollBars]::Both
$txtLog.WordWrap = $false
$txtLog.Font = New-Object System.Drawing.Font('Consolas', 9)
$txtLog.BackColor = [System.Drawing.Color]::FromArgb(15, 23, 42)
$txtLog.ForeColor = [System.Drawing.Color]::FromArgb(226, 232, 240)
$splitMain.Panel2.Controls.Add($txtLog)

$statusStrip = New-Object System.Windows.Forms.StatusStrip
$statusLabel = New-Object System.Windows.Forms.ToolStripStatusLabel
$statusStrip.Items.Add($statusLabel) | Out-Null

$form.Controls.AddRange(@($splitMain, $actionPanel, $policyGroup, $scopeGroup, $headerPanel, $statusStrip))

function Append-GuiLog {
    param([string]$Message)
    $stamp = [DateTime]::Now.ToString('HH:mm:ss')
    $txtLog.AppendText("[$stamp] $Message`r`n")
}

function Apply-GuiLanguage {
    param([Parameter(Mandatory = $true)][string]$Lang)

    $s = Get-GuiStrings -Lang $Lang
    $form.Text = $s.WindowTitle
    $lblTitle.Text = $s.HeaderTitle
    $lblBadge.Text = $s.SafetyBadge
    $lblSubtitle.Text = $s.Subtitle
    $btnLangToggle.Text = $s.LangToggle

    $scopeGroup.Text = $s.ScopeGroup
    $chkCode.Text = $s.ChkCode
    $chkDesktop.Text = $s.ChkDesktop
    $chkVsCode.Text = $s.ChkVsCode
    $chkCred.Text = $s.ChkCred
    $chkEnv.Text = $s.ChkEnv

    $toolTip.SetToolTip($chkCode, $s.TipCode)
    $toolTip.SetToolTip($chkDesktop, $s.TipDesktop)
    $toolTip.SetToolTip($chkVsCode, $s.TipVsCode)
    $toolTip.SetToolTip($chkCred, $s.TipCred)
    $toolTip.SetToolTip($chkEnv, $s.TipEnv)

    $policyGroup.Text = $s.PolicyGroup
    $rbAccountData.Text = $s.PolicyAccount
    $rbFullRemoval.Text = $s.PolicyFull

    $btnScan.Text = $s.BtnScan
    $btnPlan.Text = $s.BtnPlan
    $btnClean.Text = $s.BtnClean
    $btnVerify.Text = $s.BtnVerify
    $btnOpenAudit.Text = $s.BtnOpenAudit
    $btnOpenPlan.Text = $s.BtnOpenPlan

    $colCat.Text = $s.ColCategory
    $colPath.Text = $s.ColPath
    $colStatus.Text = $s.ColStatus
    $colDecision.Text = $s.ColDecision
    $colReason.Text = $s.ColReason

    if (-not $state.HasScanned) {
        $statusLabel.Text = $s.ReadyStatusIdle
    }
}

function Populate-AuditListView {
    param([Parameter(Mandatory = $true)][object]$AuditReport)

    $s = Get-GuiStrings -Lang $state.Language
    $lvResults.BeginUpdate()
    try {
        $lvResults.Items.Clear()
        foreach ($item in @($AuditReport.Inventory)) {
            $catKey = Get-GuiTargetCategory -Record $item
            if (($catKey -eq 'ClaudeCode' -and -not $chkCode.Checked) -or
                ($catKey -eq 'ClaudeDesktop' -and -not $chkDesktop.Checked) -or
                ($catKey -eq 'VsCodeExtensions' -and -not $chkVsCode.Checked)) {
                continue
            }
            $rowStatus = if ($item.Decision -eq 'Ready') { $s.StatusFound } else { $s.StatusSkipped }
            Add-GuiResultRow -Category ([string]$item.Category) -PathOrName ([string]$item.Path) -StatusText $rowStatus -DecisionText ([string]$item.Decision) -DetailsText ([string]$item.Reason)
        }

        if ($chkEnv.Checked -and $AuditReport.PSObject.Properties['Summary'] -and $AuditReport.Summary) {
            $envNames = @($AuditReport.Summary.EnvironmentVariableNames)
            if ($envNames.Count -eq 0) {
                Add-GuiResultRow -Category 'Environment Variables' -PathOrName 'CLAUDE_* / ANTHROPIC_*' -StatusText $s.StatusClean -DecisionText 'ReadOnly' -DetailsText 'None detected'
            } else {
                foreach ($ev in $envNames) {
                    Add-GuiResultRow -Category "Env ($($ev.Scope))" -PathOrName ([string]$ev.Name) -StatusText $s.StatusFound -DecisionText 'ReadOnly' -DetailsText 'Name reported only (secret values omitted)'
                }
            }
        }

        if ($chkCred.Checked) {
            $credLines = @($AuditReport.EnvironmentLines | Where-Object { $_ -match 'Credential Manager' })
            $credDetail = if ($credLines.Count -gt 0) { [string]$credLines[0] } else { 'Audited (count only)' }
            $credStatus = if ($credDetail -match 'count:\s*0\b') { $s.StatusClean } else { $s.StatusFound }
            Add-GuiResultRow -Category 'Credential Manager' -PathOrName 'Claude* generic targets' -StatusText $credStatus -DecisionText 'ReadOnly' -DetailsText $credDetail
        }
    } finally {
        $lvResults.EndUpdate()
    }
}

function Set-BusyState {
    param([bool]$Busy)
    $btnScan.Enabled = -not $Busy
    $btnPlan.Enabled = -not $Busy
    $btnVerify.Enabled = -not $Busy
    $btnLangToggle.Enabled = -not $Busy
    $btnClean.Enabled = (-not $Busy) -and $state.HasScanned -and $state.HasPlan -and ($state.ReadyTargetCount -gt 0)
}

function Invoke-ToggleGuiLanguage {
    $state.Language = if ($state.Language -eq 'zh-CN') { 'en-US' } else { 'zh-CN' }
    Apply-GuiLanguage -Lang $state.Language
    if ($null -ne $state.LastAuditReport) {
        Populate-AuditListView -AuditReport $state.LastAuditReport
    }
}

function Invoke-GuiBusyAction {
    param(
        [string]$ErrorTitle = '',
        [Parameter(Mandatory = $true)][scriptblock]$Action
    )
    Set-BusyState -Busy $true
    try {
        & $Action
    } catch {
        Append-GuiLog ('[ERROR] ' + $_.Exception.Message)
        if (-not [string]::IsNullOrEmpty($ErrorTitle)) {
            [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, $ErrorTitle, [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
        }
    } finally {
        Set-BusyState -Busy $false
    }
}

function Invoke-GuiBackendJsonStep {
    param(
        [Parameter(Mandatory = $true)][string[]]$BackendArgs,
        [Parameter(Mandatory = $true)][string]$StepLabel
    )
    $res = Invoke-GuiBackendCommand -BackendPath $backendPath -Arguments $BackendArgs -PumpEvents
    if ($res.ExitCode -ne 0) {
        throw ("$StepLabel failed (exit=$($res.ExitCode)): $($res.StdErr)")
    }
    return (ConvertFrom-BackendJsonOutput -Text $res.StdOut)
}

$btnLangToggle.Add_Click({ Invoke-ToggleGuiLanguage })

$btnScan.Add_Click({
    $s = Get-GuiStrings -Lang $state.Language
    Invoke-GuiBusyAction -ErrorTitle 'Audit Error' -Action {
        Append-GuiLog "Running read-only Audit (-Language $($state.Language))..."
        $auditObj = Invoke-GuiBackendJsonStep -BackendArgs @('-Audit', '-Language', $state.Language, '-OutputFormat', 'Json') -StepLabel 'Audit'
        $state.LastAuditReport = $auditObj
        $state.HasScanned = $true
        Populate-AuditListView -AuditReport $auditObj
        $invCount = @($auditObj.Inventory).Count
        $statusLabel.Text = ($s.ReadyStatusScanned -f $invCount)
        Append-GuiLog ("Audit complete: {0} inventory item(s)." -f $invCount)
    }
})

$btnPlan.Add_Click({
    $s = Get-GuiStrings -Lang $state.Language
    Invoke-GuiBusyAction -ErrorTitle 'Plan Error' -Action {
        Append-GuiLog "Generating SchemaVersion=3 plan (-Language $($state.Language))..."
        $planObj = Invoke-GuiBackendJsonStep -BackendArgs @('-Plan', '-Language', $state.Language, '-OutputFormat', 'Json') -StepLabel 'Plan'
        $state.HasPlan = $true
        $state.PlanSha256 = [string]$planObj.Sha256
        $state.ReadyTargetCount = [int]$planObj.Ready
        $shortSha = if ($state.PlanSha256.Length -ge 12) { $state.PlanSha256.Substring(0, 12) } else { $state.PlanSha256 }
        $statusLabel.Text = ($s.ReadyStatusPlanned -f $planObj.Ready, $shortSha)
        Append-GuiLog ("Plan written: $($planObj.PlanPath) | SHA256=$($state.PlanSha256) | Ready=$($planObj.Ready)")
    }
})

$btnClean.Add_Click({
    $s = Get-GuiStrings -Lang $state.Language
    $selectedPolicy = if ($rbFullRemoval.Checked) { 'FullRemoval' } else { 'AccountData' }
    if (-not $state.HasScanned -or -not $state.HasPlan -or [string]::IsNullOrWhiteSpace($state.PlanSha256)) {
        return
    }
    if (-not ($chkCode.Checked -or $chkDesktop.Checked -or $chkVsCode.Checked)) {
        [System.Windows.Forms.MessageBox]::Show($s.NoReadyTargets, $s.ConfirmTitle, [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
        return
    }

    Invoke-GuiBusyAction -ErrorTitle 'Cleanup Error' -Action {
        Append-GuiLog 'Running mandatory -WhatIf preview before confirmation...'
        $previewObj = Invoke-GuiBackendJsonStep -BackendArgs @('-Apply', '-Policy', $selectedPolicy, '-ApprovedManifestSha256', $state.PlanSha256, '-Language', $state.Language, '-OutputFormat', 'Json', '-WhatIf') -StepLabel 'WhatIf preview'
        $readyPreview = @($previewObj.Results | Where-Object { $_.Status -eq 'PreviewOnly' })
        if ($readyPreview.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show($s.NoReadyTargets, $s.ConfirmTitle, [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
            return
        }

        $targetLines = ($readyPreview | ForEach-Object { "  - [$($_.Id)] ($($_.Kind)) $($_.Path)" }) -join "`r`n"
        if ($DryRun) {
            Append-GuiLog ($s.DryRunNotice + "`r`n" + $targetLines)
            [System.Windows.Forms.MessageBox]::Show(($s.DryRunNotice + "`r`n`r`n" + $targetLines), $s.ConfirmTitle, [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
            return
        }

        $msg = ($s.ConfirmBody -f $readyPreview.Count, $selectedPolicy, $state.PlanSha256, $targetLines)
        $choice = [System.Windows.Forms.MessageBox]::Show(
            $msg,
            $s.ConfirmTitle,
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Warning,
            [System.Windows.Forms.MessageBoxDefaultButton]::Button2
        )
        if ($choice -ne [System.Windows.Forms.DialogResult]::Yes) {
            Append-GuiLog 'Cleanup cancelled by user confirmation dialog.'
            return
        }

        Append-GuiLog "User explicitly approved SHA256=$($state.PlanSha256). Executing ClaudeCleanup.ps1 -Apply..."
        $applyObj = Invoke-GuiBackendJsonStep -BackendArgs @('-Apply', '-Policy', $selectedPolicy, '-ApprovedManifestSha256', $state.PlanSha256, '-Language', $state.Language, '-OutputFormat', 'Json', '-Confirm:$false') -StepLabel 'Apply'
        $state.HasPlan = $false
        $state.ReadyTargetCount = 0
        Append-GuiLog ($s.CleanSuccess -f $applyObj.Outcome)
        $statusLabel.Text = ($s.CleanSuccess -f $applyObj.Outcome)
        $btnVerify.PerformClick()
    }
})

$btnVerify.Add_Click({
    $s = Get-GuiStrings -Lang $state.Language
    Invoke-GuiBusyAction -ErrorTitle 'Verify Error' -Action {
        Append-GuiLog "Running Verify (-Language $($state.Language))..."
        $verObj = Invoke-GuiBackendJsonStep -BackendArgs @('-Verify', '-Language', $state.Language, '-OutputFormat', 'Json') -StepLabel 'Verify'
        $state.LastVerifyReport = $verObj
        $planCount = @($verObj.Verify.PlanChecks).Count
        $curCount = @($verObj.Verify.CurrentInventory).Count
        $statusLabel.Text = ($s.VerifyDone -f $planCount, $curCount)
        Append-GuiLog ($s.VerifyDone -f $planCount, $curCount)
    }
})

$btnOpenAudit.Add_Click({
    Invoke-GuiBusyAction -Action {
        $null = Invoke-GuiBackendJsonStep -BackendArgs @('-Audit', '-Language', $state.Language, '-SaveAuditReport', '-OutputFormat', 'Json') -StepLabel 'Export AUDIT.md'
        $auditFile = Join-Path $resolvedRoot 'AUDIT.md'
        if (Test-Path -LiteralPath $auditFile -PathType Leaf) {
            Append-GuiLog "Exported AUDIT.md ($($state.Language)): $auditFile"
            Start-Process -FilePath $auditFile | Out-Null
        }
    }
})

$btnOpenPlan.Add_Click({
    $s = Get-GuiStrings -Lang $state.Language
    $planFile = Join-Path $resolvedRoot 'CLEANUP-PLAN.md'
    if (-not (Test-Path -LiteralPath $planFile -PathType Leaf)) {
        [System.Windows.Forms.MessageBox]::Show($s.ReportMissingPlan, $s.BtnOpenPlan, [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
        return
    }
    Start-Process -FilePath $planFile | Out-Null
})

Apply-GuiLanguage -Lang $state.Language

if ($Headless) {
    $form.CreateControl()
    $initialTitle = $form.Text
    $initialBadge = $lblBadge.Text
    $initialCleanEnabled = $btnClean.Enabled

    Invoke-ToggleGuiLanguage
    $toggledLang = $state.Language
    $toggledTitle = $form.Text
    $toggledBadge = $lblBadge.Text

    $result = [pscustomobject]@{
        GuiInstantiated = $true
        ToolkitRoot = $resolvedRoot
        InitialLanguage = (Resolve-GuiLanguage -Requested $Language)
        ToggledLanguage = $toggledLang
        InitialCleanButtonEnabled = $initialCleanEnabled
        InitialTitle = $initialTitle
        InitialBadge = $initialBadge
        ToggledTitle = $toggledTitle
        ToggledBadge = $toggledBadge
        ChecklistCount = 5
        DryRun = [bool]$DryRun
    }
    $form.Dispose()
    $result
    return
}

try {
    [void]$form.ShowDialog()
} finally {
    $form.Dispose()
}
