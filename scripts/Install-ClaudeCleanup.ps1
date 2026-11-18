[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$InstallRoot,
    [string]$SourceRoot,
    [switch]$InstallSkill,
    [switch]$SkillOnly,
    [ValidateSet('Codex', 'Antigravity', 'Gemini', 'Claude', 'Agents', 'All')]
    [string[]]$SkillTarget,
    [string]$AgentHomeRoot,
    [string]$SkillSourcePath,
    [switch]$Force,
    [ValidateSet('Auto', 'zh-CN', 'en-US')]
    [string]$Language = 'Auto'
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function Initialize-ToolkitUtf8Encoding {
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    $script:OutputEncoding = $utf8NoBom
    $global:OutputEncoding = $utf8NoBom
    try { [Console]::OutputEncoding = $utf8NoBom } catch {}
}

function Resolve-ToolkitLanguage {
    param([string]$RequestedLanguage = 'Auto')

    if ($RequestedLanguage -eq 'zh-CN' -or $RequestedLanguage -eq 'en-US') {
        return $RequestedLanguage
    }
    try {
        if ([System.Globalization.CultureInfo]::CurrentUICulture.Name -like 'zh*') {
            return 'zh-CN'
        }
    } catch {}
    return 'en-US'
}

Initialize-ToolkitUtf8Encoding
$script:ResolvedToolkitLanguage = Resolve-ToolkitLanguage -RequestedLanguage $Language

$script:ToolkitManifestFileName = '.claude-cleanup-install.json'
$script:SkillManifestFileName = '.claude-cleanup-skill-install.json'
$script:KnownReportFiles = @('AUDIT.md', 'CLEANUP-PLAN.md', 'VERIFICATION.md')

function Get-NormalizedToolkitPath {
    param([Parameter(Mandatory = $true)][string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        throw 'Path cannot be empty.'
    }
    $trimmed = $Path.Trim()
    if ($trimmed.Length -ge 2 -and $trimmed.Substring(2).Contains(':')) {
        throw "Path contains invalid colon / alternate data stream syntax: $Path"
    }
    if ($trimmed.Contains('?') -or $trimmed.Contains('*')) {
        throw "Path contains invalid wildcard characters: $Path"
    }
    $full = [System.IO.Path]::GetFullPath($trimmed)
    $root = [System.IO.Path]::GetPathRoot($full)
    if ($full.Length -gt $root.Length) {
        $full = $full.TrimEnd('\', '/')
    }
    $segments = @($full.Substring($root.Length).Split(@('\', '/'), [System.StringSplitOptions]::RemoveEmptyEntries))
    foreach ($seg in $segments) {
        if ($seg.EndsWith(' ') -or $seg.EndsWith('.')) {
            throw "Path segment has unsafe trailing space or dot: $Path"
        }
    }
    return $full
}

function Test-ToolkitPathWithin {
    param(
        [Parameter(Mandatory = $true)][string]$Candidate,
        [Parameter(Mandatory = $true)][string]$Base
    )

    $c = Get-NormalizedToolkitPath -Path $Candidate
    $b = Get-NormalizedToolkitPath -Path $Base
    if ($c.Equals($b, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $true
    }
    $prefix = if ($b.EndsWith('\')) { $b } else { $b + '\' }
    return $c.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)
}

function Test-IsReparsePointPath {
    param([Parameter(Mandatory = $true)][string]$Path)

    try {
        $attrs = [System.IO.File]::GetAttributes($Path)
    } catch [System.IO.FileNotFoundException] {
        return $false
    } catch [System.IO.DirectoryNotFoundException] {
        return $false
    }
    if ([int]$attrs -eq -1) {
        return $false
    }
    return (($attrs -band [System.IO.FileAttributes]::ReparsePoint) -ne 0)
}

function Assert-NoReparsePointAncestors {
    param([Parameter(Mandatory = $true)][string]$Path)

    $current = Get-NormalizedToolkitPath -Path $Path
    $root = [System.IO.Path]::GetPathRoot($current)
    while ($current -and -not $current.Equals($root, [System.StringComparison]::OrdinalIgnoreCase)) {
        if (Test-IsReparsePointPath -Path $current) {
            throw "Reparse point detected in path: $current"
        }
        $parent = Split-Path -Parent $current
        if ($parent -eq $current) { break }
        $current = $parent
    }
}

function Assert-SafeManagedRoot {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Purpose,
        [string]$DisallowedSourceRoot
    )

    $full = Get-NormalizedToolkitPath -Path $Path
    $driveRoot = [System.IO.Path]::GetPathRoot($full)
    if ($full.Equals($driveRoot.TrimEnd('\'), [System.StringComparison]::OrdinalIgnoreCase) -or
        $full.Equals($driveRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Protected drive root cannot be used for ${Purpose}: $full"
    }

    $subtreeProtected = @($env:WINDIR, $env:ProgramFiles, ${env:ProgramFiles(x86)})
    foreach ($p in $subtreeProtected) {
        if ([string]::IsNullOrWhiteSpace($p)) { continue }
        if (Test-ToolkitPathWithin -Candidate $full -Base $p) {
            throw "Protected OS path cannot be used for ${Purpose}: $full"
        }
    }

    $exactProtected = @(
        $env:USERPROFILE,
        $env:APPDATA,
        $env:LOCALAPPDATA,
        $env:ProgramData,
        $env:PUBLIC,
        $env:TEMP,
        $env:TMP
    )
    foreach ($p in $exactProtected) {
        if ([string]::IsNullOrWhiteSpace($p)) { continue }
        $base = Get-NormalizedToolkitPath -Path $p
        if ($full.Equals($base, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "Protected profile/system root cannot be targeted directly for ${Purpose}: $full"
        }
    }

    $agentProtected = @(
        (Join-Path $env:USERPROFILE '.codex'),
        (Join-Path $env:USERPROFILE '.agents'),
        (Join-Path $env:USERPROFILE '.gemini'),
        (Join-Path $env:USERPROFILE '.claude')
    )
    foreach ($p in $agentProtected) {
        if ([string]::IsNullOrWhiteSpace($p)) { continue }
        if (Test-ToolkitPathWithin -Candidate $full -Base $p) {
            throw "Protected agent configuration directory cannot be targeted for ${Purpose}: $full"
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($DisallowedSourceRoot)) {
        $srcNorm = Get-NormalizedToolkitPath -Path $DisallowedSourceRoot
        if ($full.Equals($srcNorm, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "InstallRoot cannot equal SourceRoot: $full"
        }
    }

    $gitDir = Join-Path $full '.git'
    if (Test-Path -LiteralPath $gitDir) {
        throw "Refusing ${Purpose} on a Git repository root containing .git: $full"
    }

    Assert-NoReparsePointAncestors -Path $full
    return $full
}

function Assert-SafeChildRelativePath {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$RelativePath
    )

    if ([string]::IsNullOrWhiteSpace($RelativePath)) {
        throw 'RelativePath cannot be empty.'
    }
    if ([System.IO.Path]::IsPathRooted($RelativePath)) {
        throw "RelativePath must not be rooted: $RelativePath"
    }
    if ($RelativePath.Contains(':')) {
        throw "RelativePath contains invalid colon: $RelativePath"
    }
    $parts = @($RelativePath.Split(@('\', '/'), [System.StringSplitOptions]::None))
    foreach ($part in $parts) {
        if ($part -eq '..' -or $part -eq '.' -or [string]::IsNullOrWhiteSpace($part)) {
            throw "RelativePath contains unsafe segment: $RelativePath"
        }
        if ($part.EndsWith(' ') -or $part.EndsWith('.')) {
            throw "RelativePath segment has unsafe trailing space or dot: $RelativePath"
        }
    }

    $rootNorm = Get-NormalizedToolkitPath -Path $Root
    $combined = Get-NormalizedToolkitPath -Path (Join-Path $rootNorm $RelativePath)
    $prefix = if ($rootNorm.EndsWith('\')) { $rootNorm } else { $rootNorm + '\' }
    if (-not $combined.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Resolved child path escapes root: $combined"
    }
    return $combined
}

function Get-ToolkitFileSha256 {
    param([Parameter(Mandatory = $true)][string]$Path)

    $bytes = [System.IO.File]::ReadAllBytes($Path)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $hash = $sha.ComputeHash($bytes)
        return ([System.BitConverter]::ToString($hash).Replace('-', '').ToLowerInvariant())
    } finally {
        $sha.Dispose()
    }
}

function Write-ToolkitUtf8NoBom {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Content
    )

    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        [System.IO.Directory]::CreateDirectory($parent) | Out-Null
    }
    $enc = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $enc)
}

function Get-DefaultInstallRoot {
    return (Join-Path $env:LOCALAPPDATA 'Programs\Claude-Residual-ID-Cleaner')
}

function Get-ToolkitPayloadSpec {
    param([Parameter(Mandatory = $true)][string]$ResolvedSourceRoot)

    $requiredRelPaths = @(
        'ClaudeCleanup.ps1',
        'ClaudeCleanupLauncher.cmd',
        'scripts\ClaudeCleanupLauncher.ps1',
        'scripts\Install-ClaudeCleanup.ps1',
        'scripts\Update-ClaudeCleanup.ps1',
        'scripts\Uninstall-ClaudeCleanup.ps1'
    )
    $optionalRelPaths = @(
        'ClaudeCleanupGUI.cmd',
        'scripts\ClaudeCleanupGUI.ps1',
        'README.md',
        'README.en.md',
        'docs\gui-evaluation.md'
    )

    $items = New-Object 'System.Collections.Generic.List[object]'
    foreach ($rel in $requiredRelPaths) {
        $src = Assert-SafeChildRelativePath -Root $ResolvedSourceRoot -RelativePath $rel
        if (-not (Test-Path -LiteralPath $src -PathType Leaf)) {
            throw "Required toolkit source file is missing: $src"
        }
        if (Test-IsReparsePointPath -Path $src) {
            throw "Required toolkit source file cannot be a reparse point: $src"
        }
        $items.Add([pscustomobject]@{ RelativePath = $rel; SourcePath = $src })
    }

    foreach ($rel in $optionalRelPaths) {
        $src = Assert-SafeChildRelativePath -Root $ResolvedSourceRoot -RelativePath $rel
        if (Test-Path -LiteralPath $src -PathType Leaf) {
            if (Test-IsReparsePointPath -Path $src) {
                throw "Optional toolkit source file cannot be a reparse point: $src"
            }
            $items.Add([pscustomobject]@{ RelativePath = $rel; SourcePath = $src })
        }
    }

    return $items.ToArray()
}

function Copy-ManagedFileSet {
    param(
        [Parameter(Mandatory = $true)][string]$DestRoot,
        [Parameter(Mandatory = $true)][object[]]$FileItems
    )

    if (-not (Test-Path -LiteralPath $DestRoot)) {
        [System.IO.Directory]::CreateDirectory($DestRoot) | Out-Null
    } elseif (Test-IsReparsePointPath -Path $DestRoot) {
        throw "Destination root cannot be a reparse point: $DestRoot"
    }

    $records = New-Object 'System.Collections.Generic.List[object]'
    foreach ($item in $FileItems) {
        $dstPath = Assert-SafeChildRelativePath -Root $DestRoot -RelativePath $item.RelativePath
        Assert-NoReparsePointAncestors -Path $dstPath
        if (Test-IsReparsePointPath -Path $dstPath) {
            throw "Destination file cannot be a reparse point: $dstPath"
        }
        $parent = Split-Path -Parent $dstPath
        if ($parent -and -not (Test-Path -LiteralPath $parent)) {
            [System.IO.Directory]::CreateDirectory($parent) | Out-Null
        }
        [System.IO.File]::Copy($item.SourcePath, $dstPath, $true)
        $info = Get-Item -LiteralPath $dstPath
        $records.Add([pscustomobject]@{
            RelativePath = $item.RelativePath
            Sha256 = (Get-ToolkitFileSha256 -Path $dstPath)
            SizeBytes = [int64]$info.Length
        })
    }

    return $records.ToArray()
}

function Remove-EmptyDirectoriesUpward {
    param(
        [Parameter(Mandatory = $true)][string]$StartDirectory,
        [Parameter(Mandatory = $true)][string]$StopAtRoot,
        [switch]$IncludeStopRoot
    )

    $current = Get-NormalizedToolkitPath -Path $StartDirectory
    $stopNorm = Get-NormalizedToolkitPath -Path $StopAtRoot
    $removedDirs = New-Object 'System.Collections.Generic.List[string]'

    while ($current -and (Test-ToolkitPathWithin -Candidate $current -Base $stopNorm)) {
        $isStop = $current.Equals($stopNorm, [System.StringComparison]::OrdinalIgnoreCase)
        if ($isStop -and -not $IncludeStopRoot) {
            break
        }
        if ((Test-Path -LiteralPath $current -PathType Container) -and -not (Test-IsReparsePointPath -Path $current)) {
            $entries = @([System.IO.Directory]::GetFileSystemEntries($current))
            if ($entries.Count -eq 0) {
                [System.IO.Directory]::Delete($current, $false)
                $removedDirs.Add($current)
            } else {
                break
            }
        }
        if ($isStop) {
            break
        }
        $parent = Split-Path -Parent $current
        if ($parent -eq $current) { break }
        $current = $parent
    }

    return $removedDirs.ToArray()
}

function Remove-ManagedFileList {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][string[]]$RelativePaths,
        [string[]]$ExtraRootFiles = @(),
        [switch]$RemoveEmptyRoot
    )

    $rootNorm = Get-NormalizedToolkitPath -Path $Root
    $removed = New-Object 'System.Collections.Generic.List[string]'
    $missing = New-Object 'System.Collections.Generic.List[string]'
    $dirsToPrune = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)

    $allRel = New-Object 'System.Collections.Generic.List[string]'
    foreach ($r in $RelativePaths) {
        if (-not [string]::IsNullOrWhiteSpace($r)) { $allRel.Add($r) }
    }
    foreach ($e in $ExtraRootFiles) {
        if (-not [string]::IsNullOrWhiteSpace($e)) { $allRel.Add($e) }
    }

    foreach ($rel in $allRel) {
        $target = Assert-SafeChildRelativePath -Root $rootNorm -RelativePath $rel
        Assert-NoReparsePointAncestors -Path $target
        if (-not (Test-Path -LiteralPath $target)) {
            $missing.Add($rel)
            continue
        }
        if (Test-IsReparsePointPath -Path $target) {
            throw "Refusing to delete reparse point: $target"
        }
        if (Test-Path -LiteralPath $target -PathType Container) {
            throw "Managed file path unexpectedly points to a directory: $target"
        }
        [System.IO.File]::Delete($target)
        $removed.Add($rel)
        $parent = Split-Path -Parent $target
        if ($parent) { $dirsToPrune.Add($parent) | Out-Null }
    }

    $sortedDirs = @($dirsToPrune | Sort-Object { $_.Length } -Descending)
    foreach ($dir in $sortedDirs) {
        Remove-EmptyDirectoriesUpward -StartDirectory $dir -StopAtRoot $rootNorm | Out-Null
    }

    $rootRemoved = $false
    if ($RemoveEmptyRoot -and (Test-Path -LiteralPath $rootNorm -PathType Container) -and -not (Test-IsReparsePointPath -Path $rootNorm)) {
        $remaining = @([System.IO.Directory]::GetFileSystemEntries($rootNorm))
        if ($remaining.Count -eq 0) {
            [System.IO.Directory]::Delete($rootNorm, $false)
            $rootRemoved = $true
        }
    }

    return [pscustomobject]@{
        RemovedFiles = $removed.ToArray()
        MissingFiles = $missing.ToArray()
        RootRemoved = $rootRemoved
    }
}

function Read-JsonManifestFile {
    param([Parameter(Mandatory = $true)][string]$ManifestPath)

    if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) {
        throw "Install manifest not found: $ManifestPath"
    }
    if (Test-IsReparsePointPath -Path $ManifestPath) {
        throw "Install manifest cannot be a reparse point: $ManifestPath"
    }
    $raw = [System.IO.File]::ReadAllText($ManifestPath, [System.Text.Encoding]::UTF8)
    $parsed = $raw | ConvertFrom-Json
    if ($null -eq $parsed -or $null -eq $parsed.PSObject.Properties['SchemaVersion'] -or [int]$parsed.SchemaVersion -ne 1) {
        throw "Invalid or unsupported install manifest schema in: $ManifestPath"
    }
    return $parsed
}

function Resolve-SkillTargets {
    param(
        [string[]]$Targets,
        [string]$HomeRoot
    )

    if ($null -eq $Targets -or $Targets.Count -eq 0) {
        throw 'Specify at least one -SkillTarget (Codex, Antigravity, Gemini, Claude, Agents, or All) when managing the optional Skill.'
    }

    $effectiveHome = if ([string]::IsNullOrWhiteSpace($HomeRoot)) { $env:USERPROFILE } else { $HomeRoot }
    $homeNorm = Get-NormalizedToolkitPath -Path $effectiveHome

    $driveRoot = [System.IO.Path]::GetPathRoot($homeNorm)
    if ($homeNorm.Equals($driveRoot.TrimEnd('\'), [System.StringComparison]::OrdinalIgnoreCase) -or
        $homeNorm.Equals($driveRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "AgentHomeRoot cannot be a drive root: $homeNorm"
    }
    foreach ($sysDir in @($env:WINDIR, $env:ProgramFiles, ${env:ProgramFiles(x86)})) {
        if ([string]::IsNullOrWhiteSpace($sysDir)) { continue }
        if (Test-ToolkitPathWithin -Candidate $homeNorm -Base $sysDir) {
            throw "AgentHomeRoot cannot be inside protected OS path: $homeNorm"
        }
    }
    Assert-NoReparsePointAncestors -Path $homeNorm

    $agentRelativeMap = @{
        'Codex' = '.codex\skills\claude-cleanup'
        'Antigravity' = '.gemini\config\skills\claude-cleanup'
        'Gemini' = '.gemini\skills\claude-cleanup'
        'Claude' = '.claude\skills\claude-cleanup'
        'Agents' = '.agents\skills\claude-cleanup'
    }

    $expanded = New-Object 'System.Collections.Generic.List[string]'
    foreach ($t in $Targets) {
        if ($t -eq 'All') {
            foreach ($name in @('Codex', 'Antigravity', 'Gemini', 'Claude', 'Agents')) {
                if (-not $expanded.Contains($name)) { $expanded.Add($name) }
            }
        } elseif ($agentRelativeMap.ContainsKey($t)) {
            if (-not $expanded.Contains($t)) { $expanded.Add($t) }
        } else {
            throw "Unsupported SkillTarget: $t"
        }
    }

    $resolved = New-Object 'System.Collections.Generic.List[object]'
    foreach ($agent in $expanded) {
        $rel = $agentRelativeMap[$agent]
        $targetDir = Assert-SafeChildRelativePath -Root $homeNorm -RelativePath $rel
        Assert-NoReparsePointAncestors -Path $targetDir
        if (Test-IsReparsePointPath -Path $targetDir) {
            throw "Skill target directory cannot be a reparse point: $targetDir"
        }
        $resolved.Add([pscustomobject]@{
            Agent = $agent
            RelativePath = $rel
            TargetPath = $targetDir
            AgentHomeRoot = $homeNorm
        })
    }

    return $resolved.ToArray()
}

function Get-SkillSourceFileList {
    param([Parameter(Mandatory = $true)][string]$SkillSourceDir)

    $srcNorm = Get-NormalizedToolkitPath -Path $SkillSourceDir
    if (-not (Test-Path -LiteralPath $srcNorm -PathType Container)) {
        throw "Skill source directory not found: $srcNorm (the canonical Stage D skills/claude-cleanup package must exist before installing the Skill)."
    }
    if (Test-IsReparsePointPath -Path $srcNorm) {
        throw "Skill source directory cannot be a reparse point: $srcNorm"
    }
    $skillMd = Join-Path $srcNorm 'SKILL.md'
    if (-not (Test-Path -LiteralPath $skillMd -PathType Leaf)) {
        throw "Skill source directory is missing required SKILL.md: $srcNorm"
    }

    $items = New-Object 'System.Collections.Generic.List[object]'
    $stack = New-Object 'System.Collections.Generic.Stack[string]'
    $stack.Push($srcNorm)

    while ($stack.Count -gt 0) {
        $dir = $stack.Pop()
        if (Test-IsReparsePointPath -Path $dir) {
            throw "Reparse point directory is not allowed in skill source: $dir"
        }
        foreach ($subDir in @([System.IO.Directory]::GetDirectories($dir))) {
            $name = Split-Path -Leaf $subDir
            if ($name -eq '.git') { continue }
            if (Test-IsReparsePointPath -Path $subDir) {
                throw "Reparse point directory is not allowed in skill source: $subDir"
            }
            $stack.Push($subDir)
        }
        foreach ($file in @([System.IO.Directory]::GetFiles($dir))) {
            $name = Split-Path -Leaf $file
            if ($name -eq $script:SkillManifestFileName -or $name.EndsWith('.tmp') -or $name.EndsWith('.log')) {
                continue
            }
            if (Test-IsReparsePointPath -Path $file) {
                throw "Reparse point file is not allowed in skill source: $file"
            }
            $rel = $file.Substring($srcNorm.Length + 1)
            $items.Add([pscustomobject]@{ RelativePath = $rel; SourcePath = $file })
        }
    }

    return @($items | Sort-Object RelativePath)
}

function Invoke-ToolkitInstallAction {
    param(
        [Parameter(Mandatory = $true)][System.Management.Automation.PSCmdlet]$Cmdlet,
        [string]$TargetInstallRoot,
        [string]$TargetSourceRoot,
        [switch]$DoInstallSkill,
        [switch]$OnlySkill,
        [string[]]$TargetSkillAgents,
        [string]$TargetAgentHomeRoot,
        [string]$TargetSkillSourcePath,
        [switch]$AllowForce
    )

    $resolvedSource = if ([string]::IsNullOrWhiteSpace($TargetSourceRoot)) {
        Get-NormalizedToolkitPath -Path (Split-Path -Parent $PSScriptRoot)
    } else {
        Get-NormalizedToolkitPath -Path $TargetSourceRoot
    }
    if (-not (Test-Path -LiteralPath $resolvedSource -PathType Container)) {
        throw "SourceRoot does not exist: $resolvedSource"
    }

    $installToolkit = -not $OnlySkill
    $installSkillEffective = [bool]($DoInstallSkill -or $OnlySkill)

    # Preflight Phase: validate ALL toolkit and skill paths, sources, and existing states BEFORE any writes
    $toolkitPlan = $null
    if ($installToolkit) {
        $candidateInstall = if ([string]::IsNullOrWhiteSpace($TargetInstallRoot)) { Get-DefaultInstallRoot } else { $TargetInstallRoot }
        $resolvedInstallRoot = Assert-SafeManagedRoot -Path $candidateInstall -Purpose 'toolkit installation' -DisallowedSourceRoot $resolvedSource
        $payload = @(Get-ToolkitPayloadSpec -ResolvedSourceRoot $resolvedSource)
        $manifestPath = Join-Path $resolvedInstallRoot $script:ToolkitManifestFileName

        if ((Test-Path -LiteralPath $manifestPath) -and -not $AllowForce) {
            throw "Toolkit is already installed at '$resolvedInstallRoot'. Run Update-ClaudeCleanup.ps1 or pass -Force to reinstall."
        }
        $toolkitPlan = [pscustomobject]@{
            InstallRoot = $resolvedInstallRoot
            Payload = $payload
            ManifestPath = $manifestPath
        }
    }

    $skillPlan = $null
    if ($installSkillEffective) {
        $effectiveSkillSource = if ([string]::IsNullOrWhiteSpace($TargetSkillSourcePath)) {
            Join-Path $resolvedSource 'skills\claude-cleanup'
        } else {
            Get-NormalizedToolkitPath -Path $TargetSkillSourcePath
        }
        $skillFiles = @(Get-SkillSourceFileList -SkillSourceDir $effectiveSkillSource)
        $targets = @(Resolve-SkillTargets -Targets $TargetSkillAgents -HomeRoot $TargetAgentHomeRoot)

        foreach ($t in $targets) {
            if ((Test-Path -LiteralPath $t.TargetPath) -and -not $AllowForce) {
                $existing = @([System.IO.Directory]::GetFileSystemEntries($t.TargetPath))
                if ($existing.Count -gt 0) {
                    throw "Skill target already exists at '$($t.TargetPath)'. Run Update-ClaudeCleanup.ps1 -SkillOnly or pass -Force."
                }
            }
        }
        $skillPlan = [pscustomobject]@{
            SourcePath = $effectiveSkillSource
            Files = $skillFiles
            Targets = $targets
        }
    }

    # Execution Phase
    $toolkitResult = $null
    if ($null -ne $toolkitPlan) {
        if ($Cmdlet.ShouldProcess($toolkitPlan.InstallRoot, 'Install Claude Residual ID Cleaner toolkit (no Claude application changes)')) {
            $nowUtc = [DateTime]::UtcNow.ToString('o')
            $copied = @(Copy-ManagedFileSet -DestRoot $toolkitPlan.InstallRoot -FileItems $toolkitPlan.Payload)
            $manifestObj = [pscustomobject]@{
                SchemaVersion = 1
                ToolkitName = 'Claude-Residual-ID-Cleaner'
                InstalledUtc = $nowUtc
                UpdatedUtc = $nowUtc
                SourceRoot = $resolvedSource
                InstallRoot = $toolkitPlan.InstallRoot
                ManagedFiles = $copied
            }
            $json = ConvertTo-Json -InputObject $manifestObj -Depth 6
            Write-ToolkitUtf8NoBom -Path $toolkitPlan.ManifestPath -Content ($json + "`n")
            $toolkitResult = [pscustomobject]@{
                Installed = $true
                WhatIf = $false
                InstallRoot = $toolkitPlan.InstallRoot
                FileCount = $copied.Count
                ManifestPath = $toolkitPlan.ManifestPath
                LauncherPath = (Join-Path $toolkitPlan.InstallRoot 'ClaudeCleanupLauncher.cmd')
            }
        } else {
            $toolkitResult = [pscustomobject]@{
                Installed = $false
                WhatIf = $true
                InstallRoot = $toolkitPlan.InstallRoot
                FileCount = $toolkitPlan.Payload.Count
                ManifestPath = $toolkitPlan.ManifestPath
                LauncherPath = (Join-Path $toolkitPlan.InstallRoot 'ClaudeCleanupLauncher.cmd')
            }
        }
    }

    $skillResults = New-Object 'System.Collections.Generic.List[object]'
    if ($null -ne $skillPlan) {
        foreach ($t in $skillPlan.Targets) {
            $skillManifestPath = Join-Path $t.TargetPath $script:SkillManifestFileName
            if ($Cmdlet.ShouldProcess($t.TargetPath, "Install claude-cleanup Agent Skill for $($t.Agent) (strictly separated from Claude app removal)")) {
                $nowUtc = [DateTime]::UtcNow.ToString('o')
                $copiedSkill = @(Copy-ManagedFileSet -DestRoot $t.TargetPath -FileItems $skillPlan.Files)
                $skillManifest = [pscustomobject]@{
                    SchemaVersion = 1
                    SkillName = 'claude-cleanup'
                    Agent = $t.Agent
                    InstalledUtc = $nowUtc
                    UpdatedUtc = $nowUtc
                    SourcePath = $skillPlan.SourcePath
                    TargetPath = $t.TargetPath
                    ManagedFiles = $copiedSkill
                }
                $skillJson = ConvertTo-Json -InputObject $skillManifest -Depth 6
                Write-ToolkitUtf8NoBom -Path $skillManifestPath -Content ($skillJson + "`n")
                $skillResults.Add([pscustomobject]@{
                    Agent = $t.Agent
                    TargetPath = $t.TargetPath
                    Installed = $true
                    WhatIf = $false
                    FileCount = $copiedSkill.Count
                })
            } else {
                $skillResults.Add([pscustomobject]@{
                    Agent = $t.Agent
                    TargetPath = $t.TargetPath
                    Installed = $false
                    WhatIf = $true
                    FileCount = $skillPlan.Files.Count
                })
            }
        }
    }

    $resolvedLang = Resolve-ToolkitLanguage -RequestedLanguage $script:ResolvedToolkitLanguage
    $noticeText = if ($resolvedLang -eq 'zh-CN') {
        '工具安装/技能部署仅管理本工具文件，绝不会修改 Windows 系统本身或删除 Claude 软件/用户数据。'
    } else {
        'Toolkit and Skill installation never alters Windows OS or modifies Claude applications/user data.'
    }
    return [pscustomobject]@{
        Action = 'Install'
        Language = $resolvedLang
        Notice = $noticeText
        Toolkit = $toolkitResult
        Skills = $skillResults.ToArray()
        ClaudeApplicationModified = $false
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    Invoke-ToolkitInstallAction `
        -Cmdlet $PSCmdlet `
        -TargetInstallRoot $InstallRoot `
        -TargetSourceRoot $SourceRoot `
        -DoInstallSkill:$InstallSkill `
        -OnlySkill:$SkillOnly `
        -TargetSkillAgents $SkillTarget `
        -TargetAgentHomeRoot $AgentHomeRoot `
        -TargetSkillSourcePath $SkillSourcePath `
        -AllowForce:$Force
}
