# AI Workspace shared config + helpers (production)
# Status enum (cache.status): initialized | in_progress | done | unknown
# Supports Windows PowerShell 5.1+ and PowerShell 7+ (Win/macOS/Linux)
$script:AIWorkspaceBundleDirName = "codestatrFirst"
$script:AIWorkspaceToolkitVersion = "1.3.0"
$script:AIWorkspaceStatusEnum = @("initialized", "in_progress", "done", "unknown")

function Get-AIWorkspaceBundleDirName {
    return $script:AIWorkspaceBundleDirName
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

function Get-AIWorkspaceCursorSkillsRoot {
    return (Join-Path (Get-AIWorkspaceHomeDirectory) (Join-Path ".cursor" "skills"))
}

function Get-AIWorkspaceGlobalSkillPath {
    return (Join-Path (Get-AIWorkspaceCursorSkillsRoot) "aiworkspace-manager")
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
    if (Test-Path -LiteralPath (Join-Path $FullPath $script:AIWorkspaceBundleDirName)) { return $true }
    $initScript = Join-Path (Join-Path $FullPath "skills") "init-workspace.ps1"
    if (Test-Path -LiteralPath $initScript) { return $true }
    if (Test-Path -LiteralPath (Join-Path (Join-Path $FullPath ".cursor") "skills")) { return $true }
    return $false
}

function Write-AIWorkspaceAllowAnyRootWarning {
    Write-Host ""
    Write-Host "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" -ForegroundColor Red
    Write-Host " SECURITY: AIWORKSPACE_ALLOW_ANY_ROOT=1 is set." -ForegroundColor Red
    Write-Host " Path safeguards (drive/system/project-shape checks) are OFF." -ForegroundColor Red
    Write-Host " Unset the variable unless you intentionally need the escape hatch." -ForegroundColor Red
    Write-Host "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" -ForegroundColor Red
    Write-Host ""
}

function Assert-AIWorkspaceRootSafe {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepositoryRoot
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
        throw "Refusing -Root that does not look like a project: $full`nRequire .git, existing codestatrFirst/, or skills/init-workspace.ps1.`nOverride: AIWORKSPACE_ALLOW_ANY_ROOT=1 (DANGEROUS)"
    }
}

function Resolve-AIRepositoryRoot {
    param(
        [string]$Root = ".",
        [string]$ScriptHome = $PSScriptRoot
    )

    $candidate = $null
    if (-not [string]::IsNullOrWhiteSpace($Root) -and ($Root -ne ".")) {
        $candidate = $Root
    }
    elseif (-not [string]::IsNullOrWhiteSpace($env:AIWORKSPACE_PROJECT_ROOT)) {
        $candidate = $env:AIWORKSPACE_PROJECT_ROOT.Trim()
    }
    else {
        $parent = Split-Path -Parent $ScriptHome
        $leaf = Split-Path -Leaf $ScriptHome
        $grand = Split-Path -Leaf $parent
        $isGlobalToolkit = ($leaf -ieq "toolkit") -or ($grand -ieq "aiworkspace-manager")
        if ($isGlobalToolkit -and ($ScriptHome -match '[\\/]\.cursor[\\/]skills[\\/]')) {
            throw "Global toolkit requires -Root `"<project>`" or AIWORKSPACE_PROJECT_ROOT."
        }
        $candidate = $parent
    }

    if (Test-IsUncPath -Path $candidate) {
        throw "Refusing UNC path: $candidate"
    }

    if (-not (Test-Path -LiteralPath $candidate)) {
        throw "Project root does not exist: $candidate`nCreate it first, then re-run with -Root."
    }

    $resolved = (Get-Item -LiteralPath $candidate).FullName
    Assert-AIWorkspaceRootSafe -RepositoryRoot $resolved
    return $resolved
}

function Get-AIWorkspaceBundlePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepositoryRoot
    )
    return Join-Path $RepositoryRoot $script:AIWorkspaceBundleDirName
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
        throw "Timeout acquiring workspace lock '$LockName' after ${TimeoutSeconds}s: $lockPath`nAnother process may be writing cache/specs."
    }
    try {
        return & $Action
    }
    finally {
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
        Write-Host "WARN: file may not be UTF-8: $Path (re-save as UTF-8 recommended)"
    }
    return [System.Text.Encoding]::UTF8.GetString($bytes)
}

function Normalize-AIWorkspaceName {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Value,
        [string]$FallbackPrefix = "module",
        [switch]$AllowFallback
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        if ($AllowFallback) {
            return "$FallbackPrefix-" + (Get-Date -Format "yyyyMMddHHmmss")
        }
        throw "Name/Title/ModuleName cannot be empty or whitespace."
    }

    $normalized = $Value.Trim().ToLowerInvariant()
    $normalized = $normalized -replace "\s+", "-"
    $normalized = $normalized -replace "[^\p{L}\p{N}\-_]", "-"
    $normalized = $normalized -replace "-{2,}", "-"
    $normalized = $normalized.Trim("-")
    if ([string]::IsNullOrWhiteSpace($normalized)) {
        if ($AllowFallback) {
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
        [string]$CreatedAt = ""
    )

    $bundleName = Get-AIWorkspaceBundleDirName
    if ([string]::IsNullOrWhiteSpace($CreatedAt)) {
        $CreatedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
    return [ordered]@{
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
}

function Write-ModuleCacheJson {
    param(
        [Parameter(Mandatory = $true)][string]$BundleRoot,
        [Parameter(Mandatory = $true)][string]$ModuleName,
        [Parameter(Mandatory = $true)][System.Collections.IDictionary]$Fields
    )

    return Invoke-WithAIWorkspaceLock -BundleRoot $BundleRoot -LockName "cache-$ModuleName" -Action {
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
}

function Read-ModuleCacheJson {
    param(
        [Parameter(Mandatory = $true)][string]$CachePath,
        [switch]$NoOverwriteOnError
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
        Write-Host "WARN: invalid cache JSON kept intact. Backup: $bak"
        Write-Host "      Error: $($_.Exception.Message)"
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
    foreach ($line in ($text -split "`r?`n")) {
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
        Write-Host "WARN: $msg"
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
                else { Write-Host "WARN: $e" }
            }
            if ($strictMode) {
                throw "Manifest validation failed ($($errors.Count) issue(s)). Re-run install-cursor-global-skill.ps1 from the template repo."
            }
        }
        return $ok
    }
    catch {
        if ($strictMode) { throw }
        Write-Host "WARN: cannot validate manifest: $($_.Exception.Message)"
        return $false
    }
}

function Assert-AIWorkspaceToolkitReady {
    param([string]$ToolkitDir = $PSScriptRoot)
    $rt = Get-AIWorkspaceRuntimeInfo
    Write-Host "Runtime: PS $($rt.PSVersion) ($($rt.Edition)) on $($rt.OS) | toolkit $($rt.Toolkit)"
    if (Test-Path -LiteralPath (Join-Path $ToolkitDir "manifest.json")) {
        # Installed global copy: default soft check; hard-fail if STRICT_MANIFEST=1
        [void](Test-AIWorkspaceManifest -ToolkitDir $ToolkitDir)
    }
}
