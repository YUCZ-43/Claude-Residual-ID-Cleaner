[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$InstallRoot,
    [string]$SourceRoot,
    [switch]$UpdateSkill,
    [switch]$SkillOnly,
    [ValidateSet('Codex', 'Antigravity', 'Gemini', 'Claude', 'Agents', 'All')]
    [string[]]$SkillTarget,
    [string]$AgentHomeRoot,
    [string]$SkillSourcePath,
    [ValidateSet('Auto', 'zh-CN', 'en-US')]
    [string]$Language = 'Auto'
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$reqInstallRoot = $InstallRoot
$reqSourceRoot = $SourceRoot
$reqUpdateSkill = [bool]$UpdateSkill
$reqSkillOnly = [bool]$SkillOnly
$reqSkillTarget = $SkillTarget
$reqAgentHomeRoot = $AgentHomeRoot
$reqSkillSourcePath = $SkillSourcePath
$reqLanguage = $Language

$helperPath = Join-Path $PSScriptRoot 'Install-ClaudeCleanup.ps1'
if (-not (Test-Path -LiteralPath $helperPath -PathType Leaf)) {
    throw "Required helper script not found: $helperPath"
}
. $helperPath

$resolvedSource = if ([string]::IsNullOrWhiteSpace($reqSourceRoot)) {
    Get-NormalizedToolkitPath -Path (Split-Path -Parent $PSScriptRoot)
} else {
    Get-NormalizedToolkitPath -Path $reqSourceRoot
}
if (-not (Test-Path -LiteralPath $resolvedSource -PathType Container)) {
    throw "SourceRoot does not exist: $resolvedSource"
}

$updateToolkit = -not $reqSkillOnly
$updateSkillEffective = [bool]($reqUpdateSkill -or $reqSkillOnly)

# Preflight Phase: validate ALL toolkit and skill targets/manifests BEFORE any writes or deletions
$toolkitPlan = $null
if ($updateToolkit) {
    $candidateInstall = if ([string]::IsNullOrWhiteSpace($reqInstallRoot)) { Get-DefaultInstallRoot } else { $reqInstallRoot }
    $resolvedInstallRoot = Assert-SafeManagedRoot -Path $candidateInstall -Purpose 'toolkit update' -DisallowedSourceRoot $resolvedSource
    $manifestPath = Join-Path $resolvedInstallRoot $script:ToolkitManifestFileName
    $oldManifest = Read-JsonManifestFile -ManifestPath $manifestPath
    $payload = @(Get-ToolkitPayloadSpec -ResolvedSourceRoot $resolvedSource)

    $newRelSet = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($item in $payload) {
        $newRelSet.Add($item.RelativePath) | Out-Null
    }

    $obsoleteRelPaths = New-Object 'System.Collections.Generic.List[string]'
    foreach ($oldEntry in @($oldManifest.ManagedFiles)) {
        if ($null -eq $oldEntry -or [string]::IsNullOrWhiteSpace($oldEntry.RelativePath)) { continue }
        if (-not $newRelSet.Contains($oldEntry.RelativePath)) {
            $obsoleteRelPaths.Add($oldEntry.RelativePath)
        }
    }

    $toolkitPlan = [pscustomobject]@{
        InstallRoot = $resolvedInstallRoot
        ManifestPath = $manifestPath
        OldManifest = $oldManifest
        Payload = $payload
        ObsoleteRelPaths = $obsoleteRelPaths.ToArray()
    }
}

$skillPlanItems = New-Object 'System.Collections.Generic.List[object]'
$effectiveSkillSource = $null
$skillFiles = @()
if ($updateSkillEffective) {
    $effectiveSkillSource = if ([string]::IsNullOrWhiteSpace($reqSkillSourcePath)) {
        Join-Path $resolvedSource 'skills\claude-cleanup'
    } else {
        Get-NormalizedToolkitPath -Path $reqSkillSourcePath
    }
    $skillFiles = @(Get-SkillSourceFileList -SkillSourceDir $effectiveSkillSource)
    $targets = @(Resolve-SkillTargets -Targets $reqSkillTarget -HomeRoot $reqAgentHomeRoot)

    $newSkillRelSet = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($item in $skillFiles) {
        $newSkillRelSet.Add($item.RelativePath) | Out-Null
    }

    foreach ($t in $targets) {
        $skillManifestPath = Join-Path $t.TargetPath $script:SkillManifestFileName
        $oldSkillManifest = Read-JsonManifestFile -ManifestPath $skillManifestPath

        $obsoleteSkillPaths = New-Object 'System.Collections.Generic.List[string]'
        foreach ($oldEntry in @($oldSkillManifest.ManagedFiles)) {
            if ($null -eq $oldEntry -or [string]::IsNullOrWhiteSpace($oldEntry.RelativePath)) { continue }
            if (-not $newSkillRelSet.Contains($oldEntry.RelativePath)) {
                $obsoleteSkillPaths.Add($oldEntry.RelativePath)
            }
        }

        $skillPlanItems.Add([pscustomobject]@{
            Target = $t
            ManifestPath = $skillManifestPath
            OldManifest = $oldSkillManifest
            ObsoletePaths = $obsoleteSkillPaths.ToArray()
        })
    }
}

# Execution Phase
$toolkitResult = $null
if ($null -ne $toolkitPlan) {
    if ($PSCmdlet.ShouldProcess($toolkitPlan.InstallRoot, 'Update claude-cleanup toolkit (local reports preserved; no Claude app changes)')) {
        $copied = @(Copy-ManagedFileSet -DestRoot $toolkitPlan.InstallRoot -FileItems $toolkitPlan.Payload)
        $removedObsolete = @()
        if ($toolkitPlan.ObsoleteRelPaths.Count -gt 0) {
            $pruneResult = Remove-ManagedFileList -Root $toolkitPlan.InstallRoot -RelativePaths $toolkitPlan.ObsoleteRelPaths
            $removedObsolete = @($pruneResult.RemovedFiles)
        }
        $nowUtc = [DateTime]::UtcNow.ToString('o')
        $installedUtc = if ($null -ne $toolkitPlan.OldManifest.PSObject.Properties['InstalledUtc'] -and $toolkitPlan.OldManifest.InstalledUtc) {
            [string]$toolkitPlan.OldManifest.InstalledUtc
        } else {
            $nowUtc
        }
        $updatedManifest = [pscustomobject]@{
            SchemaVersion = 1
            ToolkitName = 'claude-cleanup'
            InstalledUtc = $installedUtc
            UpdatedUtc = $nowUtc
            SourceRoot = $resolvedSource
            InstallRoot = $toolkitPlan.InstallRoot
            ManagedFiles = $copied
        }
        $json = ConvertTo-Json -InputObject $updatedManifest -Depth 6
        Write-ToolkitUtf8NoBom -Path $toolkitPlan.ManifestPath -Content ($json + "`n")
        $toolkitResult = [pscustomobject]@{
            Updated = $true
            WhatIf = $false
            InstallRoot = $toolkitPlan.InstallRoot
            FileCount = $copied.Count
            ObsoleteFilesRemoved = $removedObsolete
            ManifestPath = $toolkitPlan.ManifestPath
        }
    } else {
        $toolkitResult = [pscustomobject]@{
            Updated = $false
            WhatIf = $true
            InstallRoot = $toolkitPlan.InstallRoot
            FileCount = $toolkitPlan.Payload.Count
            ObsoleteFilesRemoved = $toolkitPlan.ObsoleteRelPaths
            ManifestPath = $toolkitPlan.ManifestPath
        }
    }
}

$skillResults = New-Object 'System.Collections.Generic.List[object]'
foreach ($item in $skillPlanItems) {
    $t = $item.Target
    if ($PSCmdlet.ShouldProcess($t.TargetPath, "Update claude-cleanup Agent Skill for $($t.Agent) (strictly separated from Claude app removal)")) {
        $copiedSkill = @(Copy-ManagedFileSet -DestRoot $t.TargetPath -FileItems $skillFiles)
        $removedSkillObsolete = @()
        if ($item.ObsoletePaths.Count -gt 0) {
            $pruneSkill = Remove-ManagedFileList -Root $t.TargetPath -RelativePaths $item.ObsoletePaths
            $removedSkillObsolete = @($pruneSkill.RemovedFiles)
        }
        $nowUtc = [DateTime]::UtcNow.ToString('o')
        $installedUtc = if ($null -ne $item.OldManifest.PSObject.Properties['InstalledUtc'] -and $item.OldManifest.InstalledUtc) {
            [string]$item.OldManifest.InstalledUtc
        } else {
            $nowUtc
        }
        $updatedSkillManifest = [pscustomobject]@{
            SchemaVersion = 1
            SkillName = 'claude-cleanup'
            Agent = $t.Agent
            InstalledUtc = $installedUtc
            UpdatedUtc = $nowUtc
            SourcePath = $effectiveSkillSource
            TargetPath = $t.TargetPath
            ManagedFiles = $copiedSkill
        }
        $skillJson = ConvertTo-Json -InputObject $updatedSkillManifest -Depth 6
        Write-ToolkitUtf8NoBom -Path $item.ManifestPath -Content ($skillJson + "`n")
        $skillResults.Add([pscustomobject]@{
            Agent = $t.Agent
            TargetPath = $t.TargetPath
            Updated = $true
            WhatIf = $false
            FileCount = $copiedSkill.Count
            ObsoleteFilesRemoved = $removedSkillObsolete
        })
    } else {
        $skillResults.Add([pscustomobject]@{
            Agent = $t.Agent
            TargetPath = $t.TargetPath
            Updated = $false
            WhatIf = $true
            FileCount = $skillFiles.Count
            ObsoleteFilesRemoved = $item.ObsoletePaths
        })
    }
}

$resolvedLang = Resolve-ToolkitLanguage -RequestedLanguage $reqLanguage
$noticeText = if ($resolvedLang -eq 'zh-CN') {
    '工具升级仅更新受管工具文件并保留本地报告，绝不会修改 Windows 系统本身或 Claude 数据。'
} else {
    'Toolkit update replaces managed toolkit files and preserves local reports without altering Windows OS or Claude data.'
}
[pscustomobject]@{
    Action = 'Update'
    Language = $resolvedLang
    Notice = $noticeText
    Toolkit = $toolkitResult
    Skills = $skillResults.ToArray()
    ClaudeApplicationModified = $false
}
