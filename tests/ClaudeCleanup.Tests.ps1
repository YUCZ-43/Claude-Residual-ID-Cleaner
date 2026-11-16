$ErrorActionPreference = 'Stop'
$scriptPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'ClaudeCleanup.ps1'
. $scriptPath

$sandbox = Join-Path $PSScriptRoot 'sandbox'
if (Test-Path -LiteralPath $sandbox) { throw "Test sandbox already exists: $sandbox" }
New-Item -ItemType Directory -Path $sandbox | Out-Null
$passed = 0
$skipped = 0

function Assert-True([bool]$Condition, [string]$Name) {
    if (-not $Condition) { throw "FAIL: $Name" }
    $script:passed++
    Write-Output "PASS: $Name"
}
function Assert-Throws([scriptblock]$Action, [string]$Name) {
    $threw = $false
    try { & $Action | Out-Null } catch { $threw = $true }
    Assert-True $threw $Name
}

try {
    $allowed = Join-Path $sandbox 'allowed'
    New-Item -ItemType Directory -Path $allowed | Out-Null
    $file = Join-Path $allowed 'sample.txt'
    Set-Content -LiteralPath $file -Value 'sample'

    Assert-True ((Test-SafeTarget -Path $file -AllowedRoots @($allowed)).Allowed) 'exact in-scope file'
    Assert-Throws { Assert-AuthorizedPath -Path (Join-Path $sandbox 'outside.txt') -AllowedRoots @($allowed) } 'out-of-scope path rejected'
    Assert-Throws { Assert-AuthorizedPath -Path ([IO.Path]::GetPathRoot($sandbox)) -AllowedRoots @($allowed) } 'drive root rejected'
    Assert-Throws { Assert-AuthorizedPath -Path $sandbox -AllowedRoots @($allowed) } 'broad parent rejected'
    Assert-Throws { Assert-AuthorizedPath -Path (Join-Path $allowed '..\outside.txt') -AllowedRoots @($allowed) } 'relative traversal rejected'
    $windowsTarget = Join-Path $env:WINDIR 'Temp\claude-test.txt'
    Assert-Throws { Assert-AuthorizedPath -Path $windowsTarget -AllowedRoots @($windowsTarget) } 'Windows path rejected'
    $programTarget = Join-Path $env:ProgramFiles 'Claude\test.txt'
    Assert-Throws { Assert-AuthorizedPath -Path $programTarget -AllowedRoots @($programTarget) } 'Program Files path rejected'
    $codexTarget = Join-Path $env:USERPROFILE '.codex\test.txt'
    Assert-Throws { Assert-AuthorizedPath -Path $codexTarget -AllowedRoots @($codexTarget) } 'Codex path rejected'
    Assert-Throws { Assert-AuthorizedPath -Path $scriptPath -AllowedRoots @($scriptPath) } 'project source path rejected'
    Assert-True ([bool](Get-Command Assert-NoOverlappingTargets -ErrorAction SilentlyContinue)) 'overlap guard exists'
    $overlapping = @([pscustomobject]@{ Kind = 'Filesystem'; Path = $allowed },
        [pscustomobject]@{ Kind = 'Filesystem'; Path = $file })
    Assert-Throws { Assert-NoOverlappingTargets -Records $overlapping } 'overlapping deletion targets rejected'

    $junction = Join-Path $allowed 'junction'
    $outside = Join-Path $sandbox 'outside'
    New-Item -ItemType Directory -Path $outside | Out-Null
    New-Item -ItemType Junction -Path $junction -Target $outside | Out-Null
    Assert-Throws { Assert-TreeWithoutLinks -Path $allowed } 'nested junction rejected'
    Assert-Throws { Assert-AuthorizedPath -Path (Join-Path $junction 'secret.txt') -AllowedRoots @($allowed) } 'junction ancestor rejected'
    Remove-Item -LiteralPath $junction -Force

    $symlink = Join-Path $allowed 'symlink'
    try {
        New-Item -ItemType SymbolicLink -Path $symlink -Target $outside | Out-Null
        Assert-Throws { Assert-TreeWithoutLinks -Path $allowed } 'nested symlink rejected'
        Remove-Item -LiteralPath $symlink -Force
    } catch [System.UnauthorizedAccessException] {
        $skipped++
        Write-Output 'SKIP: symlink creation needs Windows privilege'
    }

    Assert-True ((Invoke-SafeFileRemoval -Path (Join-Path $allowed 'missing.txt') -AllowedRoots @($allowed)).Status -eq 'AlreadyAbsent') 'missing target idempotent'
    Invoke-SafeFileRemoval -Path $file -AllowedRoots @($allowed) -WhatIf | Out-Null
    Assert-True (Test-Path -LiteralPath $file) 'WhatIf preserves file'

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

    $candidate = Get-Candidate -Id 'stale-sandbox-file' -Path $file -Category 'Test' -Policy 'AccountData'
    $record = Get-ArtifactRecord $candidate
    Add-Content -LiteralPath $file -Value 'changed after planning'
    Assert-Throws { Assert-CurrentRecord -Record $record -Candidates @($candidate) } 'changed target invalidates plan'

    $stream = [IO.File]::Open($file, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::None)
    try {
        Assert-Throws { Invoke-SafeFileRemoval -Path $file -AllowedRoots @($allowed) } 'locked file reports failure'
    } finally { $stream.Dispose() }
    Assert-True (Test-Path -LiteralPath $file) 'failed deletion leaves file'
    Assert-True ((Invoke-SafeFileRemoval -Path $file -AllowedRoots @($allowed)).Status -eq 'Removed') 'approved sandbox file removed'
    Assert-True ((Invoke-SafeFileRemoval -Path $file -AllowedRoots @($allowed)).Status -eq 'AlreadyAbsent') 'second removal idempotent'
    $empty = Join-Path $allowed 'empty'
    New-Item -ItemType Directory -Path $empty | Out-Null
    Assert-True ((Invoke-SafeFileRemoval -Path $empty -AllowedRoots @($allowed)).Status -eq 'Removed') 'empty directory removed'
    Write-Output "RESULT: $passed passed; $skipped skipped"
} finally {
    if (Test-Path -LiteralPath $sandbox) {
        try { Assert-TreeWithoutLinks -Path $sandbox; Remove-SafeTree -Path $sandbox }
        catch { Write-Warning "Sandbox retained for manual review: $sandbox ($($_.Exception.Message))" }
    }
}
