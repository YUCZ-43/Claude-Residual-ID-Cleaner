Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$scriptPath = Join-Path $repoRoot 'ClaudeCleanup.ps1'
$skillRoot = Join-Path $repoRoot 'skills\claude-cleanup'
$skillMdPath = Join-Path $skillRoot 'SKILL.md'
$permRefPath = Join-Path $skillRoot 'references\permissions-and-risks.md'
$installRefPath = Join-Path $skillRoot 'references\agent-installation.md'
$usageGuideZhPath = Join-Path $repoRoot 'docs\Skills-Usage-Guide.md'
$usageGuideEnPath = Join-Path $repoRoot 'docs\Skills-Usage-Guide.en.md'

$sandboxRoot = Join-Path $PSScriptRoot 'sandbox'
$sandboxRootExisted = Test-Path -LiteralPath $sandboxRoot
$skillSandbox = Join-Path $sandboxRoot 'skill'
if (Test-Path -LiteralPath $skillSandbox) {
    throw "Skill test sandbox already exists: $skillSandbox"
}
New-Item -ItemType Directory -Path $skillSandbox -Force | Out-Null

. $scriptPath

$passed = 0
$skipped = 0
$notExecuted = 0
$failedList = New-Object 'System.Collections.Generic.List[string]'

function Assert-True([bool]$Condition, [string]$Name) {
    if (-not $Condition) {
        $script:failedList.Add($Name)
        throw "FAIL: $Name"
    }
    $script:passed++
    Write-Output "PASS: $Name"
}

function Parse-SkillFrontmatter {
    param([Parameter(Mandatory = $true)][string]$Content)

    $lines = $Content -split "`r?`n"
    if ($lines.Count -lt 3 -or $lines[0].Trim() -ne '---') {
        return $null
    }

    $endIndex = -1
    for ($i = 1; $i -lt $lines.Count; $i++) {
        if ($lines[$i].Trim() -eq '---') {
            $endIndex = $i
            break
        }
    }
    if ($endIndex -lt 1) {
        return $null
    }

    $fmLines = @()
    if ($endIndex -gt 1) {
        $fmLines = @($lines[1..($endIndex - 1)])
    }

    $fields = @{}
    $currentKey = $null
    $foldedMode = $false
    $buffer = New-Object 'System.Collections.Generic.List[string]'

    foreach ($line in $fmLines) {
        if ($line -match '^([A-Za-z0-9_-]+)\s*:\s*(.*)$') {
            if ($null -ne $currentKey) {
                $fields[$currentKey] = (($buffer.ToArray() -join ' ').Trim())
                $buffer.Clear()
            }
            $currentKey = $Matches[1]
            $val = $Matches[2].Trim()
            if ($val -eq '>-' -or $val -eq '>' -or $val -eq '|-' -or $val -eq '|') {
                $foldedMode = $true
            } else {
                $foldedMode = $false
                $unquoted = $val.Trim('"', "'")
                $buffer.Add($unquoted)
            }
        } elseif ($null -ne $currentKey -and ($foldedMode -or $line -match '^\s+')) {
            $trimmed = $line.Trim()
            if (-not [string]::IsNullOrEmpty($trimmed)) {
                $buffer.Add($trimmed)
            }
        }
    }
    if ($null -ne $currentKey) {
        $fields[$currentKey] = (($buffer.ToArray() -join ' ').Trim())
    }

    return [pscustomobject]@{
        Fields = $fields
        Body   = (($lines[($endIndex + 1)..($lines.Count - 1)]) -join "`n")
    }
}

function Get-FileStateSnapshot {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        return [pscustomobject]@{ Exists = $false; Length = 0; LastWriteUtcTicks = 0 }
    }
    $item = Get-Item -LiteralPath $Path
    return [pscustomobject]@{
        Exists            = $true
        Length            = [int64]$item.Length
        LastWriteUtcTicks = $item.LastWriteTimeUtc.Ticks
    }
}

try {
    # 1. Required skill package structure and zero duplicated cleanup scripts
    Assert-True (Test-Path -LiteralPath $skillMdPath) 'skills/claude-cleanup/SKILL.md exists'
    Assert-True (Test-Path -LiteralPath $permRefPath) 'skills/claude-cleanup/references/permissions-and-risks.md exists'
    Assert-True (Test-Path -LiteralPath $installRefPath) 'skills/claude-cleanup/references/agent-installation.md exists'

    $extraCodeFiles = @(Get-ChildItem -LiteralPath $skillRoot -Recurse -File | Where-Object { $_.Extension -in @('.ps1', '.psm1', '.cmd', '.bat', '.vbs', '.js', '.py') })
    Assert-True ($extraCodeFiles.Count -eq 0) 'skill package contains zero duplicated helper scripts'

    # 2. Frontmatter and cross-agent discovery metadata
    $utf8Strict = New-Object System.Text.UTF8Encoding($false, $true)
    $skillBytes = [IO.File]::ReadAllBytes($skillMdPath)
    $skillText = $utf8Strict.GetString($skillBytes)
    $parsedFm = Parse-SkillFrontmatter -Content $skillText
    Assert-True ($null -ne $parsedFm) 'SKILL.md contains valid YAML frontmatter block'

    $skillName = if ($parsedFm.Fields.ContainsKey('name')) { [string]$parsedFm.Fields['name'] } else { '' }
    $skillDesc = if ($parsedFm.Fields.ContainsKey('description')) { [string]$parsedFm.Fields['description'] } else { '' }
    $folderName = Split-Path -Leaf $skillRoot
    Assert-True ($skillName -eq 'claude-cleanup' -and $skillName -eq $folderName) 'SKILL.md name matches claude-cleanup folder'
    Assert-True ($skillName -match '^[a-z0-9-]+$' -and $skillName.Length -le 64) 'SKILL.md name follows lowercase-hyphenated specification'
    Assert-True ((-not [string]::IsNullOrWhiteSpace($skillDesc)) -and $skillDesc.Length -le 1024) 'SKILL.md description is non-empty and within 1024 chars'
    Assert-True (($skillDesc -match 'ClaudeCleanup\.ps1') -and ($skillDesc -match 'Windows') -and ($skillDesc -match 'Audit|audit')) 'SKILL.md description clearly states Windows ClaudeCleanup.ps1 trigger and scope'

    # 3. Relative Markdown link resolution inside self-contained skill package
    $docFiles = @($skillMdPath, $permRefPath, $installRefPath)
    $allLinksValid = $true
    $checkedLinks = 0
    foreach ($doc in $docFiles) {
        $docBytes = [IO.File]::ReadAllBytes($doc)
        $docText = $utf8Strict.GetString($docBytes)
        $docDir = Split-Path -Parent $doc
        $linkMatches = [regex]::Matches($docText, '\[[^\]]+\]\(([^)]+)\)')
        foreach ($m in $linkMatches) {
            $target = $m.Groups[1].Value.Trim()
            if ($target -match '^(https?://|mailto:|#)') { continue }
            $targetNoAnchor = ($target -split '#')[0]
            if ([string]::IsNullOrWhiteSpace($targetNoAnchor)) { continue }
            $resolved = [IO.Path]::GetFullPath((Join-Path $docDir ($targetNoAnchor -replace '/', '\')))
            $checkedLinks++
            if (-not (Test-PathWithin -Path $resolved -Root $skillRoot) -or -not (Test-Path -LiteralPath $resolved)) {
                Write-Warning "Invalid relative link in ${doc}: $target -> $resolved"
                $allLinksValid = $false
            }
        }
    }
    Assert-True ($checkedLinks -ge 4 -and $allLinksValid) 'all internal relative Markdown links inside skills/claude-cleanup resolve cleanly'

    # 4. Safety, authorization gate, ExecutionPolicy, and REA invariants
    $permText = $utf8Strict.GetString([IO.File]::ReadAllBytes($permRefPath))
    $installText = $utf8Strict.GetString([IO.File]::ReadAllBytes($installRefPath))
    $allSkillText = $skillText + "`n" + $permText + "`n" + $installText

    Assert-True (($skillText -match 'ClaudeCleanup\.ps1') -and ($skillText -match 'Single Backend Only') -and ($skillText -match 'Zero Duplicated Deletion')) 'SKILL.md enforces single ClaudeCleanup.ps1 backend with zero duplicated deletion code'
    Assert-True (($skillText -match 'Read-Only Default') -and ($skillText -match '-Audit') -and ($skillText -match '-Verify')) 'SKILL.md defaults to read-only -Audit and covers -Verify'
    Assert-True (($skillText -match 'ApprovedManifestSha256') -and ($skillText -match '-WhatIf') -and ($skillText -match 'AccountData') -and ($skillText -match 'FullRemoval')) 'SKILL.md requires manifest SHA-256, policy, -WhatIf preview, and per-target approval before -Apply'
    Assert-True (($skillText -match 'Never Recommend `-ExecutionPolicy Bypass`') -and ($allSkillText -match 'REA') -and ($allSkillText -match 'optional development-time')) 'skill docs forbid ExecutionPolicy Bypass and keep REA strictly optional dev-only'

    # Ensure fenced code blocks never recommend dangerous or duplicated commands
    $codeBlocks = [regex]::Matches($allSkillText, '```[a-zA-Z]*\r?\n([\s\S]*?)```')
    $unsafeCodeFound = $false
    foreach ($cb in $codeBlocks) {
        $block = $cb.Groups[1].Value
        if ($block -match '(?i)(-ExecutionPolicy\s+Bypass|-ep\s+bypass|ExecutionPolicy\s+Unrestricted|-Confirm:\$false|Remove-Item|RegDeleteKeyW|Remove-AppxPackage|SetFileInformationByHandle|NtDeleteKey)') {
            $unsafeCodeFound = $true
        }
    }
    Assert-True (-not $unsafeCodeFound) 'no fenced code block recommends ExecutionPolicy Bypass, -Confirm:$false, or duplicated deletion commands'

    # Check agent coverage and clean uninstall documentation
    Assert-True (($installText -match 'Codex CLI') -and ($installText -match 'Antigravity CLI') -and ($installText -match 'Gemini CLI') -and ($installText -match 'Claude Code')) 'agent-installation.md documents all four target agent CLIs'
    Assert-True (($installText -match 'Uninstallation') -and ($installText -match 'does \*\*not\*\* remove Claude') -and ($installText -match 'Live CLI Discovery Check')) 'agent-installation.md documents skill-only uninstallation and manual live CLI discovery check'
    Assert-True (($permText -match 'SetFileInformationByHandle') -and ($permText -match 'NtDeleteKey') -and ($permText -match 'SchemaVersion = 3') -and ($permText -match 'Unknown')) 'permissions-and-risks.md accurately summarizes Win32, registry, manifest, and 3-state safeguards'

    # 4b. Bilingual Skills Usage Guides (docs/Skills-Usage-Guide.md & docs/Skills-Usage-Guide.en.md)
    Assert-True ((Test-Path -LiteralPath $usageGuideZhPath -PathType Leaf) -and (Test-Path -LiteralPath $usageGuideEnPath -PathType Leaf)) 'docs/Skills-Usage-Guide.md and docs/Skills-Usage-Guide.en.md exist'
    $usageGuideZhText = $utf8Strict.GetString([IO.File]::ReadAllBytes($usageGuideZhPath))
    $usageGuideEnText = $utf8Strict.GetString([IO.File]::ReadAllBytes($usageGuideEnPath))
    $emojiRegex = '[\u2600-\u27BF]|[\uD800-\uDBFF][\uDC00-\uDFFF]'
    Assert-True (
        ($usageGuideZhText -match 'Antigravity') -and
        ($usageGuideZhText -match 'Codex CLI') -and
        ($usageGuideZhText -match 'Claude Code') -and
        ($usageGuideZhText -match 'Gemini CLI') -and
        ($usageGuideZhText -match 'Skills-Usage-Guide\.en\.md') -and
        ($usageGuideEnText -match 'Antigravity') -and
        ($usageGuideEnText -match 'Codex CLI') -and
        ($usageGuideEnText -match 'Claude Code') -and
        ($usageGuideEnText -match 'Gemini CLI') -and
        ($usageGuideEnText -match 'Skills-Usage-Guide\.md')
    ) 'Bilingual Skills-Usage-Guide docs cover Antigravity, Codex CLI, Claude Code, Gemini CLI, and bidirectional links'

    Assert-True (
        ($usageGuideZhText -notmatch $emojiRegex) -and
        ($usageGuideEnText -notmatch $emojiRegex) -and
        (-not $usageGuideZhText.Contains([char]0xFFFD)) -and
        (-not $usageGuideEnText.Contains([char]0xFFFD))
    ) 'Bilingual Skills-Usage-Guide docs contain zero emojis and zero UTF-8 replacement characters'

    $combinedBrandDocs = $skillText + "`n" + $permText + "`n" + $installText + "`n" + $usageGuideZhText + "`n" + $usageGuideEnText
    Assert-True (
        ($combinedBrandDocs -notmatch '(?i)suyuan2022|suyuan-skill') -and
        ($combinedBrandDocs -notmatch 'YUCZ-43/claude-cleanup') -and
        ($usageGuideZhText -match 'YUCZ-43/Claude-Residual-ID-Cleaner') -and
        ($usageGuideEnText -match 'YUCZ-43/Claude-Residual-ID-Cleaner')
    ) 'Skill package and guides use YUCZ-43/Claude-Residual-ID-Cleaner branding with zero suyuan2022 references'

    # 5. Privacy & placeholder checks (zero personal user paths or SIDs)
    $allCheckedDocs = @($skillText, $permText, $installText, $usageGuideZhText, $usageGuideEnText, ($utf8Strict.GetString([IO.File]::ReadAllBytes($PSCommandPath))))
    $privacyLeak = $false
    foreach ($txt in $allCheckedDocs) {
        if ($txt -match 'C:\\Users\\(?!<USERNAME>)[A-Za-z0-9._-]+' -or $txt -match 'S-1-5-21-\d+') {
            $privacyLeak = $true
        }
    }
    Assert-True (-not $privacyLeak) 'skill docs and tests contain zero personal local paths or Windows SIDs'

    # 6. PowerShell syntax & parameter contract verification against ClaudeCleanup.ps1
    $parseErrors = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$null, [ref]$parseErrors)
    Assert-True (@($parseErrors).Count -eq 0) 'ClaudeCleanup.ps1 parses with zero syntax errors'

    $cmdInfo = Get-Command $scriptPath
    $hasRequiredParams = $cmdInfo.Parameters.ContainsKey('Audit') -and
        $cmdInfo.Parameters.ContainsKey('Plan') -and
        $cmdInfo.Parameters.ContainsKey('Apply') -and
        $cmdInfo.Parameters.ContainsKey('Verify') -and
        $cmdInfo.Parameters.ContainsKey('Help') -and
        $cmdInfo.Parameters.ContainsKey('Policy') -and
        $cmdInfo.Parameters.ContainsKey('ApprovedManifestSha256') -and
        $cmdInfo.Parameters.ContainsKey('OutputFormat') -and
        $cmdInfo.Parameters.ContainsKey('WhatIf')
    Assert-True $hasRequiredParams 'ClaudeCleanup.ps1 exposes all parameters documented in SKILL.md'

    # 7. Simulated cross-agent discovery install/uninstall inside tests/sandbox/skill/
    $mockHome = Join-Path $skillSandbox 'mock-home'
    $agentDirs = @(
        '.codex\skills\claude-cleanup',
        '.agents\skills\claude-cleanup',
        '.gemini\config\skills\claude-cleanup',
        '.gemini\skills\claude-cleanup',
        '.claude\skills\claude-cleanup'
    )
    $allSimulatedInstallsValid = $true
    foreach ($rel in $agentDirs) {
        $dest = Join-Path $mockHome $rel
        $parent = Split-Path -Parent $dest
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
        $unrelated = Join-Path $parent 'other-skill.txt'
        Set-Content -LiteralPath $unrelated -Value 'keep-me'
        Copy-Item -LiteralPath $skillRoot -Destination $dest -Recurse -Force

        $copiedSkill = Join-Path $dest 'SKILL.md'
        $copiedPerm = Join-Path $dest 'references\permissions-and-risks.md'
        $copiedInstall = Join-Path $dest 'references\agent-installation.md'
        if (-not ((Test-Path -LiteralPath $copiedSkill) -and (Test-Path -LiteralPath $copiedPerm) -and (Test-Path -LiteralPath $copiedInstall))) {
            $allSimulatedInstallsValid = $false
        }
        $copiedFm = Parse-SkillFrontmatter -Content ($utf8Strict.GetString([IO.File]::ReadAllBytes($copiedSkill)))
        if ($null -eq $copiedFm -or $copiedFm.Fields['name'] -ne 'claude-cleanup') {
            $allSimulatedInstallsValid = $false
        }

        # Simulated clean uninstall (removes only claude-cleanup folder, preserves sibling files)
        Invoke-SafeFileRemoval -Path $dest -AllowedRoots @($dest) -Confirm:$false | Out-Null
        if ((Test-Path -LiteralPath $dest) -or -not (Test-Path -LiteralPath $unrelated)) {
            $allSimulatedInstallsValid = $false
        }
    }
    Assert-True $allSimulatedInstallsValid 'simulated user-scoped skill install and clean uninstall pass across all 4 agent paths in tests/sandbox/skill'

    # 8. Non-destructive ClaudeCleanup.ps1 CLI invocation checks (-Help, -Audit, -Plan -WhatIf, -Verify)
    $psExe = if ($PSVersionTable.PSVersion.Major -ge 6) { 'pwsh.exe' } else { 'powershell.exe' }
    $planFile = Join-Path $repoRoot 'CLEANUP-PLAN.md'
    $verFile = Join-Path $repoRoot 'VERIFICATION.md'
    $planBefore = Get-FileStateSnapshot -Path $planFile
    $verBefore = Get-FileStateSnapshot -Path $verFile

    $helpOut = (& $psExe -NoProfile -File $scriptPath -Help) -join "`n"
    $helpExit = $LASTEXITCODE
    Assert-True ($helpExit -eq 0 -and ($helpOut -match '-Audit') -and ($helpOut -match '-Plan') -and ($helpOut -match '-Apply') -and ($helpOut -match '-Verify')) 'non-destructive ClaudeCleanup.ps1 -Help exits 0 and outputs expected modes'

    $auditJsonText = (& $psExe -NoProfile -File $scriptPath -Audit -OutputFormat Json) -join "`n"
    $auditExit = $LASTEXITCODE
    $auditObj = $auditJsonText | ConvertFrom-Json
    $envNoValues = (@($auditObj.Summary.EnvironmentVariableNames | Where-Object { $_.PSObject.Properties['Value'] }).Count -eq 0)
    Assert-True ($auditExit -eq 0 -and $auditObj.SchemaVersion -eq 3 -and $auditObj.Mode -eq 'Audit' -and $envNoValues) 'non-destructive -Audit -OutputFormat Json exits 0 with SchemaVersion 3 and no secret env values'

    $planWhatIfText = (& $psExe -NoProfile -File $scriptPath -Plan -WhatIf) -join "`n"
    $planWhatIfExit = $LASTEXITCODE
    Assert-True ($planWhatIfExit -eq 0 -and ($planWhatIfText -match 'WhatIf: would write')) 'non-destructive -Plan -WhatIf exits 0 and previews without writing manifest'

    $verifyJsonText = (& $psExe -NoProfile -File $scriptPath -Verify -OutputFormat Json) -join "`n"
    $verifyExit = $LASTEXITCODE
    $verifyObj = $verifyJsonText | ConvertFrom-Json
    Assert-True ($verifyExit -eq 0 -and $verifyObj.SchemaVersion -eq 3 -and $verifyObj.Mode -eq 'Verify' -and $null -ne $verifyObj.Verify) 'non-destructive -Verify -OutputFormat Json exits 0 with valid SchemaVersion 3 structure'

    $planAfter = Get-FileStateSnapshot -Path $planFile
    $verAfter = Get-FileStateSnapshot -Path $verFile
    Assert-True (
        ($planBefore.Exists -eq $planAfter.Exists) -and
        ($planBefore.LastWriteUtcTicks -eq $planAfter.LastWriteUtcTicks) -and
        ($verBefore.Exists -eq $verAfter.Exists) -and
        ($verBefore.LastWriteUtcTicks -eq $verAfter.LastWriteUtcTicks)
    ) 'non-destructive skill validation leaves CLEANUP-PLAN.md and VERIFICATION.md untouched'

    # 9. Honest NotExecuted accounting for live user-global CLI discovery checks
    $notExecuted += 4
    Write-Output 'NOT_EXECUTED: live Codex CLI skill discovery in ~/.agents/skills/claude-cleanup (global config untouched)'
    Write-Output 'NOT_EXECUTED: live Antigravity CLI skill discovery in ~/.gemini/config/skills/claude-cleanup (global config untouched)'
    Write-Output 'NOT_EXECUTED: live Gemini CLI skill discovery in ~/.gemini/skills/claude-cleanup (global config untouched)'
    Write-Output 'NOT_EXECUTED: live Claude Code skill discovery in ~/.claude/skills/claude-cleanup (global config untouched)'

    Write-Output "RESULT: $passed passed; $skipped skipped; $notExecuted not_executed; 0 failed"
} finally {
    if (Test-Path -LiteralPath $skillSandbox) {
        try {
            Invoke-SafeFileRemoval -Path $skillSandbox -AllowedRoots @($skillSandbox) -Confirm:$false | Out-Null
        } catch {
            Write-Warning "Skill test sandbox retained for manual inspection: $skillSandbox ($($_.Exception.Message))"
        }
    }
    if (-not $sandboxRootExisted -and (Test-Path -LiteralPath $sandboxRoot)) {
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
