$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

$repoRoot = Split-Path -Parent $PSScriptRoot
$backendPath = Join-Path $repoRoot 'ClaudeCleanup.ps1'
$launcherPs1 = Join-Path $repoRoot 'scripts\ClaudeCleanupLauncher.ps1'
$guiPs1 = Join-Path $repoRoot 'scripts\ClaudeCleanupGUI.ps1'
$guiCmd = Join-Path $repoRoot 'ClaudeCleanupGUI.cmd'
$installPs1 = Join-Path $repoRoot 'scripts\Install-ClaudeCleanup.ps1'
$updatePs1 = Join-Path $repoRoot 'scripts\Update-ClaudeCleanup.ps1'
$uninstallPs1 = Join-Path $repoRoot 'scripts\Uninstall-ClaudeCleanup.ps1'

$sandboxRoot = Join-Path $PSScriptRoot 'sandbox'
$sandboxExisted = Test-Path -LiteralPath $sandboxRoot
$stageHSandbox = Join-Path $sandboxRoot 'stage-h'
if (Test-Path -LiteralPath $stageHSandbox) {
    throw "Sandbox directory already exists: $stageHSandbox"
}
New-Item -ItemType Directory -Path $stageHSandbox -Force | Out-Null

$passed = 0
$skipped = 0
$notExecuted = 0
$failedList = New-Object 'System.Collections.Generic.List[string]'

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Name
    )
    if (-not $Condition) {
        $script:failedList.Add($Name)
        throw "FAIL: $Name"
    }
    $script:passed++
    Write-Output "PASS: $Name"
}

function Assert-Throws {
    param(
        [scriptblock]$Action,
        [string]$Name
    )
    $threw = $false
    try {
        & $Action | Out-Null
    } catch {
        $threw = $true
    }
    Assert-True -Condition $threw -Name $Name
}

function Invoke-Utf8ChildPowerShell {
    param(
        [Parameter(Mandatory = $true)][string]$ScriptPath,
        [string[]]$ScriptArgs = @(),
        [switch]$UseSta
    )

    $psExe = (Get-Process -Id $PID).Path
    $argParts = New-Object 'System.Collections.Generic.List[string]'
    if ($UseSta) { $argParts.Add('-Sta') }
    $argParts.Add('-NoProfile')
    $argParts.Add('-NonInteractive')
    $argParts.Add('-File')
    $argParts.Add($ScriptPath)
    foreach ($a in $ScriptArgs) { $argParts.Add($a) }

    $quoted = foreach ($v in $argParts) {
        if ($v -eq '') { '""' }
        elseif ($v -notmatch '[\s"]') { $v }
        else { '"' + ($v.Replace('"', '\"')) + '"' }
    }

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $psExe
    $psi.Arguments = ($quoted -join ' ')
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
    $psi.StandardErrorEncoding = [System.Text.Encoding]::UTF8

    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $psi
    [void]$p.Start()
    $out = $p.StandardOutput.ReadToEnd()
    $err = $p.StandardError.ReadToEnd()
    $p.WaitForExit()
    $code = $p.ExitCode
    $p.Dispose()

    return [pscustomobject]@{
        ExitCode = $code
        StdOut = $out
        StdErr = $err
    }
}

try {
    # 1. AST parse validation across modified and new scripts
    $scriptsToParse = @($backendPath, $launcherPs1, $guiPs1, $installPs1, $updatePs1, $uninstallPs1, $PSCommandPath)
    foreach ($file in $scriptsToParse) {
        $errs = $null
        $null = [System.Management.Automation.Language.Parser]::ParseFile($file, [ref]$null, [ref]$errs)
        Assert-True (@($errs).Count -eq 0) "AST parse has 0 syntax errors for $([IO.Path]::GetFileName($file))"
    }

    # 2. Static security invariants on GUI wrapper (.cmd + .ps1)
    Assert-True (Test-Path -LiteralPath $guiCmd -PathType Leaf) 'ClaudeCleanupGUI.cmd exists at repository root'
    Assert-True (Test-Path -LiteralPath $guiPs1 -PathType Leaf) 'scripts/ClaudeCleanupGUI.ps1 exists'
    $guiCmdText = [IO.File]::ReadAllText($guiCmd, [System.Text.Encoding]::UTF8)
    $guiPs1Text = [IO.File]::ReadAllText($guiPs1, [System.Text.Encoding]::UTF8)
    Assert-True ($guiCmdText -notmatch '(?i)Bypass|Unrestricted|RunAs|-Apply|Invoke-Expression') 'ClaudeCleanupGUI.cmd has zero bypass, UAC elevation, or -Apply'

    $guiAst = [System.Management.Automation.Language.Parser]::ParseFile($guiPs1, [ref]$null, [ref]$null)
    $guiCmdNames = @($guiAst.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] }, $true) | ForEach-Object { $_.GetCommandName() })
    Assert-True (
        ($guiCmdNames -notcontains 'Remove-Item') -and
        ($guiCmdNames -notcontains 'Invoke-Expression') -and
        ($guiPs1Text -notmatch '(?i)ExecutionPolicy\s+(Bypass|Unrestricted)|RegDeleteKeyW|SetFileInformationByHandle|NtDeleteKey|Verb\s+["'']?RunAs')
    ) 'ClaudeCleanupGUI.ps1 duplicates zero deletion APIs and contains no policy bypass or elevation'
    Assert-True (($guiPs1Text -match 'btnClean\.Enabled\s*=\s*\$false') -and ($guiPs1Text -match '-WhatIf') -and ($guiPs1Text -match 'YesNo')) 'ClaudeCleanupGUI.ps1 disables Clean button initially and mandates -WhatIf preview + confirmation dialog'

    # 3. CLI bilingual output & UTF-8 encoding checks
    $helpZh = Invoke-Utf8ChildPowerShell -ScriptPath $backendPath -ScriptArgs @('-Help', '-Language', 'zh-CN')
    Assert-True ($helpZh.ExitCode -eq 0 -and $helpZh.StdOut -match '账号封号残余' -and $helpZh.StdOut -match '绝不改动或损害 Windows 操作系统本身' -and (-not $helpZh.StdOut.Contains([char]0xFFFD))) 'ClaudeCleanup.ps1 -Help -Language zh-CN outputs clean UTF-8 Chinese positioning'

    $helpEn = Invoke-Utf8ChildPowerShell -ScriptPath $backendPath -ScriptArgs @('-Help', '-Language', 'en-US')
    Assert-True ($helpEn.ExitCode -eq 0 -and $helpEn.StdOut -match 'Banned-Account Residual ID' -and $helpEn.StdOut -match 'without altering or harming the Windows OS itself') 'ClaudeCleanup.ps1 -Help -Language en-US outputs expected English positioning'

    # 4. Verify JSON schema key invariance across zh-CN and en-US
    $verJsonZhRes = Invoke-Utf8ChildPowerShell -ScriptPath $backendPath -ScriptArgs @('-Verify', '-Language', 'zh-CN', '-OutputFormat', 'Json')
    $verJsonEnRes = Invoke-Utf8ChildPowerShell -ScriptPath $backendPath -ScriptArgs @('-Verify', '-Language', 'en-US', '-OutputFormat', 'Json')
    Assert-True ($verJsonZhRes.ExitCode -eq 0 -and $verJsonEnRes.ExitCode -eq 0) 'ClaudeCleanup.ps1 -Verify -OutputFormat Json succeeds in both zh-CN and en-US'
    $objZh = $verJsonZhRes.StdOut | ConvertFrom-Json
    $objEn = $verJsonEnRes.StdOut | ConvertFrom-Json
    $keysZh = @($objZh.PSObject.Properties.Name | Sort-Object) -join ','
    $keysEn = @($objEn.PSObject.Properties.Name | Sort-Object) -join ','
    Assert-True ($objZh.SchemaVersion -eq 3 -and $objEn.SchemaVersion -eq 3 -and $keysZh -eq $keysEn -and $objZh.Language -eq 'zh-CN' -and $objEn.Language -eq 'en-US') 'JSON output maintains identical schema keys across zh-CN and en-US'

    # 5. Isolated localized Markdown report & ledger parsing tests inside tests/sandbox/stage-h/
    . $backendPath
    Assert-True ((Resolve-UiLanguage -RequestedLanguage 'zh-CN') -eq 'zh-CN' -and (Resolve-UiLanguage -RequestedLanguage 'en-US') -eq 'en-US' -and ((Resolve-UiLanguage -RequestedLanguage 'Auto') -in @('zh-CN', 'en-US'))) 'Resolve-UiLanguage handles Auto, zh-CN, and en-US cleanly'

    $sbSampleFile = Join-Path $stageHSandbox 'sample-residual.txt'
    [IO.File]::WriteAllText($sbSampleFile, 'dummy', (New-Object System.Text.UTF8Encoding($false)))
    $sbCand = Get-Candidate -Id 'sb-bilingual' -Path $sbSampleFile -Category 'Test Residual' -Policy 'AccountData' -Decision 'Ready'
    $sbRec = Get-ArtifactRecord $sbCand
    $sbPlanPath = Join-Path $stageHSandbox 'CLEANUP-PLAN.md'
    $sbPlanHash = Write-PlanDocument -Records @($sbRec) -PlanPath $sbPlanPath -Lang 'zh-CN'
    $planTextZh = [IO.File]::ReadAllText($sbPlanPath, [System.Text.Encoding]::UTF8)
    Assert-True ($planTextZh -match 'Windows Claude 封号残余数据清理方案' -and $planTextZh -match '计划 ID:') 'Write-PlanDocument localizes CLEANUP-PLAN.md under zh-CN'
    $parsedPlan = Read-AuthorizedPlanDocument -PlanPath $sbPlanPath -ApprovedHash $sbPlanHash
    Assert-True ($parsedPlan.Manifest.SchemaVersion -eq 3 -and @($parsedPlan.Records).Count -eq 1) 'Read-AuthorizedPlanDocument parses localized zh-CN CLEANUP-PLAN.md'

    $sbAuditZh = Join-Path $stageHSandbox 'AUDIT.zh.md'
    $fakeAuditReport = [pscustomobject]@{
        GeneratedUtc = [DateTime]::UtcNow.ToString('o')
        PowerShellVersion = $PSVersionTable.PSVersion.ToString()
        EnvironmentLines = @('Credential Manager Claude* target count: 1')
        Inventory = @($sbCand)
    }
    $null = Write-AuditReportDocument -AuditPath $sbAuditZh -Lang 'zh-CN' -StructuredReport $fakeAuditReport
    $auditTextZh = [IO.File]::ReadAllText($sbAuditZh, [System.Text.Encoding]::UTF8)
    Assert-True ((Test-Path -LiteralPath $sbAuditZh) -and ($auditTextZh -match '只读审计报告') -and ($auditTextZh -match '绝不读取或保存环境变量秘密值')) 'Write-AuditReportDocument produces localized zh-CN AUDIT.md without secret exposure'

    $sbVerPath = Join-Path $stageHSandbox 'VERIFICATION.md'
    $prevLang = $script:ActiveLanguage
    $script:ActiveLanguage = 'zh-CN'
    try {
        $ledgerEntry = [pscustomobject]@{
            PlanId = $parsedPlan.Manifest.PlanId
            ManifestSha256 = $sbPlanHash
            Policy = 'AccountData'
            StartedUtc = [DateTime]::UtcNow.ToString('o')
            CompletedUtc = [DateTime]::UtcNow.ToString('o')
            Outcome = 'Succeeded'
            Results = @()
        }
        Save-ExecutionLedgerEntry -VerificationPath $sbVerPath -Entry $ledgerEntry
    } finally {
        $script:ActiveLanguage = $prevLang
    }
    $verTextZh = [IO.File]::ReadAllText($sbVerPath, [System.Text.Encoding]::UTF8)
    $parsedLedger = @(Get-ExecutionLedgerEntries -VerificationPath $sbVerPath)
    Assert-True (($verTextZh -match '^# 执行核验报告与账本') -and ($parsedLedger.Count -eq 1) -and ($parsedLedger[0].PlanId -eq $parsedPlan.Manifest.PlanId)) 'Localized zh-CN VERIFICATION.md ledger initializes and parses accurately'

    $truncZhVer = Join-Path $stageHSandbox 'VERIFICATION-TRUNC-ZH.md'
    [IO.File]::WriteAllText($truncZhVer, "# 执行核验报告与账本`r`n", (New-Object System.Text.UTF8Encoding($false)))
    Assert-Throws -Action { Get-ExecutionLedgerEntries -VerificationPath $truncZhVer } 'Localized zh-CN verification header missing ledger markers fails closed'

    # 6. Bilingual launcher checks
    $launchHelpZh = Invoke-Utf8ChildPowerShell -ScriptPath $launcherPs1 -ScriptArgs @('-Action', 'Help', '-Language', 'zh-CN', '-Exit')
    Assert-True ($launchHelpZh.ExitCode -eq 0 -and $launchHelpZh.StdOut -match '启动器安全提示') 'Launcher Help supports zh-CN output cleanly'

    $launchGuiSmoke = Invoke-Utf8ChildPowerShell -ScriptPath $launcherPs1 -ScriptArgs @('-Action', 'LaunchGui', '-Language', 'zh-CN', '-Exit')
    Assert-True ($launchGuiSmoke.ExitCode -eq 0 -and $launchGuiSmoke.StdOut -match 'ClaudeCleanupGUI\.ps1') 'Launcher -Action LaunchGui -Exit validates GUI integration cleanly'

    $launcherViewFake = Join-Path $stageHSandbox 'launcher-reports'
    New-Item -ItemType Directory -Path $launcherViewFake -Force | Out-Null
    Copy-Item -LiteralPath $backendPath -Destination (Join-Path $launcherViewFake 'ClaudeCleanup.ps1') -Force
    Copy-Item -LiteralPath $sbPlanPath -Destination (Join-Path $launcherViewFake 'CLEANUP-PLAN.md') -Force
    $viewRepRes = Invoke-Utf8ChildPowerShell -ScriptPath $launcherPs1 -ScriptArgs @('-Action', 'ViewReports', '-Language', 'zh-CN', '-OutputFormat', 'Json', '-ToolkitRoot', $launcherViewFake, '-Exit')
    $viewObj = $viewRepRes.StdOut | ConvertFrom-Json
    $planRep = @($viewObj.Reports | Where-Object { $_.Name -eq 'CLEANUP-PLAN.md' })[0]
    Assert-True ($viewRepRes.ExitCode -eq 0 -and $viewObj.Language -eq 'zh-CN' -and $planRep.PlanId -eq $parsedPlan.Manifest.PlanId) 'Launcher ViewReports extracts PlanId from localized zh-CN CLEANUP-PLAN.md'

    # 7. Native Desktop GUI headless instantiation, live toggle, and safety checks
    $guiHeadlessCmd = @"
`$res = & '$($guiPs1.Replace("'", "''"))' -Headless -DryRun -Language en-US
`$res | ConvertTo-Json -Depth 4
"@
    $guiRunner = Join-Path $stageHSandbox 'run-gui-headless.ps1'
    [IO.File]::WriteAllText($guiRunner, $guiHeadlessCmd, (New-Object System.Text.UTF8Encoding($true)))
    $guiRun = Invoke-Utf8ChildPowerShell -ScriptPath $guiRunner -UseSta
    Assert-True ($guiRun.ExitCode -eq 0) "Native GUI instantiates cleanly in headless STA mode ($($guiRun.StdErr))"
    $guiJsonIdx = $guiRun.StdOut.IndexOf('{')
    $guiInfo = ($guiRun.StdOut.Substring($guiJsonIdx)) | ConvertFrom-Json
    Assert-True (
        $guiInfo.GuiInstantiated -and
        $guiInfo.InitialLanguage -eq 'en-US' -and
        $guiInfo.ToggledLanguage -eq 'zh-CN' -and
        (-not $guiInfo.InitialCleanButtonEnabled) -and
        $guiInfo.ChecklistCount -eq 5 -and
        ($guiInfo.InitialBadge -match 'Never Alters Windows OS') -and
        ($guiInfo.ToggledBadge -match '绝不改动 Windows 系统本身') -and
        $guiInfo.DryRun
    ) 'Native GUI verifies live EN->zh-CN toggle, 5-category checklist, OS-safety badge, and disabled-by-default Clean button'

    Write-Output "RESULT: $passed passed; $skipped skipped; $notExecuted not_executed; $($failedList.Count) failed"
    if ($failedList.Count -gt 0) { exit 1 }
    exit 0
} finally {
    if (Test-Path -LiteralPath $stageHSandbox) {
        try {
            Remove-Item -LiteralPath $stageHSandbox -Recurse -Force
        } catch {
            Write-Warning "Failed to clean stage-h sandbox: $($_.Exception.Message)"
        }
    }
    if (-not $sandboxExisted -and (Test-Path -LiteralPath $sandboxRoot)) {
        $remaining = @(Get-ChildItem -LiteralPath $sandboxRoot -Force)
        if ($remaining.Count -eq 0) {
            try {
                [IO.Directory]::Delete($sandboxRoot, $false)
            } catch {
                Write-Warning "Empty sandbox root retained: $sandboxRoot ($($_.Exception.Message))"
            }
        }
    }
}
