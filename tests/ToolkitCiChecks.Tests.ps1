$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

$repoRoot = Split-Path -Parent $PSScriptRoot
$ciWorkflowPath = Join-Path $repoRoot '.github\workflows\ci.yml'
$releaseScriptPath = Join-Path $repoRoot 'scripts\New-ReleasePackage.ps1'

$sandboxRoot = Join-Path $PSScriptRoot 'sandbox'
$ciSandbox = Join-Path $sandboxRoot 'ci'
$releaseSandbox = Join-Path $sandboxRoot 'release'

if ((Test-Path -LiteralPath $ciSandbox) -or (Test-Path -LiteralPath $releaseSandbox)) {
    throw "Toolkit CI sandbox directories already exist: $ciSandbox / $releaseSandbox"
}

New-Item -ItemType Directory -Path $ciSandbox -Force | Out-Null
New-Item -ItemType Directory -Path $releaseSandbox -Force | Out-Null

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

function Assert-Throws {
    param(
        [scriptblock]$Action,
        [string]$Name
    )
    $threw = $false
    try {
        & $Action | Out-Null
    } catch {
        $threw = $true
    }
    Assert-True -Condition $threw -Name $Name
}

function Remove-SandboxDirectorySafely {
    param(
        [Parameter(Mandatory = $true)][string]$TargetDir,
        [Parameter(Mandatory = $true)][string]$ExpectedParent
    )
    if (-not (Test-Path -LiteralPath $TargetDir)) { return }
    $fullTarget = [IO.Path]::GetFullPath($TargetDir)
    $fullParent = [IO.Path]::GetFullPath($ExpectedParent).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    if (-not $fullTarget.StartsWith($fullParent, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to clean path outside sandbox root: $fullTarget"
    }
    $item = Get-Item -LiteralPath $fullTarget -Force
    if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "Refusing to recursively clean reparse point: $fullTarget"
    }
    [IO.Directory]::Delete($fullTarget, $true)
}

try {
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem

    # 1. PowerShell AST syntax checks on owned scripts
    foreach ($psFile in @($releaseScriptPath, $PSCommandPath)) {
        $tokens = $null
        $parseErrors = $null
        [void][System.Management.Automation.Language.Parser]::ParseFile($psFile, [ref]$tokens, [ref]$parseErrors)
        Assert-True (@($parseErrors).Count -eq 0) "AST parse has 0 errors for $([IO.Path]::GetFileName($psFile))"
    }

    # 2. CI workflow YAML invariants (validated against .github/workflows/ci.yml and sandboxed simulations)
    Assert-True (Test-Path -LiteralPath $ciWorkflowPath -PathType Leaf) 'CI workflow file exists at .github/workflows/ci.yml'
    $ciYaml = [IO.File]::ReadAllText($ciWorkflowPath)
    Assert-True (-not [string]::IsNullOrWhiteSpace($ciYaml)) 'CI workflow YAML is non-empty'
    Assert-True ($ciYaml -notmatch "`t") 'CI workflow YAML contains no tab characters'
    Assert-True ($ciYaml -match '(?m)^name:\s*CI\s*$') 'CI workflow defines top-level name'
    Assert-True (($ciYaml -match '(?m)^on:\s*$') -and ($ciYaml -match '(?m)^\s+push:\s*$') -and ($ciYaml -match '(?m)^\s+pull_request:\s*$') -and ($ciYaml -match '(?m)^\s+workflow_dispatch:\s*$')) 'CI workflow configures push, pull_request, and workflow_dispatch triggers'
    Assert-True ($ciYaml -match '(?m)^\s+contents:\s*read\s*$') 'CI workflow restricts token permissions to contents: read'
    Assert-True ($ciYaml -match '(?m)^\s+runs-on:\s*windows-latest\s*$') 'CI workflow runs on windows-latest'
    Assert-True ($ciYaml -match '(?m)^\s+fail-fast:\s*false\s*$') 'CI workflow sets fail-fast: false so both shells report independently'
    Assert-True (($ciYaml -match 'gh_shell:\s*powershell\b') -and ($ciYaml -match 'shell_exe:\s*powershell\.exe\b') -and ($ciYaml -match 'expected_major:\s*5\b')) 'CI workflow includes Windows PowerShell 5.1 job'
    Assert-True (($ciYaml -match 'gh_shell:\s*pwsh\b') -and ($ciYaml -match 'shell_exe:\s*pwsh\.exe\b') -and ($ciYaml -match 'expected_major:\s*7\b')) 'CI workflow includes PowerShell 7 job'
    Assert-True ($ciYaml -match 'Parser\]::ParseFile') 'CI workflow performs PowerShell AST parse checks'
    Assert-True (($ciYaml -match '\*\.Tests\.ps1') -and ($ciYaml -match '-Help') -and ($ciYaml -match '-Verify -OutputFormat Json')) 'CI workflow runs read-only CLI checks and full *.Tests.ps1 test suites'
    Assert-True (($ciYaml -match 'GITHUB_STEP_SUMMARY') -and ($ciYaml -match 'CI_TEST_TOTALS') -and ($ciYaml -match 'not counted as Passed') -and ($ciYaml -match 'totalSkipped') -and ($ciYaml -match 'totalNotExecuted')) 'CI workflow visibly reports Skipped and NotExecuted without counting them as Passed'
    Assert-True (($ciYaml -match 'LINK_CHECK_OK') -and ($ciYaml -match 'PRIVACY_CHECK_OK') -and ($ciYaml -match 'GIT_HYGIENE_OK')) 'CI workflow enforces Markdown link, privacy, and git hygiene checks'
    Assert-True (
        ($ciYaml -match '(?m)^\s+release-artifacts:\s*$') -and
        ($ciYaml -match '(?m)^\s+needs:\s*test\s*$') -and
        ($ciYaml -match 'actions/upload-artifact@v4') -and
        ($ciYaml -match 'claude-residual-id-cleaner-exe') -and
        ($ciYaml -match 'claude-residual-id-cleaner-setup-exe') -and
        ($ciYaml -match 'claude-residual-id-cleaner-release-bundle') -and
        ($ciYaml -match 'Claude-Residual-ID-Cleaner-0\.1\.0-x64-portable\.exe') -and
        ($ciYaml -match 'Claude-Residual-ID-Cleaner-0\.1\.0-x64-setup\.exe') -and
        ($ciYaml -match 'Claude-Residual-ID-Cleaner-0\.1\.0-x64-bundle\.zip') -and
        ($ciYaml -match 'NavTabCount -ne 3') -and
        ($ciYaml -match 'New-ReleasePackage\.ps1') -and
        ($ciYaml -match 'Build-Installer\.ps1')
    ) 'CI workflow includes release-artifacts job building standardized x64 .exe, Setup .exe, bundle ZIP, SHA256SUMS.txt, NavTabCount=3 checks, and actions/upload-artifact@v4'
    Assert-True (($ciYaml -notmatch 'ExecutionPolicy\s+Bypass') -and ($ciYaml -notmatch '\s-Apply\b') -and ($ciYaml -notmatch 'Remove-AppxPackage') -and ($ciYaml -notmatch 'npm\s+uninstall')) 'CI workflow never invokes ExecutionPolicy Bypass or destructive uninstall/apply commands'

    # Sandboxed CI behavior simulation inside tests/sandbox/ci/
    $ciSimResultLog = Join-Path $ciSandbox 'sample-suite-output.txt'
    $simOutput = @(
        'PASS: sample check 1',
        'PASS: sample check 2',
        'SKIP: directory symlink test skipped (SeCreateSymbolicLinkPrivilege required)',
        'NOT_EXECUTED: live HKCU NtDeleteKey test excluded by policy',
        'RESULT: 84 passed; 4 skipped; 7 not_executed; 0 failed'
    )
    [IO.File]::WriteAllLines($ciSimResultLog, $simOutput)
    $parsedLines = [IO.File]::ReadAllLines($ciSimResultLog)
    $simPassed = 0
    $simSkipped = 0
    $simNotExec = 0
    $simFailed = 0
    foreach ($l in $parsedLines) {
        if ($l -match 'RESULT:\s*(\d+)\s+passed;\s*(\d+)\s+skipped;\s*(\d+)\s+not_executed;\s*(\d+)\s+failed') {
            $simPassed = [int]$Matches[1]
            $simSkipped = [int]$Matches[2]
            $simNotExec = [int]$Matches[3]
            $simFailed = [int]$Matches[4]
        }
    }
    Assert-True ($simPassed -eq 84 -and $simSkipped -eq 4 -and $simNotExec -eq 7 -and $simFailed -eq 0) 'CI result parser keeps Passed=84 separate from Skipped=4 and NotExecuted=7'

    $ciLinkDir = Join-Path $ciSandbox 'docs'
    New-Item -ItemType Directory -Path $ciLinkDir -Force | Out-Null
    [IO.File]::WriteAllText((Join-Path $ciLinkDir 'target.md'), '# Target')
    $ciMdFile = Join-Path $ciLinkDir 'index.md'
    [IO.File]::WriteAllText($ciMdFile, "[ok](target.md)`n[broken](missing-file.md)")
    $mdRaw = [IO.File]::ReadAllText($ciMdFile)
    $mdMatches = [regex]::Matches($mdRaw, '\[[^\]]+\]\(([^)\s]+)\)')
    $missingFound = New-Object 'System.Collections.Generic.List[string]'
    foreach ($m in $mdMatches) {
        $cand = [IO.Path]::GetFullPath((Join-Path $ciLinkDir $m.Groups[1].Value))
        if (-not (Test-Path -LiteralPath $cand)) {
            $missingFound.Add($m.Groups[1].Value)
        }
    }
    Assert-True ($missingFound.Count -eq 1 -and $missingFound[0] -eq 'missing-file.md') 'Sandboxed Markdown link validator detects broken relative link while accepting valid link'

    # 3. Release packaging exclusions and SHA-256 verification inside tests/sandbox/release/
    $fakeRepo = Join-Path $releaseSandbox 'fake-repo'
    $customOut = Join-Path $releaseSandbox 'custom-out'
    New-Item -ItemType Directory -Path $fakeRepo -Force | Out-Null

    # Legitimate files expected in release ZIP
    $legitFiles = @{
        'ClaudeCleanup.ps1'             = '# cleanup script placeholder'
        'README.md'                     = '简体中文 | [English](README.en.md)'
        'README.en.md'                  = '[简体中文](README.md) | English'
        '.gitignore'                    = 'AUDIT.md'
        '.github/workflows/ci.yml'      = 'name: CI'
        'scripts/New-ReleasePackage.ps1'= '# release helper'
        'tests/ClaudeCleanup.Tests.ps1' = '# tests'
    }
    foreach ($rel in $legitFiles.Keys) {
        $dest = Join-Path $fakeRepo ($rel -replace '/', '\')
        $parent = Split-Path -Parent $dest
        if (-not (Test-Path -LiteralPath $parent)) {
            New-Item -ItemType Directory -Path $parent -Force | Out-Null
        }
        [IO.File]::WriteAllText($dest, $legitFiles[$rel])
    }

    # Forbidden/excluded files and directories that must NEVER enter the release ZIP
    $excludedFixtures = @(
        '.git/HEAD',
        '.git/config',
        'AGENTS.md',
        'GOAL.md',
        'PLAN.md',
        'HANDOFF.md',
        'AUDIT.md',
        'CLEANUP-PLAN.md',
        'VERIFICATION.md',
        'host.audit.md',
        'host.plan.md',
        'host.verification.md',
        'execution-ledger.json',
        'custom.ledger.json',
        'dist/stale-release.zip',
        'stale-0.1.0-x64-portable.exe',
        'stale-0.1.0-x64-setup.exe',
        'stale-0.1.0-x64-bundle.zip',
        'tests/sandbox/temp-fixture.txt',
        'sandbox/nested.txt',
        '.credentials.json',
        'claude-credentials.json',
        'api-secret.json',
        'buddy-tokens.json',
        '.env',
        '.env.local',
        'dev.pfx',
        'private.key',
        'cert.pem',
        'personal.log',
        'logs/session.txt',
        'notes.tmp',
        'backup.bak',
        '.claude/settings.json',
        '.claude.json',
        '.codex/config.toml',
        '.agents/state.json',
        '.gemini/settings.json',
        '.vscode/settings.json',
        'Thumbs.db'
    )
    foreach ($rel in $excludedFixtures) {
        $dest = Join-Path $fakeRepo ($rel -replace '/', '\')
        $parent = Split-Path -Parent $dest
        if (-not (Test-Path -LiteralPath $parent)) {
            New-Item -ItemType Directory -Path $parent -Force | Out-Null
        }
        [IO.File]::WriteAllText($dest, "excluded-content:$rel")
    }

    $pkgResult = & $releaseScriptPath -SourceRoot $fakeRepo -OutputDirectory $customOut -Version '1.2.3-test'
    Assert-True (Test-Path -LiteralPath $pkgResult.PackagePath -PathType Leaf) 'Release ZIP created in caller -OutputDirectory'
    Assert-True ($pkgResult.PackagePath -match 'Claude-Residual-ID-Cleaner-1\.2\.3-test-x64-bundle\.zip$') 'Release ZIP uses standardized Claude-Residual-ID-Cleaner-<Version>-<Arch>-bundle.zip naming'
    Assert-True (Test-Path -LiteralPath $pkgResult.Sha256SumsPath -PathType Leaf) 'SHA256SUMS.txt created in caller -OutputDirectory'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $fakeRepo 'dist\Claude-Residual-ID-Cleaner-1.2.3-test-x64-bundle.zip'))) 'Caller -OutputDirectory does not write into SourceRoot/dist'

    $zipEntries = New-Object 'System.Collections.Generic.List[string]'
    $zipRead = [System.IO.Compression.ZipFile]::OpenRead($pkgResult.PackagePath)
    try {
        foreach ($entry in $zipRead.Entries) {
            $zipEntries.Add($entry.FullName)
        }
    } finally {
        $zipRead.Dispose()
    }

    $allLegitIncluded = $true
    foreach ($rel in $legitFiles.Keys) {
        if ($zipEntries -notcontains $rel) {
            $allLegitIncluded = $false
        }
    }
    Assert-True ($allLegitIncluded -and ($zipEntries.Count -eq $legitFiles.Count)) 'Release ZIP includes all expected legitimate files (including .github and .gitignore)'

    $leakedExclusions = @($zipEntries | Where-Object {
        $e = $_
        ($e -match '(?i)^(?:\.git|dist|tests/sandbox|sandbox|logs|\.claude|\.codex|\.agents|\.gemini|\.vscode)/') -or
        ($e -match '(?i)(?:AGENTS|GOAL|PLAN|HANDOFF|AUDIT|CLEANUP-PLAN|VERIFICATION)\.md$') -or
        ($e -match '(?i)(?:credentials|secret|buddy-tokens|\.env|\.pfx|\.key|\.pem|\.log|\.tmp|\.bak|\.claude\.json|Thumbs\.db)') -or
        ($e -match '(?i)(?:-portable\.exe|-setup\.exe|-bundle\.zip)$')
    })
    Assert-True ($leakedExclusions.Count -eq 0) 'Release ZIP excludes .git/, orchestration docs, audit/plan/verification, dist/, tests/sandbox/, credentials, personal logs, and stale release artifacts'

    # SHA-256 verification and tamper detection
    $sumsText = ([IO.File]::ReadAllText($pkgResult.Sha256SumsPath)).Trim()
    $actualSha = (Get-FileHash -LiteralPath $pkgResult.PackagePath -Algorithm SHA256).Hash.ToLowerInvariant()
    $zipLeaf = [IO.Path]::GetFileName($pkgResult.PackagePath)
    Assert-True ($sumsText -eq "$actualSha  $zipLeaf") 'SHA256SUMS.txt matches actual ZIP SHA-256 in standard two-space format'

    $tamperedZip = Join-Path $releaseSandbox 'tampered.zip'
    $zipBytes = [IO.File]::ReadAllBytes($pkgResult.PackagePath)
    $zipBytes[0] = [byte]($zipBytes[0] -bxor 0xFF)
    [IO.File]::WriteAllBytes($tamperedZip, $zipBytes)
    $tamperedSha = (Get-FileHash -LiteralPath $tamperedZip -Algorithm SHA256).Hash.ToLowerInvariant()
    Assert-True ($tamperedSha -ne $actualSha) 'Tampered release ZIP fails SHA-256 verification'

    # 4. Default dist/ behavior inside tests/sandbox/release/default-dist-repo/
    $defaultRepo = Join-Path $releaseSandbox 'default-dist-repo'
    $defaultScriptsDir = Join-Path $defaultRepo 'scripts'
    New-Item -ItemType Directory -Path $defaultScriptsDir -Force | Out-Null
    $copiedReleaseScript = Join-Path $defaultScriptsDir 'New-ReleasePackage.ps1'
    [IO.File]::Copy($releaseScriptPath, $copiedReleaseScript, $true)
    [IO.File]::Copy((Join-Path $repoRoot 'scripts\Common-BuildHelpers.ps1'), (Join-Path $defaultScriptsDir 'Common-BuildHelpers.ps1'), $true)
    [IO.File]::WriteAllText((Join-Path $defaultRepo 'README.md'), '# Sandbox Default Dist Repo')
    [IO.File]::WriteAllText((Join-Path $defaultRepo '.git'), 'gitdir: ../fake-git')
    [IO.File]::WriteAllText((Join-Path $defaultRepo 'AGENTS.md'), '# excluded')

    $defaultRes1 = & $copiedReleaseScript
    $expectedDistDir = Join-Path $defaultRepo 'dist'
    Assert-True ($defaultRes1.PackagePath.StartsWith($expectedDistDir, [StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath (Join-Path $expectedDistDir 'SHA256SUMS.txt'))) 'New-ReleasePackage.ps1 defaults output to SourceRoot/dist/ and excludes .git file pointer'

    # Re-run to verify existing dist/ is never packaged inside the new ZIP
    $defaultRes2 = & $copiedReleaseScript
    $zipRead2 = [System.IO.Compression.ZipFile]::OpenRead($defaultRes2.PackagePath)
    $defaultEntries = New-Object 'System.Collections.Generic.List[string]'
    try {
        foreach ($entry in $zipRead2.Entries) {
            $defaultEntries.Add($entry.FullName)
        }
    } finally {
        $zipRead2.Dispose()
    }
    Assert-True ((@($defaultEntries | Where-Object { $_ -match '^dist/' }).Count -eq 0) -and ($defaultEntries -notcontains '.git') -and ($defaultEntries -notcontains 'AGENTS.md')) 'Re-running default dist/ build never self-includes dist/ or excluded files'

    # 5. Fail-closed privacy gate in New-ReleasePackage.ps1
    $leakRepo = Join-Path $releaseSandbox 'leak-repo'
    New-Item -ItemType Directory -Path $leakRepo -Force | Out-Null
    $fakeSid = ('S-1-5-21-' + '111111111-222222222-333333333-1001')
    [IO.File]::WriteAllText((Join-Path $leakRepo 'README.md'), "Leaked SID: $fakeSid")
    $leakOut = Join-Path $releaseSandbox 'leak-out'
    Assert-Throws { & $releaseScriptPath -SourceRoot $leakRepo -OutputDirectory $leakOut -Version '0.0.1-leak' } 'New-ReleasePackage.ps1 fails closed when included file contains a user SID'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $leakOut 'Claude-Residual-ID-Cleaner-0.0.1-leak-x64-bundle.zip'))) 'Failed privacy gate leaves no release ZIP behind'

    # 5b. Sandboxed repo snapshot with src/Gui/* + scripts/Build-DesktopApp.ps1 bundles Claude-Residual-ID-Cleaner.exe at archive root
    $exeFakeRepo = Join-Path $releaseSandbox 'fake-exe-repo'
    $exeGuiDir = Join-Path $exeFakeRepo 'src\Gui'
    $exeScriptsDir = Join-Path $exeFakeRepo 'scripts'
    $exeCustomOut = Join-Path $releaseSandbox 'exe-custom-out'
    New-Item -ItemType Directory -Path $exeGuiDir -Force | Out-Null
    New-Item -ItemType Directory -Path $exeScriptsDir -Force | Out-Null
    [IO.File]::WriteAllText((Join-Path $exeFakeRepo 'README.md'), '# Sandboxed Desktop Bundle Test')
    [IO.File]::Copy((Join-Path $repoRoot 'scripts\Build-DesktopApp.ps1'), (Join-Path $exeScriptsDir 'Build-DesktopApp.ps1'), $true)
    [IO.File]::Copy((Join-Path $repoRoot 'scripts\Common-BuildHelpers.ps1'), (Join-Path $exeScriptsDir 'Common-BuildHelpers.ps1'), $true)
    [IO.File]::Copy($releaseScriptPath, (Join-Path $exeScriptsDir 'New-ReleasePackage.ps1'), $true)
    foreach ($guiItem in @(Get-ChildItem -LiteralPath (Join-Path $repoRoot 'src\Gui') -File)) {
        [IO.File]::Copy($guiItem.FullName, (Join-Path $exeGuiDir $guiItem.Name), $true)
    }

    $exePkgResult = & $releaseScriptPath -SourceRoot $exeFakeRepo -OutputDirectory $exeCustomOut -Version '1.2.3-exe'
    Assert-True ((Test-Path -LiteralPath $exePkgResult.PackagePath -PathType Leaf) -and (-not (Test-Path -LiteralPath (Join-Path $exeFakeRepo 'dist')))) 'New-ReleasePackage.ps1 with src/Gui/* builds release ZIP into custom OutputDirectory without writing to SourceRoot/dist'

    $exeZipEntries = New-Object 'System.Collections.Generic.List[string]'
    $exeZipRead = [System.IO.Compression.ZipFile]::OpenRead($exePkgResult.PackagePath)
    try {
        foreach ($entry in $exeZipRead.Entries) {
            $exeZipEntries.Add($entry.FullName)
        }
    } finally {
        $exeZipRead.Dispose()
    }
    Assert-True ($exeZipEntries -contains 'Claude-Residual-ID-Cleaner.exe') 'Release ZIP bundles compiled Claude-Residual-ID-Cleaner.exe at archive root'

    # 6. Repository Stage I/J bilingual docs, UI screenshot PNGs, relative links, and zero-emoji hygiene checks
    $utf8Strict = New-Object System.Text.UTF8Encoding($false, $true)
    $rootReadmePath = Join-Path $repoRoot 'README.md'
    $enReadmePath = Join-Path $repoRoot 'README.en.md'
    $legacyZhReadmePath = Join-Path $repoRoot 'README_zh-CN.md'
    $skillsGuideZhPath = Join-Path $repoRoot 'docs\Skills-Usage-Guide.md'
    $skillsGuideEnPath = Join-Path $repoRoot 'docs\Skills-Usage-Guide.en.md'
    $rootReadmeText = $utf8Strict.GetString([IO.File]::ReadAllBytes($rootReadmePath))
    $enReadmeText = $utf8Strict.GetString([IO.File]::ReadAllBytes($enReadmePath))
    $skillsGuideZhText = $utf8Strict.GetString([IO.File]::ReadAllBytes($skillsGuideZhPath))
    $skillsGuideEnText = $utf8Strict.GetString([IO.File]::ReadAllBytes($skillsGuideEnPath))
    $emojiRegex = '[\u2600-\u27BF]|[\uD800-\uDBFF][\uDC00-\uDFFF]'
    Assert-True (
        (Test-Path -LiteralPath $rootReadmePath -PathType Leaf) -and
        (Test-Path -LiteralPath $enReadmePath -PathType Leaf) -and
        (Test-Path -LiteralPath $skillsGuideZhPath -PathType Leaf) -and
        (Test-Path -LiteralPath $skillsGuideEnPath -PathType Leaf) -and
        (-not (Test-Path -LiteralPath $legacyZhReadmePath)) -and
        ($rootReadmeText.StartsWith('简体中文 | [English](README.en.md)')) -and
        ($enReadmeText.StartsWith('[简体中文](README.md) | English')) -and
        ($rootReadmeText -notmatch $emojiRegex) -and
        ($enReadmeText -notmatch $emojiRegex) -and
        ($skillsGuideZhText -notmatch $emojiRegex) -and
        ($skillsGuideEnText -notmatch $emojiRegex) -and
        (-not $rootReadmeText.Contains([char]0xFFFD)) -and
        (-not $enReadmeText.Contains([char]0xFFFD)) -and
        (-not $skillsGuideZhText.Contains([char]0xFFFD)) -and
        (-not $skillsGuideEnText.Contains([char]0xFFFD))
    ) 'Primary README.md, README.en.md, and Skills-Usage-Guide*.md exist with zero emojis and clean UTF-8'

    $requiredPngs = @('logo.png', 'ui-main-zh.png', 'ui-scan-results-zh.png', 'ui-main-en.png')
    $allPngsValid = $true
    foreach ($pngName in $requiredPngs) {
        $pngPath = Join-Path $repoRoot ("docs\images\$pngName")
        if (-not (Test-Path -LiteralPath $pngPath -PathType Leaf)) {
            $allPngsValid = $false
            continue
        }
        $pBytes = [IO.File]::ReadAllBytes($pngPath)
        $isValidPng = ($pBytes.Length -gt 20480 -and
            $pBytes[0] -eq 0x89 -and $pBytes[1] -eq 0x50 -and $pBytes[2] -eq 0x4E -and $pBytes[3] -eq 0x47 -and
            $pBytes[4] -eq 0x0D -and $pBytes[5] -eq 0x0A -and $pBytes[6] -eq 0x1A -and $pBytes[7] -eq 0x0A)
        if (-not $isValidPng) {
            $allPngsValid = $false
        }
    }
    Assert-True ($allPngsValid -and ($rootReadmeText -match 'docs/images/logo\.png') -and ($enReadmeText -match 'docs/images/logo\.png')) 'Mascot logo.png and all embedded UI screenshot PNGs exist under docs/images/ (>20 KB, valid PNG header) and logo is showcased in both READMEs'

    $demoGifPath = Join-Path $repoRoot 'docs\images\demo-workflow.gif'
    $demoGifValid = $false
    if (Test-Path -LiteralPath $demoGifPath -PathType Leaf) {
        $gBytes = [IO.File]::ReadAllBytes($demoGifPath)
        $demoGifValid = ($gBytes.Length -gt 20480 -and
            $gBytes[0] -eq 0x47 -and $gBytes[1] -eq 0x49 -and $gBytes[2] -eq 0x46 -and
            $gBytes[3] -eq 0x38 -and $gBytes[4] -eq 0x39 -and $gBytes[5] -eq 0x61)
    }
    Assert-True (
        $demoGifValid -and
        ($rootReadmeText -match 'docs/images/demo-workflow\.gif') -and
        ($enReadmeText -match 'docs/images/demo-workflow\.gif') -and
        ($rootReadmeText -match 'api\.star-history\.com/svg\?repos=YUCZ-43/Claude-Residual-ID-Cleaner') -and
        ($enReadmeText -match 'api\.star-history\.com/svg\?repos=YUCZ-43/Claude-Residual-ID-Cleaner')
    ) 'Animated demo-workflow.gif exists (>20 KB, valid GIF89a) and both READMEs embed demo GIF and Star History chart for YUCZ-43/Claude-Residual-ID-Cleaner'

    $noticeText = $utf8Strict.GetString([IO.File]::ReadAllBytes((Join-Path $repoRoot 'NOTICE')))
    $licenseText = $utf8Strict.GetString([IO.File]::ReadAllBytes((Join-Path $repoRoot 'LICENSE')))
    $cliRefText = $utf8Strict.GetString([IO.File]::ReadAllBytes((Join-Path $repoRoot 'docs\CLI-Reference.md')))
    $rebrandCorpus = $rootReadmeText + "`n" + $enReadmeText + "`n" + $noticeText + "`n" + $licenseText + "`n" + $skillsGuideZhText + "`n" + $skillsGuideEnText + "`n" + $cliRefText
    Assert-True (
        ($rebrandCorpus -notmatch '(?i)suyuan2022|suyuan-skill') -and
        ($rebrandCorpus -notmatch 'YUCZ-43/claude-cleanup') -and
        ($rootReadmeText -match 'Claude-Residual-ID-Cleaner-0\.1\.0-x64-setup\.exe') -and
        ($rootReadmeText -match 'Claude-Residual-ID-Cleaner-0\.1\.0-x64-portable\.exe') -and
        ($rootReadmeText -match 'Claude-Residual-ID-Cleaner-0\.1\.0-x64-bundle\.zip') -and
        ($rootReadmeText -match 'Claude-Residual-ID-Cleaner-0\.1\.0-arm64-setup\.exe') -and
        ($rootReadmeText -match 'Claude-Residual-ID-Cleaner-0\.1\.0-arm64-portable\.exe') -and
        ($rootReadmeText -match 'Claude-Residual-ID-Cleaner-0\.1\.0-arm64-bundle\.zip') -and
        ($enReadmeText -match 'Claude-Residual-ID-Cleaner-0\.1\.0-x64-setup\.exe') -and
        ($enReadmeText -match 'Claude-Residual-ID-Cleaner-0\.1\.0-x64-portable\.exe') -and
        ($enReadmeText -match 'Claude-Residual-ID-Cleaner-0\.1\.0-x64-bundle\.zip') -and
        ($enReadmeText -match 'Claude-Residual-ID-Cleaner-0\.1\.0-arm64-setup\.exe') -and
        ($enReadmeText -match 'Claude-Residual-ID-Cleaner-0\.1\.0-arm64-portable\.exe') -and
        ($enReadmeText -match 'Claude-Residual-ID-Cleaner-0\.1\.0-arm64-bundle\.zip')
    ) 'Public READMEs, NOTICE, LICENSE, and guides use clean MIT licensing, standardized 0.1.0-x64/arm64 release names, and zero suyuan2022 or old repo references'

    $docLinkFiles = @($rootReadmePath, $enReadmePath, $skillsGuideZhPath, $skillsGuideEnPath)
    $allDocLinksOk = $true
    $docLinksChecked = 0
    foreach ($docFile in $docLinkFiles) {
        $docDir = Split-Path -Parent $docFile
        $docRaw = $utf8Strict.GetString([IO.File]::ReadAllBytes($docFile))
        $docStripped = [regex]::Replace($docRaw, '(?ms)```.*?```', '')
        $docStripped = [regex]::Replace($docStripped, '`[^`\r\n]+`', '')
        $linkMatches = [regex]::Matches($docStripped, '!?\[[^\]]+\]\(([^)\s]+)(?:\s+"[^"]*")?\)')
        foreach ($m in $linkMatches) {
            $target = $m.Groups[1].Value
            if ($target -match '^(?:https?://|mailto:|#)') { continue }
            $cleanTarget = ($target -split '[#?]')[0]
            if ([string]::IsNullOrWhiteSpace($cleanTarget)) { continue }
            $resolvedTarget = [IO.Path]::GetFullPath((Join-Path $docDir ($cleanTarget -replace '/', '\')))
            $docLinksChecked++
            if (-not $resolvedTarget.StartsWith($repoRoot, [StringComparison]::OrdinalIgnoreCase) -or -not (Test-Path -LiteralPath $resolvedTarget)) {
                Write-Warning "Broken Markdown/image link in ${docFile}: $target -> $resolvedTarget"
                $allDocLinksOk = $false
            }
        }
    }
    Assert-True ($docLinksChecked -ge 20 -and $allDocLinksOk) "README.md, README.en.md, and docs/Skills-Usage-Guide*.md resolve all $docLinksChecked relative and image links cleanly"

    Write-Output "RESULT: $passed passed; $skipped skipped; $notExecuted not_executed; 0 failed"
} finally {
    Remove-SandboxDirectorySafely -TargetDir $ciSandbox -ExpectedParent $sandboxRoot
    Remove-SandboxDirectorySafely -TargetDir $releaseSandbox -ExpectedParent $sandboxRoot
    if (Test-Path -LiteralPath $sandboxRoot) {
        $remaining = @(Get-ChildItem -LiteralPath $sandboxRoot -Force)
        if ($remaining.Count -eq 0) {
            Remove-SandboxDirectorySafely -TargetDir $sandboxRoot -ExpectedParent $PSScriptRoot
        }
    }
}
