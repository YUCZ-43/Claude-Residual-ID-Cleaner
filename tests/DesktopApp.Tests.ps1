$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

$repoRoot = Split-Path -Parent $PSScriptRoot
$buildScript = Join-Path $repoRoot 'scripts\Build-DesktopApp.ps1'
$locCs = Join-Path $repoRoot 'src\Gui\Localization.cs'
$progCs = Join-Path $repoRoot 'src\Gui\Program.cs'

$sandboxRoot = Join-Path $PSScriptRoot 'sandbox'
$sandboxExisted = Test-Path -LiteralPath $sandboxRoot
$appSandbox = Join-Path $sandboxRoot 'desktop-app'
if (Test-Path -LiteralPath $appSandbox) {
    throw "Desktop app test sandbox already exists: $appSandbox"
}
New-Item -ItemType Directory -Path $appSandbox -Force | Out-Null

$passed = 0
$skipped = 0
$notExecuted = 0
$failedList = New-Object 'System.Collections.Generic.List[string]'

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Name
    )
    if (-not $Condition) {
        $script:failedList.Add($Name)
        throw "FAIL: $Name"
    }
    $script:passed++
    Write-Output "PASS: $Name"
}

function Get-PeSubsystemType {
    param([Parameter(Mandatory = $true)][string]$ExePath)

    $bytes = [System.IO.File]::ReadAllBytes($ExePath)
    if ($bytes.Length -lt 256 -or $bytes[0] -ne 0x4D -or $bytes[1] -ne 0x5A) {
        return -1
    }
    $peOffset = [BitConverter]::ToInt32($bytes, 0x3C)
    if ($bytes[$peOffset] -ne 0x50 -or $bytes[$peOffset + 1] -ne 0x45) {
        return -1
    }
    $optHeaderStart = $peOffset + 24
    # PE OptionalHeader Subsystem offset: +68 bytes for both PE32 (0x10B) and PE32+ (0x20B)
    return [int][BitConverter]::ToUInt16($bytes, $optHeaderStart + 68)
}

try {
    # 1. Source & build script existence and AST parse checks
    Assert-True ((Test-Path -LiteralPath $buildScript -PathType Leaf) -and (Test-Path -LiteralPath $locCs -PathType Leaf) -and (Test-Path -LiteralPath $progCs -PathType Leaf)) 'Desktop GUI source files and Build-DesktopApp.ps1 exist'

    foreach ($psFile in @($buildScript, $PSCommandPath)) {
        $errs = $null
        $null = [System.Management.Automation.Language.Parser]::ParseFile($psFile, [ref]$null, [ref]$errs)
        Assert-True (@($errs).Count -eq 0) "AST parse has 0 syntax errors for $([IO.Path]::GetFileName($psFile))"
    }

    # 2. Static security & localization completeness checks on C# sources
    $locText = [IO.File]::ReadAllText($locCs, [System.Text.Encoding]::UTF8)
    $progText = [IO.File]::ReadAllText($progCs, [System.Text.Encoding]::UTF8)

    Assert-True (
        ($progText -notmatch 'ExecutionPolicy\s*(Bypass|Unrestricted)|RegDeleteKeyW|SetFileInformationByHandle|NtDeleteKey|Remove-Item|Verb\s*=\s*"RunAs"') -and
        ($progText -match 'ClaudeCleanup\.ps1') -and
        ($progText -match '"-WhatIf"') -and
        ($progText -match '_btnClean\.IsEnabled\s*=\s*false')
    ) 'Desktop WPF source duplicates zero deletion APIs, has no bypass/elevation, disables Clean initially, and mandates -WhatIf'

    $zhMatches = [regex]::Matches($locText.Split(@('else'), [System.StringSplitOptions]::None)[0], 'd\["([^"]+)"\]\s*=')
    $enMatches = [regex]::Matches($locText.Split(@('else'), [System.StringSplitOptions]::None)[1], 'd\["([^"]+)"\]\s*=')
    $zhKeys = @($zhMatches | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
    $enKeys = @($enMatches | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
    Assert-True (($zhKeys.Count -ge 30) -and (($zhKeys -join ',') -eq ($enKeys -join ','))) "Localization dictionary defines identical complete key sets for zh-CN and en-US ($($zhKeys.Count) keys)"

    Assert-True (
        ($locText -match '绝不改动 Windows 系统') -and
        ($locText -match 'Never Alters Windows OS') -and
        (-not $locText.Contains([char]0xFFFD)) -and
        (-not $progText.Contains([char]0xFFFD))
    ) 'Bilingual positioning promise present in zh-CN & en-US without UTF-8 replacement characters'

    $combinedCs = $locText + "`n" + $progText
    $sidPattern = 'S-1-5-21-' + '\d+-\d+-\d+-\d+'
    $userPathPattern = '(?i)C:\\Users\\(?!(?:<USERNAME>|<USER>|<name>|username|user|example|Public|Default)(?:[\\"`\s]|$))[A-Za-z0-9._-]+\\'
    Assert-True (($combinedCs -notmatch $sidPattern) -and ($combinedCs -notmatch $userPathPattern)) 'Desktop C# sources contain zero local user paths or Windows SIDs'

    # 3. Compile standalone zero-console WPF .exe inside tests/sandbox/desktop-app/
    $sandboxExe = Join-Path $appSandbox 'Claude-Residual-ID-Cleaner.exe'
    $buildRes = & $buildScript -SourceDir (Join-Path $repoRoot 'src\Gui') -OutputPath $sandboxExe
    Assert-True ($buildRes.Succeeded -and (Test-Path -LiteralPath $sandboxExe -PathType Leaf) -and $buildRes.SizeBytes -gt 10000 -and $buildRes.Sha256 -match '^[a-f0-9]{64}$') 'Build-DesktopApp.ps1 compiles standalone Claude-Residual-ID-Cleaner.exe cleanly inside sandbox'

    # 4. Verify PE subsystem == 2 (IMAGE_SUBSYSTEM_WINDOWS_GUI -> zero black console window)
    $subsys = Get-PeSubsystemType -ExePath $sandboxExe
    Assert-True ($subsys -eq 2) "Compiled .exe uses Windows GUI subsystem (PE Subsystem=$subsys; no console window)"

    # 5. Execute compiled .exe in non-destructive headless self-test mode (zh-CN -> en-US live toggle)
    $outZh = Join-Path $appSandbox 'selftest-zh.json'
    $pZh = [System.Diagnostics.Process]::Start($sandboxExe, "--headless --dry-run --language zh-CN --toolkit-root `"$repoRoot`" --self-test `"$outZh`"")
    $pZh.WaitForExit()
    Assert-True ($pZh.ExitCode -eq 0 -and (Test-Path -LiteralPath $outZh -PathType Leaf)) 'Compiled desktop .exe executes zh-CN headless self-test cleanly'
    $jZh = [IO.File]::ReadAllText($outZh, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
    Assert-True (
        $jZh.AppInstantiated -and
        $jZh.InitialLanguage -eq 'zh-CN' -and
        $jZh.ToggledLanguage -eq 'en-US' -and
        $jZh.ScopeCheckboxCount -eq 5 -and
        $jZh.DataGridColumnCount -eq 5 -and
        (-not $jZh.InitialCleanButtonEnabled) -and
        $jZh.BackendFound -and
        $jZh.DryRun -and
        ($jZh.InitialSafetyPill -match '绝不改动 Windows 系统') -and
        ($jZh.ToggledSafetyPill -match 'Never Alters Windows OS')
    ) 'Compiled WPF .exe validates zh-CN default, live zh-CN->en-US switch, 5 checklist items, 5 DataGrid columns, and disabled Clean button'

    # 6. Execute compiled .exe reverse toggle (en-US -> zh-CN)
    $outEn = Join-Path $appSandbox 'selftest-en.json'
    $pEn = [System.Diagnostics.Process]::Start($sandboxExe, "--headless --dry-run --language en-US --toolkit-root `"$repoRoot`" --self-test `"$outEn`"")
    $pEn.WaitForExit()
    $jEn = [IO.File]::ReadAllText($outEn, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
    Assert-True ($pEn.ExitCode -eq 0 -and $jEn.InitialLanguage -eq 'en-US' -and $jEn.ToggledLanguage -eq 'zh-CN') 'Compiled WPF .exe validates live en-US->zh-CN toggle'

    Write-Output "RESULT: $passed passed; $skipped skipped; $notExecuted not_executed; $($failedList.Count) failed"
    if ($failedList.Count -gt 0) { exit 1 }
    exit 0
} finally {
    if (Test-Path -LiteralPath $appSandbox) {
        try {
            Remove-Item -LiteralPath $appSandbox -Recurse -Force
        } catch {
            Write-Warning "Failed to clean desktop-app sandbox: $($_.Exception.Message)"
        }
    }
    if (-not $sandboxExisted -and (Test-Path -LiteralPath $sandboxRoot)) {
        $remaining = @(Get-ChildItem -LiteralPath $sandboxRoot -Force)
        if ($remaining.Count -eq 0) {
            try {
                [IO.Directory]::Delete($sandboxRoot, $false)
            } catch {
                Write-Warning "Empty sandbox root retained: $sandboxRoot ($($_.Exception.Message))"
            }
        }
    }
}
