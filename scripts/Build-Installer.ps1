[CmdletBinding()]
param(
    [string]$SourceDir = '',
    [string]$GuiSourceDir = '',
    [string]$OutputPath = '',
    [string]$DesktopExePath = '',
    [string]$Version = '0.1.0'
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

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

$resolvedOutput = if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    Join-Path $repoRoot 'dist\Claude-Residual-ID-Cleaner-Setup.exe'
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
    (Join-Path $fxRoot 'System.IO.Compression.dll'),
    (Join-Path $fxRoot 'System.IO.Compression.FileSystem.dll'),
    (Join-Path $fxRoot 'System.Web.Extensions.dll'),
    (Join-Path $fxRoot 'System.Windows.Forms.dll'),
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

$icoPath = Join-Path $resolvedGuiDir 'app.ico'
if (-not (Test-Path -LiteralPath $icoPath -PathType Leaf)) {
    $iconScript = Join-Path $repoRoot 'scripts\New-AppIcon.ps1'
    if (Test-Path -LiteralPath $iconScript -PathType Leaf) {
        & $iconScript -IconPath $icoPath | Out-Null
    }
}

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
        $guiBuild = & $buildDesktopScript -SourceDir $resolvedGuiDir -OutputPath $tempDesktopExe
        if (-not $guiBuild.Succeeded -or -not (Test-Path -LiteralPath $tempDesktopExe -PathType Leaf)) {
            throw 'Failed to build desktop executable for Setup payload.'
        }
        $resolvedDesktopExe = $tempDesktopExe
    }

    $releasePkgScript = Join-Path $repoRoot 'scripts\New-ReleasePackage.ps1'
    $payloadOutDir = Join-Path $tempWorkDir 'payload'
    $pkg = & $releasePkgScript -SourceRoot $repoRoot -OutputDirectory $payloadOutDir -Version $Version -DesktopExePath $resolvedDesktopExe
    if (-not (Test-Path -LiteralPath $pkg.PackagePath -PathType Leaf)) {
        throw "Failed to build embedded payload ZIP for Setup installer."
    }

    $cscArgs = New-Object 'System.Collections.Generic.List[string]'
    $cscArgs.Add('/nologo')
    $cscArgs.Add('/target:winexe')
    $cscArgs.Add('/platform:anycpu')
    $cscArgs.Add('/optimize+')
    $cscArgs.Add('/utf8output')
    $cscArgs.Add('/codepage:65001')
    if (Test-Path -LiteralPath $icoPath -PathType Leaf) {
        $cscArgs.Add("/win32icon:$icoPath")
        $cscArgs.Add("/resource:$icoPath,ClaudeResidualIdCleanerSetup.app.ico")
    }
    if (Test-Path -LiteralPath $manifestPath -PathType Leaf) {
        $cscArgs.Add("/win32manifest:$manifestPath")
    }
    $cscArgs.Add("/resource:$($pkg.PackagePath),ClaudeResidualIdCleanerSetup.payload.zip")
    $cscArgs.Add("/out:$resolvedOutput")
    foreach ($r in $refs) {
        $cscArgs.Add("/reference:$r")
    }
    foreach ($csFile in @(Get-ChildItem -LiteralPath $resolvedSourceDir -Filter '*.cs' -File | Sort-Object Name)) {
        $cscArgs.Add($csFile.FullName)
    }

    $outputLines = & $cscExe @($cscArgs.ToArray()) 2>&1
    if ($LASTEXITCODE -ne 0) {
        $msg = ($outputLines | Out-String)
        throw "csc.exe Setup build failed with exit code ${LASTEXITCODE}:`n$msg"
    }

    if (-not (Test-Path -LiteralPath $resolvedOutput -PathType Leaf)) {
        throw "Setup build reported exit 0, but executable was not found at: $resolvedOutput"
    }

    $fileInfo = Get-Item -LiteralPath $resolvedOutput
    $sha256 = (Get-FileHash -LiteralPath $resolvedOutput -Algorithm SHA256).Hash.ToLowerInvariant()

    [pscustomobject]@{
        Succeeded     = $true
        Compiler      = $cscExe
        OutputPath    = $resolvedOutput
        SizeBytes     = [int64]$fileInfo.Length
        Sha256        = $sha256
        TargetType    = 'winexe (Zero-Console WPF Setup Wizard)'
        PayloadFiles  = $pkg.FileCount
    }
} finally {
    if (Test-Path -LiteralPath $tempWorkDir) {
        try { Remove-Item -LiteralPath $tempWorkDir -Recurse -Force } catch {}
    }
}
