[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$InstallRoot,
    [switch]$UninstallSkill,
    [switch]$SkillOnly,
    [ValidateSet('Codex', 'Antigravity', 'Gemini', 'Claude', 'Agents', 'All')]
    [string[]]$SkillTarget,
    [string]$AgentHomeRoot,
    [switch]$RemoveReports,
    [ValidateSet('Auto', 'zh-CN', 'en-US')]
    [string]$Language = 'Auto'
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$reqInstallRoot = $InstallRoot
$reqUninstallSkill = [bool]$UninstallSkill
$reqSkillOnly = [bool]$SkillOnly
$reqSkillTarget = $SkillTarget
$reqAgentHomeRoot = $AgentHomeRoot
$reqRemoveReports = [bool]$RemoveReports
$reqLanguage = $Language

$helperPath = Join-Path $PSScriptRoot 'Install-ClaudeCleanup.ps1'
if (-not (Test-Path -LiteralPath $helperPath -PathType Leaf)) {
    throw "Required helper script not found: $helperPath"
}
. $helperPath

$uninstallToolkit = -not $reqSkillOnly
$uninstallSkillEffective = [bool]($reqUninstallSkill -or $reqSkillOnly)

# Preflight Phase: validate ALL toolkit and skill manifests BEFORE deleting anything
$toolkitPlan = $null
if ($uninstallToolkit) {
    $candidateInstall = if ([string]::IsNullOrWhiteSpace($reqInstallRoot)) { Get-DefaultInstallRoot } else { $reqInstallRoot }
    $resolvedInstallRoot = Assert-SafeManagedRoot -Path $candidateInstall -Purpose 'toolkit uninstallation'
    $manifestPath = Join-Path $resolvedInstallRoot $script:ToolkitManifestFileName
    $manifest = Read-JsonManifestFile -ManifestPath $manifestPath

    $managedRel = New-Object 'System.Collections.Generic.List[string]'
    foreach ($entry in @($manifest.ManagedFiles)) {
        if ($null -ne $entry -and -not [string]::IsNullOrWhiteSpace($entry.RelativePath)) {
            $managedRel.Add([string]$entry.RelativePath)
        }
    }

    $extraFiles = New-Object 'System.Collections.Generic.List[string]'
    $extraFiles.Add($script:ToolkitManifestFileName)
    if ($reqRemoveReports) {
        foreach ($rep in $script:KnownReportFiles) {
            $extraFiles.Add($rep)
        }
    }

    $toolkitPlan = [pscustomobject]@{
        InstallRoot = $resolvedInstallRoot
        ManagedRel = $managedRel.ToArray()
        ExtraFiles = $extraFiles.ToArray()
    }
}

$skillPlanItems = New-Object 'System.Collections.Generic.List[object]'
if ($uninstallSkillEffective) {
    $targets = @(Resolve-SkillTargets -Targets $reqSkillTarget -HomeRoot $reqAgentHomeRoot)

    foreach ($t in $targets) {
        $skillManifestPath = Join-Path $t.TargetPath $script:SkillManifestFileName
        $skillManifest = Read-JsonManifestFile -ManifestPath $skillManifestPath

        $managedSkillRel = New-Object 'System.Collections.Generic.List[string]'
        foreach ($entry in @($skillManifest.ManagedFiles)) {
            if ($null -ne $entry -and -not [string]::IsNullOrWhiteSpace($entry.RelativePath)) {
                $managedSkillRel.Add([string]$entry.RelativePath)
            }
        }

        $skillPlanItems.Add([pscustomobject]@{
            Target = $t
            ManagedRel = $managedSkillRel.ToArray()
        })
    }
}

# Execution Phase
$toolkitResult = $null
if ($null -ne $toolkitPlan) {
    if ($PSCmdlet.ShouldProcess($toolkitPlan.InstallRoot, 'Uninstall claude-cleanup toolkit (does NOT remove Claude)')) {
        $removal = Remove-ManagedFileList `
            -Root $toolkitPlan.InstallRoot `
            -RelativePaths $toolkitPlan.ManagedRel `
            -ExtraRootFiles $toolkitPlan.ExtraFiles `
            -RemoveEmptyRoot

        $preservedReports = @()
        if (Test-Path -LiteralPath $toolkitPlan.InstallRoot -PathType Container) {
            $preservedReports = @($script:KnownReportFiles | Where-Object { Test-Path -LiteralPath (Join-Path $toolkitPlan.InstallRoot $_) })
        }

        $toolkitResult = [pscustomobject]@{
            Uninstalled = $true
            WhatIf = $false
            InstallRoot = $toolkitPlan.InstallRoot
            RemovedFiles = $removal.RemovedFiles
            MissingFiles = $removal.MissingFiles
            RootRemoved = $removal.RootRemoved
            PreservedReports = $preservedReports
        }
    } else {
        $toolkitResult = [pscustomobject]@{
            Uninstalled = $false
            WhatIf = $true
            InstallRoot = $toolkitPlan.InstallRoot
            RemovedFiles = $toolkitPlan.ManagedRel
            MissingFiles = @()
            RootRemoved = $false
            PreservedReports = @()
        }
    }
}

$skillResults = New-Object 'System.Collections.Generic.List[object]'
foreach ($item in $skillPlanItems) {
    $t = $item.Target
    if ($PSCmdlet.ShouldProcess($t.TargetPath, "Uninstall claude-cleanup Agent Skill for $($t.Agent) (does NOT remove Claude or other skills)")) {
        $skillRemoval = Remove-ManagedFileList `
            -Root $t.TargetPath `
            -RelativePaths $item.ManagedRel `
            -ExtraRootFiles @($script:SkillManifestFileName) `
            -RemoveEmptyRoot

        $skillsParent = Split-Path -Parent $t.TargetPath
        if ($skillsParent -and (Test-Path -LiteralPath $skillsParent -PathType Container) -and -not (Test-IsReparsePointPath -Path $skillsParent)) {
            $siblings = @([System.IO.Directory]::GetFileSystemEntries($skillsParent))
            if ($siblings.Count -eq 0) {
                [System.IO.Directory]::Delete($skillsParent, $false)
            }
        }

        $skillResults.Add([pscustomobject]@{
            Agent = $t.Agent
            TargetPath = $t.TargetPath
            Uninstalled = $true
            WhatIf = $false
            RemovedFiles = $skillRemoval.RemovedFiles
            RootRemoved = $skillRemoval.RootRemoved
        })
    } else {
        $skillResults.Add([pscustomobject]@{
            Agent = $t.Agent
            TargetPath = $t.TargetPath
            Uninstalled = $false
            WhatIf = $true
            RemovedFiles = $item.ManagedRel
            RootRemoved = $false
        })
    }
}

$resolvedLang = Resolve-ToolkitLanguage -RequestedLanguage $reqLanguage
$noticeText = if ($resolvedLang -eq 'zh-CN') {
    '仅卸载本清理工具及受管脚本/技能包，绝不会卸载 Claude 软件或改动 Windows 系统本身。'
} else {
    'Removes only this cleanup toolkit or skill manifests without uninstalling Claude applications or altering Windows OS.'
}
[pscustomobject]@{
    Action = 'Uninstall'
    Language = $resolvedLang
    Notice = $noticeText
    Toolkit = $toolkitResult
    Skills = $skillResults.ToArray()
    ClaudeApplicationModified = $false
}
