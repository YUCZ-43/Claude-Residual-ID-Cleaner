[CmdletBinding()]
param(
    [string]$ExePath = '',
    [string]$OutputDir = ''
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function Resolve-CallerPath {
    param([Parameter(Mandatory = $true)][string]$PathValue)

    $raw = $PathValue.Trim()
    if (-not [System.IO.Path]::IsPathRooted($raw)) {
        $raw = Join-Path (Get-Location).Path $raw
    }
    return [System.IO.Path]::GetFullPath($raw)
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

function Test-CapturedPng {
    param([Parameter(Mandatory = $true)][string]$FilePath)

    if (-not (Test-Path -LiteralPath $FilePath -PathType Leaf)) {
        throw "Captured PNG file was not created: $FilePath"
    }

    $bytes = [System.IO.File]::ReadAllBytes($FilePath)
    if ($bytes.Length -le 20480) {
        throw "Captured PNG file is smaller than 20 KB ($($bytes.Length) bytes): $FilePath"
    }

    if ($bytes.Length -lt 24 -or
        $bytes[0] -ne 0x89 -or
        $bytes[1] -ne 0x50 -or
        $bytes[2] -ne 0x4E -or
        $bytes[3] -ne 0x47 -or
        $bytes[4] -ne 0x0D -or
        $bytes[5] -ne 0x0A -or
        $bytes[6] -ne 0x1A -or
        $bytes[7] -ne 0x0A) {
        throw "Invalid PNG file header (expected 89 50 4E 47 0D 0A 1A 0A): $FilePath"
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
$buildScript = Join-Path $repoRoot 'scripts\Build-DesktopApp.ps1'

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
$tempBuildDir = ''
$usedTempExe = $false

try {
    $resolvedExe = ''
    if (-not [string]::IsNullOrWhiteSpace($ExePath)) {
        $resolvedExe = Resolve-CallerPath -PathValue $ExePath
        if (-not (Test-Path -LiteralPath $resolvedExe -PathType Leaf)) {
            throw "Specified ExePath does not exist: $resolvedExe"
        }
        $exeItem = Get-Item -LiteralPath $resolvedExe -Force
        if (($exeItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Refusing to execute reparse point ExePath: $resolvedExe"
        }
    } else {
        if (-not (Test-Path -LiteralPath $buildScript -PathType Leaf)) {
            throw "Build script not found: $buildScript"
        }
        $tempBuildDir = Join-Path $sandboxRoot ('ui-capture-' + [Guid]::NewGuid().ToString('N'))
        [System.IO.Directory]::CreateDirectory($tempBuildDir) | Out-Null
        $resolvedExe = Join-Path $tempBuildDir 'Claude-Residual-ID-Cleaner.exe'
        $usedTempExe = $true

        $buildRes = & $buildScript -SourceDir (Join-Path $repoRoot 'src\Gui') -OutputPath $resolvedExe
        if ($null -eq $buildRes -or -not $buildRes.Succeeded -or -not (Test-Path -LiteralPath $resolvedExe -PathType Leaf)) {
            throw "Temporary desktop build failed at: $resolvedExe"
        }
    }

    $captures = @(
        @{
            Name = 'ui-main-zh.png'
            Args = "--dry-run --language zh-CN --nav 0 --toolkit-root `"$repoRoot`""
        },
        @{
            Name = 'ui-scan-results-zh.png'
            Args = "--demo-audit --dry-run --language zh-CN --nav 0 --toolkit-root `"$repoRoot`""
        },
        @{
            Name = 'ui-main-en.png'
            Args = "--demo-audit --dry-run --language en-US --nav 0 --toolkit-root `"$repoRoot`""
        }
    )

    $results = New-Object 'System.Collections.Generic.List[object]'
    foreach ($item in $captures) {
        $targetPng = (Join-Path $resolvedOutputDir $item.Name).TrimEnd('\', '/')
        $fullArgs = "$($item.Args) --capture-png `"$targetPng`""
        Invoke-DesktopCapture -ExecutablePath $resolvedExe -ArgumentsLine $fullArgs
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
    if (-not [string]::IsNullOrEmpty($tempBuildDir) -and (Test-Path -LiteralPath $tempBuildDir)) {
        try {
            Remove-Item -LiteralPath $tempBuildDir -Recurse -Force
        } catch {
            Write-Warning "Failed to remove temporary capture build directory '$tempBuildDir': $($_.Exception.Message)"
        }
    }
    if (-not $sandboxExisted -and (Test-Path -LiteralPath $sandboxRoot)) {
        $remaining = @(Get-ChildItem -LiteralPath $sandboxRoot -Force)
        if ($remaining.Count -eq 0) {
            try {
                [System.IO.Directory]::Delete($sandboxRoot, $false)
            } catch {
                Write-Warning "Empty sandbox root retained: $sandboxRoot ($($_.Exception.Message))"
            }
        }
    }
}
