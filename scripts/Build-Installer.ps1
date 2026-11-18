[CmdletBinding()]
param(
    [string]$SourceDir = '',
    [string]$GuiSourceDir = '',
    [string]$OutputPath = '',
    [string]$DesktopExePath = '',
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
    Join-Path $repoRoot 'src\Installer'
} else {
    [System.IO.Path]::GetFullPath($SourceDir)
}
$resolvedGuiDir = if ([string]::IsNullOrWhiteSpace($GuiSourceDir)) {
    Join-Path $repoRoot 'src\Gui'
} else {
    [System.IO.Path]::GetFullPath($GuiSourceDir)
}

if (-not (Test-Path -LiteralPath $resolvedSourceDir -PathType Container)) {
    throw "Installer source directory not found: $resolvedSourceDir"
}

$setupCs = Join-Path $resolvedSourceDir 'SetupProgram.cs'
if (-not (Test-Path -LiteralPath $setupCs -PathType Leaf)) {
    throw "Required SetupProgram.cs missing under: $resolvedSourceDir"
}

$defaultSetupName = Get-ArtifactStandardName -Version $Version -Arch $targetArch -Suffix 'setup.exe'
$resolvedOutput = Resolve-BuildOutputPath -RepoRoot $repoRoot -OutputPath $OutputPath -DefaultFileName $defaultSetupName

$compilerInfo = Get-DotNetFrameworkCompilerInfo -Platform $targetArch -ReferenceNames @(
    'System.dll',
    'System.Core.dll',
    'System.IO.Compression.dll',
    'System.IO.Compression.FileSystem.dll',
    'System.Web.Extensions.dll',
    'System.Windows.Forms.dll',
    'System.Xaml.dll',
    'WindowsBase.dll',
    'PresentationCore.dll',
    'PresentationFramework.dll'
)

$icoPath = Join-Path $resolvedGuiDir 'app.ico'
Ensure-AppIconFile -RepoRoot $repoRoot -IconPath $icoPath
$manifestPath = Join-Path $resolvedSourceDir 'app.manifest'

$tempBase = if (-not [string]::IsNullOrWhiteSpace($env:TEMP)) { $env:TEMP } else { [System.IO.Path]::GetTempPath() }
$tempWorkDir = Join-Path $tempBase ('claude-setup-build-' + [Guid]::NewGuid().ToString('N'))
[System.IO.Directory]::CreateDirectory($tempWorkDir) | Out-Null

try {
    $resolvedDesktopExe = ''
    if (-not [string]::IsNullOrWhiteSpace($DesktopExePath)) {
        $resolvedDesktopExe = [System.IO.Path]::GetFullPath($DesktopExePath)
        if (-not (Test-Path -LiteralPath $resolvedDesktopExe -PathType Leaf)) {
            throw "Provided DesktopExePath not found: $resolvedDesktopExe"
        }
    } else {
        $buildDesktopScript = Join-Path $repoRoot 'scripts\Build-DesktopApp.ps1'
        $tempDesktopExe = Join-Path $tempWorkDir 'Claude-Residual-ID-Cleaner.exe'
        $guiBuild = & $buildDesktopScript -SourceDir $resolvedGuiDir -OutputPath $tempDesktopExe -Version $Version -Platform $targetArch
        if (-not $guiBuild.Succeeded -or -not (Test-Path -LiteralPath $tempDesktopExe -PathType Leaf)) {
            throw 'Failed to build desktop executable for Setup payload.'
        }
        $resolvedDesktopExe = $tempDesktopExe
    }

    $releasePkgScript = Join-Path $repoRoot 'scripts\New-ReleasePackage.ps1'
    $payloadOutDir = Join-Path $tempWorkDir 'payload'
    $pkg = & $releasePkgScript -SourceRoot $repoRoot -OutputDirectory $payloadOutDir -Version $Version -Arch $targetArch -DesktopExePath $resolvedDesktopExe
    if (-not (Test-Path -LiteralPath $pkg.PackagePath -PathType Leaf)) {
        throw 'Failed to build embedded payload ZIP for Setup installer.'
    }

    $sourceFiles = @(Get-ChildItem -LiteralPath $resolvedSourceDir -Filter '*.cs' -File | Sort-Object Name | ForEach-Object { $_.FullName })
    $compileRes = Invoke-WinExeCscCompile `
        -CscExe $compilerInfo.CscExe `
        -CompilerDll $compilerInfo.CompilerDll `
        -FxRoot $compilerInfo.FxRoot `
        -Platform $targetArch `
        -OutputPath $resolvedOutput `
        -References $compilerInfo.References `
        -SourceFiles $sourceFiles `
        -IconPath $icoPath `
        -IconResourceName 'ClaudeResidualIdCleanerSetup.app.ico' `
        -ManifestPath $manifestPath `
        -ExtraResources @("$($pkg.PackagePath),ClaudeResidualIdCleanerSetup.payload.zip") `
        -FailureLabel 'csc.exe Setup build'

    [pscustomobject]@{
        Succeeded    = $true
        Compiler     = if ($compilerInfo.CompilerDll) { $compilerInfo.CompilerDll } else { $compilerInfo.CscExe }
        OutputPath   = $compileRes.OutputPath
        Version      = $Version
        Arch         = $targetArch
        Platform     = $targetArch
        PeMachine    = $compileRes.PeMachine
        SizeBytes    = $compileRes.SizeBytes
        Sha256       = $compileRes.Sha256
        TargetType   = 'winexe (Zero-Console WPF Setup Wizard)'
        PayloadFiles = $pkg.FileCount
    }
} finally {
    if (Test-Path -LiteralPath $tempWorkDir) {
        try { Remove-Item -LiteralPath $tempWorkDir -Recurse -Force } catch {}
    }
}
