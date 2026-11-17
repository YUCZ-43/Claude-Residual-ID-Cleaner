[CmdletBinding()]
param(
    [string]$SourceDir = '',
    [string]$OutputPath = ''
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$resolvedSourceDir = if ([string]::IsNullOrWhiteSpace($SourceDir)) {
    Join-Path $repoRoot 'src\Gui'
} else {
    [System.IO.Path]::GetFullPath($SourceDir)
}

if (-not (Test-Path -LiteralPath $resolvedSourceDir -PathType Container)) {
    throw "GUI source directory not found: $resolvedSourceDir"
}

$locCs = Join-Path $resolvedSourceDir 'Localization.cs'
$progCs = Join-Path $resolvedSourceDir 'Program.cs'
if (-not (Test-Path -LiteralPath $locCs -PathType Leaf) -or -not (Test-Path -LiteralPath $progCs -PathType Leaf)) {
    throw "Required C# WPF source files (Localization.cs, Program.cs) missing under: $resolvedSourceDir"
}

$resolvedOutput = if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    Join-Path $repoRoot 'dist\Claude-Residual-ID-Cleaner.exe'
} else {
    $rawOut = $OutputPath
    if (-not [System.IO.Path]::IsPathRooted($rawOut)) {
        $rawOut = Join-Path (Get-Location).Path $rawOut
    }
    [System.IO.Path]::GetFullPath($rawOut)
}

$outDir = Split-Path -Parent $resolvedOutput
if ($outDir -and -not (Test-Path -LiteralPath $outDir)) {
    [System.IO.Directory]::CreateDirectory($outDir) | Out-Null
}

$fxRoot = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319'
if (-not (Test-Path -LiteralPath $fxRoot -PathType Container)) {
    $fxRoot = Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319'
}
$cscExe = Join-Path $fxRoot 'csc.exe'
$wpfDir = Join-Path $fxRoot 'WPF'

if (-not (Test-Path -LiteralPath $cscExe -PathType Leaf)) {
    throw ".NET Framework C# compiler csc.exe not found at: $cscExe"
}
if (-not (Test-Path -LiteralPath $wpfDir -PathType Container)) {
    throw ".NET Framework WPF assemblies directory not found at: $wpfDir"
}

$refs = @(
    (Join-Path $fxRoot 'System.dll'),
    (Join-Path $fxRoot 'System.Core.dll'),
    (Join-Path $fxRoot 'System.Web.Extensions.dll'),
    (Join-Path $fxRoot 'System.Xaml.dll'),
    (Join-Path $wpfDir 'WindowsBase.dll'),
    (Join-Path $wpfDir 'PresentationCore.dll'),
    (Join-Path $wpfDir 'PresentationFramework.dll')
)

foreach ($r in $refs) {
    if (-not (Test-Path -LiteralPath $r -PathType Leaf)) {
        throw "Required .NET reference assembly not found: $r"
    }
}

$cscArgs = New-Object 'System.Collections.Generic.List[string]'
$cscArgs.Add('/nologo')
$cscArgs.Add('/target:winexe')
$cscArgs.Add('/platform:anycpu')
$cscArgs.Add('/optimize+')
$cscArgs.Add('/utf8output')
$cscArgs.Add('/codepage:65001')
$cscArgs.Add("/out:$resolvedOutput")
foreach ($r in $refs) {
    $cscArgs.Add("/reference:$r")
}
$cscArgs.Add($locCs)
$cscArgs.Add($progCs)
$extraCsFiles = @(Get-ChildItem -LiteralPath $resolvedSourceDir -Filter '*.cs' -File | Sort-Object Name)
foreach ($csFile in $extraCsFiles) {
    if ($csFile.FullName -ne $locCs -and $csFile.FullName -ne $progCs) {
        $cscArgs.Add($csFile.FullName)
    }
}

$outputLines = & $cscExe @($cscArgs.ToArray()) 2>&1
if ($LASTEXITCODE -ne 0) {
    $msg = ($outputLines | Out-String)
    throw "csc.exe build failed with exit code ${LASTEXITCODE}:`n$msg"
}

if (-not (Test-Path -LiteralPath $resolvedOutput -PathType Leaf)) {
    throw "Build reported exit 0, but executable was not found at: $resolvedOutput"
}

$fileInfo = Get-Item -LiteralPath $resolvedOutput
$sha256 = (Get-FileHash -LiteralPath $resolvedOutput -Algorithm SHA256).Hash.ToLowerInvariant()

[pscustomobject]@{
    Succeeded = $true
    Compiler = $cscExe
    OutputPath = $resolvedOutput
    SizeBytes = [int64]$fileInfo.Length
    Sha256 = $sha256
    TargetType = 'winexe (Zero-Console WPF)'
}
