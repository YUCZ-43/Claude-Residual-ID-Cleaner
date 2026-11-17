$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

$repoRoot = Split-Path -Parent $PSScriptRoot
$launcherCmd = Join-Path $repoRoot 'ClaudeCleanupLauncher.cmd'
$launcherPs1 = Join-Path $repoRoot 'scripts\ClaudeCleanupLauncher.ps1'
$installPs1 = Join-Path $repoRoot 'scripts\Install-ClaudeCleanup.ps1'
$updatePs1 = Join-Path $repoRoot 'scripts\Update-ClaudeCleanup.ps1'
$uninstallPs1 = Join-Path $repoRoot 'scripts\Uninstall-ClaudeCleanup.ps1'
$guiDoc = Join-Path $repoRoot 'docs\gui-evaluation.md'

$sandbox = Join-Path $PSScriptRoot 'sandbox'
if (Test-Path -LiteralPath $sandbox) {
    throw "Test sandbox already exists: $sandbox"
}
New-Item -ItemType Directory -Path $sandbox | Out-Null

$passed = 0
$skipped = 0
$notExecuted = 0
$failedList = New-Object 'System.Collections.Generic.List[string]'

function Assert-True {
    param(
        [Parameter(Mandatory = $true)][bool]$Condition,
        [Parameter(Mandatory = $true)][string]$Name
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
        [Parameter(Mandatory = $true)][scriptblock]$Action,
        [Parameter(Mandatory = $true)][string]$Name
    )
    $threw = $false
    try {
        & $Action | Out-Null
    } catch {
        $threw = $true
    }
    Assert-True -Condition $threw -Name $Name
}

function Copy-ToolkitSourceSnapshot {
    param(
        [Parameter(Mandatory = $true)][string]$FromRoot,
        [Parameter(Mandatory = $true)][string]$ToRoot,
        [switch]$OmitGuiDoc
    )
    $files = @(
        'ClaudeCleanup.ps1',
        'ClaudeCleanupLauncher.cmd',
        'ClaudeCleanupGUI.cmd',
        'scripts\ClaudeCleanupLauncher.ps1',
        'scripts\ClaudeCleanupGUI.ps1',
        'scripts\Install-ClaudeCleanup.ps1',
        'scripts\Update-ClaudeCleanup.ps1',
        'scripts\Uninstall-ClaudeCleanup.ps1',
        'README.md',
        'README.en.md'
    )
    if (-not $OmitGuiDoc) {
        $files += 'docs\gui-evaluation.md'
    }
    foreach ($rel in $files) {
        $src = Join-Path $FromRoot $rel
        $dst = Join-Path $ToRoot $rel
        $parent = Split-Path -Parent $dst
        if ($parent -and -not (Test-Path -LiteralPath $parent)) {
            [System.IO.Directory]::CreateDirectory($parent) | Out-Null
        }
        [System.IO.File]::Copy($src, $dst, $true)
    }
}

$currentPsExe = (Get-Process -Id $PID).Path

try {
    $installStage = Join-Path $sandbox 'install'
    $installTarget = Join-Path $sandbox 'install-target'
    New-Item -ItemType Directory -Path $installStage, $installTarget | Out-Null

    # 1. Static safety invariants across launcher, installer, updater, uninstaller
    $cmdText = [System.IO.File]::ReadAllText($launcherCmd, [System.Text.Encoding]::UTF8)
    $launcherText = [System.IO.File]::ReadAllText($launcherPs1, [System.Text.Encoding]::UTF8)
    $installText = [System.IO.File]::ReadAllText($installPs1, [System.Text.Encoding]::UTF8)
    $updateText = [System.IO.File]::ReadAllText($updatePs1, [System.Text.Encoding]::UTF8)
    $uninstallText = [System.IO.File]::ReadAllText($uninstallPs1, [System.Text.Encoding]::UTF8)

    Assert-True -Condition (($cmdText -notmatch '(?i)Bypass|Unrestricted|RunAs|-Apply|Invoke-Expression')) -Name 'ClaudeCleanupLauncher.cmd has no policy bypass, elevation, or -Apply'
    $launcherAst = [System.Management.Automation.Language.Parser]::ParseFile($launcherPs1, [ref]$null, [ref]$null)
    $launcherCmdNames = @($launcherAst.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] }, $true) | ForEach-Object { $_.GetCommandName() })
    $launcherParams = @($launcherAst.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandParameterAst] }, $true) | ForEach-Object { $_.ParameterName })
    Assert-True -Condition (
        ($launcherCmdNames -notcontains 'Remove-Item') -and
        ($launcherCmdNames -notcontains 'Invoke-Expression') -and
        ($launcherCmdNames -notcontains 'Start-Process') -and
        ($launcherParams -notcontains 'Apply') -and
        ($launcherParams -notcontains 'ExecutionPolicy') -and
        ($launcherText -notmatch '(?i)-ExecutionPolicy\s+(Bypass|Unrestricted)|RegDeleteKeyW|Verb\s+["'']?RunAs')
    ) -Name 'ClaudeCleanupLauncher.ps1 AST has no policy bypass, elevation, Remove-Item, or -Apply invocation'

    $lifecycleText = $installText + "`n" + $updateText + "`n" + $uninstallText
    Assert-True -Condition (($lifecycleText -notmatch '(?i)Remove-AppxPackage|npm\s+uninstall|--uninstall-extension|HKCU:|HKLM:|Set-Acl|icacls|ExecutionPolicy|Bypass|RunAs|Invoke-Expression') -and ($lifecycleText -notmatch 'ClaudeCleanup\.ps1\s+-Apply')) -Name 'Install/Update/Uninstall scripts contain zero Claude removal, registry, ACL, or policy bypass calls'

    # 2. Protected path rejections (dot-sourcing Install-ClaudeCleanup.ps1 helpers)
    . $installPs1
    Assert-Throws -Action { Assert-SafeManagedRoot -Path ([System.IO.Path]::GetPathRoot($sandbox)) -Purpose 'test' } -Name 'installer rejects drive root'
    Assert-Throws -Action { Assert-SafeManagedRoot -Path $env:USERPROFILE -Purpose 'test' } -Name 'installer rejects USERPROFILE root'
    Assert-Throws -Action { Assert-SafeManagedRoot -Path $env:APPDATA -Purpose 'test' } -Name 'installer rejects APPDATA root'
    Assert-Throws -Action { Assert-SafeManagedRoot -Path $env:LOCALAPPDATA -Purpose 'test' } -Name 'installer rejects LOCALAPPDATA root'
    Assert-Throws -Action { Assert-SafeManagedRoot -Path $env:WINDIR -Purpose 'test' } -Name 'installer rejects WINDIR'
    Assert-Throws -Action { Assert-SafeManagedRoot -Path $repoRoot -Purpose 'test' } -Name 'installer rejects git repository root'
    Assert-Throws -Action { Assert-SafeManagedRoot -Path (Join-Path $env:USERPROFILE '.codex') -Purpose 'test' } -Name 'installer rejects .codex root'
    Assert-Throws -Action { Assert-SafeChildRelativePath -Root $installTarget -RelativePath '..\escape.txt' } -Name 'installer rejects relative parent traversal'

    # 3. Launcher non-interactive smoke tests (.ps1 and .cmd)
    $helpOut = & $currentPsExe -NoProfile -File $launcherPs1 -Action Help -Exit 2>&1
    $helpExit = $LASTEXITCODE
    $helpJoined = ($helpOut | Out-String)
    Assert-True -Condition ($helpExit -eq 0 -and $helpJoined -match 'ClaudeCleanup\.ps1' -and $helpJoined -match 'Launcher Safety Notice') -Name 'ClaudeCleanupLauncher.ps1 -Action Help -Exit succeeds'

    $exitOnlyOut = & $currentPsExe -NoProfile -File $launcherPs1 -Exit 2>&1
    Assert-True -Condition ($LASTEXITCODE -eq 0) -Name 'ClaudeCleanupLauncher.ps1 -Exit succeeds without prompt'

    $actionExitOut = & $currentPsExe -NoProfile -File $launcherPs1 -Action Exit -Exit 2>&1
    Assert-True -Condition ($LASTEXITCODE -eq 0 -and (($actionExitOut | Out-String) -match 'Exiting Windows Claude Cleanup Launcher')) -Name 'ClaudeCleanupLauncher.ps1 -Action Exit -Exit succeeds'

    $cmdHelpOut = & cmd.exe /c "`"$launcherCmd`" -Action Help -Exit" 2>&1
    Assert-True -Condition ($LASTEXITCODE -eq 0 -and (($cmdHelpOut | Out-String) -match 'ClaudeCleanup\.ps1')) -Name 'ClaudeCleanupLauncher.cmd -Action Help -Exit succeeds'

    $cmdExitOut = & cmd.exe /c "`"$launcherCmd`" -Exit" 2>&1
    Assert-True -Condition ($LASTEXITCODE -eq 0) -Name 'ClaudeCleanupLauncher.cmd -Exit succeeds'

    $missingBackendDir = Join-Path $installStage 'missing-backend'
    New-Item -ItemType Directory -Path $missingBackendDir | Out-Null
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        & $currentPsExe -NoProfile -File $launcherPs1 -Action Help -Exit -ToolkitRoot $missingBackendDir 2>&1 | Out-Null
        $missingExit = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $prevEap
    }
    Assert-True -Condition ($missingExit -ne 0) -Name 'ClaudeCleanupLauncher.ps1 fails closed when ClaudeCleanup.ps1 is missing'

    # ViewReports test against synthetic sandboxed toolkit root
    $reportRoot = Join-Path $installStage 'report-smoke'
    Copy-ToolkitSourceSnapshot -FromRoot $repoRoot -ToRoot $reportRoot
    $syntheticPlan = @(
        '# Windows Claude cleanup plan',
        '',
        'Plan ID: 11111111-2222-3333-4444-555555555555',
        'Generated: 2026-11-16T00:00:00Z'
    ) -join "`n"
    [System.IO.File]::WriteAllText((Join-Path $reportRoot 'CLEANUP-PLAN.md'), $syntheticPlan, (New-Object System.Text.UTF8Encoding($false)))

    $viewJsonRaw = & $currentPsExe -NoProfile -File $launcherPs1 -Action ViewReports -OutputFormat Json -Exit -ToolkitRoot $reportRoot
    Assert-True -Condition ($LASTEXITCODE -eq 0) -Name 'ClaudeCleanupLauncher.ps1 -Action ViewReports -OutputFormat Json -Exit succeeds'
    $viewJson = ($viewJsonRaw | Out-String) | ConvertFrom-Json
    $planReportItem = @($viewJson.Reports | Where-Object { $_.Name -eq 'CLEANUP-PLAN.md' })[0]
    $auditReportItem = @($viewJson.Reports | Where-Object { $_.Name -eq 'AUDIT.md' })[0]
    Assert-True -Condition ($viewJson.Mode -eq 'ViewReports' -and $planReportItem.Exists -and $planReportItem.PlanId -eq '11111111-2222-3333-4444-555555555555' -and (-not $auditReportItem.Exists)) -Name 'Launcher ViewReports JSON summarizes present CLEANUP-PLAN.md and absent AUDIT.md'

    $verifyJsonRaw = & $currentPsExe -NoProfile -File $launcherPs1 -Action Verify -OutputFormat Json -Exit -ToolkitRoot $reportRoot
    Assert-True -Condition ($LASTEXITCODE -eq 0) -Name 'ClaudeCleanupLauncher.ps1 -Action Verify -OutputFormat Json -Exit succeeds'
    $verifyJson = ($verifyJsonRaw | Out-String) | ConvertFrom-Json
    Assert-True -Condition ($verifyJson.Mode -eq 'Verify' -and $verifyJson.SchemaVersion -eq 3) -Name 'Launcher Verify JSON returns backend SchemaVersion 3 payload'

    # 4. Toolkit Install -> Update -> Uninstall lifecycle inside tests/sandbox/install and tests/sandbox/install-target
    $sourceV1 = Join-Path $installStage 'source-v1'
    $sourceV2 = Join-Path $installStage 'source-v2'
    $toolkitTarget = Join-Path $installTarget 'toolkit'
    Copy-ToolkitSourceSnapshot -FromRoot $repoRoot -ToRoot $sourceV1
    # Seed non-payload artifacts in source-v1 to confirm installer never copies reports/tests
    [System.IO.File]::WriteAllText((Join-Path $sourceV1 'AUDIT.md'), 'do-not-copy', (New-Object System.Text.UTF8Encoding($false)))
    [System.IO.Directory]::CreateDirectory((Join-Path $sourceV1 'tests')) | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $sourceV1 'tests\dummy.txt'), 'do-not-copy', (New-Object System.Text.UTF8Encoding($false)))

    $whatIfInstall = & $installPs1 -SourceRoot $sourceV1 -InstallRoot $toolkitTarget -WhatIf
    Assert-True -Condition ($whatIfInstall.Toolkit.WhatIf -and (-not (Test-Path -LiteralPath $toolkitTarget))) -Name 'Install-ClaudeCleanup.ps1 -WhatIf does not write files'

    $installRes = & $installPs1 -SourceRoot $sourceV1 -InstallRoot $toolkitTarget
    Assert-True -Condition ($installRes.Toolkit.Installed -and (-not $installRes.ClaudeApplicationModified)) -Name 'Install-ClaudeCleanup.ps1 installs toolkit without touching Claude app'
    Assert-True -Condition ((Test-Path -LiteralPath (Join-Path $toolkitTarget 'ClaudeCleanup.ps1')) -and (Test-Path -LiteralPath (Join-Path $toolkitTarget 'ClaudeCleanupLauncher.cmd')) -and (Test-Path -LiteralPath (Join-Path $toolkitTarget 'docs\gui-evaluation.md')) -and (Test-Path -LiteralPath (Join-Path $toolkitTarget '.claude-cleanup-install.json'))) -Name 'installed toolkit contains core scripts, gui-evaluation.md, and manifest'
    Assert-True -Condition ((-not (Test-Path -LiteralPath (Join-Path $toolkitTarget 'AUDIT.md'))) -and (-not (Test-Path -LiteralPath (Join-Path $toolkitTarget 'tests\dummy.txt')))) -Name 'installer excludes local reports and tests from install target'

    $installedCmdOut = & cmd.exe /c "`"$(Join-Path $toolkitTarget 'ClaudeCleanupLauncher.cmd')`" -Action Help -Exit" 2>&1
    Assert-True -Condition ($LASTEXITCODE -eq 0 -and (($installedCmdOut | Out-String) -match 'ClaudeCleanup\.ps1')) -Name 'installed ClaudeCleanupLauncher.cmd runs independently from install-target'

    Assert-Throws -Action { & $installPs1 -SourceRoot $sourceV1 -InstallRoot $toolkitTarget } -Name 'Install-ClaudeCleanup.ps1 refuses duplicate install without -Force'

    # Simulate user-created report and custom note inside installed folder before update
    $installedAudit = Join-Path $toolkitTarget 'AUDIT.md'
    $installedNote = Join-Path $toolkitTarget 'user-note.txt'
    [System.IO.File]::WriteAllText($installedAudit, 'user-audit-report', (New-Object System.Text.UTF8Encoding($false)))
    [System.IO.File]::WriteAllText($installedNote, 'keep-user-note', (New-Object System.Text.UTF8Encoding($false)))

    Copy-ToolkitSourceSnapshot -FromRoot $repoRoot -ToRoot $sourceV2 -OmitGuiDoc
    $v2Readme = Join-Path $sourceV2 'README.md'
    [System.IO.File]::AppendAllText($v2Readme, "`n<!-- v2-test-marker -->`n", (New-Object System.Text.UTF8Encoding($false)))

    $whatIfUpdate = & $updatePs1 -SourceRoot $sourceV2 -InstallRoot $toolkitTarget -WhatIf
    Assert-True -Condition ($whatIfUpdate.Toolkit.WhatIf -and (Test-Path -LiteralPath (Join-Path $toolkitTarget 'docs\gui-evaluation.md'))) -Name 'Update-ClaudeCleanup.ps1 -WhatIf previews without modifying files'

    $updateRes = & $updatePs1 -SourceRoot $sourceV2 -InstallRoot $toolkitTarget
    $updatedReadmeText = [System.IO.File]::ReadAllText((Join-Path $toolkitTarget 'README.md'), [System.Text.Encoding]::UTF8)
    Assert-True -Condition ($updateRes.Toolkit.Updated -and ($updatedReadmeText -match 'v2-test-marker') -and (-not (Test-Path -LiteralPath (Join-Path $toolkitTarget 'docs\gui-evaluation.md'))) -and (@($updateRes.Toolkit.ObsoleteFilesRemoved) -contains 'docs\gui-evaluation.md')) -Name 'Update-ClaudeCleanup.ps1 updates changed files and prunes obsolete managed files'
    Assert-True -Condition ((Test-Path -LiteralPath $installedAudit) -and (Test-Path -LiteralPath $installedNote)) -Name 'Update-ClaudeCleanup.ps1 preserves user reports and custom files'

    $unmanagedDir = Join-Path $installTarget 'unmanaged'
    New-Item -ItemType Directory -Path $unmanagedDir | Out-Null
    Assert-Throws -Action { & $updatePs1 -SourceRoot $sourceV2 -InstallRoot $unmanagedDir } -Name 'Update-ClaudeCleanup.ps1 fails closed on unmanaged directory'
    Assert-Throws -Action { & $uninstallPs1 -InstallRoot $unmanagedDir } -Name 'Uninstall-ClaudeCleanup.ps1 fails closed on unmanaged directory'

    # Run the installed uninstaller itself (default keeps reports & user files)
    $installedUninstall = Join-Path $toolkitTarget 'scripts\Uninstall-ClaudeCleanup.ps1'
    $uninstallKeepRes = & $installedUninstall -InstallRoot $toolkitTarget
    Assert-True -Condition ($uninstallKeepRes.Toolkit.Uninstalled -and (-not $uninstallKeepRes.ClaudeApplicationModified) -and (-not (Test-Path -LiteralPath (Join-Path $toolkitTarget 'ClaudeCleanup.ps1'))) -and (-not (Test-Path -LiteralPath (Join-Path $toolkitTarget '.claude-cleanup-install.json')))) -Name 'installed Uninstall-ClaudeCleanup.ps1 removes all managed toolkit files and manifest'
    Assert-True -Condition ((Test-Path -LiteralPath $installedAudit) -and (Test-Path -LiteralPath $installedNote)) -Name 'default Uninstall-ClaudeCleanup.ps1 preserves local reports and user notes'

    # Clean reinstall and uninstall with -RemoveReports (root should be completely removed)
    [System.IO.File]::Delete($installedAudit)
    [System.IO.File]::Delete($installedNote)
    & $installPs1 -SourceRoot $sourceV1 -InstallRoot $toolkitTarget | Out-Null
    [System.IO.File]::WriteAllText($installedAudit, 'temp-audit', (New-Object System.Text.UTF8Encoding($false)))
    $uninstallPurgeRes = & $uninstallPs1 -InstallRoot $toolkitTarget -RemoveReports
    Assert-True -Condition ($uninstallPurgeRes.Toolkit.Uninstalled -and $uninstallPurgeRes.Toolkit.RootRemoved -and (-not (Test-Path -LiteralPath $toolkitTarget))) -Name 'Uninstall-ClaudeCleanup.ps1 -RemoveReports cleans empty install root'

    # 5. Optional explicit Agent Skill install -> update -> uninstall (strictly inside sandbox)
    $agentHome = Join-Path $installTarget 'agent-home'
    $claudeAppDataSim = Join-Path $agentHome '.claude\projects'
    $otherSkillDir = Join-Path $agentHome '.codex\skills\other-skill'
    New-Item -ItemType Directory -Path $claudeAppDataSim, $otherSkillDir | Out-Null
    $claudeKeepFile = Join-Path $claudeAppDataSim 'session-keep.jsonl'
    $otherSkillFile = Join-Path $otherSkillDir 'SKILL.md'
    [System.IO.File]::WriteAllText($claudeKeepFile, '{"keep":true}', (New-Object System.Text.UTF8Encoding($false)))
    [System.IO.File]::WriteAllText($otherSkillFile, '# Other Skill', (New-Object System.Text.UTF8Encoding($false)))

    $skillSrcV1 = Join-Path $installStage 'skill-v1'
    $skillSrcV2 = Join-Path $installStage 'skill-v2'
    New-Item -ItemType Directory -Path (Join-Path $skillSrcV1 'references'), $skillSrcV2 | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $skillSrcV1 'SKILL.md'), "# claude-cleanup v1`n", (New-Object System.Text.UTF8Encoding($false)))
    [System.IO.File]::WriteAllText((Join-Path $skillSrcV1 'references\guide.md'), "guide v1`n", (New-Object System.Text.UTF8Encoding($false)))
    [System.IO.File]::WriteAllText((Join-Path $skillSrcV2 'SKILL.md'), "# claude-cleanup v2`n", (New-Object System.Text.UTF8Encoding($false)))

    Assert-Throws -Action { & $installPs1 -InstallRoot $toolkitTarget -InstallSkill -AgentHomeRoot $agentHome -SkillSourcePath $skillSrcV1 } -Name 'Install-ClaudeCleanup.ps1 -InstallSkill requires explicit -SkillTarget'
    Assert-True -Condition (-not (Test-Path -LiteralPath $toolkitTarget)) -Name 'Atomic preflight prevents toolkit writes when skill preflight fails'
    $badSkillSrc = Join-Path $installStage 'skill-missing-md'
    New-Item -ItemType Directory -Path $badSkillSrc | Out-Null
    Assert-Throws -Action { & $installPs1 -SkillOnly -SkillTarget Codex -AgentHomeRoot $agentHome -SkillSourcePath $badSkillSrc } -Name 'Skill install fails closed when SKILL.md is missing'

    $skillInstallRes = & $installPs1 -SkillOnly -SkillTarget Codex,Claude -AgentHomeRoot $agentHome -SkillSourcePath $skillSrcV1
    $codexSkillDir = Join-Path $agentHome '.codex\skills\claude-cleanup'
    $claudeSkillDir = Join-Path $agentHome '.claude\skills\claude-cleanup'
    Assert-True -Condition (($null -eq $skillInstallRes.Toolkit) -and (-not $skillInstallRes.ClaudeApplicationModified) -and (@($skillInstallRes.Skills).Count -eq 2)) -Name 'SkillOnly install installs only selected skill targets without toolkit'
    Assert-True -Condition ((Test-Path -LiteralPath (Join-Path $codexSkillDir 'SKILL.md')) -and (Test-Path -LiteralPath (Join-Path $codexSkillDir 'references\guide.md')) -and (Test-Path -LiteralPath (Join-Path $claudeSkillDir 'SKILL.md'))) -Name 'Skill files copied to Codex and Claude sandbox skill directories'

    $skillUpdateRes = & $updatePs1 -SkillOnly -SkillTarget Codex,Claude -AgentHomeRoot $agentHome -SkillSourcePath $skillSrcV2
    $codexSkillText = [System.IO.File]::ReadAllText((Join-Path $codexSkillDir 'SKILL.md'), [System.Text.Encoding]::UTF8)
    Assert-True -Condition (($null -eq $skillUpdateRes.Toolkit) -and ($codexSkillText -match 'v2') -and (-not (Test-Path -LiteralPath (Join-Path $codexSkillDir 'references\guide.md')))) -Name 'Update-ClaudeCleanup.ps1 -SkillOnly updates SKILL.md and removes obsolete skill files'

    $skillUninstallRes = & $uninstallPs1 -SkillOnly -SkillTarget Codex,Claude -AgentHomeRoot $agentHome
    Assert-True -Condition (($null -eq $skillUninstallRes.Toolkit) -and (-not $skillUninstallRes.ClaudeApplicationModified) -and (-not (Test-Path -LiteralPath $codexSkillDir)) -and (-not (Test-Path -LiteralPath $claudeSkillDir))) -Name 'Uninstall-ClaudeCleanup.ps1 -SkillOnly removes claude-cleanup skill directories cleanly'
    Assert-True -Condition ((Test-Path -LiteralPath $claudeKeepFile) -and (Test-Path -LiteralPath $otherSkillFile)) -Name 'Skill uninstall preserves Claude application data and sibling skills'

    # 6. Reparse-point / junction rejection test on install target
    $junctionTarget = Join-Path $installStage 'junc-outside'
    $junctionInstall = Join-Path $installTarget 'junc-install'
    New-Item -ItemType Directory -Path $junctionTarget | Out-Null
    $juncCreated = $false
    try {
        New-Item -ItemType Junction -Path $junctionInstall -Target $junctionTarget -ErrorAction Stop | Out-Null
        $juncCreated = $true
    } catch {
        $skipped++
        Write-Output "SKIP: installer junction test skipped because environment blocked junction creation ($($_.Exception.Message))"
    }
    if ($juncCreated) {
        try {
            Assert-Throws -Action { & $installPs1 -SourceRoot $sourceV1 -InstallRoot $junctionInstall } -Name 'Install-ClaudeCleanup.ps1 rejects junction install root'
        } finally {
            [System.IO.Directory]::Delete($junctionInstall)
        }
    }

    # 7. docs/gui-evaluation.md relative links and privacy check
    $docText = [System.IO.File]::ReadAllText($guiDoc, [System.Text.Encoding]::UTF8)
    Assert-True -Condition (($docText -match 'Implemented in Stage H') -and ($docText -match 'ClaudeCleanup\.ps1') -and ($docText -match 'ClaudeCleanupGUI\.ps1') -and ($docText -notmatch 'C:\\Users\\')) -Name 'docs/gui-evaluation.md documents Stage H GUI implementation, references ClaudeCleanup.ps1 and ClaudeCleanupGUI.ps1, and has zero local user paths'

    $linkMatches = [regex]::Matches($docText, '\[[^\]]+\]\(([^)]+)\)')
    $brokenLinks = New-Object 'System.Collections.Generic.List[string]'
    $docDir = Split-Path -Parent $guiDoc
    foreach ($m in $linkMatches) {
        $href = $m.Groups[1].Value
        if ($href -match '^(https?:|#|mailto:)') { continue }
        $cleanHref = $href.Split('#')[0]
        $resolvedTarget = [System.IO.Path]::GetFullPath((Join-Path $docDir $cleanHref))
        if (-not (Test-Path -LiteralPath $resolvedTarget)) {
            $brokenLinks.Add($href)
        }
    }
    Assert-True -Condition ($brokenLinks.Count -eq 0) -Name 'docs/gui-evaluation.md has zero broken relative Markdown links'

    Write-Output "RESULT: $passed passed; $skipped skipped; $notExecuted not_executed; $($failedList.Count) failed"
    if ($failedList.Count -gt 0) {
        exit 1
    }
} finally {
    if (Test-Path -LiteralPath $sandbox) {
        Remove-Item -LiteralPath $sandbox -Recurse -Force -ErrorAction SilentlyContinue
    }
}
