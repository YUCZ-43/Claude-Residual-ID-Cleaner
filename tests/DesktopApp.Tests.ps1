$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

$repoRoot = Split-Path -Parent $PSScriptRoot
$buildScript = Join-Path $repoRoot 'scripts\Build-DesktopApp.ps1'
$iconScript = Join-Path $repoRoot 'scripts\New-AppIcon.ps1'
$installerBuildScript = Join-Path $repoRoot 'scripts\Build-Installer.ps1'
$locCs = Join-Path $repoRoot 'src\Gui\Localization.cs'
$progCs = Join-Path $repoRoot 'src\Gui\Program.cs'
$asmInfoCs = Join-Path $repoRoot 'src\Gui\AssemblyInfo.cs'
$appIcoPath = Join-Path $repoRoot 'src\Gui\app.ico'
$appManifestPath = Join-Path $repoRoot 'src\Gui\app.manifest'
$logoPngPath = Join-Path $repoRoot 'docs\images\logo.png'
$setupCs = Join-Path $repoRoot 'src\Installer\SetupProgram.cs'
$setupAsmCs = Join-Path $repoRoot 'src\Installer\SetupAssemblyInfo.cs'
$setupManifestPath = Join-Path $repoRoot 'src\Installer\app.manifest'

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
    Add-Type -AssemblyName PresentationCore, System.Drawing

    # 1. Source & build script existence and AST parse checks
    Assert-True (
        (Test-Path -LiteralPath $buildScript -PathType Leaf) -and
        (Test-Path -LiteralPath $iconScript -PathType Leaf) -and
        (Test-Path -LiteralPath $installerBuildScript -PathType Leaf) -and
        (Test-Path -LiteralPath $locCs -PathType Leaf) -and
        (Test-Path -LiteralPath $progCs -PathType Leaf) -and
        (Test-Path -LiteralPath $asmInfoCs -PathType Leaf) -and
        (Test-Path -LiteralPath $appIcoPath -PathType Leaf) -and
        (Test-Path -LiteralPath $appManifestPath -PathType Leaf) -and
        (Test-Path -LiteralPath $logoPngPath -PathType Leaf) -and
        (Test-Path -LiteralPath $setupCs -PathType Leaf) -and
        (Test-Path -LiteralPath $setupAsmCs -PathType Leaf) -and
        (Test-Path -LiteralPath $setupManifestPath -PathType Leaf)
    ) 'Desktop GUI, icon, manifest, and Setup Installer source/build files exist'

    foreach ($psFile in @($buildScript, $iconScript, $installerBuildScript, $PSCommandPath)) {
        $errs = $null
        $null = [System.Management.Automation.Language.Parser]::ParseFile($psFile, [ref]$null, [ref]$errs)
        Assert-True (@($errs).Count -eq 0) "AST parse has 0 syntax errors for $([IO.Path]::GetFileName($psFile))"
    }

    # 2. Static security, manifest asInvoker, & localization completeness checks on C# sources
    $locText = [IO.File]::ReadAllText($locCs, [System.Text.Encoding]::UTF8)
    $progText = [IO.File]::ReadAllText($progCs, [System.Text.Encoding]::UTF8)
    $asmInfoText = [IO.File]::ReadAllText($asmInfoCs, [System.Text.Encoding]::UTF8)
    $appManText = [IO.File]::ReadAllText($appManifestPath, [System.Text.Encoding]::UTF8)
    $setupText = [IO.File]::ReadAllText($setupCs, [System.Text.Encoding]::UTF8)
    $setupManText = [IO.File]::ReadAllText($setupManifestPath, [System.Text.Encoding]::UTF8)

    Assert-True (
        ($appManText -match 'level="asInvoker"') -and
        ($appManText -notmatch 'requireAdministrator') -and
        ($setupManText -match 'level="asInvoker"') -and
        ($setupManText -notmatch 'requireAdministrator')
    ) 'Desktop and Setup manifests strictly enforce asInvoker (never force UAC on startup)'

    Assert-True (
        ($asmInfoText -match 'AssemblyProduct\("claude-cleanup"\)') -and
        ($asmInfoText -match 'AssemblyTitle\("Claude Residual ID Cleaner"\)') -and
        ($asmInfoText -match 'AssemblyVersion\(')
    ) 'AssemblyInfo.cs defines product, title, and version metadata for standalone .exe'

    Assert-True (
        ($progText -match '#1E1E1E') -and
        ($progText -match '#252526') -and
        ($progText -match '#2D2D30') -and
        ($progText -match 'ThemeStyle\s*=\s*"AdobeDarkSlate"') -and
        ($progText -match 'SaveFileDialog') -and
        ($progText -match 'GridSplitter') -and
        ($progText -match 'HorizontalScrollBarVisibility\s*=\s*ScrollBarVisibility\.Auto') -and
        ($progText -match '_chkSelectAll') -and
        ($progText -match 'ResidualAccountIdRecord') -and
        ($progText -match '_btnRestartAdmin') -and
        ($progText -match '_lblPrivilegeBadge')
    ) 'Desktop WPF source defines Adobe dark palette, Stage K controls, privilege badge, and on-demand admin restart button'

    $runasMatches = [regex]::Matches($progText, '(?i)Verb\s*=\s*"runas"')
    Assert-True (
        ($progText -notmatch 'ExecutionPolicy\s*(Bypass|Unrestricted)|RegDeleteKeyW|SetFileInformationByHandle|NtDeleteKey|Remove-Item') -and
        ($runasMatches.Count -eq 1) -and
        ($progText -match 'OnRestartAsAdminClick[\s\S]{0,1200}MessageBox\.Show[\s\S]{0,1200}Verb\s*=\s*"runas"') -and
        ($progText -match 'ClaudeCleanup\.ps1') -and
        ($progText -match '"-WhatIf"') -and
        ($progText -match '_btnClean\.IsEnabled\s*=\s*false')
    ) 'Desktop WPF source duplicates zero deletion APIs, has no bypass, gates runas strictly behind explicit OnRestartAsAdminClick prompt, disables Clean initially, and mandates -WhatIf'

    $zhMatches = [regex]::Matches($locText.Split(@('else'), [System.StringSplitOptions]::None)[0], 'd\["([^"]+)"\]\s*=')
    $enMatches = [regex]::Matches($locText.Split(@('else'), [System.StringSplitOptions]::None)[1], 'd\["([^"]+)"\]\s*=')
    $zhKeys = @($zhMatches | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
    $enKeys = @($enMatches | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
    Assert-True (($zhKeys.Count -ge 30) -and (($zhKeys -join ',') -eq ($enKeys -join ','))) "Localization dictionary defines identical complete key sets for zh-CN and en-US ($($zhKeys.Count) keys)"

    Assert-True (
        ($locText -match '绝不改动 Windows 系统') -and
        ($locText -match 'Never Alters Windows OS') -and
        (-not $locText.Contains([char]0xFFFD)) -and
        (-not $progText.Contains([char]0xFFFD)) -and
        (-not $asmInfoText.Contains([char]0xFFFD)) -and
        (-not $setupText.Contains([char]0xFFFD))
    ) 'Bilingual positioning promise present in zh-CN & en-US without UTF-8 replacement characters'

    $combinedCs = $locText + "`n" + $progText + "`n" + $asmInfoText + "`n" + $setupText
    $sidPattern = 'S-1-5-21-' + '\d+-\d+-\d+-\d+'
    $userPathPattern = '(?i)C:\\Users\\(?!(?:<USERNAME>|<USER>|<name>|username|user|example|Public|Default)(?:[\\"`\s]|$))[A-Za-z0-9._-]+\\'
    Assert-True (($combinedCs -notmatch $sidPattern) -and ($combinedCs -notmatch $userPathPattern)) 'Desktop & Setup C# sources contain zero local user paths or Windows SIDs'

    # 2b. Verify New-AppIcon.ps1 produces valid multi-resolution .ico (16, 32, 48, 256) and fallback programmatic PNG inside sandbox
    $icoFromLogo = Join-Path $appSandbox 'from-logo.ico'
    $icoFallbackPng = Join-Path $appSandbox 'fallback-logo.png'
    $icoFallbackIco = Join-Path $appSandbox 'fallback.ico'
    $icoRes1 = & $iconScript -LogoPngPath $logoPngPath -IconPath $icoFromLogo
    $icoRes2 = & $iconScript -LogoPngPath $icoFallbackPng -IconPath $icoFallbackIco -ForceRegenerate
    $fsIco = [IO.File]::OpenRead($icoFromLogo)
    try {
        $icoDec = New-Object System.Windows.Media.Imaging.IconBitmapDecoder($fsIco, 'PreservePixelFormat', 'Default')
        $frameDims = @($icoDec.Frames | ForEach-Object { "$($_.PixelWidth)x$($_.PixelHeight)" })
    } finally {
        $fsIco.Dispose()
    }
    Assert-True (
        $icoRes1.Succeeded -and $icoRes2.Succeeded -and $icoRes2.GeneratedLogo -and
        (Test-Path -LiteralPath $icoFallbackPng -PathType Leaf) -and
        ($frameDims -contains '16x16') -and ($frameDims -contains '32x32') -and ($frameDims -contains '48x48') -and ($frameDims -contains '256x256')
    ) 'New-AppIcon.ps1 builds multi-resolution .ico (16, 32, 48, 256) from logo.png and supports programmatic mascot fallback'

    # 3. Compile standalone zero-console WPF .exe inside tests/sandbox/desktop-app/
    $sandboxExe = Join-Path $appSandbox 'Claude-Residual-ID-Cleaner.exe'
    $buildRes = & $buildScript -SourceDir (Join-Path $repoRoot 'src\Gui') -OutputPath $sandboxExe
    Assert-True ($buildRes.Succeeded -and (Test-Path -LiteralPath $sandboxExe -PathType Leaf) -and $buildRes.SizeBytes -gt 10000 -and $buildRes.Sha256 -match '^[a-f0-9]{64}$') 'Build-DesktopApp.ps1 compiles standalone Claude-Residual-ID-Cleaner.exe cleanly inside sandbox'

    # 4. Verify PE subsystem == 2, Win32 icon resource embedded, and asInvoker manifest embedded
    $subsys = Get-PeSubsystemType -ExePath $sandboxExe
    $assocIcon = [System.Drawing.Icon]::ExtractAssociatedIcon($sandboxExe)
    $hasAssocIcon = ($null -ne $assocIcon -and $assocIcon.Width -gt 0)
    if ($null -ne $assocIcon) { $assocIcon.Dispose() }
    $exeTextUtf8 = [System.Text.Encoding]::UTF8.GetString([IO.File]::ReadAllBytes($sandboxExe))
    Assert-True ($subsys -eq 2 -and $hasAssocIcon -and ($exeTextUtf8 -match 'level="asInvoker"')) "Compiled .exe uses Windows GUI subsystem ($subsys), embeds PE icon, and embeds asInvoker manifest"

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
        $jZh.NavTabCount -eq 5 -and
        $jZh.MetricCardCount -eq 4 -and
        $jZh.ThemeStyle -eq 'AdobeDarkSlate' -and
        $jZh.HasGridSplitter -and
        $jZh.HasAccountIdCard -and
        $jZh.HorizontalScrollEnabled -and
        $jZh.HasWindowIcon -and
        $jZh.HasRestartAdminButton -and
        (-not [string]::IsNullOrWhiteSpace($jZh.PrivilegeBadgeText)) -and
        (-not $jZh.InitialCleanButtonEnabled) -and
        $jZh.BackendFound -and
        $jZh.DryRun -and
        ($jZh.InitialSafetyPill -match '绝不改动 Windows 系统') -and
        ($jZh.ToggledSafetyPill -match 'Never Alters Windows OS')
    ) 'Compiled WPF .exe validates zh-CN default, mascot Window.Icon, privilege badge, on-demand admin button, AdobeDarkSlate layout, and disabled Clean button'

    # 6. Execute compiled .exe reverse toggle (en-US -> zh-CN)
    $outEn = Join-Path $appSandbox 'selftest-en.json'
    $pEn = [System.Diagnostics.Process]::Start($sandboxExe, "--headless --dry-run --language en-US --toolkit-root `"$repoRoot`" --self-test `"$outEn`"")
    $pEn.WaitForExit()
    $jEn = [IO.File]::ReadAllText($outEn, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
    Assert-True (
        $pEn.ExitCode -eq 0 -and
        $jEn.InitialLanguage -eq 'en-US' -and
        $jEn.ToggledLanguage -eq 'zh-CN' -and
        $jEn.NavTabCount -eq 5 -and
        $jEn.MetricCardCount -eq 4 -and
        $jEn.ThemeStyle -eq 'AdobeDarkSlate'
    ) 'Compiled WPF .exe validates live en-US->zh-CN toggle and AdobeDarkSlate layout metrics'

    # 7. Non-destructive --demo-audit --capture-png render inside tests/sandbox/desktop-app/
    $demoPng = Join-Path $appSandbox 'demo-audit-capture.png'
    $pCap = [System.Diagnostics.Process]::Start($sandboxExe, "--demo-audit --dry-run --language zh-CN --nav 0 --toolkit-root `"$repoRoot`" --capture-png `"$demoPng`"")
    $pCap.WaitForExit()
    $pngValid = $false
    $pngLen = 0
    if ($pCap.ExitCode -eq 0 -and (Test-Path -LiteralPath $demoPng -PathType Leaf)) {
        $pngBytes = [IO.File]::ReadAllBytes($demoPng)
        $pngLen = $pngBytes.Length
        $hasMagic = ($pngLen -gt 20480 -and
            $pngBytes[0] -eq 0x89 -and $pngBytes[1] -eq 0x50 -and $pngBytes[2] -eq 0x4E -and $pngBytes[3] -eq 0x47 -and
            $pngBytes[4] -eq 0x0D -and $pngBytes[5] -eq 0x0A -and $pngBytes[6] -eq 0x1A -and $pngBytes[7] -eq 0x0A)
        $hasIhdr = ($pngLen -ge 24 -and $pngBytes[12] -eq 0x49 -and $pngBytes[13] -eq 0x48 -and $pngBytes[14] -eq 0x44 -and $pngBytes[15] -eq 0x52)
        if ($hasMagic -and $hasIhdr) {
            $pngW = ([int]$pngBytes[16] -shl 24) -bor ([int]$pngBytes[17] -shl 16) -bor ([int]$pngBytes[18] -shl 8) -bor [int]$pngBytes[19]
            $pngH = ([int]$pngBytes[20] -shl 24) -bor ([int]$pngBytes[21] -shl 16) -bor ([int]$pngBytes[22] -shl 8) -bor [int]$pngBytes[23]
            $pngValid = ($pngW -gt 0 -and $pngH -gt 0)
        }
    }
    Assert-True $pngValid "Compiled WPF .exe --demo-audit --capture-png produces valid PNG >20 KB in sandbox ($pngLen bytes)"

    # 8. Verify --demo-audit populates non-secret residual Account IDs cleanly
    $outDemo = Join-Path $appSandbox 'selftest-demo.json'
    $pDemo = [System.Diagnostics.Process]::Start($sandboxExe, "--headless --demo-audit --dry-run --language zh-CN --toolkit-root `"$repoRoot`" --self-test `"$outDemo`"")
    $pDemo.WaitForExit()
    $jDemo = [IO.File]::ReadAllText($outDemo, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
    Assert-True ($pDemo.ExitCode -eq 0 -and $jDemo.AccountIdCount -eq 3 -and $jDemo.HasAccountIdCard -and $jDemo.HasGridSplitter -and $jDemo.HorizontalScrollEnabled -and $jDemo.HasWindowIcon) 'Compiled WPF .exe --demo-audit populates 3 mock residual Account/Org/Device IDs alongside Stage K/L controls'

    # 9. Compile standalone Claude-Residual-ID-Cleaner-Setup.exe inside sandbox and verify headless install-uninstall roundtrip
    $sandboxSetupExe = Join-Path $appSandbox 'Claude-Residual-ID-Cleaner-Setup.exe'
    $setupBuildRes = & $installerBuildScript -SourceDir (Join-Path $repoRoot 'src\Installer') -GuiSourceDir (Join-Path $repoRoot 'src\Gui') -OutputPath $sandboxSetupExe -DesktopExePath $sandboxExe -Version '0.1.0-test'
    $setupSubsys = Get-PeSubsystemType -ExePath $sandboxSetupExe
    $setupIcon = [System.Drawing.Icon]::ExtractAssociatedIcon($sandboxSetupExe)
    $hasSetupPeIcon = ($null -ne $setupIcon -and $setupIcon.Width -gt 0)
    if ($null -ne $setupIcon) { $setupIcon.Dispose() }
    Assert-True ($setupBuildRes.Succeeded -and (Test-Path -LiteralPath $sandboxSetupExe -PathType Leaf) -and $setupSubsys -eq 2 -and $hasSetupPeIcon) 'Build-Installer.ps1 compiles standalone Claude-Residual-ID-Cleaner-Setup.exe cleanly with GUI subsystem and embedded icon'

    $setupInstallTarget = Join-Path $appSandbox 'setup-install-target'
    $setupDesktopDir = Join-Path $appSandbox 'setup-desktop'
    $setupStartMenuDir = Join-Path $appSandbox 'setup-startmenu'
    $setupRegJson = Join-Path $appSandbox 'setup-reg.json'
    $setupInstOut = Join-Path $appSandbox 'setup-install-selftest.json'
    $setupUninstOut = Join-Path $appSandbox 'setup-uninstall-selftest.json'

    $pSetupInst = [System.Diagnostics.Process]::Start($sandboxSetupExe, "--headless --no-registry --install-dir `"$setupInstallTarget`" --desktop-dir `"$setupDesktopDir`" --start-menu-dir `"$setupStartMenuDir`" --reg-out `"$setupRegJson`" --self-test `"$setupInstOut`"")
    $pSetupInst.WaitForExit()
    $jSetupInst = [IO.File]::ReadAllText($setupInstOut, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
    $jSetupReg = [IO.File]::ReadAllText($setupRegJson, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
    Assert-True (
        $pSetupInst.ExitCode -eq 0 -and
        $jSetupInst.Succeeded -and
        $jSetupInst.HasWindowIcon -and
        $jSetupReg.SkippedLiveRegistryWrite -and
        ($jSetupReg.UninstallString -match '--uninstall') -and
        (Test-Path -LiteralPath (Join-Path $setupInstallTarget 'Claude-Residual-ID-Cleaner.exe') -PathType Leaf) -and
        (Test-Path -LiteralPath (Join-Path $setupInstallTarget 'ClaudeCleanup.ps1') -PathType Leaf) -and
        (Test-Path -LiteralPath (Join-Path $setupDesktopDir 'Claude Residual ID Cleaner.lnk') -PathType Leaf) -and
        (Test-Path -LiteralPath (Join-Path $setupStartMenuDir 'Uninstall claude-cleanup.lnk') -PathType Leaf)
    ) 'Compiled Setup .exe completes sandboxed install with payload, shortcuts, manifest, and zero live registry writes'

    $pSetupUninst = [System.Diagnostics.Process]::Start($sandboxSetupExe, "--headless --uninstall --no-registry --install-dir `"$setupInstallTarget`" --self-test `"$setupUninstOut`"")
    $pSetupUninst.WaitForExit()
    $jSetupUninst = [IO.File]::ReadAllText($setupUninstOut, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
    Assert-True (
        $pSetupUninst.ExitCode -eq 0 -and
        $jSetupUninst.Succeeded -and
        $jSetupUninst.RemovedFileCount -ge 40 -and
        (-not (Test-Path -LiteralPath $setupInstallTarget)) -and
        (-not (Test-Path -LiteralPath (Join-Path $setupDesktopDir 'Claude Residual ID Cleaner.lnk'))) -and
        (-not (Test-Path -LiteralPath (Join-Path $setupStartMenuDir 'Uninstall claude-cleanup.lnk')))
    ) 'Compiled Setup .exe completes sandboxed uninstall removing managed files and shortcuts cleanly'

    # 10. Verify ANSI escape-code stripping and friendly bilingual "Claude is running" translation on compiled .exe assembly
    Assert-True (
        ($progText -match 'StripAnsiEscapeCodes') -and
        ($progText -match 'TranslateFriendlyBackendError') -and
        ($progText -match 'ShowBackendErrorDialog') -and
        ($progText -match '"NO_COLOR"')
    ) 'Desktop WPF source implements ANSI stripping, friendly error translation, and NO_COLOR child env'

    $guiAsm = [System.Reflection.Assembly]::Load([IO.File]::ReadAllBytes($sandboxExe))
    $mainWinType = $guiAsm.GetType('ClaudeResidualIdCleaner.MainWindow', $true)
    $esc = [char]27
    $rawAnsiClaude = "${esc}[31;1mException: ${esc}[0mD:\repo\ClaudeCleanup.ps1:2631`nClaude is running. Shut it down normally and retry.${esc}[0m"
    $strippedClaude = $mainWinType.GetMethod('StripAnsiEscapeCodes').Invoke($null, @($rawAnsiClaude))

    $isWarnZh = $false
    $titleZh = ''
    $argsZh = [object[]]@($rawAnsiClaude, 'zh-CN', $isWarnZh, $titleZh)
    $msgZh = $mainWinType.GetMethod('TranslateFriendlyBackendError').Invoke($null, $argsZh)

    $isWarnEn = $false
    $titleEn = ''
    $argsEn = [object[]]@($rawAnsiClaude, 'en-US', $isWarnEn, $titleEn)
    $msgEn = $mainWinType.GetMethod('TranslateFriendlyBackendError').Invoke($null, $argsEn)

    $rawGeneric = "${esc}[31;1mFatal error${esc}[0m: access denied"
    $argsGen = [object[]]@($rawGeneric, 'en-US', $false, '')
    $msgGen = $mainWinType.GetMethod('TranslateFriendlyBackendError').Invoke($null, $argsGen)

    Assert-True (
        (-not $strippedClaude.Contains($esc)) -and
        ($strippedClaude -notmatch '\[31;1m|\[0m') -and
        ([bool]$argsZh[2] -eq $true) -and
        ($msgZh -match '检测到 Claude 客户端或后台进程仍在运行') -and
        ([bool]$argsEn[2] -eq $true) -and
        ($msgEn -match 'Claude Desktop or background Claude processes are currently running') -and
        ([bool]$argsGen[2] -eq $false) -and
        ($msgGen -eq 'Fatal error: access denied')
    ) 'Compiled .exe strips ANSI escape codes cleanly and translates Claude-running error in zh-CN and en-US'

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
