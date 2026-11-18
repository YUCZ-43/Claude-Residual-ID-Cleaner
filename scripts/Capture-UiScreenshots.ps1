[CmdletBinding()]
param(
    [string]$ExePath = '',
    [string]$OutputDir = ''
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'Common-BuildHelpers.ps1')

function Test-CapturedPng {
    param([Parameter(Mandatory = $true)][string]$FilePath)

    if (-not (Test-Path -LiteralPath $FilePath -PathType Leaf)) {
        throw "Captured PNG file was not created: $FilePath"
    }

    $bytes = [System.IO.File]::ReadAllBytes($FilePath)
    if ($bytes.Length -le 20480) {
        throw "Captured PNG file is smaller than 20 KB ($($bytes.Length) bytes): $FilePath"
    }

    $expectedHeader = [byte[]]@(0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A)
    if ($bytes.Length -lt 24) {
        throw "Captured PNG too short: $FilePath"
    }
    for ($i = 0; $i -lt 8; $i++) {
        if ($bytes[$i] -ne $expectedHeader[$i]) {
            throw "Invalid PNG file header (expected 89 50 4E 47 0D 0A 1A 0A): $FilePath"
        }
    }

    $width = 0
    $height = 0
    if ($bytes[12] -eq 0x49 -and $bytes[13] -eq 0x48 -and $bytes[14] -eq 0x44 -and $bytes[15] -eq 0x52) {
        $width = ([int]$bytes[16] -shl 24) -bor ([int]$bytes[17] -shl 16) -bor ([int]$bytes[18] -shl 8) -bor [int]$bytes[19]
        $height = ([int]$bytes[20] -shl 24) -bor ([int]$bytes[21] -shl 16) -bor ([int]$bytes[22] -shl 8) -bor [int]$bytes[23]
    }
    if ($width -le 0 -or $height -le 0) {
        throw "Captured PNG has invalid IHDR dimensions (${width}x${height}): $FilePath"
    }

    return [pscustomobject]@{
        Path      = $FilePath
        SizeBytes = [int64]$bytes.Length
        Width     = $width
        Height    = $height
    }
}

$repoRoot = (Split-Path -Parent $PSScriptRoot).TrimEnd('\', '/')
$resolvedOutputDir = if ([string]::IsNullOrWhiteSpace($OutputDir)) {
    Join-Path $repoRoot 'docs\images'
} else {
    Resolve-CallerPath -PathValue $OutputDir
}

if (-not (Test-Path -LiteralPath $resolvedOutputDir -PathType Container)) {
    [System.IO.Directory]::CreateDirectory($resolvedOutputDir) | Out-Null
}

$sandboxRoot = Join-Path $repoRoot 'tests\sandbox'
$sandboxExisted = Test-Path -LiteralPath $sandboxRoot
$tempBuildDir = Join-Path $sandboxRoot ('ui-capture-' + [Guid]::NewGuid().ToString('N'))

try {
    $exeInfo = Resolve-CaptureDesktopExecutable -RepoRoot $repoRoot -ExePath $ExePath -SandboxWorkDir $tempBuildDir
    $resolvedExe = $exeInfo.ExePath
    $usedTempExe = $exeInfo.UsedTempExe

    $captures = @(
        @{ Name = 'ui-main-zh.png'; Args = "--dry-run --language zh-CN --nav 0 --toolkit-root `"$repoRoot`"" },
        @{ Name = 'ui-scan-results-zh.png'; Args = "--demo-audit --dry-run --language zh-CN --nav 0 --toolkit-root `"$repoRoot`"" },
        @{ Name = 'ui-report-dialog-zh.png'; Args = "--demo-report --dry-run --language zh-CN --nav 1 --toolkit-root `"$repoRoot`"" },
        @{ Name = 'ui-main-en.png'; Args = "--demo-audit --dry-run --language en-US --nav 0 --toolkit-root `"$repoRoot`"" }
    )

    $results = New-Object 'System.Collections.Generic.List[object]'
    foreach ($item in $captures) {
        $targetPng = (Join-Path $resolvedOutputDir $item.Name).TrimEnd('\', '/')
        Invoke-DesktopCapture -ExecutablePath $resolvedExe -ArgumentsLine "$($item.Args) --capture-png `"$targetPng`""
        $validated = Test-CapturedPng -FilePath $targetPng
        $results.Add([pscustomobject]@{
            FileName  = $item.Name
            Path      = $validated.Path
            SizeBytes = $validated.SizeBytes
            Width     = $validated.Width
            Height    = $validated.Height
        })
    }

    [pscustomobject]@{
        Succeeded   = $true
        OutputDir   = $resolvedOutputDir
        UsedTempExe = $usedTempExe
        Screenshots = @($results.ToArray())
    }
} finally {
    Remove-CaptureSandboxDirectory -WorkDir $tempBuildDir -SandboxRoot $sandboxRoot -SandboxExisted $sandboxExisted
}
