[CmdletBinding()]
param(
    [string]$SourceRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$OutputDirectory = '',
    [string]$PackageName = 'claude-cleanup',
    [string]$Version = '0.1.0'
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($PackageName) -or ($PackageName -notmatch '^[A-Za-z0-9._-]+$')) {
    throw "Invalid PackageName '$PackageName'. Allowed characters: A-Z, a-z, 0-9, '.', '_', '-'."
}
if ([string]::IsNullOrWhiteSpace($Version) -or ($Version -notmatch '^[A-Za-z0-9._-]+$')) {
    throw "Invalid Version '$Version'. Allowed characters: A-Z, a-z, 0-9, '.', '_', '-'."
}
if ([string]::IsNullOrWhiteSpace($SourceRoot) -or -not (Test-Path -LiteralPath $SourceRoot -PathType Container)) {
    throw "SourceRoot does not exist or is not a directory: $SourceRoot"
}

$resolvedSourceRoot = (Resolve-Path -LiteralPath $SourceRoot).Path.TrimEnd('\', '/')

if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $resolvedOutputDir = Join-Path $resolvedSourceRoot 'dist'
} else {
    $rawOut = $OutputDirectory
    if (-not [IO.Path]::IsPathRooted($rawOut)) {
        $rawOut = Join-Path (Get-Location).Path $rawOut
    }
    $resolvedOutputDir = [IO.Path]::GetFullPath($rawOut).TrimEnd('\', '/')
}

$outputRelPrefix = ''
if ($resolvedOutputDir.StartsWith($resolvedSourceRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    $outputRelPrefix = ($resolvedOutputDir.Substring($resolvedSourceRoot.Length + 1) -replace '\\', '/').Trim('/')
} elseif ($resolvedOutputDir.Equals($resolvedSourceRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'OutputDirectory cannot be identical to SourceRoot.'
}

function Test-ReleaseExcludedPath {
    param(
        [Parameter(Mandatory = $true)][string]$RelativePath,
        [Parameter(Mandatory = $true)][bool]$IsDirectory,
        [string]$ExtraExcludedPrefix = ''
    )

    $norm = ($RelativePath -replace '\\', '/').Trim('/')
    if ([string]::IsNullOrEmpty($norm)) { return $false }

    if (-not [string]::IsNullOrEmpty($ExtraExcludedPrefix)) {
        if ($norm.Equals($ExtraExcludedPrefix, [StringComparison]::OrdinalIgnoreCase) -or
            $norm.StartsWith($ExtraExcludedPrefix + '/', [StringComparison]::OrdinalIgnoreCase)) {
            return $true
        }
    }

    # Excluded directories (and .git worktree pointer file)
    if ($norm -match '(?i)^(?:\.git|dist|tests/sandbox|logs)(?:/|$)') { return $true }
    if ($norm -match '(?i)(?:^|/)sandbox(?:/|$)') { return $true }
    if ($norm -match '(?i)(?:^|/)\.(?:claude|codex|agents|gemini|vscode|idea)(?:/|$)') { return $true }

    if ($IsDirectory) {
        return $false
    }

    $leaf = [IO.Path]::GetFileName($norm)

    # Excluded temporary management, audit, plan, verification, and credential filenames
    $exactExcludedNames = @(
        'AGENTS.md',
        'GOAL.md',
        'PLAN.md',
        'HANDOFF.md',
        'AUDIT.md',
        'CLEANUP-PLAN.md',
        'VERIFICATION.md',
        '.credentials.json',
        'buddy-tokens.json',
        '.claude.json',
        '.env',
        'Thumbs.db',
        'desktop.ini',
        '.DS_Store'
    )
    foreach ($name in $exactExcludedNames) {
        if ($leaf.Equals($name, [StringComparison]::OrdinalIgnoreCase)) {
            return $true
        }
    }

    # Excluded filename patterns: local reports, ledgers, credentials, keys, certs, local overrides, logs, temps, backups
    $patternList = @(
        '(?i)\.audit\.md$',
        '(?i)\.plan\.md$',
        '(?i)\.verification\.md$',
        '(?i)execution-ledger\.json$',
        '(?i)\.ledger\.json$',
        '(?i)credentials.*\.(?:json|txt|ps1|psd1|psm1|yml|yaml|xml|ini|conf)$',
        '(?i)secret.*\.(?:json|txt|ps1|psd1|psm1|yml|yaml|xml|ini|conf)$',
        '(?i)^\.env\..+$',
        '(?i)\.(?:pfx|p12|key|pem|cer|crt)$',
        '(?i)\.(?:local|private)\.(?:json|ps1)$',
        '(?i)personal.*log',
        '(?i)\.(?:log|tmp|temp|bak|backup|rea\.backup|orig|stackdump)$'
    )
    foreach ($pat in $patternList) {
        if ($leaf -match $pat) {
            return $true
        }
    }

    return $false
}

function Assert-FilePrivacySafe {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [Parameter(Mandatory = $true)][string]$RelativePath
    )

    $ext = [IO.Path]::GetExtension($FilePath)
    $leaf = [IO.Path]::GetFileName($FilePath)
    $textExtensions = @('.ps1', '.psm1', '.psd1', '.py', '.cs', '.md', '.yml', '.yaml', '.json', '.cmd', '.txt', '.gitignore')
    if (($ext -notin $textExtensions) -and (-not $leaf.Equals('.gitignore', [StringComparison]::OrdinalIgnoreCase))) {
        return
    }

    $text = [IO.File]::ReadAllText($FilePath)
    $sidPattern = 'S-1-5-21-' + '\d+-\d+-\d+-\d+'
    $userPathPattern = '(?i)C:\\Users\\(?!(?:<USERNAME>|<USER>|<name>|username|user|example|Public|Default)(?:[\\"`\s]|$))[A-Za-z0-9._-]+\\'
    $privKeyPattern = '-----BEGIN [A-Z ]*PRIVATE ' + 'KEY-----'
    $tokenPattern = '(?:' + 'sk-' + 'ant-[A-Za-z0-9_-]{10,}|ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,})'

    if ($text -match $sidPattern) {
        throw "Privacy gate blocked release packaging: domain/user SID detected in '$RelativePath'."
    }
    if ($text -match $userPathPattern) {
        throw "Privacy gate blocked release packaging: local user profile path detected in '$RelativePath'."
    }
    if ($text -match $privKeyPattern) {
        throw "Privacy gate blocked release packaging: private key header detected in '$RelativePath'."
    }
    if ($text -match $tokenPattern) {
        throw "Privacy gate blocked release packaging: credential token prefix detected in '$RelativePath'."
    }
}

$includedEntries = New-Object 'System.Collections.Generic.List[object]'
$excludedPaths = New-Object 'System.Collections.Generic.List[string]'

$dirStack = New-Object 'System.Collections.Generic.Stack[string]'
$dirStack.Push($resolvedSourceRoot)

while ($dirStack.Count -gt 0) {
    $currentDir = $dirStack.Pop()
    $entries = @(Get-ChildItem -LiteralPath $currentDir -Force | Sort-Object -Property FullName)
    foreach ($entry in $entries) {
        $full = $entry.FullName
        $rel = ($full.Substring($resolvedSourceRoot.Length + 1) -replace '\\', '/')
        $isDir = [bool]($entry.PSIsContainer)

        if (Test-ReleaseExcludedPath -RelativePath $rel -IsDirectory $isDir -ExtraExcludedPrefix $outputRelPrefix) {
            $excludedPaths.Add($rel)
            continue
        }

        if (($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Refusing to package reparse point inside source tree: $rel"
        }

        if ($isDir) {
            $dirStack.Push($full)
        } else {
            Assert-FilePrivacySafe -FilePath $full -RelativePath $rel
            $includedEntries.Add([pscustomobject]@{
                FullName     = $full
                RelativePath = $rel
            })
        }
    }
}

$sortedIncluded = @($includedEntries | Sort-Object -Property RelativePath)
if ($sortedIncluded.Count -eq 0) {
    throw "No eligible files found to package in '$resolvedSourceRoot'."
}

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

if (-not (Test-Path -LiteralPath $resolvedOutputDir)) {
    New-Item -ItemType Directory -Path $resolvedOutputDir -Force | Out-Null
}

$zipFileName = "$PackageName-$Version.zip"
$zipPath = Join-Path $resolvedOutputDir $zipFileName
$tempZipPath = Join-Path $resolvedOutputDir ("$zipFileName.tmp-" + [Guid]::NewGuid().ToString('N'))
$sumsPath = Join-Path $resolvedOutputDir 'SHA256SUMS.txt'

try {
    $archive = [System.IO.Compression.ZipFile]::Open($tempZipPath, [System.IO.Compression.ZipArchiveMode]::Create)
    try {
        foreach ($item in $sortedIncluded) {
            [void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
                $archive,
                $item.FullName,
                $item.RelativePath,
                [System.IO.Compression.CompressionLevel]::Optimal
            )
        }
    } finally {
        $archive.Dispose()
    }

    if (Test-Path -LiteralPath $zipPath) {
        [IO.File]::Delete($zipPath)
    }
    [IO.File]::Move($tempZipPath, $zipPath)
} finally {
    if (Test-Path -LiteralPath $tempZipPath) {
        try { [IO.File]::Delete($tempZipPath) } catch {}
    }
}

$sha256Provider = [System.Security.Cryptography.SHA256]::Create()
try {
    $zipStream = [IO.File]::OpenRead($zipPath)
    try {
        $hashBytes = $sha256Provider.ComputeHash($zipStream)
    } finally {
        $zipStream.Dispose()
    }
} finally {
    $sha256Provider.Dispose()
}
$sha256Hex = ([BitConverter]::ToString($hashBytes) -replace '-', '').ToLowerInvariant()

$sumsContent = "$sha256Hex  $zipFileName`n"
$utf8NoBom = New-Object 'System.Text.UTF8Encoding'($false)
[IO.File]::WriteAllText($sumsPath, $sumsContent, $utf8NoBom)

[pscustomobject]@{
    PackagePath     = $zipPath
    Sha256SumsPath  = $sumsPath
    Sha256          = $sha256Hex
    FileCount       = $sortedIncluded.Count
    ExcludedCount   = $excludedPaths.Count
    IncludedFiles   = @($sortedIncluded | ForEach-Object { $_.RelativePath })
    ExcludedFiles   = @($excludedPaths)
}
