Set-StrictMode -Version 2.0

function Test-BuildVersionAndArch {
    param(
        [Parameter(Mandatory = $true)][string]$Version,
        [AllowEmptyString()][string]$Arch = ''
    )

    if ([string]::IsNullOrWhiteSpace($Version) -or ($Version -notmatch '^[A-Za-z0-9._-]+$')) {
        throw "Invalid Version '$Version'. Allowed characters: A-Z, a-z, 0-9, '.', '_', '-'."
    }
    if (-not [string]::IsNullOrEmpty($Arch) -and ($Arch -notmatch '^[A-Za-z0-9._-]+$')) {
        throw "Invalid Arch '$Arch'. Allowed characters: A-Z, a-z, 0-9, '.', '_', '-'."
    }
}

function Resolve-CallerPath {
    param([Parameter(Mandatory = $true)][string]$PathValue)

    $raw = $PathValue.Trim()
    if (-not [System.IO.Path]::IsPathRooted($raw)) {
        $raw = Join-Path (Get-Location).Path $raw
    }
    return [System.IO.Path]::GetFullPath($raw)
}

function Get-ArtifactStandardName {
    param(
        [string]$ProductName = 'Claude-Residual-ID-Cleaner',
        [Parameter(Mandatory = $true)][string]$Version,
        [AllowEmptyString()][string]$Arch = 'x64',
        [Parameter(Mandatory = $true)][string]$Suffix
    )

    if ([string]::IsNullOrWhiteSpace($Arch)) {
        return "$ProductName-$Version-$Suffix"
    }
    return "$ProductName-$Version-$Arch-$Suffix"
}

function Resolve-BuildOutputPath {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [AllowEmptyString()][string]$OutputPath,
        [Parameter(Mandatory = $true)][string]$DefaultFileName
    )

    $resolved = if ([string]::IsNullOrWhiteSpace($OutputPath)) {
        Join-Path $RepoRoot ("dist\$DefaultFileName")
    } else {
        Resolve-CallerPath -PathValue $OutputPath
    }

    $outDir = Split-Path -Parent $resolved
    if ($outDir -and -not (Test-Path -LiteralPath $outDir)) {
        [System.IO.Directory]::CreateDirectory($outDir) | Out-Null
    }
    return $resolved
}

function Get-DotNetFrameworkCompilerInfo {
    param(
        [Parameter(Mandatory = $true)][string[]]$ReferenceNames,
        [ValidateSet('anycpu', 'x86', 'x64', 'arm64')][string]$Platform = 'x64'
    )

    $fxRoot = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319'
    if (-not (Test-Path -LiteralPath $fxRoot -PathType Container)) {
        $fxRoot = Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319'
    }
    $cscExe = Join-Path $fxRoot 'csc.exe'
    $wpfDir = Join-Path $fxRoot 'WPF'

    if (-not (Test-Path -LiteralPath $wpfDir -PathType Container)) {
        throw ".NET Framework WPF assemblies directory not found at: $wpfDir"
    }

    $refs = New-Object 'System.Collections.Generic.List[string]'
    if ($Platform -eq 'arm64') {
        $mscorlibPath = Join-Path $fxRoot 'mscorlib.dll'
        if (-not (Test-Path -LiteralPath $mscorlibPath -PathType Leaf)) {
            throw "Required .NET mscorlib.dll not found: $mscorlibPath"
        }
        $refs.Add($mscorlibPath)
    }
    foreach ($name in $ReferenceNames) {
        $candidate = if ($name -in @('WindowsBase.dll', 'PresentationCore.dll', 'PresentationFramework.dll')) {
            Join-Path $wpfDir $name
        } else {
            Join-Path $fxRoot $name
        }
        if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            throw "Required .NET reference assembly not found: $candidate"
        }
        $refs.Add($candidate)
    }

    $compilerDll = ''
    if ($Platform -eq 'arm64') {
        $dotnetCmd = Get-Command dotnet -ErrorAction SilentlyContinue
        if ($null -eq $dotnetCmd) {
            throw ".NET SDK (dotnet) is required to compile /platform:arm64 binaries cleanly."
        }
        $dotnetExe = $dotnetCmd.Source
        $sdkBase = Join-Path (Split-Path -Parent $dotnetExe) 'sdk'
        $cscDllItem = $null
        if (Test-Path -LiteralPath $sdkBase -PathType Container) {
            $cscDllItem = Get-ChildItem -LiteralPath $sdkBase -Filter 'csc.dll' -Recurse -File -ErrorAction SilentlyContinue |
                Where-Object { $_.FullName -match 'Roslyn[\\/]bincore[\\/]csc\.dll$' } |
                Sort-Object FullName -Descending |
                Select-Object -First 1
        }
        if ($null -eq $cscDllItem) {
            throw "Roslyn csc.dll not found under .NET SDK directory ($sdkBase) for /platform:arm64 compilation."
        }
        $cscExe = $dotnetExe
        $compilerDll = $cscDllItem.FullName
    } else {
        if (-not (Test-Path -LiteralPath $cscExe -PathType Leaf)) {
            throw ".NET Framework C# compiler csc.exe not found at: $cscExe"
        }
    }

    return [pscustomobject]@{
        FxRoot      = $fxRoot
        CscExe      = $cscExe
        CompilerDll = $compilerDll
        Platform    = $Platform
        WpfDir      = $wpfDir
        References  = @($refs.ToArray())
    }
}

function Ensure-AppIconFile {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string]$IconPath
    )

    if (-not (Test-Path -LiteralPath $IconPath -PathType Leaf)) {
        $iconScript = Join-Path $RepoRoot 'scripts\New-AppIcon.ps1'
        if (Test-Path -LiteralPath $iconScript -PathType Leaf) {
            & $iconScript -IconPath $IconPath | Out-Null
        }
    }
}

function Get-FileSha256LowerHex {
    param([Parameter(Mandatory = $true)][string]$Path)

    $sha256Provider = [System.Security.Cryptography.SHA256]::Create()
    try {
        $stream = [System.IO.File]::OpenRead($Path)
        try {
            $hashBytes = $sha256Provider.ComputeHash($stream)
        } finally {
            $stream.Dispose()
        }
        return ([BitConverter]::ToString($hashBytes) -replace '-', '').ToLowerInvariant()
    } finally {
        $sha256Provider.Dispose()
    }
}

function Invoke-WinExeCscCompile {
    param(
        [Parameter(Mandatory = $true)][string]$CscExe,
        [string]$CompilerDll = '',
        [string]$FxRoot = '',
        [ValidateSet('anycpu', 'x86', 'x64', 'arm64')][string]$Platform = 'x64',
        [Parameter(Mandatory = $true)][string]$OutputPath,
        [Parameter(Mandatory = $true)][string[]]$References,
        [Parameter(Mandatory = $true)][string[]]$SourceFiles,
        [string]$IconPath = '',
        [string]$IconResourceName = '',
        [string]$ManifestPath = '',
        [string[]]$ExtraResources = @(),
        [string]$FailureLabel = 'csc.exe build'
    )

    $cscArgs = New-Object 'System.Collections.Generic.List[string]'
    $cscArgs.Add('/nologo')
    $cscArgs.Add('/target:winexe')
    $cscArgs.Add("/platform:$Platform")
    $cscArgs.Add('/optimize+')
    $cscArgs.Add('/utf8output')
    $cscArgs.Add('/codepage:65001')
    if (-not [string]::IsNullOrWhiteSpace($CompilerDll)) {
        $cscArgs.Add('/nowarn:CS8012')
        if (-not [string]::IsNullOrWhiteSpace($FxRoot)) {
            $cscArgs.Add("/lib:$FxRoot")
        }
    }
    if (-not [string]::IsNullOrWhiteSpace($IconPath) -and (Test-Path -LiteralPath $IconPath -PathType Leaf)) {
        $cscArgs.Add("/win32icon:$IconPath")
        if (-not [string]::IsNullOrWhiteSpace($IconResourceName)) {
            $cscArgs.Add("/resource:$IconPath,$IconResourceName")
        }
    }
    if (-not [string]::IsNullOrWhiteSpace($ManifestPath) -and (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) {
        $cscArgs.Add("/win32manifest:$ManifestPath")
    }
    foreach ($res in $ExtraResources) {
        if (-not [string]::IsNullOrWhiteSpace($res)) {
            $cscArgs.Add("/resource:$res")
        }
    }
    $cscArgs.Add("/out:$OutputPath")
    foreach ($r in $References) {
        $cscArgs.Add("/reference:$r")
    }
    foreach ($src in $SourceFiles) {
        $cscArgs.Add($src)
    }

    if (-not [string]::IsNullOrWhiteSpace($CompilerDll)) {
        $outputLines = & $CscExe $CompilerDll @($cscArgs.ToArray()) 2>&1
    } else {
        $outputLines = & $CscExe @($cscArgs.ToArray()) 2>&1
    }
    if ($LASTEXITCODE -ne 0) {
        $msg = ($outputLines | Out-String)
        throw "$FailureLabel failed with exit code ${LASTEXITCODE}:`n$msg"
    }
    if (-not (Test-Path -LiteralPath $OutputPath -PathType Leaf)) {
        throw "$FailureLabel reported exit 0, but executable was not found at: $OutputPath"
    }

    $peBytes = [System.IO.File]::ReadAllBytes($OutputPath)
    $peOffset = [BitConverter]::ToInt32($peBytes, 0x3C)
    $machineVal = [BitConverter]::ToUInt16($peBytes, $peOffset + 4)
    $peMachineHex = ('0x{0:X4}' -f $machineVal)
    if ($Platform -eq 'x64' -and $machineVal -ne 0x8664) {
        throw "$FailureLabel expected x64 PE Machine 0x8664, got $peMachineHex ($OutputPath)"
    }
    if ($Platform -eq 'arm64' -and $machineVal -ne 0xAA64) {
        throw "$FailureLabel expected arm64 PE Machine 0xAA64, got $peMachineHex ($OutputPath)"
    }

    $fileInfo = Get-Item -LiteralPath $OutputPath
    $sha256 = Get-FileSha256LowerHex -Path $OutputPath
    return [pscustomobject]@{
        OutputPath = $OutputPath
        SizeBytes  = [int64]$fileInfo.Length
        Sha256     = $sha256
        PeMachine  = $peMachineHex
    }
}

function Invoke-DesktopCapture {
    param(
        [Parameter(Mandatory = $true)][string]$ExecutablePath,
        [Parameter(Mandatory = $true)][string]$ArgumentsLine
    )

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $ExecutablePath
    $psi.Arguments = $ArgumentsLine
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true

    $proc = [System.Diagnostics.Process]::Start($psi)
    if ($null -eq $proc) {
        throw "Failed to start desktop executable: $ExecutablePath"
    }
    $proc.WaitForExit()
    if ($proc.ExitCode -ne 0) {
        throw "Desktop capture failed with exit code $($proc.ExitCode) for args: $ArgumentsLine"
    }
}

function Resolve-CaptureDesktopExecutable {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [AllowEmptyString()][string]$ExePath,
        [Parameter(Mandatory = $true)][string]$SandboxWorkDir
    )

    if (-not [string]::IsNullOrWhiteSpace($ExePath)) {
        $resolvedExe = Resolve-CallerPath -PathValue $ExePath
        if (-not (Test-Path -LiteralPath $resolvedExe -PathType Leaf)) {
            throw "Specified ExePath does not exist: $resolvedExe"
        }
        $exeItem = Get-Item -LiteralPath $resolvedExe -Force
        if (($exeItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Refusing to execute reparse point ExePath: $resolvedExe"
        }
        return [pscustomobject]@{ ExePath = $resolvedExe; UsedTempExe = $false }
    }

    $buildScript = Join-Path $RepoRoot 'scripts\Build-DesktopApp.ps1'
    if (-not (Test-Path -LiteralPath $buildScript -PathType Leaf)) {
        throw "Build script not found: $buildScript"
    }
    if (-not (Test-Path -LiteralPath $SandboxWorkDir)) {
        [System.IO.Directory]::CreateDirectory($SandboxWorkDir) | Out-Null
    }
    $tempExe = Join-Path $SandboxWorkDir 'Claude-Residual-ID-Cleaner.exe'
    $buildRes = & $buildScript -SourceDir (Join-Path $RepoRoot 'src\Gui') -OutputPath $tempExe
    if ($null -eq $buildRes -or -not $buildRes.Succeeded -or -not (Test-Path -LiteralPath $tempExe -PathType Leaf)) {
        throw "Temporary desktop build failed at: $tempExe"
    }
    return [pscustomobject]@{ ExePath = $tempExe; UsedTempExe = $true }
}

function Remove-CaptureSandboxDirectory {
    param(
        [AllowEmptyString()][string]$WorkDir,
        [Parameter(Mandatory = $true)][string]$SandboxRoot,
        [Parameter(Mandatory = $true)][bool]$SandboxExisted
    )

    if (-not [string]::IsNullOrEmpty($WorkDir) -and (Test-Path -LiteralPath $WorkDir)) {
        try {
            Remove-Item -LiteralPath $WorkDir -Recurse -Force
        } catch {
            Write-Warning "Failed to remove temporary capture directory '$WorkDir': $($_.Exception.Message)"
        }
    }
    if (-not $SandboxExisted -and (Test-Path -LiteralPath $SandboxRoot)) {
        $remaining = @(Get-ChildItem -LiteralPath $SandboxRoot -Force)
        if ($remaining.Count -eq 0) {
            try {
                [System.IO.Directory]::Delete($SandboxRoot, $false)
            } catch {
                Write-Warning "Empty sandbox root retained: $SandboxRoot ($($_.Exception.Message))"
            }
        }
    }
}
