[CmdletBinding()]
param(
    [string]$SourceDir = '',
    [string]$OutputPath = '',
    [string]$Version = '0.1.0',
    [ValidateSet('x64', 'arm64')][string]$Arch = 'x64',
    [string]$Platform = ''
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'Common-BuildHelpers.ps1')

$targetArch = if (-not [string]::IsNullOrWhiteSpace($Platform)) { $Platform.Trim().ToLowerInvariant() } else { $Arch.Trim().ToLowerInvariant() }
if ($targetArch -notin @('x64', 'arm64')) {
    throw "Unsupported target platform '$targetArch'. Allowed: x64, arm64."
}
Test-BuildVersionAndArch -Version $Version -Arch $targetArch

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

$defaultExeName = Get-ArtifactStandardName -Version $Version -Arch $targetArch -Suffix 'portable.exe'
$resolvedOutput = Resolve-BuildOutputPath -RepoRoot $repoRoot -OutputPath $OutputPath -DefaultFileName $defaultExeName

$compilerInfo = Get-DotNetFrameworkCompilerInfo -Platform $targetArch -ReferenceNames @(
    'System.dll',
    'System.Core.dll',
    'System.Web.Extensions.dll',
    'System.Xaml.dll',
    'WindowsBase.dll',
    'PresentationCore.dll',
    'PresentationFramework.dll'
)

$icoPath = Join-Path $resolvedSourceDir 'app.ico'
Ensure-AppIconFile -RepoRoot $repoRoot -IconPath $icoPath
$manifestPath = Join-Path $resolvedSourceDir 'app.manifest'

$sourceRepoRoot = Split-Path -Parent (Split-Path -Parent $resolvedSourceDir)
$backendScriptPath = Join-Path $sourceRepoRoot 'ClaudeCleanup.ps1'
if (-not (Test-Path -LiteralPath $backendScriptPath -PathType Leaf)) {
    $repoBackendFallback = Join-Path $repoRoot 'ClaudeCleanup.ps1'
    if (Test-Path -LiteralPath $repoBackendFallback -PathType Leaf) {
        $backendScriptPath = $repoBackendFallback
    }
}
$extraResources = @()
if (Test-Path -LiteralPath $backendScriptPath -PathType Leaf) {
    $extraResources = @("$backendScriptPath,ClaudeCleanup.ps1")
} elseif ([string]::IsNullOrWhiteSpace($SourceDir)) {
    throw "Required backend script ClaudeCleanup.ps1 missing under: $repoRoot"
}

$sourceFiles = New-Object 'System.Collections.Generic.List[string]'
$sourceFiles.Add($locCs)
$sourceFiles.Add($progCs)
foreach ($csFile in @(Get-ChildItem -LiteralPath $resolvedSourceDir -Filter '*.cs' -File | Sort-Object Name)) {
    if ($csFile.FullName -ne $locCs -and $csFile.FullName -ne $progCs) {
        $sourceFiles.Add($csFile.FullName)
    }
}

$compileRes = Invoke-WinExeCscCompile `
    -CscExe $compilerInfo.CscExe `
    -CompilerDll $compilerInfo.CompilerDll `
    -FxRoot $compilerInfo.FxRoot `
    -Platform $targetArch `
    -OutputPath $resolvedOutput `
    -References $compilerInfo.References `
    -SourceFiles @($sourceFiles.ToArray()) `
    -IconPath $icoPath `
    -IconResourceName 'ClaudeResidualIdCleaner.app.ico' `
    -ManifestPath $manifestPath `
    -ExtraResources $extraResources `
    -FailureLabel 'csc.exe build'

[pscustomobject]@{
    Succeeded      = $true
    Compiler       = if ($compilerInfo.CompilerDll) { $compilerInfo.CompilerDll } else { $compilerInfo.CscExe }
    OutputPath     = $compileRes.OutputPath
    Version        = $Version
    Arch           = $targetArch
    Platform       = $targetArch
    PeMachine      = $compileRes.PeMachine
    SizeBytes      = $compileRes.SizeBytes
    Sha256         = $compileRes.Sha256
    EmbeddedEngine = ($extraResources.Count -gt 0)
    TargetType     = 'winexe (Zero-Console WPF)'
}
