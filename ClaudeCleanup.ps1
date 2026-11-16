[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [switch]$Audit,
    [switch]$Plan,
    [switch]$Apply,
    [switch]$Verify,
    [switch]$Help,
    [ValidateSet('AccountData', 'FullRemoval')][string]$Policy,
    [ValidatePattern('^[A-Fa-f0-9]{64}$')][string]$ApprovedManifestSha256
)

Set-StrictMode -Version 2.0
$script:ProjectRoot = $PSScriptRoot
$script:PlanPath = Join-Path $PSScriptRoot 'CLEANUP-PLAN.md'
$script:VerificationPath = Join-Path $PSScriptRoot 'VERIFICATION.md'

function Get-NormalPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not [IO.Path]::IsPathRooted($Path) -or $Path.StartsWith('\\') -or $Path.StartsWith('\\?\')) {
        throw "Only local absolute paths are allowed: $Path"
    }
    if ($Path -notmatch '^[A-Za-z]:[\\/]' -or $Path -match '[*?]' -or
        $Path -match '(^|[\\/])\.\.([\\/]|$)' -or $Path.Substring(2).Contains(':')) {
        throw "Unsafe path syntax: $Path"
    }
    $full = [IO.Path]::GetFullPath($Path).TrimEnd([char]'\')
    $root = [IO.Path]::GetPathRoot($full).TrimEnd([char]'\')
    if ($full -eq $root) { throw "Drive root is protected: $Path" }
    return $full
}

function Test-PathWithin {
    param([string]$Path, [string]$Root)
    $comparison = [StringComparison]::OrdinalIgnoreCase
    return ($Path.Equals($Root, $comparison) -or $Path.StartsWith($Root + '\', $comparison))
}

function Get-ExistingItem {
    param([Parameter(Mandatory = $true)][string]$Path)
    try { return (Get-Item -LiteralPath $Path -Force -ErrorAction Stop) }
    catch [System.Management.Automation.ItemNotFoundException] { return $null }
}

function Assert-NoLinkAncestors {
    param([string]$Path)
    $current = $Path
    while ($current) {
        $item = Get-ExistingItem $current
        if ($item -and (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)) {
            throw "Reparse point is not an approved deletion target: $current"
        }
        $parent = [IO.Path]::GetDirectoryName($current)
        if (-not $parent -or $parent -eq $current) { break }
        $current = $parent
    }
}

function Assert-AuthorizedPath {
    param([Parameter(Mandatory = $true)][string]$Path, [Parameter(Mandatory = $true)][string[]]$AllowedRoots)
    $full = Get-NormalPath $Path
    $testSandbox = Join-Path $script:ProjectRoot 'tests\sandbox'
    $isApprovedTestPath = (Test-PathWithin $full $testSandbox) -and
        (@($AllowedRoots | Where-Object { Test-PathWithin ([IO.Path]::GetFullPath($_).TrimEnd([char]'\')) $testSandbox }).Count -gt 0)
    $protected = @($env:WINDIR, $env:ProgramFiles, ${env:ProgramFiles(x86)}, $script:ProjectRoot,
        (Join-Path $env:USERPROFILE '.codex'), (Join-Path $env:USERPROFILE '.agents'))
    foreach ($p in $protected) {
        if (-not $p) { continue }
        $base = [IO.Path]::GetFullPath($p).TrimEnd([char]'\')
        if ((Test-PathWithin $full $base) -and -not ($isApprovedTestPath -and $base -eq $script:ProjectRoot)) {
            throw "Protected path: $full"
        }
    }
    $allowed = $false
    foreach ($root in $AllowedRoots) {
        $base = Get-NormalPath $root
        if (Test-PathWithin $full $base) { $allowed = $true; break }
    }
    if (-not $allowed) { throw "Path is not on the exact allowlist: $full" }
    Assert-NoLinkAncestors $full
    if (Get-ExistingItem $full) {
        $owner = (Get-Acl -LiteralPath $full -ErrorAction Stop).GetOwner([Security.Principal.SecurityIdentifier]).Value
        $currentSid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
        if ($owner -ne $currentSid) { throw "Target is not owned by the current user: $full" }
    }
    return $full
}

function Test-SafeTarget {
    param([string]$Path, [string[]]$AllowedRoots)
    try {
        $full = Assert-AuthorizedPath -Path $Path -AllowedRoots $AllowedRoots
        return [pscustomobject]@{ Allowed = $true; Path = $full; Reason = '' }
    } catch {
        return [pscustomobject]@{ Allowed = $false; Path = $Path; Reason = $_.Exception.Message }
    }
}

function Assert-TreeWithoutLinks {
    param([Parameter(Mandatory = $true)][string]$Path)
    $root = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
    $stack = New-Object 'System.Collections.Generic.Stack[System.IO.FileSystemInfo]'
    $stack.Push($root)
    while ($stack.Count -gt 0) {
        $item = $stack.Pop()
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw "Linked item blocks removal: $($item.FullName)" }
        if ($item.PSIsContainer) {
            foreach ($child in (Get-ChildItem -LiteralPath $item.FullName -Force -ErrorAction Stop)) { $stack.Push($child) }
        }
    }
}

function Get-SafeSize {
    param([string]$Path)
    $root = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
    $bytes = [long]0
    $count = 0
    $stack = New-Object 'System.Collections.Generic.Stack[System.IO.FileSystemInfo]'
    $stack.Push($root)
    while ($stack.Count -gt 0) {
        $item = $stack.Pop()
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw "Linked item blocks size measurement: $($item.FullName)" }
        $count++
        if ($count -gt 100000) { throw 'Size measurement limit reached (100000 entries)' }
        if ($item.PSIsContainer) {
            foreach ($child in (Get-ChildItem -LiteralPath $item.FullName -Force -ErrorAction Stop)) { $stack.Push($child) }
        } else { $bytes += $item.Length }
    }
    return [pscustomobject]@{ Bytes = $bytes; Entries = $count }
}

function Remove-SafeTree {
    param([string]$Path)
    $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
    if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw "Linked item blocks removal: $Path" }
    if ($item.PSIsContainer) {
        foreach ($child in (Get-ChildItem -LiteralPath $Path -Force -ErrorAction Stop)) { Remove-SafeTree $child.FullName }
        Remove-Item -LiteralPath $Path -Force -ErrorAction Stop
    } else { Remove-Item -LiteralPath $Path -Force -ErrorAction Stop }
}

function Invoke-SafeFileRemoval {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param([string]$Path, [string[]]$AllowedRoots)
    $full = Assert-AuthorizedPath -Path $Path -AllowedRoots $AllowedRoots
    $item = Get-ExistingItem $full
    if (-not $item) { return [pscustomobject]@{ Path = $full; Status = 'AlreadyAbsent' } }
    Assert-TreeWithoutLinks $full
    if ($PSCmdlet.ShouldProcess($full, 'Permanently remove')) {
        Remove-SafeTree $full
        return [pscustomobject]@{ Path = $full; Status = 'Removed' }
    }
    return [pscustomobject]@{ Path = $full; Status = 'PreviewOnly' }
}

function Assert-ManifestAuthorization {
    param([string]$ManifestPath, [string]$ApprovedHash)
    if (-not $ApprovedHash -or $ApprovedHash -notmatch '^[A-Fa-f0-9]{64}$') { throw 'An approved SHA-256 manifest hash is required.' }
    $actual = Get-Sha256 -Path $ManifestPath
    if (-not $actual.Equals($ApprovedHash, [StringComparison]::OrdinalIgnoreCase)) { throw 'Manifest hash does not match approval.' }
    return $true
}
function Get-Sha256 {
    param([Parameter(Mandatory = $true)][string]$Path)
    $stream = [IO.File]::OpenRead($Path)
    $hasher = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($hasher.ComputeHash($stream))).Replace('-', '') }
    finally { $hasher.Dispose(); $stream.Dispose() }
}
function Get-ClaudeAppxPackage {
    $previous = $WhatIfPreference
    $WhatIfPreference = $false
    try { Get-AppxPackage -Name 'Claude' -ErrorAction Stop }
    finally { $WhatIfPreference = $previous }
}
function Test-ManifestAuthorization {
    param([string]$ManifestPath, [string]$ApprovedHash)
    Assert-ManifestAuthorization -ManifestPath $ManifestPath -ApprovedHash $ApprovedHash | Out-Null
    return $true
}

function Get-Candidate {
    param([string]$Id, [string]$Path, [string]$Category, [string]$Policy,
        [string]$Kind = 'Filesystem', [string]$Warning = '', [string]$Decision = 'Ready')
    return [pscustomobject]@{ Id = $Id; Path = $Path; Category = $Category; Policy = $Policy;
        Kind = $Kind; Warning = $Warning; Decision = $Decision }
}

function Test-RemovableRoot {
    param([string]$Path)
    try {
        Assert-AuthorizedPath -Path $Path -AllowedRoots @($Path) | Out-Null
        Assert-TreeWithoutLinks -Path $Path
        return $true
    } catch { return $false }
}

function Assert-NoOverlappingTargets {
    param([object[]]$Records)
    $paths = @($Records | Where-Object { $_.Kind -eq 'Filesystem' } | ForEach-Object { Get-NormalPath $_.Path })
    for ($i = 0; $i -lt $paths.Count; $i++) {
        for ($j = $i + 1; $j -lt $paths.Count; $j++) {
            if ((Test-PathWithin $paths[$i] $paths[$j]) -or (Test-PathWithin $paths[$j] $paths[$i])) {
                throw "Overlapping deletion targets: $($paths[$i]) and $($paths[$j])"
            }
        }
    }
}

function Get-CurrentCandidates {
    $homePath = $env:USERPROFILE
    $roaming = $env:APPDATA
    $local = $env:LOCALAPPDATA
    $cli = Join-Path $homePath '.claude'
    $items = New-Object 'System.Collections.Generic.List[object]'
    $account = @(
        @('cli-credentials', (Join-Path $cli '.credentials.json'), 'Authentication'),
        @('cli-auth-cache', (Join-Path $cli 'mcp-needs-auth-cache.json'), 'Authentication cache'),
        @('cli-cache', (Join-Path $cli 'cache'), 'Cache'),
        @('cli-stats', (Join-Path $cli 'stats-cache.json'), 'Cache'),
        @('native-staging', (Join-Path $homePath '.cache\claude\staging'), 'Installer cache'),
        @('desktop-buddy-tokens', (Join-Path $roaming 'Claude\buddy-tokens.json'), 'Authentication'),
        @('desktop-cache', (Join-Path $roaming 'Claude\Cache'), 'Cache'),
        @('desktop-code-cache', (Join-Path $roaming 'Claude\Code Cache'), 'Cache'),
        @('desktop-gpu-cache', (Join-Path $roaming 'Claude\GPUCache'), 'Cache'),
        @('desktop-logs', (Join-Path $roaming 'Claude\logs'), 'Diagnostics'),
        @('local-logs', (Join-Path $local 'Claude\logs'), 'Diagnostics')
    )
    foreach ($row in $account) {
        $decision = if ($row[0] -eq 'desktop-buddy-tokens') { 'ReviewOnly' } else { 'Ready' }
        $warning = if ($row[0] -eq 'desktop-buddy-tokens') { 'Filename suggests token state, but its role is unverified; separate decision required.' } else { '' }
        $items.Add((Get-Candidate -Id $row[0] -Path $row[1] -Category $row[2] -Policy 'AccountData' -Decision $decision -Warning $warning))
    }
    $full = @(
        @('cli-home', $cli, 'Claude Code user data'),
        @('cli-global', (Join-Path $homePath '.claude.json'), 'Claude Code mixed configuration'),
        @('cli-exe', (Join-Path $homePath '.local\bin\claude.exe'), 'Claude Code installation'),
        @('cli-versions', (Join-Path $homePath '.local\share\claude'), 'Claude Code installation'),
        @('cli-installer-cache', (Join-Path $homePath '.cache\claude'), 'Claude Code cache'),
        @('desktop-roaming', (Join-Path $roaming 'Claude'), 'Claude Desktop user data'),
        @('desktop-local', (Join-Path $local 'Claude'), 'Claude Desktop user data'),
        @('desktop-old-local', (Join-Path $local 'Claude-3p'), 'Possible old Desktop data'),
        @('desktop-old-roaming', (Join-Path $roaming 'Claude-3p'), 'Possible old Desktop data')
    )
    foreach ($row in $full) {
        $decision = 'Ready'
        $warning = ''
        if ($row[0] -eq 'cli-home') { $warning = 'Removes skills, plugins, MCP settings, history, sessions, and other user-created data.' }
        if ($row[0] -eq 'cli-global') { $warning = 'Also removes MCP configuration and per-project state.' }
        if ($row[0] -eq 'desktop-roaming') {
            $warning = 'Removes Desktop sessions, local files, extensions, Cowork data, and any user backup inside this directory.'
            if (Test-Path -LiteralPath (Join-Path $roaming 'Claude\claude_desktop_config.json.rea.backup')) { $decision = 'ReviewOnly' }
        }
        if ($row[0] -match '^desktop-old') { $decision = 'ReviewOnly'; $warning = 'Old path attribution requires separate confirmation.' }
        $items.Add((Get-Candidate -Id $row[0] -Path $row[1] -Category $row[2] -Policy 'FullRemoval' -Warning $warning -Decision $decision))
    }
    $cliReady = Test-RemovableRoot $cli
    $nativeCacheRoot = Join-Path $homePath '.cache\claude'
    $nativeCacheReady = Test-RemovableRoot $nativeCacheRoot
    $desktopRoamingRoot = Join-Path $roaming 'Claude'
    $desktopRoamingReady = (-not (Test-Path -LiteralPath (Join-Path $desktopRoamingRoot 'claude_desktop_config.json.rea.backup'))) -and
        (Test-RemovableRoot $desktopRoamingRoot)
    $desktopLocalReady = Test-RemovableRoot (Join-Path $local 'Claude')
    foreach ($row in $account) {
        $covered = switch -Regex ($row[0]) {
            '^cli-' { $cliReady; break }
            '^native-' { $nativeCacheReady; break }
            '^desktop-' { $desktopRoamingReady; break }
            '^local-' { $desktopLocalReady; break }
            default { $false }
        }
        if ($covered) { continue }
        $decision = if ($row[0] -eq 'desktop-buddy-tokens') { 'ReviewOnly' } else { 'Ready' }
        $warning = if ($decision -eq 'ReviewOnly') { 'Authentication role unverified; separate decision required.' } else { 'Fallback because the parent directory is blocked or under review.' }
        $items.Add((Get-Candidate -Id ('full-' + $row[0]) -Path $row[1] -Category $row[2] -Policy 'FullRemoval' -Decision $decision -Warning $warning))
    }
    $extRoot = Join-Path $homePath '.vscode\extensions'
    if (Test-Path -LiteralPath $extRoot) {
        foreach ($ext in (Get-ChildItem -LiteralPath $extRoot -Directory -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^anthropic\.claude-code-[0-9]' })) {
            $metadata = Join-Path $ext.FullName 'package.json'
            try {
                $package = Get-Content -LiteralPath $metadata -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
                if ($package.publisher -eq 'anthropic' -and $package.name -eq 'claude-code') {
                    $items.Add((Get-Candidate -Id ('vscode-' + $ext.Name) -Path $ext.FullName -Category 'VS Code extension' -Policy 'FullRemoval' -Warning 'VS Code should be closed before removal.'))
                }
            } catch { continue }
        }
    }
    $pkg = Get-ClaudeAppxPackage | Where-Object {
        $_.PackageFamilyName -eq 'Claude_pzs8sxrjxfjjc' -and $_.Publisher -match 'Anthropic'
    }
    foreach ($p in $pkg) {
        $items.Add((Get-Candidate -Id ('appx-' + $p.PackageFullName) -Path $p.PackageFullName -Category 'Claude Desktop MSIX' -Policy 'FullRemoval' -Kind 'AppxPackage' -Warning 'Windows package removal may remove package-managed data and its service.'))
        $packageData = Join-Path $local ('Packages\' + $p.PackageFamilyName)
        if (Test-Path -LiteralPath $packageData) {
            $items.Add((Get-Candidate -Id 'desktop-msix-data' -Path $packageData -Category 'OS-managed MSIX data' -Policy 'FullRemoval' -Decision 'ReviewOnly' -Warning 'Contains junctions; never direct-delete. Package removal may affect this data.'))
        }
    }
    $obsolete = Join-Path $homePath '.vscode\extensions\.obsolete'
    if (Test-Path -LiteralPath $obsolete) {
        $obsoleteText = Get-Content -LiteralPath $obsolete -Raw -ErrorAction SilentlyContinue
        if ($obsoleteText -match '(?i)anthropic\.claude-code') {
            $items.Add((Get-Candidate -Id 'vscode-shared-obsolete' -Path $obsolete -Category 'Shared VS Code registration file' -Policy 'FullRemoval' -Decision 'ReviewOnly' -Warning 'Shared file; do not delete as a whole.'))
        }
    }
    $pivotRoot = Join-Path $local 'Packages'
    foreach ($pivot in (Get-ChildItem -LiteralPath $pivotRoot -Directory -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '^0_https___pivot\.claude\.ai' })) {
        $items.Add((Get-Candidate -Id ('suspected-' + $pivot.Name) -Path $pivot.FullName -Category 'Suspected Claude-related package data' -Policy 'FullRemoval' -Decision 'ReviewOnly' -Warning 'Name alone does not establish ownership.'))
    }
    foreach ($browser in @('Google\Chrome', 'Microsoft\Edge')) {
        $key = 'HKCU:\Software\' + $browser + '\NativeMessagingHosts\com.anthropic.claude_browser_extension'
        if (Test-Path -LiteralPath $key) {
            $destination = (Get-Item -LiteralPath $key).GetValue('')
            $decision = if ($destination -match '(?i)Claude|Anthropic') { 'Ready' } else { 'ReviewOnly' }
            $items.Add((Get-Candidate -Id ('native-host-' + ($browser -replace '[\\ ]', '-')) -Path $key -Category 'Browser native host registration' -Policy 'FullRemoval' -Kind 'RegistryKey' -Decision $decision -Warning 'Does not modify browser profiles or site data.'))
        }
    }
    return $items.ToArray()
}

function Get-ArtifactRecord {
    param([object]$Candidate)
    $status = $Candidate.Decision
    $bytes = $null
    $entries = $null
    $reason = ''
    $lastWriteUtcTicks = $null
    $identity = $null
    if ($Candidate.Kind -eq 'Filesystem') {
        try { $item = Get-ExistingItem $Candidate.Path }
        catch { $status = 'Blocked'; $reason = 'Cannot inspect target: ' + $_.Exception.Message; $item = $null }
        if ($status -eq 'Blocked') {
            return [pscustomobject]@{ Id = $Candidate.Id; Path = $Candidate.Path; Category = $Candidate.Category;
                Policy = $Candidate.Policy; Kind = $Candidate.Kind; Decision = $status; SizeBytes = $null;
                Entries = $null; LastWriteUtcTicks = $null; Identity = $null; Reason = $reason;
                Warning = $Candidate.Warning; Ownership = 'Unverified' }
        }
        if (-not $item) { return $null }
        $lastWriteUtcTicks = $item.LastWriteTimeUtc.Ticks
        $safe = Test-SafeTarget -Path $Candidate.Path -AllowedRoots @($Candidate.Path)
        if (-not $safe.Allowed) { $status = 'Blocked'; $reason = $safe.Reason }
        if ($status -ne 'Blocked') {
            try { $size = Get-SafeSize $Candidate.Path; $bytes = $size.Bytes; $entries = $size.Entries }
            catch { $status = 'Blocked'; $reason = $_.Exception.Message }
        }
    } elseif ($Candidate.Kind -eq 'RegistryKey') {
        $identity = [string](Get-Item -LiteralPath $Candidate.Path -ErrorAction Stop).GetValue('')
    }
    return [pscustomobject]@{ Id = $Candidate.Id; Path = $Candidate.Path; Category = $Candidate.Category;
        Policy = $Candidate.Policy; Kind = $Candidate.Kind; Decision = $status; SizeBytes = $bytes;
        Entries = $entries; LastWriteUtcTicks = $lastWriteUtcTicks; Identity = $identity;
        Reason = $reason; Warning = $Candidate.Warning;
        Ownership = if ($Candidate.Decision -eq 'ReviewOnly') { 'Suspected / mixed' } else { 'Confirmed Claude path or registration' } }
}

function Get-Inventory {
    $records = New-Object 'System.Collections.Generic.List[object]'
    foreach ($candidate in (Get-CurrentCandidates)) {
        $record = Get-ArtifactRecord $candidate
        if ($record) { $records.Add($record) }
    }
    return $records.ToArray()
}

function Get-EnvironmentReport {
    $lines = New-Object 'System.Collections.Generic.List[string]'
    $lines.Add('Windows user: ' + [Security.Principal.WindowsIdentity]::GetCurrent().Name)
    $lines.Add('PowerShell: ' + $PSVersionTable.PSVersion.ToString())
    $resolved = Get-Command claude -All -ErrorAction SilentlyContinue
    foreach ($command in $resolved) { $lines.Add('Claude command: ' + $command.Source) }
    $native = Get-Item -LiteralPath (Join-Path $env:USERPROFILE '.local\bin\claude.exe') -ErrorAction SilentlyContinue
    if ($native) {
        $signature = Get-AuthenticodeSignature -LiteralPath $native.FullName
        $lines.Add(('Native executable: {0}; version={1}; signature={2}; company={3}' -f
            $native.FullName, $native.VersionInfo.FileVersion, $signature.Status, $native.VersionInfo.CompanyName))
    }
    $npm = Get-Command npm.cmd -ErrorAction SilentlyContinue
    if ($npm) {
        $lines.Add('npm command: ' + $npm.Source)
        $npmPrefix = [Environment]::GetEnvironmentVariable('NPM_CONFIG_PREFIX')
        if ($npmPrefix) { $lines.Add('npm prefix override (not independently validated): ' + $npmPrefix) }
        else { $lines.Add('npm global prefix: unverified; known default package locations checked without invoking npm') }
        $npmRoots = @((Join-Path $env:APPDATA 'npm\node_modules\@anthropic-ai\claude-code'),
            (Join-Path $env:ProgramFiles 'nodejs\node_modules\@anthropic-ai\claude-code'))
        foreach ($npmRoot in $npmRoots) {
            if (Test-Path -LiteralPath $npmRoot) { $lines.Add('npm Claude package candidate: ' + $npmRoot) }
        }
    }
    foreach ($scope in @('User', 'Machine')) {
        $pathValue = [Environment]::GetEnvironmentVariable('PATH', $scope)
        foreach ($entry in @($pathValue -split ';')) {
            if ($entry -match '(?i)claude|anthropic|[\\/]\.local[\\/]bin$') { $lines.Add("$scope PATH entry: $entry") }
        }
    }
    $running = @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -match '^(?i:claude)(-|$)' })
    $lines.Add('Claude-named running processes: ' + $running.Count)
    $lines.Add('Node-based Claude processes cannot be attributed without reading command lines; close Claude normally before Apply.')
    foreach ($process in $running) { $lines.Add(('Process: {0} PID={1}' -f $process.ProcessName, $process.Id)) }
    foreach ($scope in @('User', 'Machine')) {
        foreach ($name in [Environment]::GetEnvironmentVariables($scope).Keys) {
            if ($name -match '(?i)claude|anthropic') { $lines.Add("$scope environment variable name: $name") }
        }
    }
    foreach ($name in @('CLAUDE_CONFIG_DIR', 'CLAUDE_USER_DATA_DIR')) {
        $value = [Environment]::GetEnvironmentVariable($name)
        if ($value) { $lines.Add("Custom path override $name`: $value (report only)") }
    }
    $credentialTargets = @(cmdkey.exe /list 2>$null | Where-Object { $_ -match '(?i)^\s*Target:.*(claude|anthropic)' })
    $lines.Add('Credential Manager Claude-named target count: ' + $credentialTargets.Count + ' (values not read)')
    foreach ($name in @('skills', 'plugins', 'projects', 'sessions', 'history.jsonl', 'settings.json',
        'settings.local.json', 'backups', 'daemon', '.credentials.json')) {
        if (Test-Path -LiteralPath (Join-Path $env:USERPROFILE ('.claude\' + $name))) {
            $lines.Add('Claude Code content category present: ' + $name)
        }
    }
    foreach ($name in @('local-agent-mode-sessions', 'claude-code-sessions', 'claude-code-vm',
        'vm_bundles', 'Claude Extensions', 'Local Storage', 'IndexedDB', 'Network', 'logs')) {
        if (Test-Path -LiteralPath (Join-Path $env:APPDATA ('Claude\' + $name))) {
            $lines.Add('Claude Desktop content category present: ' + $name)
        }
    }
    $obsolete = Join-Path $env:USERPROFILE '.vscode\extensions\.obsolete'
    if (Test-Path -LiteralPath $obsolete) {
        $obsoleteText = Get-Content -LiteralPath $obsolete -Raw -ErrorAction SilentlyContinue
        if ($obsoleteText -match '(?i)anthropic\.claude-code') {
            $lines.Add('VS Code shared .obsolete file references Claude extension; report only')
        }
    }
    $uninstallRoots = @('HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall')
    foreach ($root in $uninstallRoots) {
        foreach ($key in (Get-ChildItem -LiteralPath $root -ErrorAction SilentlyContinue)) {
            $value = Get-ItemProperty -LiteralPath $key.PSPath -ErrorAction SilentlyContinue
            if (-not $value -or -not $value.PSObject.Properties['DisplayName'] -or
                -not $value.PSObject.Properties['Publisher']) { continue }
            if ($value.DisplayName -match '(?i)^Claude( Code| Desktop)?$' -and $value.Publisher -match 'Anthropic') {
                $lines.Add('Uninstall registration: ' + $key.Name)
            }
        }
    }
    $lines.Add('Machine-level MSIX provisioning: unverified without an elevated or management-scope query')
    foreach ($service in (Get-CimInstance Win32_Service -ErrorAction SilentlyContinue | Where-Object {
        $_.PathName -match 'WindowsApps\\Claude_[^\\]+\\' -or ($_.Name -eq 'CoworkVMService' -and $_.DisplayName -eq 'Claude')
    })) {
        $lines.Add(('Service: {0} ({1})' -f $service.Name, $service.State))
    }
    foreach ($pkg in (Get-ClaudeAppxPackage | Where-Object { $_.Publisher -match 'Anthropic' })) {
        $lines.Add(('MSIX: {0}; family={1}; install={2}' -f $pkg.PackageFullName, $pkg.PackageFamilyName, $pkg.InstallLocation))
        $packageData = Join-Path $env:LOCALAPPDATA ('Packages\' + $pkg.PackageFamilyName)
        if (Test-Path -LiteralPath $packageData) {
            foreach ($child in (Get-ChildItem -LiteralPath $packageData -Force -ErrorAction SilentlyContinue | Where-Object { ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 })) {
                $linkTarget = 'target unavailable in this PowerShell version'
                if ($child.PSObject.Properties['LinkTarget']) { $linkTarget = [string]$child.LinkTarget }
                elseif ($child.PSObject.Properties['Target']) { $linkTarget = [string]$child.Target }
                $lines.Add(('MSIX data junction (never direct-delete): {0} -> {1}' -f $child.FullName, $linkTarget))
            }
        }
    }
    $pivot = Get-ChildItem -LiteralPath (Join-Path $env:LOCALAPPDATA 'Packages') -Directory -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '^0_https___pivot\.claude\.ai' }
    foreach ($item in $pivot) { $lines.Add('Suspected Claude-related package data; ownership unverified: ' + $item.FullName) }
    foreach ($task in (Get-ScheduledTask -ErrorAction SilentlyContinue)) {
        $claudeAction = @($task.Actions | Where-Object {
            $_.PSObject.Properties['Execute'] -and
            ($_.Execute -match '(?i)(^|[\\/])claude(\.exe)?$' -or $_.Execute -match '(?i)WindowsApps[\\/]Claude_')
        }).Count -gt 0
        if ($task.TaskName -match '(?i)^Claude' -or $claudeAction) {
            $lines.Add('Scheduled task candidate: ' + $task.TaskPath + $task.TaskName)
        }
    }
    try {
        $wsl = [regex]::Replace((wsl.exe --list --verbose | Out-String), '\x00', '')
        $lines.Add('WSL distributions (read-only report; never apply):')
        foreach ($line in ($wsl -split "`r?`n")) {
            if (-not $line.Trim()) { continue }
            $lines.Add('  ' + $line.Trim())
            if ($line -match '^\s*\*?\s*([A-Za-z0-9._-]+)\s+(Running|Stopped)\s+\d+' -and
                $matches[1] -ne 'docker-desktop') {
                $distro = $matches[1]
                if ($matches[2] -eq 'Stopped') { $lines.Add("  $distro`: paths not inspected because distribution is stopped"); continue }
                $linuxCommand = 'for p in "$HOME/.claude" "$HOME/.claude.json" "$HOME/.local/bin/claude"; do if [ -e "$p" ] || [ -L "$p" ]; then stat -c "%n|%F|%s" "$p"; fi; done'
                try {
                    foreach ($result in (& wsl.exe -d $distro --exec /bin/sh -c $linuxCommand 2>$null)) {
                        if ($result) { $lines.Add("  $distro`: $result") }
                    }
                } catch { $lines.Add("  $distro`: path inspection failed") }
            }
        }
    } catch { $lines.Add('WSL listing unavailable: ' + $_.Exception.Message) }
    return $lines.ToArray()
}

function Write-PlanDocument {
    param([object[]]$Records)
    $manifest = [pscustomobject]@{
        SchemaVersion = 2
        GeneratedUtc = [DateTime]::UtcNow.ToString('o')
        UserSid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
        UserProfile = $env:USERPROFILE
        Records = @($Records)
    }
    $json = ConvertTo-Json -InputObject $manifest -Depth 12
    $body = @(
        '# Windows Claude cleanup plan',
        '',
        ('Generated: ' + $manifest.GeneratedUtc),
        'No deletion has been performed. Only Decision=Ready entries can be applied after explicit approval of this exact file hash and one policy.',
        'ReviewOnly and Blocked entries are excluded. Missing paths are omitted. WSL and browser site data are excluded.',
        '',
        '| Policy | ID | Category | Path or package | Size (bytes) | Decision | Reason / warning |',
        '| --- | --- | --- | --- | ---: | --- | --- |'
    )
    foreach ($record in $Records) {
        $sizeText = if ($null -eq $record.SizeBytes) { 'unknown' } else { [string]$record.SizeBytes }
        $note = ($record.Reason + ' ' + $record.Warning).Trim().Replace('|', '\|').Replace("`r", ' ').Replace("`n", ' ')
        $body += ('| {0} | {1} | {2} | `{3}` | {4} | {5} | {6} |' -f $record.Policy, $record.Id,
            $record.Category, $record.Path.Replace('|', '\|'), $sizeText, $record.Decision, $note)
    }
    $body += @('', '<!-- MANIFEST-JSON-BEGIN -->', $json, '<!-- MANIFEST-JSON-END -->', '')
    [IO.File]::WriteAllLines($script:PlanPath, [string[]]$body, (New-Object System.Text.UTF8Encoding($false)))
    return (Get-Sha256 -Path $script:PlanPath)
}

function Read-PlanDocument {
    $content = [IO.File]::ReadAllText($script:PlanPath)
    $match = [regex]::Match($content, '(?s)<!-- MANIFEST-JSON-BEGIN -->\s*(\{.*?\})\s*<!-- MANIFEST-JSON-END -->')
    if (-not $match.Success) { throw 'Manifest JSON block is missing or malformed.' }
    $manifest = ConvertFrom-Json -InputObject $match.Groups[1].Value
    if ($manifest.SchemaVersion -ne 2) { throw 'Unsupported manifest schema.' }
    if ($manifest.UserSid -ne [Security.Principal.WindowsIdentity]::GetCurrent().User.Value) { throw 'Manifest belongs to another user.' }
    if ($manifest.UserProfile -ne $env:USERPROFILE) { throw 'Manifest belongs to another profile.' }
    return $manifest
}

function Assert-CurrentRecord {
    param([object]$Record, [object[]]$Candidates)
    $matching = @($Candidates | Where-Object { $_.Id -eq $Record.Id -and $_.Policy -eq $Record.Policy })
    if ($matching.Count -ne 1 -or $matching[0].Path -ne $Record.Path -or $matching[0].Kind -ne $Record.Kind) {
        throw "Manifest entry is not a current exact candidate: $($Record.Id)"
    }
    if ($matching[0].Decision -ne 'Ready' -or $Record.Decision -ne 'Ready') { throw "Entry is not approved for automatic application: $($Record.Id)" }
    if ($Record.Kind -eq 'Filesystem') {
        $full = Assert-AuthorizedPath -Path $Record.Path -AllowedRoots @($matching[0].Path)
        if (-not $full.Equals($matching[0].Path, [StringComparison]::OrdinalIgnoreCase)) { throw "Path changed: $($Record.Id)" }
        $item = Get-ExistingItem $full
        if (-not $item) { throw "Target disappeared after planning: $($Record.Id)" }
        Assert-TreeWithoutLinks $full
        $currentSize = Get-SafeSize $full
        if ($null -eq $Record.SizeBytes -or $null -eq $Record.Entries -or
            $null -eq $Record.LastWriteUtcTicks -or
            [long]$Record.SizeBytes -ne $currentSize.Bytes -or
            [int]$Record.Entries -ne $currentSize.Entries -or
            [long]$Record.LastWriteUtcTicks -ne $item.LastWriteTimeUtc.Ticks) {
            throw "Target metadata changed after planning: $($Record.Id)"
        }
    } elseif ($Record.Kind -eq 'AppxPackage') {
        $present = Get-ClaudeAppxPackage | Where-Object { $_.PackageFullName -eq $Record.Path -and $_.Publisher -match 'Anthropic' }
        if (-not $present) { throw "Package registration changed: $($Record.Id)" }
    } elseif ($Record.Kind -eq 'RegistryKey') {
        if ($Record.Path -notmatch '^HKCU:\\Software\\(Google\\Chrome|Microsoft\\Edge)\\NativeMessagingHosts\\com\.anthropic\.claude_browser_extension$') { throw 'Registry key is outside allowlist.' }
        if (-not (Test-Path -LiteralPath $Record.Path)) { throw "Registry key changed: $($Record.Id)" }
        $currentValue = [string](Get-Item -LiteralPath $Record.Path -ErrorAction Stop).GetValue('')
        if ($currentValue -ne $Record.Identity) { throw "Registry value changed after planning: $($Record.Id)" }
    } else { throw "Unsupported action kind: $($Record.Kind)" }
}

function Write-VerificationLine {
    param([string]$Line)
    Add-Content -LiteralPath $script:VerificationPath -Value $Line -Encoding UTF8
}

function Show-Help {
    @'
ClaudeCleanup.ps1 - native Windows Claude cleanup utility

  .\ClaudeCleanup.ps1 -Audit
  .\ClaudeCleanup.ps1 -Plan
  .\ClaudeCleanup.ps1 -Apply -Policy AccountData -ApprovedManifestSha256 <64-hex-hash> -WhatIf
  .\ClaudeCleanup.ps1 -Apply -Policy FullRemoval -ApprovedManifestSha256 <64-hex-hash>
  .\ClaudeCleanup.ps1 -Verify
  .\ClaudeCleanup.ps1 -Help

Audit and Verify inspect without deleting. Plan writes only CLEANUP-PLAN.md in this project.
Apply requires a separately approved, unchanged plan hash and one policy; it permanently removes
only Ready entries after preflight and confirmation. It does not change WSL, browser profiles,
device IDs, telemetry, proxy settings, or unrelated software. Credential Manager entries need
separate authorization and are not removed by this version. No backup or quarantine is made.
'@ | Write-Output
}

if ($MyInvocation.InvocationName -ne '.') {
    $modeCount = @($Audit, $Plan, $Apply, $Verify, $Help | Where-Object { $_ }).Count
    if ($modeCount -ne 1) { throw 'Choose exactly one mode: -Audit, -Plan, -Apply, -Verify, or -Help.' }
    if ($Help) { Show-Help; return }
    if ($Audit) {
        Get-EnvironmentReport | Write-Output
        Get-Inventory | Format-Table Policy, Category, Path, SizeBytes, Ownership, Decision, Reason -AutoSize | Out-String -Width 260 | Write-Output
        return
    }
    if ($Plan) {
        $records = @(Get-Inventory)
        if ($WhatIfPreference) {
            Write-Output "WhatIf: would write $script:PlanPath with $($records.Count) candidate entries."
            return
        }
        $hash = Write-PlanDocument $records
        Write-Output "Plan: $script:PlanPath"
        Write-Output "SHA256: $hash"
        Write-Output "Entries: $($records.Count); Ready: $(@($records | Where-Object Decision -eq 'Ready').Count); ReviewOnly/Blocked: $(@($records | Where-Object Decision -ne 'Ready').Count)"
        return
    }
    if ($Verify) {
        Get-EnvironmentReport | Write-Output
        $records = @(Get-Inventory)
        Write-Output 'Current Claude candidate inventory (read-only):'
        $records | Format-Table Policy, Category, Path, Decision -AutoSize | Out-String -Width 240 | Write-Output
        if (Test-Path -LiteralPath $script:PlanPath) {
            $manifest = Read-PlanDocument
            foreach ($record in $manifest.Records) {
                if ($record.Decision -ne 'Ready') { continue }
                $present = if ($record.Kind -eq 'Filesystem' -or $record.Kind -eq 'RegistryKey') {
                    [bool](Get-ExistingItem $record.Path)
                } else { [bool](Get-ClaudeAppxPackage | Where-Object PackageFullName -eq $record.Path) }
                Write-Output ("{0}: {1} present={2}" -f $record.Policy, $record.Id, $present)
            }
        }
        return
    }
    if ($Apply) {
        if (-not $Policy -or -not $ApprovedManifestSha256) { throw '-Apply requires -Policy and -ApprovedManifestSha256.' }
        Assert-ManifestAuthorization -ManifestPath $script:PlanPath -ApprovedHash $ApprovedManifestSha256 | Out-Null
        $manifest = Read-PlanDocument
        $all = @(Get-CurrentCandidates)
        $selected = @($manifest.Records | Where-Object { $_.Policy -eq $Policy -and $_.Decision -eq 'Ready' })
        if ($selected.Count -eq 0) { throw "No Ready entries for policy $Policy." }
        $running = @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -match '^(?i:claude)(-|$)' })
        if ($running.Count -gt 0) { throw 'Claude is running. Shut it down normally and retry.' }
        if ($Policy -eq 'FullRemoval' -and @($selected | Where-Object { $_.Id -like 'vscode-*' }).Count -gt 0) {
            $vscode = @(Get-Process -Name Code -ErrorAction SilentlyContinue)
            if ($vscode.Count -gt 0) { throw 'VS Code is running. Shut it down normally before removing its Claude extension.' }
        }
        foreach ($record in $selected) { Assert-CurrentRecord -Record $record -Candidates $all }
        Assert-NoOverlappingTargets -Records $selected
        foreach ($record in $selected) {
            Write-Output ("Target: {0}; category={1}; kind={2}; path={3}" -f $record.Id, $record.Category, $record.Kind, $record.Path)
        }
        $description = "Policy=$Policy; targets=$($selected.Count); manifest=$ApprovedManifestSha256"
        if (-not $PSCmdlet.ShouldProcess($description, 'Apply permanent Claude cleanup')) { Write-Output 'Preview only; no deletion performed.'; return }
        Write-VerificationLine ('# Claude cleanup execution' + "`n" + "`n" + 'Policy: ' + $Policy + "`n" + 'Manifest SHA256: ' + $ApprovedManifestSha256 + "`n" + 'Started: ' + [DateTime]::UtcNow.ToString('o') + "`n")
        foreach ($record in $selected) {
            try {
                Assert-CurrentRecord -Record $record -Candidates $all
                if ($record.Kind -eq 'Filesystem') {
                    $result = Invoke-SafeFileRemoval -Path $record.Path -AllowedRoots @($record.Path) -Confirm:$false
                    $state = $result.Status
                } elseif ($record.Kind -eq 'AppxPackage') {
                    Remove-AppxPackage -Package $record.Path -ErrorAction Stop -Confirm:$false
                    $state = 'Removed'
                } elseif ($record.Kind -eq 'RegistryKey') {
                    Remove-Item -LiteralPath $record.Path -Force -ErrorAction Stop
                    $state = 'Removed'
                }
                Write-VerificationLine ("- $($record.Id): $state")
            } catch {
                Write-VerificationLine ("- $($record.Id): FAILED - $($_.Exception.Message)")
                Write-VerificationLine '- Remaining targets: NOT EXECUTED. Run -Verify and review the partial result.'
                throw
            }
        }
        Write-VerificationLine ('Completed: ' + [DateTime]::UtcNow.ToString('o') + "`n" + 'Run -Verify independently and record residual findings.')
        Write-Output 'Apply finished. Run -Verify; do not infer remote account changes.'
    }
}
