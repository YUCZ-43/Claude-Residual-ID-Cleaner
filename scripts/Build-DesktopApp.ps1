[CmdletBinding()]
param(
    [string]$SourceDir = '',
    [string]$OutputPath = '',
    [string]$Version = '0.1.0',
    [string]$Arch = 'x64'
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'Common-BuildHelpers.ps1')

Test-BuildVersionAndArch -Version $Version -Arch $Arch

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

$defaultExeName = Get-ArtifactStandardName -Version $Version -Arch $Arch -Suffix 'portable.exe'
$resolvedOutput = Resolve-BuildOutputPath -RepoRoot $repoRoot -OutputPath $OutputPath -DefaultFileName $defaultExeName

$compilerInfo = Get-DotNetFrameworkCompilerInfo -ReferenceNames @(
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
    -OutputPath $resolvedOutput `
    -References $compilerInfo.References `
    -SourceFiles @($sourceFiles.ToArray()) `
    -IconPath $icoPath `
    -IconResourceName 'ClaudeResidualIdCleaner.app.ico' `
    -ManifestPath $manifestPath `
    -FailureLabel 'csc.exe build'

[pscustomobject]@{
    Succeeded  = $true
    Compiler   = $compilerInfo.CscExe
    OutputPath = $compileRes.OutputPath
    Version    = $Version
    Arch       = $Arch
    SizeBytes  = $compileRes.SizeBytes
    Sha256     = $compileRes.Sha256
    TargetType = 'winexe (Zero-Console WPF)'
}
