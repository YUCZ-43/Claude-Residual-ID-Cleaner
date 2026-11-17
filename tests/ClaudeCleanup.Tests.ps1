$ErrorActionPreference = 'Stop'
$scriptPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'ClaudeCleanup.ps1'
. $scriptPath

$sandbox = Join-Path $PSScriptRoot 'sandbox'
if (Test-Path -LiteralPath $sandbox) { throw "Test sandbox already exists: $sandbox" }
New-Item -ItemType Directory -Path $sandbox | Out-Null
$passed = 0
$skipped = 0
$notExecuted = 0
$failedList = New-Object 'System.Collections.Generic.List[string]'

function Assert-True([bool]$Condition, [string]$Name) {
    if (-not $Condition) {
        $script:failedList.Add($Name)
        throw "FAIL: $Name"
    }
    $script:passed++
    Write-Output "PASS: $Name"
}

function Assert-Throws([scriptblock]$Action, [string]$Name) {
    $threw = $false
    try { & $Action | Out-Null } catch { $threw = $true }
    Assert-True $threw $Name
}

function Unlock-Safely($stream) {
    if ($null -ne $stream) {
        try { $stream.Dispose() } catch {}
    }
}

$openStreams = New-Object 'System.Collections.Generic.List[System.IO.Stream]'

try {
    $allowed = Join-Path $sandbox 'allowed'
    New-Item -ItemType Directory -Path $allowed | Out-Null
    $file = Join-Path $allowed 'sample.txt'
    Set-Content -LiteralPath $file -Value 'sample'

    # 1. Path & boundary safety checks
    Assert-True ((Test-SafeTarget -Path $file -AllowedRoots @($allowed)).Allowed) 'exact in-scope file'
    Assert-Throws { Assert-AuthorizedPath -Path (Join-Path $sandbox 'outside.txt') -AllowedRoots @($allowed) } 'out-of-scope path rejected'
    Assert-Throws { Assert-AuthorizedPath -Path ([IO.Path]::GetPathRoot($sandbox)) -AllowedRoots @($allowed) } 'drive root rejected'
    Assert-Throws { Assert-AuthorizedPath -Path $sandbox -AllowedRoots @($allowed) } 'broad parent rejected'
    Assert-Throws { Assert-AuthorizedPath -Path (Join-Path $allowed '..\outside.txt') -AllowedRoots @($allowed) } 'relative traversal rejected'
    Assert-Throws { Assert-AuthorizedPath -Path ($file + ':ads') -AllowedRoots @($allowed) } 'alternate data stream path rejected'
    Assert-Throws { Assert-AuthorizedPath -Path ($file + ' ') -AllowedRoots @($allowed) } 'trailing space segment rejected'
    Assert-Throws { Assert-AuthorizedPath -Path ($file + '.') -AllowedRoots @($allowed) } 'trailing dot segment rejected'
    $windowsTarget = Join-Path $env:WINDIR 'Temp\claude-test.txt'
    Assert-Throws { Assert-AuthorizedPath -Path $windowsTarget -AllowedRoots @($windowsTarget) } 'Windows path rejected'
    $programTarget = Join-Path $env:ProgramFiles 'Claude\test.txt'
    Assert-Throws { Assert-AuthorizedPath -Path $programTarget -AllowedRoots @($programTarget) } 'Program Files path rejected'
    $codexTarget = Join-Path $env:USERPROFILE '.codex\test.txt'
    Assert-Throws { Assert-AuthorizedPath -Path $codexTarget -AllowedRoots @($codexTarget) } 'Codex path rejected'
    $geminiTarget = Join-Path $env:USERPROFILE '.gemini\test.txt'
    Assert-Throws { Assert-AuthorizedPath -Path $geminiTarget -AllowedRoots @($geminiTarget) } 'Gemini path rejected'
    Assert-Throws { Assert-AuthorizedPath -Path $env:USERPROFILE -AllowedRoots @($env:USERPROFILE) } 'USERPROFILE exact root rejected'
    Assert-Throws { Assert-AuthorizedPath -Path $env:APPDATA -AllowedRoots @($env:APPDATA) } 'APPDATA exact root rejected'
    Assert-Throws { Assert-AuthorizedPath -Path $scriptPath -AllowedRoots @($scriptPath) } 'project source path rejected'

    # 2. Code-level safety invariants (no Remove-Item, no RegDeleteKeyW, no CheckOwner $false)
    $fnDeleteTree = (Get-Command Invoke-HandleTreeDeletion).Definition
    $fnSafeRemoval = (Get-Command Invoke-SafeFileRemoval).Definition
    $fnSnapshot = (Get-Command Get-SafeTreeSnapshot).Definition
    $scriptText = [IO.File]::ReadAllText($scriptPath)
    Assert-True (($fnDeleteTree -notmatch 'Remove-Item') -and ($fnSafeRemoval -notmatch 'Remove-Item')) 'filesystem deletion has no Remove-Item fallback'
    Assert-True (($fnDeleteTree -notmatch '-CheckOwner\s+\$false') -and ($fnSnapshot -match '-RequireOwnerMatch')) 'tree inspection and deletion enforce owner matching on children'
    Assert-True (($scriptText -match 'NtDeleteKey\(') -and ($scriptText -notmatch 'RegDeleteKeyW\(')) 'registry deletion uses object-bound NtDeleteKey without path-based RegDeleteKeyW'

    # 3. Overlap guard
    Assert-True ([bool](Get-Command Assert-NoOverlappingTargets -ErrorAction SilentlyContinue)) 'overlap guard exists'
    $overlapping = @([pscustomobject]@{ Kind = 'Filesystem'; Path = $allowed },
        [pscustomobject]@{ Kind = 'Filesystem'; Path = $file })
    Assert-Throws { Assert-NoOverlappingTargets -Records $overlapping } 'overlapping deletion targets rejected'

    # 4. Finding 1: Explicit 3-state presence detection (Present / Absent / Unknown)
    Assert-True ((Get-TargetPresenceState -Path $file).State -eq 'Present') 'existing file reports Present'
    Assert-True ((Get-TargetPresenceState -Path (Join-Path $allowed 'missing-3state.txt')).State -eq 'Absent') 'missing file reports Absent'
    Assert-True ((Get-TargetPresenceState -Path '\\?\C:\invalid').State -eq 'Unknown') 'unsafe/inaccessible path reports Unknown rather than Absent'
    $origAppxFn = (Get-Item Function:\Get-ClaudeAppxPackage).ScriptBlock
    try {
        Set-Item Function:\Get-ClaudeAppxPackage -Value { throw [System.UnauthorizedAccessException]::new('Simulated Appx access denied') }
        $appxPres = Get-RecordPresenceState -Record ([pscustomobject]@{ Kind = 'AppxPackage'; Path = 'Claude_1.0.0.0_x64__pzs8sxrjxfjjc' })
        Assert-True ($appxPres.State -eq 'Unknown' -and -not [string]::IsNullOrEmpty($appxPres.Error)) 'access error in record presence probe reports Unknown rather than Absent'
    } finally {
        Set-Item Function:\Get-ClaudeAppxPackage -Value $origAppxFn
    }

    # Verify Unknown post-deletion state never produces VerifiedAbsent=true
    $unkFile = Join-Path $allowed 'unknown-post.txt'
    Set-Content -LiteralPath $unkFile -Value 'u'
    $origPresenceFn = (Get-Item Function:\Get-TargetPresenceState).ScriptBlock
    try {
        Set-Item Function:\Get-TargetPresenceState -Value {
            param([Parameter(Mandatory = $true)][string]$Path)
            if ($Path -like '*unknown-post.txt') {
                return [pscustomobject]@{ State = 'Unknown'; Error = 'Simulated access denied on presence check' }
            }
            return (& $script:origPresenceFnForTest $Path)
        }
        $script:origPresenceFnForTest = $origPresenceFn
        $unkRes = Invoke-SafeFileRemoval -Path $unkFile -AllowedRoots @($allowed) -ReturnFailureResult -Confirm:$false
        Assert-True ($unkRes.Status -eq 'Failed' -and $unkRes.PresenceState -eq 'Unknown' -and (-not $unkRes.VerifiedAbsent) -and ($null -eq $unkRes.RemainingExists)) 'Unknown presence never becomes VerifiedAbsent'
    } finally {
        Set-Item Function:\Get-TargetPresenceState -Value $origPresenceFn
    }
    Invoke-SafeFileRemoval -Path $unkFile -AllowedRoots @($allowed) -Confirm:$false | Out-Null

    # 5. Junction, dangling junction, parent-path substitution, and expanded symlink checks
    $junction = Join-Path $allowed 'junction'
    $outside = Join-Path $sandbox 'outside'
    New-Item -ItemType Directory -Path $outside | Out-Null
    $outsideSentinel = Join-Path $outside 'sentinel.txt'
    Set-Content -LiteralPath $outsideSentinel -Value 'keep-me'
    $junctionCreated = $false
    try {
        New-Item -ItemType Junction -Path $junction -Target $outside -ErrorAction Stop | Out-Null
        $junctionCreated = $true
    } catch {
        $skipped += 8
        Write-Output "SKIP: junction tests skipped because environment/sandbox blocked reparse point creation ($($_.Exception.Message))"
    }
    if ($junctionCreated) {
        Assert-Throws { Assert-TreeWithoutLinks -Path $allowed } 'nested junction rejected'
        Assert-Throws { Assert-AuthorizedPath -Path (Join-Path $junction 'secret.txt') -AllowedRoots @($allowed) } 'junction ancestor rejected'
        Assert-Throws { Invoke-SafeFileRemoval -Path $allowed -AllowedRoots @($allowed) -Confirm:$false } 'junction blocks parent removal'
        Assert-True (Test-Path -LiteralPath $outsideSentinel) 'outside sentinel untouched after junction rejection'
        [IO.Directory]::Delete($junction)

        # Broken/dangling junction
        $danglingTarget = Join-Path $sandbox 'gone-target'
        New-Item -ItemType Directory -Path $danglingTarget | Out-Null
        $danglingJunction = Join-Path $allowed 'dangling-junction'
        New-Item -ItemType Junction -Path $danglingJunction -Target $danglingTarget | Out-Null
        [IO.Directory]::Delete($danglingTarget)
        Assert-Throws { Assert-NoLinkAncestors -Path (Join-Path $danglingJunction 'child.txt') } 'dangling junction ancestor rejected'
        Assert-Throws { Assert-TreeWithoutLinks -Path $allowed } 'dangling nested junction rejected'
        [IO.Directory]::Delete($danglingJunction)

        # Parent-path substitution simulation
        $subParent = Join-Path $sandbox 'parent-swap'
        New-Item -ItemType Junction -Path $subParent -Target $outside | Out-Null
        Assert-Throws { Assert-AuthorizedPath -Path (Join-Path $subParent 'sentinel.txt') -AllowedRoots @($subParent) } 'parent-path substitution rejected'
        Assert-True (Test-Path -LiteralPath $outsideSentinel) 'parent-path substitution leaves outside target intact'
        [IO.Directory]::Delete($subParent)
    }

    # Expanded symlink tests (directory symlink, file symlink, dangling symlink, symlink ancestor)
    $dirSymlink = Join-Path $allowed 'dir-symlink'
    $fileSymlink = Join-Path $allowed 'file-symlink.txt'
    $danglingSymTarget = Join-Path $sandbox 'sym-gone.txt'
    $danglingSymlink = Join-Path $allowed 'dangling-symlink.txt'
    $symlinkSupported = $false
    try {
        New-Item -ItemType SymbolicLink -Path $dirSymlink -Target $outside -ErrorAction Stop | Out-Null
        $symlinkSupported = $true
    } catch {
        $skipped += 4
        Write-Output "SKIP: directory symlink test skipped (privilege required: $($_.Exception.Message))"
        Write-Output 'SKIP: file symlink test skipped (requires symlink creation privilege)'
        Write-Output 'SKIP: dangling symlink test skipped (requires symlink creation privilege)'
        Write-Output 'SKIP: symlink ancestor test skipped (requires symlink creation privilege)'
    }
    if ($symlinkSupported) {
        Assert-Throws { Assert-TreeWithoutLinks -Path $allowed } 'directory symlink rejected'
        Assert-Throws { Assert-AuthorizedPath -Path (Join-Path $dirSymlink 'sentinel.txt') -AllowedRoots @($allowed) } 'directory symlink ancestor rejected'
        [IO.Directory]::Delete($dirSymlink)

        New-Item -ItemType SymbolicLink -Path $fileSymlink -Target $outsideSentinel -ErrorAction Stop | Out-Null
        Assert-Throws { Invoke-SafeFileRemoval -Path $fileSymlink -AllowedRoots @($allowed) -Confirm:$false } 'file symlink rejected'
        [IO.File]::Delete($fileSymlink)

        Set-Content -LiteralPath $danglingSymTarget -Value 'temp'
        New-Item -ItemType SymbolicLink -Path $danglingSymlink -Target $danglingSymTarget -ErrorAction Stop | Out-Null
        [IO.File]::Delete($danglingSymTarget)
        Assert-Throws { Assert-NoLinkAncestors -Path $danglingSymlink } 'dangling file symlink rejected'
        [IO.File]::Delete($danglingSymlink)
    }

    # 6. Missing target, WhatIf, ReadOnly file, locked file, empty dir, and idempotency
    Assert-True ((Invoke-SafeFileRemoval -Path (Join-Path $allowed 'missing.txt') -AllowedRoots @($allowed) -Confirm:$false).Status -eq 'AlreadyAbsent') 'missing target idempotent'
    Invoke-SafeFileRemoval -Path $file -AllowedRoots @($allowed) -WhatIf | Out-Null
    Assert-True (Test-Path -LiteralPath $file) 'WhatIf preserves file'

    $roFile = Join-Path $allowed 'readonly.txt'
    Set-Content -LiteralPath $roFile -Value 'readonly-data'
    [IO.File]::SetAttributes($roFile, [IO.FileAttributes]::ReadOnly)
    Assert-True ((Invoke-SafeFileRemoval -Path $roFile -AllowedRoots @($allowed) -Confirm:$false).Status -eq 'Removed') 'ReadOnly file removed via handle'
    Assert-True (-not (Test-Path -LiteralPath $roFile)) 'ReadOnly file absent after removal'

    $manifest = Join-Path $sandbox 'manifest.md'
    Set-Content -LiteralPath $manifest -Value 'test manifest'
    $hash = (Get-FileHash -LiteralPath $manifest -Algorithm SHA256).Hash
    Assert-True (Test-ManifestAuthorization -ManifestPath $manifest -ApprovedHash $hash) 'matching manifest hash accepted'
    Assert-Throws { Assert-ManifestAuthorization -ManifestPath $manifest -ApprovedHash ('0' * 64) } 'wrong manifest hash rejected'
    Assert-Throws { Assert-ManifestAuthorization -ManifestPath $manifest -ApprovedHash '' } 'missing approval hash rejected'
    $priorWhatIf = $WhatIfPreference
    $WhatIfPreference = $true
    try {
        Assert-True (Test-ManifestAuthorization -ManifestPath $manifest -ApprovedHash $hash) 'WhatIf still validates matching manifest hash'
        Assert-Throws { Assert-ManifestAuthorization -ManifestPath $manifest -ApprovedHash ('0' * 64) } 'WhatIf still rejects wrong manifest hash'
    } finally { $WhatIfPreference = $priorWhatIf }

    # 7. Stale target detection: nested same-size edit & FileIndex swap with identical timestamps
    $nestedDir = Join-Path $allowed 'nested-tree'
    $nestedSub = Join-Path $nestedDir 'sub'
    New-Item -ItemType Directory -Path $nestedSub -Force | Out-Null
    $nestedFile = Join-Path $nestedSub 'payload.dat'
    [IO.File]::WriteAllText($nestedFile, 'AAAAA')
    $dirCand = Get-Candidate -Id 'sandbox-nested-dir' -Path $nestedDir -Category 'Test' -Policy 'AccountData'
    $dirRec = Get-ArtifactRecord $dirCand
    [IO.File]::WriteAllText($nestedFile, 'BBBBB')
    $bumped = (Get-Item -LiteralPath $nestedFile).LastWriteTimeUtc.AddSeconds(5)
    [IO.File]::SetLastWriteTimeUtc($nestedFile, $bumped)
    Assert-Throws { Assert-CurrentRecord -Record $dirRec -Candidates @($dirCand) } 'same-size nested modification detected via MaxLastWriteUtcTicks'

    $swapFile = Join-Path $allowed 'swap.txt'
    [IO.File]::WriteAllText($swapFile, '12345')
    $origCreation = [IO.File]::GetCreationTimeUtc($swapFile)
    $origWrite = [IO.File]::GetLastWriteTimeUtc($swapFile)
    $swapCand = Get-Candidate -Id 'sandbox-swap-file' -Path $swapFile -Category 'Test' -Policy 'AccountData'
    $swapRec = Get-ArtifactRecord $swapCand
    [IO.File]::Delete($swapFile)
    [IO.File]::WriteAllText($swapFile, '67890')
    [IO.File]::SetCreationTimeUtc($swapFile, $origCreation)
    [IO.File]::SetLastWriteTimeUtc($swapFile, $origWrite)
    Assert-Throws { Assert-CurrentRecord -Record $swapRec -Candidates @($swapCand) } 'replaced file with identical timestamps and size detected via FileIndex'

    # 8. Locked file & partial directory deletion detection
    $lockStream = [IO.File]::Open($file, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::None)
    $openStreams.Add($lockStream)
    try {
        Assert-Throws { Invoke-SafeFileRemoval -Path $file -AllowedRoots @($allowed) -Confirm:$false } 'locked file reports failure'
    } finally {
        Unlock-Safely $lockStream
        $openStreams.Remove($lockStream) | Out-Null
    }
    Assert-True (Test-Path -LiteralPath $file) 'failed deletion leaves file'
    Assert-True ((Invoke-SafeFileRemoval -Path $file -AllowedRoots @($allowed) -Confirm:$false).Status -eq 'Removed') 'approved sandbox file removed'
    Assert-True ((Invoke-SafeFileRemoval -Path $file -AllowedRoots @($allowed) -Confirm:$false).Status -eq 'AlreadyAbsent') 'second removal idempotent'

    $empty = Join-Path $allowed 'empty'
    New-Item -ItemType Directory -Path $empty | Out-Null
    Assert-True ((Invoke-SafeFileRemoval -Path $empty -AllowedRoots @($allowed) -Confirm:$false).Status -eq 'Removed') 'empty directory removed'

    $partialDir = Join-Path $allowed 'partial-dir'
    New-Item -ItemType Directory -Path $partialDir | Out-Null
    $pFile1 = Join-Path $partialDir 'a_unlocked.txt'
    $pFile2 = Join-Path $partialDir 'z_locked.txt'
    Set-Content -LiteralPath $pFile1 -Value 'a'
    Set-Content -LiteralPath $pFile2 -Value 'z'
    $pStream = [IO.File]::Open($pFile2, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::None)
    $openStreams.Add($pStream)
    try {
        $partialRes = Invoke-SafeFileRemoval -Path $partialDir -AllowedRoots @($partialDir) -ReturnFailureResult -Confirm:$false
        Assert-True ($partialRes.Status -eq 'Failed' -and $partialRes.PartialRemoval -and $partialRes.ItemsRemoved -ge 1 -and $partialRes.ItemsFailed -ge 1 -and $partialRes.RemainingExists) 'partial directory failure accurately detected'
    } finally {
        Unlock-Safely $pStream
        $openStreams.Remove($pStream) | Out-Null
    }

    # 9. End-to-end sandbox Plan -> Apply -> Tamper -> Replay -> PartialFailure -> Verify
    $e2eDir = Join-Path $sandbox 'e2e'
    New-Item -ItemType Directory -Path $e2eDir | Out-Null
    $accFile = Join-Path $e2eDir 'account.dat'
    $fullFile = Join-Path $e2eDir 'full.dat'
    $reviewFile = Join-Path $e2eDir 'review.dat'
    Set-Content -LiteralPath $accFile -Value 'acc'
    Set-Content -LiteralPath $fullFile -Value 'full'
    Set-Content -LiteralPath $reviewFile -Value 'rev'

    $cands = @(
        (Get-Candidate -Id 'sb-acc' -Path $accFile -Category 'Test' -Policy 'AccountData' -Decision 'Ready'),
        (Get-Candidate -Id 'sb-rev' -Path $reviewFile -Category 'Test' -Policy 'AccountData' -Decision 'ReviewOnly'),
        (Get-Candidate -Id 'sb-full' -Path $fullFile -Category 'Test' -Policy 'FullRemoval' -Decision 'Ready')
    )
    $sbPlan = Join-Path $e2eDir 'PLAN.md'
    $sbVer = Join-Path $e2eDir 'VERIFICATION.md'

    $planInfo = Invoke-CleanupPlan -PlanPath $sbPlan -CandidatesOverride $cands
    Assert-True ($planInfo.Entries -eq 3 -and $planInfo.Ready -eq 2 -and $planInfo.NonReady -eq 1) 'sandbox plan counts accurate'

    $tamperedPlan = Join-Path $e2eDir 'PLAN-TAMPERED.md'
    $origPlanText = [IO.File]::ReadAllText($sbPlan)
    [IO.File]::WriteAllText($tamperedPlan, ($origPlanText + "`n<!-- tampered -->"), (New-Object System.Text.UTF8Encoding($false)))
    Assert-Throws { Invoke-CleanupApply -Policy 'AccountData' -ApprovedManifestSha256 $planInfo.Sha256 -PlanPath $tamperedPlan -VerificationPath $sbVer -CandidatesOverride $cands -Confirm:$false } 'tampered manifest rejected'

    $dupPlan = Join-Path $e2eDir 'PLAN-DUP.md'
    $dupText = $origPlanText + "`r`n<!-- MANIFEST-JSON-BEGIN -->`r`n{}`r`n<!-- MANIFEST-JSON-END -->`r`n"
    [IO.File]::WriteAllText($dupPlan, $dupText, (New-Object System.Text.UTF8Encoding($false)))
    $dupHash = Get-Sha256 -Path $dupPlan
    Assert-Throws { Invoke-CleanupApply -Policy 'AccountData' -ApprovedManifestSha256 $dupHash -PlanPath $dupPlan -VerificationPath $sbVer -CandidatesOverride $cands -Confirm:$false } 'duplicate JSON block rejected'

    $v2Plan = Join-Path $e2eDir 'PLAN-V2.md'
    $v2Text = [regex]::Replace($origPlanText, '"SchemaVersion"\s*:\s*3', '"SchemaVersion": 2')
    [IO.File]::WriteAllText($v2Plan, $v2Text, (New-Object System.Text.UTF8Encoding($false)))
    $v2Hash = Get-Sha256 -Path $v2Plan
    Assert-Throws { Invoke-CleanupApply -Policy 'AccountData' -ApprovedManifestSha256 $v2Hash -PlanPath $v2Plan -VerificationPath $sbVer -CandidatesOverride $cands -Confirm:$false } 'SchemaVersion 2 manifest rejected by Apply'
    $v2Ver = Invoke-CleanupVerify -PlanPath $v2Plan -VerificationPath $sbVer -CandidatesOverride $cands
    Assert-True (-not [string]::IsNullOrEmpty($v2Ver.PlanError)) 'Verify reports SchemaVersion 2 warning without crashing'

    $escalatedPlan = Join-Path $e2eDir 'PLAN-ESCALATED.md'
    $escalatedText = [regex]::Replace($origPlanText, '"Decision"\s*:\s*"ReviewOnly"', '"Decision": "Ready"')
    [IO.File]::WriteAllText($escalatedPlan, $escalatedText, (New-Object System.Text.UTF8Encoding($false)))
    $escalatedHash = Get-Sha256 -Path $escalatedPlan
    Assert-Throws { Invoke-CleanupApply -Policy 'AccountData' -ApprovedManifestSha256 $escalatedHash -PlanPath $escalatedPlan -VerificationPath $sbVer -CandidatesOverride $cands -Confirm:$false } 'ReviewOnly promotion in manifest rejected'

    $previewOut = Invoke-CleanupApply -Policy 'AccountData' -ApprovedManifestSha256 $planInfo.Sha256 -PlanPath $sbPlan -VerificationPath $sbVer -CandidatesOverride $cands -WhatIf
    Assert-True ($previewOut.Outcome -eq 'PreviewOnly' -and (Test-Path -LiteralPath $accFile) -and (-not (Test-Path -LiteralPath $sbVer))) 'WhatIf does not consume authorization or delete target'

    $applyOut = Invoke-CleanupApply -Policy 'AccountData' -ApprovedManifestSha256 $planInfo.Sha256 -PlanPath $sbPlan -VerificationPath $sbVer -CandidatesOverride $cands -Confirm:$false
    $tmpLeftovers = @(Get-ChildItem -LiteralPath $e2eDir -Force | Where-Object { $_.Name -like 'VERIFICATION.md.tmp.*' -or $_.Name -like 'VERIFICATION.md.bak.*' })
    Assert-True ($applyOut.Outcome -eq 'Succeeded' -and (-not (Test-Path -LiteralPath $accFile)) -and (Test-Path -LiteralPath $fullFile) -and (Test-Path -LiteralPath $reviewFile) -and ($tmpLeftovers.Count -eq 0)) 'policy-scoped apply removes only approved policy Ready items with clean atomic ledger'

    Assert-Throws { Invoke-CleanupApply -Policy 'AccountData' -ApprovedManifestSha256 $planInfo.Sha256 -PlanPath $sbPlan -VerificationPath $sbVer -CandidatesOverride $cands -Confirm:$false } 'replay of consumed manifest hash (same policy) rejected'
    Assert-Throws { Invoke-CleanupApply -Policy 'FullRemoval' -ApprovedManifestSha256 $planInfo.Sha256 -PlanPath $sbPlan -VerificationPath $sbVer -CandidatesOverride $cands -Confirm:$false } 'replay of consumed manifest hash (cross-policy) rejected'

    # 10. Finding 2: Execution ledger corruption, truncation, and durable write failure checks
    $corruptDir = Join-Path $sandbox 'ledger-corrupt'
    New-Item -ItemType Directory -Path $corruptDir | Out-Null
    $truncLedger = Join-Path $corruptDir 'TRUNC.md'
    [IO.File]::WriteAllText($truncLedger, "# Execution verification log`r`n`r`n<!-- EXECUTION-LEDGER-BEGIN -->`r`n[{", (New-Object System.Text.UTF8Encoding($false)))
    Assert-Throws { Get-ExecutionLedgerEntries -VerificationPath $truncLedger } 'truncated ledger fails closed'

    $strippedLedger = Join-Path $corruptDir 'STRIPPED.md'
    [IO.File]::WriteAllText($strippedLedger, "# Execution verification log`r`n", (New-Object System.Text.UTF8Encoding($false)))
    Assert-Throws { Get-ExecutionLedgerEntries -VerificationPath $strippedLedger } 'ledger missing markers after execution header fails closed'

    $badSchemaLedger = Join-Path $corruptDir 'BADSCHEMA.md'
    [IO.File]::WriteAllText($badSchemaLedger, "<!-- EXECUTION-LEDGER-BEGIN -->`r`n[{`"PlanId`":`"not-a-guid`"}]`r`n<!-- EXECUTION-LEDGER-END -->", (New-Object System.Text.UTF8Encoding($false)))
    Assert-Throws { Get-ExecutionLedgerEntries -VerificationPath $badSchemaLedger } 'malformed ledger schema rejected'
    $corruptVerOut = Invoke-CleanupVerify -PlanPath $sbPlan -VerificationPath $badSchemaLedger -CandidatesOverride $cands
    Assert-True (-not [string]::IsNullOrEmpty($corruptVerOut.LedgerError)) 'Verify reports corrupted ledger error safely'

    # Simulate durable ledger failure on final commit: Apply must throw rather than claim success
    $durDir = Join-Path $sandbox 'durable-fail'
    New-Item -ItemType Directory -Path $durDir | Out-Null
    $durFile = Join-Path $durDir 'd.dat'
    Set-Content -LiteralPath $durFile -Value 'd'
    $durCands = @(Get-Candidate -Id 'dur-1' -Path $durFile -Category 'Test' -Policy 'AccountData' -Decision 'Ready')
    $durPlan = Join-Path $durDir 'PLAN.md'
    $durVer = Join-Path $durDir 'VERIFICATION.md'
    $durInfo = Invoke-CleanupPlan -PlanPath $durPlan -CandidatesOverride $durCands
    $origSaveLedger = (Get-Item Function:\Save-ExecutionLedgerEntry).ScriptBlock
    $script:origSaveLedgerForTest = $origSaveLedger
    try {
        Set-Item Function:\Save-ExecutionLedgerEntry -Value {
            param([string]$VerificationPath, [object]$Entry, [switch]$UpdateExisting)
            if ($UpdateExisting) { throw [System.IO.IOException]::new('Simulated disk write failure on ledger commit') }
            & $script:origSaveLedgerForTest -VerificationPath $VerificationPath -Entry $Entry
        }
        Assert-Throws { Invoke-CleanupApply -Policy 'AccountData' -ApprovedManifestSha256 $durInfo.Sha256 -PlanPath $durPlan -VerificationPath $durVer -CandidatesOverride $durCands -Confirm:$false } 'durable ledger commit failure prevents success claim'
    } finally {
        Set-Item Function:\Save-ExecutionLedgerEntry -Value $origSaveLedger
    }

    # 11. Finding 3: Non-destructive & mocked RegistryKey safety validation (no live HKCU writes)
    Assert-Throws { Invoke-RegistryLeafKeyDeletion -Path 'HKCU:\Software\NotClaude\FakeKey' -ExpectedDefaultValue '' } 'non-allowlisted registry key rejected'
    Assert-Throws { [ClaudeCleanup.NativeFs]::DeleteHkcuLeafKeySafely('Software\..\Evil', '') } 'malformed registry subkey path rejected'
    $regFakeKey = 'HKCU:\Software\Google\Chrome\NativeMessagingHosts\com.anthropic.claude_browser_extension'
    $regCand = Get-Candidate -Id 'mock-reg' -Path $regFakeKey -Category 'Browser native host registration' -Policy 'FullRemoval' -Kind 'RegistryKey' -Decision 'Ready'
    $regTestDir = Join-Path $sandbox 'reg-mock'
    New-Item -ItemType Directory -Path $regTestDir | Out-Null
    $regPlanPath = Join-Path $regTestDir 'PLAN.md'
    $regVerPath = Join-Path $regTestDir 'VERIFICATION.md'
    $regMockRecord = [pscustomobject]@{
        Id = 'mock-reg'; Path = $regFakeKey; Category = 'Browser native host registration'
        Policy = 'FullRemoval'; Kind = 'RegistryKey'; Decision = 'Ready'
        SizeBytes = $null; Entries = $null; LastWriteUtcTicks = $null
        MaxLastWriteUtcTicks = $null; VolumeSerialNumber = $null; FileIndex = $null
        Identity = 'C:\Program Files\Claude\fake.json'; Reason = ''; Warning = ''; Ownership = 'Confirmed Claude path or registration'
    }
    $regPlanSha = Write-PlanDocument -Records @($regMockRecord) -PlanPath $regPlanPath
    $origAssertCurrent = (Get-Item Function:\Assert-CurrentRecord).ScriptBlock
    $origRegDelete = (Get-Item Function:\Invoke-RegistryLeafKeyDeletion).ScriptBlock
    $origRecPresence = (Get-Item Function:\Get-RecordPresenceState).ScriptBlock
    try {
        Set-Item Function:\Assert-CurrentRecord -Value { param($Record, $Candidates) }
        Set-Item Function:\Invoke-RegistryLeafKeyDeletion -Value {
            param([string]$Path, [string]$ExpectedDefaultValue)
            $script:mockRegDeletedPath = $Path
        }
        Set-Item Function:\Get-RecordPresenceState -Value {
            param($Record)
            return [pscustomobject]@{ State = 'Absent'; Error = '' }
        }
        $mockRegOut = Invoke-CleanupApply -Policy 'FullRemoval' -ApprovedManifestSha256 $regPlanSha -PlanPath $regPlanPath -VerificationPath $regVerPath -CandidatesOverride @($regCand) -Confirm:$false
        Assert-True ($mockRegOut.Outcome -eq 'Succeeded' -and $script:mockRegDeletedPath -eq $regFakeKey -and $mockRegOut.Results[0].VerifiedAbsent) 'mocked registry deletion succeeds and verifies absence'

        # Mock post-delete Unknown state -> must fail closed
        $regPlanSha2 = Write-PlanDocument -Records @($regMockRecord) -PlanPath $regPlanPath
        Set-Item Function:\Get-RecordPresenceState -Value {
            param($Record)
            return [pscustomobject]@{ State = 'Unknown'; Error = 'Simulated registry query denied' }
        }
        Assert-Throws { Invoke-CleanupApply -Policy 'FullRemoval' -ApprovedManifestSha256 $regPlanSha2 -PlanPath $regPlanPath -VerificationPath $regVerPath -CandidatesOverride @($regCand) -Confirm:$false } 'mocked registry Unknown post-check fails closed'
    } finally {
        Set-Item Function:\Assert-CurrentRecord -Value $origAssertCurrent
        Set-Item Function:\Invoke-RegistryLeafKeyDeletion -Value $origRegDelete
        Set-Item Function:\Get-RecordPresenceState -Value $origRecPresence
    }

    $notExecuted += 4
    Write-Output 'NOT_EXECUTED: live HKCU leaf key creation and NtDeleteKey deletion (restricted by authorization)'
    Write-Output 'NOT_EXECUTED: live HKCU subkey-present rejection (restricted by authorization)'
    Write-Output 'NOT_EXECUTED: live HKCU registry symbolic-link rejection (restricted by authorization)'
    Write-Output 'NOT_EXECUTED: live mixed-ownership child file created by another Windows SID (ACL/ownership changes forbidden in sandbox)'

    # 12. Multi-target partial failure + Verify post-check
    $pfDir = Join-Path $sandbox 'pf'
    New-Item -ItemType Directory -Path $pfDir | Out-Null
    $t1 = Join-Path $pfDir 't1.txt'
    $t2 = Join-Path $pfDir 't2.txt'
    $t3 = Join-Path $pfDir 't3.txt'
    Set-Content -LiteralPath $t1 -Value '1'
    Set-Content -LiteralPath $t2 -Value '2'
    Set-Content -LiteralPath $t3 -Value '3'
    $pfCands = @(
        (Get-Candidate -Id 'pf-1' -Path $t1 -Category 'Test' -Policy 'FullRemoval' -Decision 'Ready'),
        (Get-Candidate -Id 'pf-2' -Path $t2 -Category 'Test' -Policy 'FullRemoval' -Decision 'Ready'),
        (Get-Candidate -Id 'pf-3' -Path $t3 -Category 'Test' -Policy 'FullRemoval' -Decision 'Ready')
    )
    $pfPlan = Join-Path $pfDir 'PLAN.md'
    $pfVer = Join-Path $pfDir 'VERIFICATION.md'
    $pfInfo = Invoke-CleanupPlan -PlanPath $pfPlan -CandidatesOverride $pfCands

    $pfLock = [IO.File]::Open($t2, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::None)
    $openStreams.Add($pfLock)
    $pfApplyEx = $null
    try {
        try {
            Invoke-CleanupApply -Policy 'FullRemoval' -ApprovedManifestSha256 $pfInfo.Sha256 -PlanPath $pfPlan -VerificationPath $pfVer -CandidatesOverride $pfCands -Confirm:$false | Out-Null
        } catch {
            $pfApplyEx = $_
        }
    } finally {
        Unlock-Safely $pfLock
        $openStreams.Remove($pfLock) | Out-Null
    }
    Assert-True ($null -ne $pfApplyEx -and $null -ne $pfApplyEx.Exception.Data['ApplyResult']) 'multi-target failure throws structured ApplyResult'
    $ar = $pfApplyEx.Exception.Data['ApplyResult']
    $s1 = @($ar.Results | Where-Object { $_.Id -eq 'pf-1' })[0].Status
    $s2 = @($ar.Results | Where-Object { $_.Id -eq 'pf-2' })[0].Status
    $s3 = @($ar.Results | Where-Object { $_.Id -eq 'pf-3' })[0].Status
    Assert-True ($ar.Outcome -eq 'PartialFailure' -and $s1 -eq 'Removed' -and $s2 -eq 'Failed' -and $s3 -eq 'NotExecuted') 'partial failure records Removed, Failed, and NotExecuted accurately'

    $verOut = Invoke-CleanupVerify -PlanPath $pfPlan -VerificationPath $pfVer -CandidatesOverride $pfCands
    $v1 = @($verOut.PlanChecks | Where-Object { $_.Id -eq 'pf-1' })[0]
    $v2 = @($verOut.PlanChecks | Where-Object { $_.Id -eq 'pf-2' })[0]
    $v3 = @($verOut.PlanChecks | Where-Object { $_.Id -eq 'pf-3' })[0]
    Assert-True (($v1.PresenceState -eq 'Absent') -and ($v2.PresenceState -eq 'Present') -and ($v3.PresenceState -eq 'Present') -and $verOut.LedgerEntries.Count -eq 1 -and $verOut.LedgerEntries[0].Outcome -eq 'PartialFailure') 'post-apply Verify reports exact 3-state presence and ledger outcome'

    # 13. Stage C: Windows coverage (npm, MSIX, VS Code, AppData classification, residuals, ACL diagnostics, JSON output)
    $npmPrefix = Join-Path $sandbox 'npm-prefix'
    $npmClaudeDir = Join-Path $npmPrefix 'node_modules\@anthropic-ai\claude-code'
    $npmUnrelatedDir = Join-Path $npmPrefix 'node_modules\unrelated-pkg'
    New-Item -ItemType Directory -Path $npmClaudeDir -Force | Out-Null
    New-Item -ItemType Directory -Path $npmUnrelatedDir -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $npmClaudeDir 'package.json') -Value '{"name":"@anthropic-ai/claude-code","version":"2.1.0"}'
    Set-Content -LiteralPath (Join-Path $npmUnrelatedDir 'package.json') -Value '{"name":"unrelated-pkg","version":"1.0.0"}'
    Set-Content -LiteralPath (Join-Path $npmPrefix 'claude.cmd') -Value '@echo off'

    $prevNpmPrefix = $env:NPM_CONFIG_PREFIX
    $env:NPM_CONFIG_PREFIX = $npmPrefix
    try {
        $npmInstalls = @(Get-NpmClaudePackageInstallations | Where-Object { $_.PrefixPath -eq $npmPrefix })
        Assert-True ($npmInstalls.Count -eq 1 -and $npmInstalls[0].Version -eq '2.1.0' -and $npmInstalls[0].SafeToUninstall -and ($npmInstalls[0].Shims -contains (Join-Path $npmPrefix 'claude.cmd'))) 'npm Claude Code installation detected without touching unrelated packages'
    } finally {
        $env:NPM_CONFIG_PREFIX = $prevNpmPrefix
    }
    Assert-Throws { Invoke-NpmClaudeUninstall -PackageName 'unrelated-pkg' -PrefixPath $npmPrefix } 'npm uninstall refuses unrelated package'

    # Mocked NpmPackage Plan -> Apply -> Verify preserves unrelated-pkg
    $npmWorkDir = Join-Path $sandbox 'npm-e2e'
    New-Item -ItemType Directory -Path $npmWorkDir -Force | Out-Null
    $npmPlanPath = Join-Path $npmWorkDir 'PLAN.md'
    $npmVerPath = Join-Path $npmWorkDir 'VERIFICATION.md'
    $npmCand = Get-Candidate -Id 'npm-sb' -Path $npmClaudeDir -Category 'npm Claude Code package' -Policy 'FullRemoval' -Kind 'NpmPackage' -Decision 'Ready' -Identity $npmPrefix
    $npmPlanInfo = Invoke-CleanupPlan -PlanPath $npmPlanPath -CandidatesOverride @($npmCand)
    $origGetNpm = (Get-Item Function:\Get-NpmCommand).ScriptBlock
    $origNpmUninstall = (Get-Item Function:\Invoke-NpmClaudeUninstall).ScriptBlock
    try {
        Set-Item Function:\Get-NpmCommand -Value { [pscustomobject]@{ Source = 'mock-npm.cmd' } }
        Set-Item Function:\Invoke-NpmClaudeUninstall -Value {
            param([string]$PackageName, [string]$PrefixPath)
            $script:mockNpmRemoved = "$PackageName|$PrefixPath"
            Invoke-SafeFileRemoval -Path (Join-Path $PrefixPath 'node_modules\@anthropic-ai\claude-code') -AllowedRoots @($PrefixPath) -Confirm:$false | Out-Null
        }
        $npmApplyOut = Invoke-CleanupApply -Policy 'FullRemoval' -ApprovedManifestSha256 $npmPlanInfo.Sha256 -PlanPath $npmPlanPath -VerificationPath $npmVerPath -CandidatesOverride @($npmCand) -Confirm:$false
        Assert-True ($npmApplyOut.Outcome -eq 'Succeeded' -and $script:mockNpmRemoved -eq "@anthropic-ai/claude-code|$npmPrefix" -and (Test-Path -LiteralPath (Join-Path $npmUnrelatedDir 'package.json'))) 'mocked npm uninstall succeeds and preserves unrelated npm packages'
    } finally {
        Set-Item Function:\Get-NpmCommand -Value $origGetNpm
        Set-Item Function:\Invoke-NpmClaudeUninstall -Value $origNpmUninstall
    }

    # Mocked MSIX AppxPackage uninstall + guard against unexpected package names
    Assert-Throws { Invoke-ClaudeAppxUninstall -PackageFullName 'FakeApp_1.0.0_x64__badid' } 'MSIX uninstall refuses non-Claude package'
    $msixWorkDir = Join-Path $sandbox 'msix-e2e'
    New-Item -ItemType Directory -Path $msixWorkDir -Force | Out-Null
    $msixPlanPath = Join-Path $msixWorkDir 'PLAN.md'
    $msixVerPath = Join-Path $msixWorkDir 'VERIFICATION.md'
    $msixName = 'Claude_5.11492.5.0_x64__pzs8sxrjxfjjc'
    $msixCand = Get-Candidate -Id 'appx-sb' -Path $msixName -Category 'Claude Desktop MSIX' -Policy 'FullRemoval' -Kind 'AppxPackage' -Decision 'Ready'
    $msixPlanInfo = Invoke-CleanupPlan -PlanPath $msixPlanPath -CandidatesOverride @($msixCand)
    $origGetAppx = (Get-Item Function:\Get-ClaudeAppxPackage).ScriptBlock
    $origAppxUninstall = (Get-Item Function:\Invoke-ClaudeAppxUninstall).ScriptBlock
    $script:mockAppxPresent = $true
    try {
        Set-Item Function:\Get-ClaudeAppxPackage -Value {
            if ($script:mockAppxPresent) {
                return @([pscustomobject]@{ PackageFullName = 'Claude_5.11492.5.0_x64__pzs8sxrjxfjjc'; PackageFamilyName = 'Claude_pzs8sxrjxfjjc'; Publisher = 'CN=Anthropic PBC' })
            }
            return @()
        }
        Set-Item Function:\Invoke-ClaudeAppxUninstall -Value {
            param([string]$PackageFullName)
            $script:mockAppxRemoved = $PackageFullName
            $script:mockAppxPresent = $false
        }
        $msixApplyOut = Invoke-CleanupApply -Policy 'FullRemoval' -ApprovedManifestSha256 $msixPlanInfo.Sha256 -PlanPath $msixPlanPath -VerificationPath $msixVerPath -CandidatesOverride @($msixCand) -Confirm:$false
        Assert-True ($msixApplyOut.Outcome -eq 'Succeeded' -and $script:mockAppxRemoved -eq $msixName -and $msixApplyOut.Results[0].VerifiedAbsent) 'mocked MSIX uninstall succeeds and verifies absence'

        # Verify fail-closed when package remains present after uninstall
        $script:mockAppxPresent = $true
        $msixPlanInfo2 = Invoke-CleanupPlan -PlanPath $msixPlanPath -CandidatesOverride @($msixCand)
        Set-Item Function:\Invoke-ClaudeAppxUninstall -Value { param([string]$PackageFullName) }
        Assert-Throws { Invoke-CleanupApply -Policy 'FullRemoval' -ApprovedManifestSha256 $msixPlanInfo2.Sha256 -PlanPath $msixPlanPath -VerificationPath $msixVerPath -CandidatesOverride @($msixCand) -Confirm:$false } 'MSIX uninstall fails closed if package stays present'
    } finally {
        Set-Item Function:\Get-ClaudeAppxPackage -Value $origGetAppx
        Set-Item Function:\Invoke-ClaudeAppxUninstall -Value $origAppxUninstall
    }

    # Mocked VS Code extension CLI uninstall + guard
    Assert-Throws { Invoke-VsCodeExtensionUninstall -ExtensionId 'unrelated.extension' } 'VS Code uninstall refuses unrelated extension ID'
    $vsSandboxRoot = Join-Path $sandbox 'vscode-ext-root'
    $vsExtDir = Join-Path $vsSandboxRoot 'anthropic.claude-code-2.1.325-win32-x64'
    New-Item -ItemType Directory -Path $vsExtDir -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $vsExtDir 'package.json') -Value '{"publisher":"anthropic","name":"claude-code","version":"2.1.325"}'
    $vsWorkDir = Join-Path $sandbox 'vscode-e2e'
    New-Item -ItemType Directory -Path $vsWorkDir -Force | Out-Null
    $vsPlanPath = Join-Path $vsWorkDir 'PLAN.md'
    $vsVerPath = Join-Path $vsWorkDir 'VERIFICATION.md'
    $vsCand = Get-Candidate -Id 'vscode-cli-sb' -Path 'anthropic.claude-code' -Category 'VS Code extension (CLI)' -Policy 'FullRemoval' -Kind 'VsCodeExtension' -Decision 'Ready' -Identity $vsSandboxRoot
    $vsPlanInfo = Invoke-CleanupPlan -PlanPath $vsPlanPath -CandidatesOverride @($vsCand)
    $origGetCode = (Get-Item Function:\Get-VsCodeCliCommand).ScriptBlock
    $origVsUninstall = (Get-Item Function:\Invoke-VsCodeExtensionUninstall).ScriptBlock
    try {
        Set-Item Function:\Get-VsCodeCliCommand -Value { [pscustomobject]@{ Source = 'mock-code.cmd' } }
        Set-Item Function:\Invoke-VsCodeExtensionUninstall -Value {
            param([string]$ExtensionId)
            $script:mockVsRemoved = $ExtensionId
            Invoke-SafeFileRemoval -Path (Join-Path $vsSandboxRoot 'anthropic.claude-code-2.1.325-win32-x64') -AllowedRoots @($vsSandboxRoot) -Confirm:$false | Out-Null
        }
        $vsApplyOut = Invoke-CleanupApply -Policy 'FullRemoval' -ApprovedManifestSha256 $vsPlanInfo.Sha256 -PlanPath $vsPlanPath -VerificationPath $vsVerPath -CandidatesOverride @($vsCand) -Confirm:$false
        Assert-True ($vsApplyOut.Outcome -eq 'Succeeded' -and $script:mockVsRemoved -eq 'anthropic.claude-code' -and $vsApplyOut.Results[0].VerifiedAbsent) 'mocked VS Code extension CLI uninstall succeeds and verifies absence'
    } finally {
        Set-Item Function:\Get-VsCodeCliCommand -Value $origGetCode
        Set-Item Function:\Invoke-VsCodeExtensionUninstall -Value $origVsUninstall
    }

    # Read-only ACL diagnostics, AppData classification, residual summary (no env secret values), and structured JSON report
    $aclOk = Get-PathAclDiagnostics -Path $allowed
    $aclAbsent = Get-PathAclDiagnostics -Path (Join-Path $sandbox 'no-such-acl-dir')
    $aclBad = Get-PathAclDiagnostics -Path '\\?\C:\invalid'
    Assert-True ($aclOk.Status -eq 'Ok' -and $aclOk.IsCurrentUserOwner -and (-not $aclOk.IsBuiltinAdminOwned) -and $aclAbsent.Status -eq 'Absent' -and $aclBad.Status -eq 'AccessDenied') 'read-only ACL diagnostics classify Ok, Absent, and AccessDenied'

    if ($junctionCreated) {
        $aclJunc = Join-Path $sandbox 'acl-junction'
        New-Item -ItemType Junction -Path $aclJunc -Target $outside -ErrorAction Stop | Out-Null
        try {
            $aclReparse = Get-PathAclDiagnostics -Path $aclJunc
            Assert-True ($aclReparse.Status -eq 'ReparseBlocked') 'read-only ACL diagnostics identify reparse points safely'
        } finally {
            [IO.Directory]::Delete($aclJunc)
        }
    } else {
        $skipped++
        Write-Output 'SKIP: ACL reparse-point diagnostic test skipped because junction creation was blocked'
    }

    $appClass = @(Get-AppDataClassification)
    $validRoles = @('Cache', 'Diagnostics', 'AuthReview', 'UserSessionOrMixed', 'AmbiguousLegacy')
    $rolesValid = (@($appClass | Where-Object { $_.Role -notin $validRoles }).Count -eq 0)
    Assert-True $rolesValid 'AppData classification assigns only valid structured roles'

    $auditJsonObj = Get-StructuredAuditReport | ConvertTo-Json -Depth 10 | ConvertFrom-Json
    $envVarsNoValues = (@($auditJsonObj.Summary.EnvironmentVariableNames | Where-Object { $_.PSObject.Properties['Value'] }).Count -eq 0)
    $hasResidualProp = ($null -ne $auditJsonObj.Summary.PSObject.Properties['ResidualAccountIds'])
    Assert-True ($auditJsonObj.SchemaVersion -eq 3 -and $auditJsonObj.Mode -eq 'Audit' -and $null -ne $auditJsonObj.Summary -and $envVarsNoValues -and $hasResidualProp) 'structured JSON audit report valid, exposes ResidualAccountIds, and omits secret env values'

    # Sandboxed non-secret Account/Org/Device UUID extraction (strictly omits OAuth tokens, refresh tokens, session keys, and emails)
    $acctMockRoot = Join-Path $sandbox 'account-meta-mock'
    $mockCliDir = Join-Path $acctMockRoot '.claude'
    $mockDeskDir = Join-Path $acctMockRoot 'AppDataClaude'
    New-Item -ItemType Directory -Path $mockCliDir, $mockDeskDir -Force | Out-Null
    $mockCliJson = Join-Path $acctMockRoot '.claude.json'
    $mockCredJson = Join-Path $mockCliDir '.credentials.json'
    $mockDeskPref = Join-Path $mockDeskDir 'Preferences'
    $fakeSecretAccess = ('sk-' + 'ant-' + 'oat01-mock-secret-value-99999')
    $fakeRefreshVal = 'mock-refresh-secret-value-88888'
    $fakeSessionVal = ('sk-' + 'ant-' + 'sid01-mock-session-key-77777')

    $cliMockPayload = [ordered]@{
        userID = 'usr-mock-001122334455'
        anonymousId = 'anon-mock-device-667788'
        sessionKey = $fakeSessionVal
        oauthAccount = [ordered]@{
            accountUuid = '11111111-2222-4333-8444-555555555555'
            organizationUuid = 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee'
            emailAddress = 'mock-user@example.invalid'
        }
        claudeAiOauth = [ordered]@{
            accessToken = $fakeSecretAccess
            refreshToken = $fakeRefreshVal
        }
    } | ConvertTo-Json -Depth 6
    [IO.File]::WriteAllText($mockCliJson, $cliMockPayload, (New-Object System.Text.UTF8Encoding($false)))

    $credMockPayload = [ordered]@{
        claudeAiOauth = [ordered]@{
            accessToken = $fakeSecretAccess
            accountUuid = '99999999-9999-4999-8999-999999999999'
        }
    } | ConvertTo-Json -Depth 4
    [IO.File]::WriteAllText($mockCredJson, $credMockPayload, (New-Object System.Text.UTF8Encoding($false)))

    $deskMockPayload = [ordered]@{
        deviceId = 'desk-dev-mock-445566'
        authToken = $fakeSecretAccess
    } | ConvertTo-Json -Depth 4
    [IO.File]::WriteAllText($mockDeskPref, $deskMockPayload, (New-Object System.Text.UTF8Encoding($false)))

    $extractedIds = @(Get-ClaudeResidualAccountMetadata -ClaudeCliConfigPath $mockCliJson -ClaudeCliDir $mockCliDir -ClaudeDesktopDir $mockDeskDir)
    $extractedVals = @($extractedIds | ForEach-Object { $_.Value })
    $extractedJoined = ($extractedIds | ConvertTo-Json -Depth 4)
    $noSecretsExtracted = (-not $extractedJoined.Contains($fakeSecretAccess)) -and
                          (-not $extractedJoined.Contains($fakeRefreshVal)) -and
                          (-not $extractedJoined.Contains($fakeSessionVal)) -and
                          (-not $extractedJoined.Contains('mock-user@example.invalid')) -and
                          (-not $extractedJoined.Contains('99999999-9999-4999-8999-999999999999'))
    Assert-True (
        ($extractedIds.Count -eq 5) -and
        ($extractedVals -contains '11111111-2222-4333-8444-555555555555') -and
        ($extractedVals -contains 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee') -and
        ($extractedVals -contains 'usr-mock-001122334455') -and
        ($extractedVals -contains 'anon-mock-device-667788') -and
        ($extractedVals -contains 'desk-dev-mock-445566') -and
        $noSecretsExtracted
    ) 'Get-ClaudeResidualAccountMetadata extracts only non-secret account/org/user/device UUIDs and never reads .credentials.json or tokens'

    $mockAuditReport = [pscustomobject]@{
        SchemaVersion = 3
        Mode = 'Audit'
        GeneratedUtc = [DateTime]::UtcNow.ToString('o')
        PowerShellVersion = $PSVersionTable.PSVersion.ToString()
        Summary = [pscustomobject]@{
            ResidualAccountIds = $extractedIds
        }
        EnvironmentLines = @('Sandbox mock summary line')
        Inventory = @()
    }
    $mockAuditMdPath = Join-Path $sandbox 'AUDIT-UUID-MOCK.md'
    $null = Write-AuditReportDocument -AuditPath $mockAuditMdPath -Lang 'zh-CN' -StructuredReport $mockAuditReport
    $mockAuditMdText = [IO.File]::ReadAllText($mockAuditMdPath, [System.Text.Encoding]::UTF8)
    Assert-True (
        ($mockAuditMdText -match '11111111-2222-4333-8444-555555555555') -and
        ($mockAuditMdText -match 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee') -and
        (-not $mockAuditMdText.Contains($fakeSecretAccess)) -and
        (-not $mockAuditMdText.Contains($fakeRefreshVal))
    ) 'AUDIT.md report includes extracted non-secret Account/Org UUIDs cleanly and contains zero secrets'

    # Process detection (strict self/cleaner exclusion) and -CloseRunningProcesses safety flow
    $mockProcList = @(
        [pscustomobject]@{ Id = 1001; ProcessName = 'Claude-Residual-ID-Cleaner'; Path = 'C:\MockApps\claude-cleanup\Claude-Residual-ID-Cleaner.exe' },
        [pscustomobject]@{ Id = 1002; ProcessName = 'Claude-Residual-ID-Cleaner-Setup'; Path = 'C:\MockApps\Downloads\Claude-Residual-ID-Cleaner-Setup.exe' },
        [pscustomobject]@{ Id = 1003; ProcessName = 'ClaudeCleanupLauncher'; Path = 'C:\MockApps\claude-cleanup\ClaudeCleanupLauncher.exe' },
        [pscustomobject]@{ Id = 1004; ProcessName = 'claude'; Path = 'C:\MockApps\Claude\claude.exe' },
        [pscustomobject]@{ Id = 1005; ProcessName = 'claude'; Path = 'C:\MockApps\Claude\claude.exe' },
        [pscustomobject]@{ Id = 1006; ProcessName = 'claude'; Path = 'C:\MockApps\Claude\claude.exe' },
        [pscustomobject]@{ Id = 1007; ProcessName = 'claude'; Path = (Join-Path (Split-Path -Parent $PSScriptRoot) 'dist\claude.exe') },
        [pscustomobject]@{ Id = 1008; ProcessName = 'pwsh'; Path = 'C:\Program Files\PowerShell\7\pwsh.exe' },
        [pscustomobject]@{ Id = 2001; ProcessName = 'Claude'; Path = 'C:\MockApps\AnthropicClaude\Claude.exe' },
        [pscustomobject]@{ Id = 2002; ProcessName = 'claude-code'; Path = 'C:\MockApps\ClaudeCode\claude-code.exe' },
        [pscustomobject]@{ Id = 2003; ProcessName = 'chrome-native-host'; Path = 'C:\MockApps\AnthropicClaude\chrome-native-host.exe'; CommandLine = '"C:\MockApps\AnthropicClaude\chrome-native-host.exe" chrome-extension://fcoeoabgfenejglbffodgkkbkcdhcgfn/' },
        [pscustomobject]@{ Id = 2004; ProcessName = 'chrome-native-host'; Path = 'C:\MockApps\OtherVendor\native-host.exe'; CommandLine = '"C:\MockApps\OtherVendor\native-host.exe" com.anthropic.claude_browser_extension' },
        [pscustomobject]@{ Id = 2005; ProcessName = 'chrome-native-host'; Path = 'C:\MockApps\1Password\chrome-native-host.exe'; CommandLine = '"C:\MockApps\1Password\chrome-native-host.exe" chrome-extension://aeblfdkhhhdcdjpifhhbdiojplfjncoa/' }
    )
    $detectedProcs = @(Get-ClaudeProcess -ProcessesOverride $mockProcList -SelfPid 1004 -ParentPidOverride 1005 -GrandParentPidOverride 1006)
    $detectedIds = @($detectedProcs | ForEach-Object { [int]$_.Id })
    Assert-True (
        ($detectedProcs.Count -eq 4) -and
        ($detectedIds -contains 2001) -and
        ($detectedIds -contains 2002) -and
        ($detectedIds -contains 2003) -and
        ($detectedIds -contains 2004) -and
        (-not ($detectedIds -contains 2005)) -and
        (-not ($detectedIds -contains 1001)) -and
        (-not ($detectedIds -contains 1002)) -and
        (-not ($detectedIds -contains 1003)) -and
        (-not ($detectedIds -contains 1004)) -and
        (-not ($detectedIds -contains 1005)) -and
        (-not ($detectedIds -contains 1006)) -and
        (-not ($detectedIds -contains 1007))
    ) 'Get-ClaudeProcess detects Claude and Claude-owned chrome-native-host.exe while excluding cleaner binaries, unrelated native hosts, self/parent/grandparent PIDs, and project paths'

    # Sandboxed Get-CurrentCandidates verification for AccountData coverage
    $candProfile = Join-Path $sandbox 'cand-profile'
    $candRoaming = Join-Path $candProfile 'AppData\Roaming'
    $candLocal = Join-Path $candProfile 'AppData\Local'
    $candCliDir = Join-Path $candProfile '.claude'
    $candDeskRoaming = Join-Path $candRoaming 'Claude'
    New-Item -ItemType Directory -Path $candCliDir, $candDeskRoaming, (Join-Path $candLocal 'Claude\logs'), (Join-Path $candDeskRoaming 'Cache'), (Join-Path $candDeskRoaming 'Network'), (Join-Path $candDeskRoaming 'Local Storage'), (Join-Path $candDeskRoaming 'IndexedDB') -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $candCliDir '.credentials.json') -Value '{}'
    Set-Content -LiteralPath (Join-Path $candCliDir 'mcp-needs-auth-cache.json') -Value '{}'
    Set-Content -LiteralPath (Join-Path $candCliDir 'stats-cache.json') -Value '{}'
    Set-Content -LiteralPath (Join-Path $candProfile '.claude.json') -Value '{}'
    Set-Content -LiteralPath (Join-Path $candDeskRoaming 'buddy-tokens.json') -Value '{}'
    Set-Content -LiteralPath (Join-Path $candDeskRoaming 'Preferences') -Value '{}'
    $origProfile = $env:USERPROFILE; $origAppData = $env:APPDATA; $origLocalAppData = $env:LOCALAPPDATA
    try {
        $env:USERPROFILE = $candProfile; $env:APPDATA = $candRoaming; $env:LOCALAPPDATA = $candLocal
        $sbCands = @(Get-CurrentCandidates)
        $accReadyIds = @($sbCands | Where-Object { $_.Policy -eq 'AccountData' -and $_.Decision -eq 'Ready' } | ForEach-Object { $_.Id })
        $fullGlobalIds = @($sbCands | Where-Object { $_.Policy -eq 'FullRemoval' -and $_.Id -eq 'full-cli-global' })
        Assert-True (
            ($accReadyIds -contains 'cli-credentials') -and
            ($accReadyIds -contains 'cli-auth-cache') -and
            ($accReadyIds -contains 'cli-stats') -and
            ($accReadyIds -contains 'cli-global') -and
            ($accReadyIds -contains 'desktop-buddy-tokens') -and
            ($accReadyIds -contains 'desktop-preferences') -and
            ($accReadyIds -contains 'desktop-network') -and
            ($accReadyIds -contains 'desktop-local-storage') -and
            ($accReadyIds -contains 'desktop-indexeddb') -and
            ($fullGlobalIds.Count -eq 1)
        ) 'Get-CurrentCandidates classifies all Claude account/UUID/token/cache residuals (including buddy-tokens.json and .claude.json) as Ready under AccountData'
    } finally {
        $env:USERPROFILE = $origProfile; $env:APPDATA = $origAppData; $env:LOCALAPPDATA = $origLocalAppData
    }

    $procTestDir = Join-Path $sandbox 'proc-close-e2e'
    $procTargetDir = Join-Path $procTestDir 'target'
    New-Item -ItemType Directory -Path $procTargetDir -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $procTargetDir 'cache.txt') -Value 'mock-cache'
    $procPlanPath = Join-Path $procTestDir 'PLAN.md'
    $procVerPath = Join-Path $procTestDir 'VERIFICATION.md'
    $procCand = Get-Candidate -Id 'proc-sb-file' -Path $procTargetDir -Category 'Cache' -Policy 'AccountData' -Kind 'Filesystem' -Decision 'Ready' -AllowedRoots @($procTestDir)
    $procPlanInfo = Invoke-CleanupPlan -PlanPath $procPlanPath -CandidatesOverride @($procCand)
    $liveClaudeMock = @([pscustomobject]@{ Id = 2001; ProcessName = 'Claude'; Path = 'C:\MockApps\AnthropicClaude\Claude.exe' })

    $threwRunning = $false
    $runningErrMsg = ''
    try {
        $null = Invoke-CleanupApply -Policy 'AccountData' -ApprovedManifestSha256 $procPlanInfo.Sha256 -PlanPath $procPlanPath -VerificationPath $procVerPath -CandidatesOverride @($procCand) -ProcessesOverride $liveClaudeMock -WhatIf
    } catch {
        $threwRunning = $true
        $runningErrMsg = $_.Exception.Message
    }
    Assert-True ($threwRunning -and $runningErrMsg -match 'Claude is running\. Processes: Claude \(PID=2001\)') 'Invoke-CleanupApply rejects running Claude processes with itemized PID list when -CloseRunningProcesses is omitted'

    $script:stoppedMockPids = New-Object 'System.Collections.Generic.List[int]'
    $procPreviewOut = Invoke-CleanupApply -Policy 'AccountData' -ApprovedManifestSha256 $procPlanInfo.Sha256 -PlanPath $procPlanPath -VerificationPath $procVerPath -CandidatesOverride @($procCand) -ProcessesOverride $liveClaudeMock -CloseRunningProcesses -StopProcessAction { param($p) [void]$script:stoppedMockPids.Add([int]$p.Id) } -WhatIf
    Assert-True ($procPreviewOut.Outcome -eq 'PreviewOnly' -and $script:stoppedMockPids.Count -eq 0 -and (Test-Path -LiteralPath $procTargetDir)) '-CloseRunningProcesses under -WhatIf previews cleanly without terminating processes or deleting targets'

    $procApplyOut = Invoke-CleanupApply -Policy 'AccountData' -ApprovedManifestSha256 $procPlanInfo.Sha256 -PlanPath $procPlanPath -VerificationPath $procVerPath -CandidatesOverride @($procCand) -ProcessesOverride $liveClaudeMock -CloseRunningProcesses -StopProcessAction { param($p) [void]$script:stoppedMockPids.Add([int]$p.Id) } -Confirm:$false
    Assert-True ($procApplyOut.Outcome -eq 'Succeeded' -and $script:stoppedMockPids.Count -eq 1 -and $script:stoppedMockPids[0] -eq 2001 -and $procApplyOut.Results[0].VerifiedAbsent -and (-not (Test-Path -LiteralPath $procTargetDir))) '-CloseRunningProcesses with confirmed -Apply invokes process shutdown once, deletes target, and verifies absence'

    $notExecuted += 3
    Write-Output 'NOT_EXECUTED: live npm uninstall -g @anthropic-ai/claude-code (mocked only)'
    Write-Output 'NOT_EXECUTED: live code --uninstall-extension anthropic.claude-code (mocked only)'
    Write-Output 'NOT_EXECUTED: live Remove-AppxPackage Claude Desktop MSIX (mocked only)'

    Write-Output "RESULT: $passed passed; $skipped skipped; $notExecuted not_executed; 0 failed"
} finally {
    foreach ($s in $openStreams) { Unlock-Safely $s }
    if (Test-Path -LiteralPath $sandbox) {
        try {
            Invoke-SafeFileRemoval -Path $sandbox -AllowedRoots @($sandbox) -Confirm:$false | Out-Null
        } catch {
            Write-Warning "Sandbox retained for manual review: $sandbox ($($_.Exception.Message))"
        }
    }
}
