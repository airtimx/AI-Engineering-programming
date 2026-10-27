# AI Workspace shared config + helpers (production)
# Status enum (cache.status): initialized | in_progress | done | unknown
# Supports Windows PowerShell 5.1+ and PowerShell 7+ (Win/macOS/Linux)
# Exit codes: 0=OK 1=fail 2=usage 3=lock 4=manifest
# PS 5.1 lacks $IsLinux/$IsMacOS — define before StrictMode
if (-not (Get-Variable -Name IsLinux -Scope Global -ErrorAction SilentlyContinue)) { Set-Variable -Name IsLinux -Scope Global -Value $false }
if (-not (Get-Variable -Name IsMacOS -Scope Global -ErrorAction SilentlyContinue)) { Set-Variable -Name IsMacOS -Scope Global -Value $false }
Set-StrictMode -Version Latest
# Preferred bundle folder for new projects; legacy "codestatrFirst" still resolved if present.
$script:AIWorkspaceBundleDirPreferred = "workspace"
$script:AIWorkspaceBundleDirLegacyNames = @("codestatrFirst")
$script:AIWorkspaceBundleDirName = if (-not [string]::IsNullOrWhiteSpace($env:AIWORKSPACE_BUNDLE_DIR)) {
    $env:AIWORKSPACE_BUNDLE_DIR.Trim()
}
else {
    $script:AIWorkspaceBundleDirPreferred
}
$script:AIWorkspaceToolkitVersion = "1.5.2"
$script:AIWorkspaceStatusEnum = @("initialized", "in_progress", "done", "unknown")
$script:AIWorkspaceExitOk = 0
$script:AIWorkspaceExitFail = 1
$script:AIWorkspaceExitUsage = 2
$script:AIWorkspaceExitLock = 3
$script:AIWorkspaceExitManifest = 4
$script:AIWorkspaceHeldLocks = New-Object 'System.Collections.Generic.HashSet[string]'

function Get-AIWorkspacePreferredBundleDirName {
    if (-not [string]::IsNullOrWhiteSpace($env:AIWORKSPACE_BUNDLE_DIR)) {
        return $env:AIWORKSPACE_BUNDLE_DIR.Trim()
    }
    return $script:AIWorkspaceBundleDirPreferred
}

function Get-AIWorkspaceBundleDirName {
    # Preferred / env name (for templates). Prefer Resolve-AIWorkspaceBundleDirName when a repo root is known.
    return (Get-AIWorkspacePreferredBundleDirName)
}

function Resolve-AIWorkspaceBundleDirName {
    param([Parameter(Mandatory = $true)][string]$RepositoryRoot)
    if (-not [string]::IsNullOrWhiteSpace($env:AIWORKSPACE_BUNDLE_DIR)) {
        return $env:AIWORKSPACE_BUNDLE_DIR.Trim()
    }
    $preferred = $script:AIWorkspaceBundleDirPreferred
    if (Test-Path -LiteralPath (Join-Path $RepositoryRoot $preferred)) {
        return $preferred
    }
    foreach ($legacy in $script:AIWorkspaceBundleDirLegacyNames) {
        if (Test-Path -LiteralPath (Join-Path $RepositoryRoot $legacy)) {
            return $legacy
        }
    }
    return $preferred
}

function Test-AIWorkspaceHasBundle {
    param([Parameter(Mandatory = $true)][string]$FullPath)
    if (Test-Path -LiteralPath (Join-Path $FullPath (Get-AIWorkspacePreferredBundleDirName))) { return $true }
    foreach ($legacy in $script:AIWorkspaceBundleDirLegacyNames) {
        if (Test-Path -LiteralPath (Join-Path $FullPath $legacy)) { return $true }
    }
    if (-not [string]::IsNullOrWhiteSpace($env:AIWORKSPACE_BUNDLE_DIR)) {
        if (Test-Path -LiteralPath (Join-Path $FullPath $env:AIWORKSPACE_BUNDLE_DIR.Trim())) { return $true }
    }
    return $false
}

function Get-AIWorkspaceExitCode {
    param([ValidateSet("Ok", "Fail", "Usage", "Lock", "Manifest")][string]$Kind = "Ok")
    switch ($Kind) {
        "Ok" { return $script:AIWorkspaceExitOk }
        "Usage" { return $script:AIWorkspaceExitUsage }
        "Lock" { return $script:AIWorkspaceExitLock }
        "Manifest" { return $script:AIWorkspaceExitManifest }
        default { return $script:AIWorkspaceExitFail }
    }
}

function Test-AIWorkspaceNonInteractive {
    return ($Host.Name -eq "ServerRemoteHost") -or
        ($env:CI -eq "true") -or
        ($env:AIWORKSPACE_NONINTERACTIVE -eq "1") -or
        (-not [Environment]::UserInteractive)
}

function Get-AIWorkspaceStatusEnum {
    return @($script:AIWorkspaceStatusEnum)
}

function Get-AIWorkspaceProjectDocFileName {
    # 项目说明.md (code points — encoding-safe)
    return ((-join @([char]0x9879, [char]0x76EE, [char]0x8BF4, [char]0x660E)) + ".md")
}

function Get-AIWorkspaceGarbledDocWhitelist {
    # Exact known mis-decoded filenames for 项目说明.md (UTF-8 bytes read as ANSI/GBK etc.)
    return @(
        "椤圭洰璇存槑.md"
    )
}

function Get-AIWorkspaceToolkitVersion {
    $verFile = Join-Path $PSScriptRoot "VERSION"
    if (Test-Path -LiteralPath $verFile) {
        $v = (Get-Content -LiteralPath $verFile -Raw -Encoding UTF8).Trim()
        if (-not [string]::IsNullOrWhiteSpace($v)) {
            return $v
        }
    }
    return $script:AIWorkspaceToolkitVersion
}

function Get-AIWorkspaceHomeDirectory {
    if (-not [string]::IsNullOrWhiteSpace($env:USERPROFILE)) {
        return $env:USERPROFILE.TrimEnd('\', '/')
    }
    if (-not [string]::IsNullOrWhiteSpace($env:HOME)) {
        return $env:HOME.TrimEnd('\', '/')
    }
    $profile = [Environment]::GetFolderPath([Environment+SpecialFolder]::UserProfile)
    if (-not [string]::IsNullOrWhiteSpace($profile)) {
        return $profile
    }
    throw "Cannot resolve user home (USERPROFILE/HOME)."
}

function Resolve-AIWorkspaceIdeName {
    param([string]$IDE = "Cursor")
    if ([string]::IsNullOrWhiteSpace($IDE)) { return "Cursor" }
    $n = $IDE.Trim()
    if ($n -match '^(?i)trae$') { return "Trae" }
    if ($n -match '^(?i)cursor$') { return "Cursor" }
    throw "Unsupported -IDE '$IDE' (use Cursor or Trae)."
}

function Get-AIWorkspaceIdeSkillsRoot {
    param(
        [ValidateSet("Cursor", "Trae")]
        [string]$IDE = "Cursor"
    )
    $ide = Resolve-AIWorkspaceIdeName -IDE $IDE
    $userHome = Get-AIWorkspaceHomeDirectory
    switch ($ide) {
        "Trae" { return (Join-Path $userHome (Join-Path ".trae-cn" "skills")) }
        default { return (Join-Path $userHome (Join-Path ".cursor" "skills")) }
    }
}

function Get-AIWorkspaceCursorSkillsRoot {
    return (Get-AIWorkspaceIdeSkillsRoot -IDE Cursor)
}

function Get-AIWorkspaceGlobalSkillPath {
    param(
        [ValidateSet("Cursor", "Trae")]
        [string]$IDE = "Cursor"
    )
    return (Join-Path (Get-AIWorkspaceIdeSkillsRoot -IDE $IDE) "aiworkspace-manager")
}

function Test-AIWorkspaceIsGlobalToolkitPath {
    param([string]$ToolkitDir)
    if ([string]::IsNullOrWhiteSpace($ToolkitDir)) { return $false }
    return ($ToolkitDir -match '[\\/]\.cursor[\\/]skills[\\/]') -or
        ($ToolkitDir -match '[\\/]\.trae-cn[\\/]skills[\\/]')
}

function Get-AIWorkspaceRuntimeInfo {
    $edition = "Desktop"
    if ($PSVersionTable.PSEdition) { $edition = [string]$PSVersionTable.PSEdition }
    $os = "Windows"
    if ($IsLinux) { $os = "Linux" }
    elseif ($IsMacOS) { $os = "macOS" }
    elseif ($env:OS -notmatch 'Windows') {
        if ($PSVersionTable.Platform -eq "Unix") { $os = "Unix" }
    }
    return [pscustomobject]@{
        PSVersion = $PSVersionTable.PSVersion.ToString()
        Edition   = $edition
        OS        = $os
        Toolkit   = Get-AIWorkspaceToolkitVersion
    }
}

function Test-IsDriveRootPath {
    param([string]$FullPath)
    $p = $FullPath.TrimEnd('\', '/')
    if ($p -eq "" -or $p -eq "/") { return $true }
    return ($FullPath -match '^[a-zA-Z]:\\?$') -or ($FullPath -match '^[a-zA-Z]:/$')
}

function Test-IsUncPath {
    param([string]$Path)
    return ($Path -match '^\\\\') -or ($Path -match '^//[^/]')
}

function Test-IsForbiddenRootPath {
    param([string]$FullPath)

    $p = $FullPath.TrimEnd('\', '/').ToLowerInvariant()
    if ([string]::IsNullOrWhiteSpace($p) -or $p -eq "/" -or $p -eq ".") { return $true }
    if (Test-IsDriveRootPath -FullPath $p) { return $true }
    if ($p -match '^[a-z]:\\windows(\\|$)') { return $true }
    if ($p -match '^[a-z]:\\program files') { return $true }
    if ($p -match '^[a-z]:\\programdata(\\|$)') { return $true }
    $forbiddenExact = @('c:\', 'c:\users', 'c:\windows', 'c:\programdata')
    foreach ($f in $forbiddenExact) {
        if ($p -eq $f) { return $true }
    }
    # Unix system roots
    foreach ($u in @('/bin', '/etc', '/usr', '/System', '/private')) {
        if ($p -eq $u.ToLowerInvariant()) { return $true }
    }
    return $false
}

function Test-LooksLikeProjectRoot {
    param([string]$FullPath)

    if (Test-Path -LiteralPath (Join-Path $FullPath ".git")) { return $true }
    if (Test-AIWorkspaceHasBundle -FullPath $FullPath) { return $true }
    $initScript = Join-Path (Join-Path $FullPath "skills") "init-workspace.ps1"
    if (Test-Path -LiteralPath $initScript) { return $true }
    if (Test-Path -LiteralPath (Join-Path (Join-Path $FullPath "skills") "aiws.ps1")) { return $true }
    if (Test-Path -LiteralPath (Join-Path (Join-Path $FullPath ".cursor") "skills")) { return $true }
    if (Test-Path -LiteralPath (Join-Path (Join-Path $FullPath ".trae") "rules")) { return $true }
    return $false
}

function Find-AIWorkspaceProjectRootCandidates {
    param(
        [string]$StartPath = "",
        [int]$MaxDepth = 14
    )
    if ([string]::IsNullOrWhiteSpace($StartPath)) {
        $StartPath = (Get-Location).Path
    }
    if (-not (Test-Path -LiteralPath $StartPath)) {
        return @()
    }
    $cur = (Get-Item -LiteralPath $StartPath).FullName
    $found = New-Object System.Collections.Generic.List[string]
    for ($i = 0; $i -lt $MaxDepth; $i++) {
        if (Test-LooksLikeProjectRoot -FullPath $cur) {
            if (-not $found.Contains($cur)) { $found.Add($cur) | Out-Null }
        }
        $parent = Split-Path -Parent $cur
        if ([string]::IsNullOrWhiteSpace($parent) -or ($parent -eq $cur)) { break }
        $cur = $parent
    }
    return @($found)
}

function Confirm-AIWorkspaceDetectedRoot {
    param([Parameter(Mandatory = $true)][string]$Candidate)
    if (Test-AIWorkspaceNonInteractive) {
        return $true
    }
    Write-Host "Detected project root: $Candidate"
    $ans = Read-Host "Use this root? (Y/n)"
    if ([string]::IsNullOrWhiteSpace($ans)) { return $true }
    return ($ans -match '^[yY]')
}

function Test-IsEmptyDirectory {
    param([string]$FullPath)
    $items = @(Get-ChildItem -LiteralPath $FullPath -Force -ErrorAction SilentlyContinue)
    return ($items.Count -eq 0)
}

function Write-AIWorkspaceAllowAnyRootWarning {
    Write-Warning "SECURITY: AIWORKSPACE_ALLOW_ANY_ROOT=1 is set — path safeguards are OFF."
    Write-Host ""
    Write-Host "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" -ForegroundColor Red
    Write-Host " SECURITY: AIWORKSPACE_ALLOW_ANY_ROOT=1 is set." -ForegroundColor Red
    Write-Host " Path safeguards (drive/system/project-shape checks) are OFF." -ForegroundColor Red
    Write-Host " Unset the variable unless you intentionally need the escape hatch." -ForegroundColor Red
    Write-Host "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" -ForegroundColor Red
    Write-Host ""
}

function Write-AIWorkspaceWarn {
    param([Parameter(Mandatory = $true)][string]$Message)
    # Warning stream is capturable via 3>&1 (unlike Write-Host on Windows PowerShell 5.1)
    Write-Warning $Message
}

function Write-AIWorkspaceInfo {
    param([Parameter(Mandatory = $true)][string]$Message)
    # Information stream capturable via 6>&1; also print for interactive visibility
    Write-Information $Message -InformationAction Continue
}

function Protect-AIWorkspaceMarkdownText {
    <#
    .SYNOPSIS
    Neutralize markdown injection when embedding user Title/Requirement into .md files.
    #>
    param(
        [AllowEmptyString()][string]$Value,
        [ValidateSet("Inline", "Block")][string]$Mode = "Inline"
    )

    if ($null -eq $Value) { return "" }
    $t = [string]$Value
    $t = $t -replace "`r`n", "`n" -replace "`r", "`n"

    $outLines = New-Object System.Collections.Generic.List[string]
    foreach ($line in ($t -split "`n")) {
        $l = $line
        # Break ATX headings: entire leading run of # → fullwidth ＃ (before inline join)
        if ($l -match '^(\s*)(#+)') {
            $l = $Matches[1] + ([string]::new([char]0xFF03, $Matches[2].Length)) + $l.Substring($Matches[0].Length)
        }
        # Neutralize task-list / checkbox injection
        $l = $l -replace '^(\s*)([-*+]|\d+\.)(\s+)\[([ xX])\]', '$1$2$3［$4］'
        $l = $l -replace '\[([ xX])\]', '［$1］'
        $outLines.Add($l) | Out-Null
    }

    if ($Mode -eq "Inline") {
        $parts = @($outLines | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        return (($parts -join " ").Trim() -replace '\s{2,}', ' ')
    }
    return ($outLines -join "`n")
}

function Assert-AIWorkspaceRootSafe {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepositoryRoot,
        [switch]$AllowEmptyBootstrap
    )

    if ($env:AIWORKSPACE_ALLOW_ANY_ROOT -eq "1") {
        Write-AIWorkspaceAllowAnyRootWarning
        return
    }

    if (Test-IsUncPath -Path $RepositoryRoot) {
        throw "Refusing UNC -Root path: $RepositoryRoot`nUse a local path, or set AIWORKSPACE_ALLOW_ANY_ROOT=1 (DANGEROUS)."
    }

    if (-not (Test-Path -LiteralPath $RepositoryRoot)) {
        throw "Project root does not exist: $RepositoryRoot`nCreate the directory first, or pass a valid -Root."
    }

    $item = Get-Item -LiteralPath $RepositoryRoot
    if (-not $item.PSIsContainer) {
        throw "Project root must be a directory: $RepositoryRoot"
    }

    $full = $item.FullName
    if (Test-IsForbiddenRootPath -FullPath $full) {
        throw "Refusing unsafe -Root path (drive/system root): $full`nSet AIWORKSPACE_ALLOW_ANY_ROOT=1 only if intentional (DANGEROUS)."
    }

    if (-not (Test-LooksLikeProjectRoot -FullPath $full)) {
        # init-workspace passes -AllowEmptyBootstrap: allow any non-forbidden dir
        # (including ones that already have README/src) so init can create the bundle.
        if ($AllowEmptyBootstrap) {
            Write-AIWorkspaceInfo "bootstrap allowed for init (not yet a marked project root): $full"
            return
        }
        throw "Refusing -Root that does not look like a project: $full`nRequire .git, existing workspace/ (or legacy codestatrFirst/), or skills/aiws.ps1.`nOr run aiws.ps1 init (bootstraps new folders), or git init first.`nOverride: AIWORKSPACE_ALLOW_ANY_ROOT=1 (DANGEROUS)"
    }
}

function Resolve-AIRepositoryRoot {
    param(
        [string]$Root = ".",
        [string]$ScriptHome = $PSScriptRoot,
        [switch]$AllowEmptyBootstrap,
        [switch]$SkipDetectConfirm
    )

    $candidate = $null
    $leaf = Split-Path -Leaf $ScriptHome
    $parent = Split-Path -Parent $ScriptHome
    $grand = Split-Path -Leaf $parent
    $isGlobalToolkit = (($leaf -ieq "toolkit") -or ($grand -ieq "aiworkspace-manager")) -and
        (Test-AIWorkspaceIsGlobalToolkitPath -ToolkitDir $ScriptHome)

    if (-not [string]::IsNullOrWhiteSpace($Root) -and ($Root -ne ".")) {
        $candidate = $Root
    }
    elseif (-not [string]::IsNullOrWhiteSpace($env:AIWORKSPACE_PROJECT_ROOT)) {
        $candidate = $env:AIWORKSPACE_PROJECT_ROOT.Trim()
    }
    elseif ($isGlobalToolkit) {
        $cands = @(Find-AIWorkspaceProjectRootCandidates -StartPath (Get-Location).Path)
        if ($cands.Count -eq 1) {
            if ($SkipDetectConfirm -or (Confirm-AIWorkspaceDetectedRoot -Candidate $cands[0])) {
                $candidate = $cands[0]
            }
            else {
                throw "Cancelled. Re-run with -Root `"<project>`" or set AIWORKSPACE_PROJECT_ROOT."
            }
        }
        elseif ($cands.Count -gt 1) {
            $list = ($cands | ForEach-Object { "  - $_" }) -join "`n"
            throw "Ambiguous project roots from current directory:`n$list`nPass -Root `"<project>`" or set AIWORKSPACE_PROJECT_ROOT."
        }
        else {
            throw "Global toolkit: no project root detected from '$((Get-Location).Path)'.`nPass -Root `"<project>`" or set AIWORKSPACE_PROJECT_ROOT.`nFix: pwsh -File `"$ScriptHome\aiws.ps1`" doctor"
        }
    }
    else {
        $candidate = $parent
        # If skills parent is not a project but cwd is, prefer detected cwd (interactive tools)
        if (-not (Test-LooksLikeProjectRoot -FullPath $candidate)) {
            $cands = @(Find-AIWorkspaceProjectRootCandidates -StartPath (Get-Location).Path)
            if ($cands.Count -eq 1) {
                if ($SkipDetectConfirm -or (Confirm-AIWorkspaceDetectedRoot -Candidate $cands[0])) {
                    $candidate = $cands[0]
                }
            }
        }
    }

    if (Test-IsUncPath -Path $candidate) {
        throw "Refusing UNC path: $candidate"
    }

    if (-not (Test-Path -LiteralPath $candidate)) {
        throw "Project root does not exist: $candidate`nCreate it first, then re-run with -Root."
    }

    $resolved = (Get-Item -LiteralPath $candidate).FullName
    Assert-AIWorkspaceRootSafe -RepositoryRoot $resolved -AllowEmptyBootstrap:$AllowEmptyBootstrap
    return $resolved
}

function Get-AIWorkspaceBundlePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepositoryRoot
    )
    $name = Resolve-AIWorkspaceBundleDirName -RepositoryRoot $RepositoryRoot
    return (Join-Path $RepositoryRoot $name)
}

function Ensure-AIWorkspaceLockDir {
    param([Parameter(Mandatory = $true)][string]$BundleRoot)
    $lockDir = Join-Path $BundleRoot ".locks"
    if (-not (Test-Path -LiteralPath $lockDir)) {
        New-Item -ItemType Directory -Path $lockDir -Force | Out-Null
    }
    $keep = Join-Path $lockDir ".gitkeep"
    if (-not (Test-Path -LiteralPath $keep)) {
        Write-Utf8NoBomFile -Path $keep -Content ""
    }
    return $lockDir
}

function Invoke-WithAIWorkspaceLock {
    param(
        [Parameter(Mandatory = $true)][string]$BundleRoot,
        [Parameter(Mandatory = $true)][string]$LockName,
        [Parameter(Mandatory = $true)][scriptblock]$Action,
        [int]$TimeoutSeconds = 45
    )

    $safeName = ($LockName -replace '[^\w\.\-]', '_')
    if ([string]::IsNullOrWhiteSpace($safeName)) { $safeName = "workspace" }
    $lockDir = Ensure-AIWorkspaceLockDir -BundleRoot $BundleRoot
    $lockPath = Join-Path $lockDir "$safeName.lock"

    $deadline = [datetime]::UtcNow.AddSeconds($TimeoutSeconds)
    $stream = $null
    while ([datetime]::UtcNow -lt $deadline) {
        try {
            $stream = [System.IO.File]::Open(
                $lockPath,
                [System.IO.FileMode]::OpenOrCreate,
                [System.IO.FileAccess]::ReadWrite,
                [System.IO.FileShare]::None
            )
            break
        }
        catch {
            Start-Sleep -Milliseconds 80
        }
    }
    if ($null -eq $stream) {
        $err = "Timeout acquiring workspace lock '$LockName' after ${TimeoutSeconds}s: $lockPath`nAnother process may be writing cache/specs."
        $ex = New-Object System.Exception $err
        $ex.Data["ExitCode"] = (Get-AIWorkspaceExitCode -Kind Lock)
        throw $ex
    }
    try {
        [void]$script:AIWorkspaceHeldLocks.Add(($BundleRoot + "|" + $safeName))
        return & $Action
    }
    finally {
        [void]$script:AIWorkspaceHeldLocks.Remove(($BundleRoot + "|" + $safeName))
        $stream.Dispose()
    }
}

function Move-ToAIWorkspaceTrash {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [Parameter(Mandatory = $true)][string]$BundleRoot
    )

    $trash = Join-Path $BundleRoot ".trash"
    if (-not (Test-Path -LiteralPath $trash)) {
        New-Item -ItemType Directory -Path $trash -Force | Out-Null
        Write-Utf8NoBomFile -Path (Join-Path $trash ".gitkeep") -Content ""
    }
    $name = Split-Path -Leaf $FilePath
    $stamp = Get-Date -Format "yyyyMMddHHmmss"
    $dest = Join-Path $trash "$stamp-$name"
    Move-Item -LiteralPath $FilePath -Destination $dest -Force
    return $dest
}

function Clear-AIWorkspaceGarbledDocs {
    param([Parameter(Mandatory = $true)][string]$BundleRoot)

    $whitelist = Get-AIWorkspaceGarbledDocWhitelist
    $moved = @()
    Get-ChildItem -LiteralPath $BundleRoot -File -ErrorAction SilentlyContinue | ForEach-Object {
        if ($whitelist -contains $_.Name) {
            $dest = Move-ToAIWorkspaceTrash -FilePath $_.FullName -BundleRoot $BundleRoot
            Write-Host "Moved garbled doc to trash: $($_.Name) -> $dest"
            $moved += $dest
        }
    }
    return $moved
}

function Write-Utf8NoBomFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Content
    )
    $dir = Split-Path -Parent $Path
    if (-not [string]::IsNullOrWhiteSpace($dir) -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    $utf8 = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($Path, $Content, $utf8)
}

function Write-Utf8BomFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Content
    )
    $dir = Split-Path -Parent $Path
    if (-not [string]::IsNullOrWhiteSpace($dir) -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    $utf8Bom = New-Object System.Text.UTF8Encoding $true
    [System.IO.File]::WriteAllText($Path, $Content, $utf8Bom)
}

function Test-AIWorkspaceFileHasUtf8Bom {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $false }
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    return ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
}

function Copy-AIWorkspaceScriptWithBom {
    <#
    .SYNOPSIS
    Copy a .ps1 (or any text) ensuring UTF-8 BOM so Windows PowerShell 5.1 can parse non-ASCII.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$SourcePath,
        [Parameter(Mandatory = $true)][string]$DestinationPath
    )
    if (-not (Test-Path -LiteralPath $SourcePath)) {
        throw "Source missing: $SourcePath"
    }
    $ext = [System.IO.Path]::GetExtension($SourcePath)
    if ($ext -ieq ".ps1") {
        $text = [System.IO.File]::ReadAllText($SourcePath, [System.Text.Encoding]::UTF8)
        Write-Utf8BomFile -Path $DestinationPath -Content $text
    }
    else {
        $destDir = Split-Path -Parent $DestinationPath
        if (-not [string]::IsNullOrWhiteSpace($destDir) -and -not (Test-Path -LiteralPath $destDir)) {
            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        }
        Copy-Item -Path $SourcePath -Destination $DestinationPath -Force
    }
}

function Get-AIWorkspaceDefaultOwner {
    if (-not [string]::IsNullOrWhiteSpace($env:AIWORKSPACE_OWNER)) {
        return $env:AIWORKSPACE_OWNER.Trim()
    }
    if (-not [string]::IsNullOrWhiteSpace($env:USERNAME)) {
        return $env:USERNAME.Trim()
    }
    if (-not [string]::IsNullOrWhiteSpace($env:USER)) {
        return $env:USER.Trim()
    }
    return ""
}

function Get-AIWorkspaceModuleOwner {
    param(
        [Parameter(Mandatory = $true)][string]$BundleRoot,
        [Parameter(Mandatory = $true)][string]$ModuleName
    )
    $cachePath = Join-Path (Join-Path $BundleRoot "cache") "$ModuleName.json"
    if (-not (Test-Path -LiteralPath $cachePath)) { return "" }
    $read = Read-ModuleCacheJson -CachePath $cachePath
    if (-not $read.Ok) { return "" }
    $p = $read.Object.PSObject.Properties["owner"]
    if ($null -eq $p -or $null -eq $p.Value) { return "" }
    return ([string]$p.Value).Trim()
}

function Set-AIWorkspaceModuleOwner {
    param(
        [Parameter(Mandatory = $true)][string]$BundleRoot,
        [Parameter(Mandatory = $true)][string]$ModuleName,
        [string]$Owner = "",
        [switch]$Force,
        [switch]$Clear
    )
    $specsDir = Join-Path $BundleRoot "specs"
    $modDir = Join-Path $specsDir $ModuleName
    if (-not (Test-Path -LiteralPath $modDir)) {
        throw "Module not found: $ModuleName under $specsDir"
    }
    $cachePath = Join-Path (Join-Path $BundleRoot "cache") "$ModuleName.json"
    $title = $ModuleName
    $requirement = ""
    $priority = "P2"
    $status = "initialized"
    $createdAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $todo = 0
    $done = 0
    $existingOwner = ""
    if (Test-Path -LiteralPath $cachePath) {
        $read = Read-ModuleCacheJson -CachePath $cachePath
        if ($read.Ok) {
            $obj = $read.Object
            $p = $obj.PSObject.Properties["title"]; if ($null -ne $p -and $null -ne $p.Value) { $title = [string]$p.Value }
            $p = $obj.PSObject.Properties["requirement"]; if ($null -ne $p -and $null -ne $p.Value) { $requirement = [string]$p.Value }
            $p = $obj.PSObject.Properties["priority"]; if ($null -ne $p -and $null -ne $p.Value -and $p.Value -in @("P0", "P1", "P2", "P3")) { $priority = [string]$p.Value }
            $p = $obj.PSObject.Properties["status"]; if ($null -ne $p -and $null -ne $p.Value) { $status = [string]$p.Value }
            $p = $obj.PSObject.Properties["created_at"]; if ($null -ne $p -and $null -ne $p.Value) { $createdAt = [string]$p.Value }
            $p = $obj.PSObject.Properties["open_todo_count"]; if ($null -ne $p -and $null -ne $p.Value) { $todo = [int]$p.Value }
            $p = $obj.PSObject.Properties["done_count"]; if ($null -ne $p -and $null -ne $p.Value) { $done = [int]$p.Value }
            $p = $obj.PSObject.Properties["owner"]; if ($null -ne $p -and $null -ne $p.Value) { $existingOwner = [string]$p.Value }
        }
    }
    $tasksPath = Join-Path $modDir "tasks.md"
    if (Test-Path -LiteralPath $tasksPath) {
        $progress = Get-TasksProgressSummary -TasksPath $tasksPath
        $todo = $progress.Todo
        $done = $progress.Done
        $status = Get-DerivedModuleStatus -Todo $todo -Done $done
    }
    $bundleLeaf = Split-Path -Leaf $BundleRoot
    $newOwner = ""
    if (-not $Clear) {
        if ([string]::IsNullOrWhiteSpace($Owner)) { $Owner = Get-AIWorkspaceDefaultOwner }
        if ([string]::IsNullOrWhiteSpace($Owner)) { throw "Owner required (-Owner or AIWORKSPACE_OWNER / USERNAME)." }
        $newOwner = $Owner.Trim()
        if (-not [string]::IsNullOrWhiteSpace($existingOwner) -and ($existingOwner -ne $newOwner) -and -not $Force) {
            throw "Module '$ModuleName' claimed by '$existingOwner'. Use -Force to take over, or: aiws.ps1 release -Module $ModuleName"
        }
    }
    # Empty Owner omits owner key (release); non-empty claims
    $fields = New-AIWorkspaceCacheSchema `
        -ModuleName $ModuleName `
        -Title $title `
        -Requirement $requirement `
        -Priority $priority `
        -Status $status `
        -OpenTodoCount $todo `
        -DoneCount $done `
        -CreatedAt $createdAt `
        -Owner $newOwner `
        -BundleDirName $bundleLeaf
    return (Write-ModuleCacheJson -BundleRoot $BundleRoot -ModuleName $ModuleName -Fields $fields)
}

function Test-AIWorkspaceOwnerConflict {
    param(
        [string]$ModuleOwner,
        [string]$Me = ""
    )
    if ([string]::IsNullOrWhiteSpace($ModuleOwner)) { return $false }
    if ([string]::IsNullOrWhiteSpace($Me)) { $Me = Get-AIWorkspaceDefaultOwner }
    if ([string]::IsNullOrWhiteSpace($Me)) { return $false }
    return ($ModuleOwner.Trim() -ne $Me.Trim())
}

function Test-ValidUtf8Bytes {
    param([byte[]]$Bytes)
    try {
        $utf8 = New-Object System.Text.UTF8Encoding $false, $true
        [void]$utf8.GetString($Bytes)
        return $true
    }
    catch {
        return $false
    }
}

function Read-Utf8File {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [switch]$Strict
    )
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        $bytes = $bytes[3..($bytes.Length - 1)]
    }
    if ($Strict -or $env:AIWORKSPACE_STRICT_UTF8 -eq "1") {
        if (-not (Test-ValidUtf8Bytes -Bytes $bytes)) {
            throw "File is not valid UTF-8: $Path`nPlease re-save as UTF-8 (no ANSI/GBK)."
        }
    }
    elseif (-not (Test-ValidUtf8Bytes -Bytes $bytes)) {
        Write-AIWorkspaceWarn "file may not be UTF-8: $Path (re-save as UTF-8 recommended)"
    }
    return [System.Text.Encoding]::UTF8.GetString($bytes)
}

function Normalize-AIWorkspaceName {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Value,
        [string]$FallbackPrefix = "module",
        [switch]$AllowFallback,
        [switch]$AsciiOnly
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        if ($AllowFallback) {
            return "$FallbackPrefix-" + (Get-Date -Format "yyyyMMddHHmmss")
        }
        throw "Name/Title/ModuleName cannot be empty or whitespace."
    }

    $ascii = $AsciiOnly -or ($env:AIWORKSPACE_ASCII_NAMES -eq "1")
    $normalized = $Value.Trim().ToLowerInvariant()
    $normalized = $normalized -replace "\s+", "-"
    if ($ascii) {
        # ASCII-safe folder names for picky filesystems / remotes
        $normalized = $normalized -replace "[^a-z0-9\-_]", "-"
    }
    else {
        $normalized = $normalized -replace "[^\p{L}\p{N}\-_]", "-"
    }
    $normalized = $normalized -replace "-{2,}", "-"
    $normalized = $normalized.Trim("-")
    if ([string]::IsNullOrWhiteSpace($normalized)) {
        if ($AllowFallback -or $ascii) {
            return "$FallbackPrefix-" + (Get-Date -Format "yyyyMMddHHmmss")
        }
        throw "Name/Title/ModuleName invalid after normalization: '$Value'"
    }
    if ($normalized.Length -gt 80) {
        $normalized = $normalized.Substring(0, 80).TrimEnd("-")
    }
    return $normalized
}

function Get-UniqueModuleName {
    param([string]$BaseRoot, [string]$Candidate)
    $name = $Candidate
    $index = 2
    while (Test-Path -LiteralPath (Join-Path $BaseRoot (Join-Path "specs" $name))) {
        $name = "$Candidate-$index"
        $index++
        if ($index -gt 9999) { throw "Cannot allocate unique module name for: $Candidate" }
    }
    if ($name -ne $Candidate) {
        Write-AIWorkspaceWarn "Module folder '$Candidate' already exists; created '$name' instead. Edit specs/$Candidate to update, or choose a unique -Title."
    }
    return $name
}

function New-AIWorkspaceCacheSchema {
    param(
        [Parameter(Mandatory = $true)][string]$ModuleName,
        [string]$Title = "",
        [string]$Requirement = "",
        [ValidateSet("P0", "P1", "P2", "P3")][string]$Priority = "P2",
        [ValidateSet("initialized", "in_progress", "done", "unknown")][string]$Status = "initialized",
        [int]$OpenTodoCount = 0,
        [int]$DoneCount = 0,
        [string]$CreatedAt = "",
        [string]$Owner = "",
        [string]$BundleDirName = ""
    )

    $bundleName = if (-not [string]::IsNullOrWhiteSpace($BundleDirName)) {
        $BundleDirName
    }
    else {
        Get-AIWorkspacePreferredBundleDirName
    }
    if ([string]::IsNullOrWhiteSpace($CreatedAt)) {
        $CreatedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
    if ([string]::IsNullOrWhiteSpace($Owner) -and -not [string]::IsNullOrWhiteSpace($env:AIWORKSPACE_OWNER)) {
        $Owner = $env:AIWORKSPACE_OWNER.Trim()
    }
    $schema = [ordered]@{
        schema_version  = 1
        module          = $ModuleName
        title           = $Title
        requirement     = $Requirement
        priority        = $Priority
        status          = $Status
        open_todo_count = $OpenTodoCount
        done_count      = $DoneCount
        created_at      = $CreatedAt
        updated_at      = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        toolkit_version = Get-AIWorkspaceToolkitVersion
        files           = @(
            "$bundleName/specs/$ModuleName/spec.md"
            "$bundleName/specs/$ModuleName/design.md"
            "$bundleName/specs/$ModuleName/tasks.md"
        )
    }
    if (-not [string]::IsNullOrWhiteSpace($Owner)) {
        $schema["owner"] = $Owner
    }
    return $schema
}

function Test-AIWorkspaceBatchFile {
    <#
    .SYNOPSIS
    Validate batch file: lines starting with # are comments; data is title|requirement|priority?
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [switch]$StrictThrow
    )
    if (-not (Test-Path -LiteralPath $Path)) {
        $msg = "Batch file not found: $Path"
        if ($StrictThrow) { throw $msg }
        return [pscustomobject]@{ Ok = $false; Errors = @($msg); Items = 0 }
    }
    $raw = Read-Utf8File -Path $Path
    $errors = New-Object System.Collections.Generic.List[string]
    $items = 0
    $lineNo = 0
    foreach ($rawLine in ($raw -split "`r?`n")) {
        $lineNo++
        $line = $rawLine.Trim()
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        if ($line.StartsWith("#")) { continue }
        $parts = $line.Split([char]('|'))
        if ($parts.Count -lt 2) {
            $errors.Add("line ${lineNo}: expected title|requirement|priority(optional)") | Out-Null
            continue
        }
        if ([string]::IsNullOrWhiteSpace($parts[0]) -or [string]::IsNullOrWhiteSpace($parts[1])) {
            $errors.Add("line ${lineNo}: empty title or requirement") | Out-Null
            continue
        }
        $items++
    }
    $ok = ($errors.Count -eq 0)
    if (-not $ok -and $StrictThrow) {
        throw ("Batch validation failed:`n - " + ($errors -join "`n - "))
    }
    return [pscustomobject]@{ Ok = $ok; Errors = @($errors); Items = $items }
}

function Write-ModuleCacheJson {
    param(
        [Parameter(Mandatory = $true)][string]$BundleRoot,
        [Parameter(Mandatory = $true)][string]$ModuleName,
        [Parameter(Mandatory = $true)][System.Collections.IDictionary]$Fields,
        [switch]$AlreadyLocked
    )

    $write = {
        $cacheDir = Join-Path $BundleRoot "cache"
        if (-not (Test-Path -LiteralPath $cacheDir)) {
            New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null
        }
        $cacheFile = Join-Path $cacheDir "$ModuleName.json"
        $payload = [ordered]@{}
        foreach ($key in @($Fields.Keys)) { $payload[$key] = $Fields[$key] }
        if (-not $payload.Contains("schema_version")) { $payload["schema_version"] = 1 }
        if (-not $payload.Contains("toolkit_version")) { $payload["toolkit_version"] = Get-AIWorkspaceToolkitVersion }
        if (-not $payload.Contains("updated_at")) { $payload["updated_at"] = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss") }
        if ($payload.Contains("status") -and ($script:AIWorkspaceStatusEnum -notcontains [string]$payload["status"])) {
            throw "Invalid cache.status '$($payload['status'])'. Allowed: $($script:AIWorkspaceStatusEnum -join ', ')"
        }
        Write-Utf8NoBomFile -Path $cacheFile -Content ($payload | ConvertTo-Json -Depth 6)
        return $cacheFile
    }

    # Avoid nested locks: if caller already holds specs-create, write inline
    $outerKey = $BundleRoot + "|specs-create"
    $held = $script:AIWorkspaceHeldLocks.Contains($outerKey)
    if ($AlreadyLocked -or $held) {
        return & $write
    }
    return Invoke-WithAIWorkspaceLock -BundleRoot $BundleRoot -LockName "cache-$ModuleName" -Action $write
}

function Read-ModuleCacheJson {
    param(
        [Parameter(Mandatory = $true)][string]$CachePath
    )

    if (-not (Test-Path -LiteralPath $CachePath)) {
        return [pscustomobject]@{ Ok = $false; Object = $null; Error = "missing" }
    }

    try {
        $raw = Read-Utf8File -Path $CachePath -Strict
        $obj = $raw | ConvertFrom-Json
        return [pscustomobject]@{ Ok = $true; Object = $obj; Error = $null }
    }
    catch {
        $bak = "$CachePath.bak"
        Copy-Item -LiteralPath $CachePath -Destination $bak -Force
        Write-AIWorkspaceWarn "invalid cache JSON kept intact. Backup: $bak"
        Write-AIWorkspaceWarn "cache parse error: $($_.Exception.Message)"
        # Always preserve original + .bak; never overwrite caller-side
        return [pscustomobject]@{ Ok = $false; Object = $null; Error = $_.Exception.Message; Backup = $bak }
    }
}

function Get-TasksProgressSummary {
    param([string]$TasksPath)

    $text = Read-Utf8File -Path $TasksPath
    if ($null -eq $text) {
        return [pscustomobject]@{ Todo = 0; Done = 0; OpenItems = @() }
    }

    $todo = 0
    $done = 0
    $open = New-Object System.Collections.Generic.List[string]
    $rx = '^[ \t]*(?:[-*+]|\d+\.)[ \t]+\[([ xX])\][ \t]*(.*)$'
    # Skip fenced code blocks (``` / ~~~) — marker-bit state machine
    $inFence = $false
    $fenceChar = $null
    $fenceLen = 0
    foreach ($line in ($text -split "`r?`n")) {
        if ($line -match '^[ \t]*([`~]{3,})(.*)$') {
            $marker = $Matches[1]
            $ch = $marker.Substring(0, 1)
            $len = $marker.Length
            $info = $Matches[2]
            if (-not $inFence) {
                $inFence = $true
                $fenceChar = $ch
                $fenceLen = $len
                continue
            }
            # Closing fence: same character, length >= open, empty info string
            if (($ch -eq $fenceChar) -and ($len -ge $fenceLen) -and ($info -match '^\s*$')) {
                $inFence = $false
                $fenceChar = $null
                $fenceLen = 0
                continue
            }
        }
        if ($inFence) { continue }

        if ($line -notmatch $rx) { continue }
        $mark = $Matches[1]
        $item = $Matches[2].Trim()
        if ($item -eq "(none)" -or [string]::IsNullOrWhiteSpace($item)) { continue }
        if ($mark -match '^[xX]$') {
            $done++
        }
        else {
            $todo++
            $open.Add($item) | Out-Null
        }
    }
    if ($inFence) {
        Write-AIWorkspaceWarn "unclosed fenced code block in $TasksPath — trailing lines ignored for progress"
    }
    return [pscustomobject]@{
        Todo      = $todo
        Done      = $done
        OpenItems = $open.ToArray()
    }
}

function Get-DerivedModuleStatus {
    param([int]$Todo, [int]$Done)
    if ($Todo -eq 0 -and $Done -gt 0) { return "done" }
    if ($Done -gt 0) { return "in_progress" }
    return "initialized"
}

function Ensure-AIWorkspaceGitkeeps {
    param([string]$BundleRoot)
    foreach ($folder in @("agents", "skills", "cache", "specs", "bugfix", ".locks", ".trash")) {
        $dir = Join-Path $BundleRoot $folder
        if (-not (Test-Path -LiteralPath $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
        $keep = Join-Path $dir ".gitkeep"
        if (-not (Test-Path -LiteralPath $keep)) {
            Write-Utf8NoBomFile -Path $keep -Content ""
        }
    }
}

function Test-AIWorkspaceManifest {
    param(
        [string]$ToolkitDir = $PSScriptRoot,
        [switch]$Strict
    )

    $strictMode = $Strict -or ($env:AIWORKSPACE_STRICT_MANIFEST -eq "1")
    $manifestPath = Join-Path $ToolkitDir "manifest.json"
    if (-not (Test-Path -LiteralPath $manifestPath)) {
        $msg = "manifest.json missing in $ToolkitDir (run install-cursor-global-skill.ps1)"
        if ($strictMode) { throw $msg }
        Write-AIWorkspaceWarn $msg
        return $false
    }
    try {
        $man = (Read-Utf8File -Path $manifestPath) | ConvertFrom-Json
        $ok = $true
        $errors = New-Object System.Collections.Generic.List[string]
        foreach ($entry in $man.files) {
            $fp = Join-Path $ToolkitDir $entry.name
            if (-not (Test-Path -LiteralPath $fp)) {
                $errors.Add("manifest file missing: $($entry.name)") | Out-Null
                $ok = $false
                continue
            }
            $hash = (Get-FileHash -LiteralPath $fp -Algorithm SHA256).Hash.ToLowerInvariant()
            if ($hash -ne ([string]$entry.sha256).ToLowerInvariant()) {
                $errors.Add("hash mismatch: $($entry.name)") | Out-Null
                $ok = $false
            }
        }
        if ($man.version -ne (Get-AIWorkspaceToolkitVersion)) {
            $errors.Add("VERSION $(Get-AIWorkspaceToolkitVersion) != manifest $($man.version)") | Out-Null
            $ok = $false
        }
        if (-not $ok) {
            foreach ($e in $errors) {
                if ($strictMode) { Write-Host "ERROR: $e" -ForegroundColor Red }
                else { Write-AIWorkspaceWarn $e }
            }
            if ($strictMode) {
                throw "Manifest validation failed ($($errors.Count) issue(s)). Re-run install-cursor-global-skill.ps1 from the template repo."
            }
        }
        return $ok
    }
    catch {
        if ($strictMode) { throw }
        Write-AIWorkspaceWarn "cannot validate manifest: $($_.Exception.Message)"
        return $false
    }
}

function Assert-AIWorkspaceToolkitReady {
    param([string]$ToolkitDir = $PSScriptRoot)
    $rt = Get-AIWorkspaceRuntimeInfo
    Write-Host "Runtime: PS $($rt.PSVersion) ($($rt.Edition)) on $($rt.OS) | toolkit $($rt.Toolkit)"
    $manifestPath = Join-Path $ToolkitDir "manifest.json"
    if (-not (Test-Path -LiteralPath $manifestPath)) { return }
    # Global toolkit (~/.cursor or ~/.trae-cn skills/.../toolkit): hard-fail on drift unless AIWORKSPACE_STRICT_MANIFEST=0
    $isGlobal = Test-AIWorkspaceIsGlobalToolkitPath -ToolkitDir $ToolkitDir
    $forceSoft = ($env:AIWORKSPACE_STRICT_MANIFEST -eq "0")
    $forceHard = ($env:AIWORKSPACE_STRICT_MANIFEST -eq "1")
    if (($isGlobal -or $forceHard) -and -not $forceSoft) {
        try {
            Test-AIWorkspaceManifest -ToolkitDir $ToolkitDir -Strict | Out-Null
        }
        catch {
            Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "Re-run install from the template repo, or set AIWORKSPACE_STRICT_MANIFEST=0 to warn-only."
            exit (Get-AIWorkspaceExitCode -Kind Manifest)
        }
    }
    else {
        [void](Test-AIWorkspaceManifest -ToolkitDir $ToolkitDir)
    }
}

function Write-AIWorkspaceJson {
    param([Parameter(Mandatory = $true)]$Object)
    $Object | ConvertTo-Json -Depth 8 -Compress:$false
}

function Get-AIWorkspaceBatchStatePath {
    param([Parameter(Mandatory = $true)][string]$BundleRoot)
    return (Join-Path (Join-Path $BundleRoot "cache") ".batch-progress.json")
}

function Read-AIWorkspaceBatchState {
    param([Parameter(Mandatory = $true)][string]$BundleRoot)
    $p = Get-AIWorkspaceBatchStatePath -BundleRoot $BundleRoot
    if (-not (Test-Path -LiteralPath $p)) { return $null }
    try {
        return (Read-Utf8File -Path $p -Strict) | ConvertFrom-Json
    }
    catch {
        Write-AIWorkspaceWarn "corrupt batch state ignored: $p"
        return $null
    }
}

function Write-AIWorkspaceBatchState {
    param(
        [Parameter(Mandatory = $true)][string]$BundleRoot,
        [Parameter(Mandatory = $true)]$State
    )
    $p = Get-AIWorkspaceBatchStatePath -BundleRoot $BundleRoot
    Write-Utf8NoBomFile -Path $p -Content ($State | ConvertTo-Json -Depth 6)
}
