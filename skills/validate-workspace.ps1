<#
.SYNOPSIS
Smoke + regression matrix for AI Workspace toolkit. Exit 0 = OK.
#>
param(
    [string]$Root = ".",
    [switch]$SkipWriteTest
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "workspace-config.ps1")

$failed = 0
function Assert-True([bool]$Cond, [string]$Msg) {
    if ($Cond) { Write-Host "[OK] $Msg" }
    else { Write-Host "[FAIL] $Msg"; $script:failed++ }
}

$ver = Get-AIWorkspaceToolkitVersion
$rt = Get-AIWorkspaceRuntimeInfo
Write-Host "=== validate-workspace (toolkit $ver | PS $($rt.PSVersion) $($rt.Edition) / $($rt.OS)) ==="

foreach ($f in @(
        "workspace-config.ps1", "init-workspace.ps1", "auto-requirement.ps1",
        "new-module-spec.ps1", "new-bugfix.ps1", "resume-workspace.ps1",
        "validate-workspace.ps1", "install-cursor-global-skill.ps1",
        "uninstall-cursor-global-skill.ps1", "run-tests.ps1", "analyze-workspace.ps1", "VERSION"
    )) {
    Assert-True (Test-Path -LiteralPath (Join-Path $PSScriptRoot $f)) "present: $f"
}

# Markdown injection neutralization
$inj = Protect-AIWorkspaceMarkdownText -Value "T1`n## Injected" -Mode Inline
Assert-True ($inj -notmatch '(?m)^##') "title inline has no ATX heading"
Assert-True ($inj.Contains([string]::new([char]0xFF03, 2))) "heading hashes fullwidth-escaped"
Assert-True ($inj -notmatch '##') "no ASCII ## left in inline title"
$injBlock = Protect-AIWorkspaceMarkdownText -Value "- [ ] fake todo" -Mode Block
Assert-True ($injBlock -notmatch '\[ \]') "checkbox brackets neutralized"
Assert-True ($injBlock -match '［ ］') "checkbox uses fullwidth brackets"

# Naming
try {
    Normalize-AIWorkspaceName -Value " " | Out-Null
    Assert-True $false "blank name should throw"
}
catch { Assert-True $true "blank name throws" }

$n1 = Normalize-AIWorkspaceName -Value "用户登录 Login"
Assert-True ($n1 -match "login") "normalize CJK+ASCII"

# Checkbox regex
$tmpTasks = Join-Path ([IO.Path]::GetTempPath()) ("aiws-tasks-" + [guid]::NewGuid().ToString("N") + ".md")
@(
    "- [ ] dash todo",
    "* [ ] star todo",
    "+ [ ] plus todo",
    "1. [ ] numbered todo",
    "- [x] done item",
    "- [ ] (none)"
) | Set-Content -Path $tmpTasks -Encoding UTF8
$prog = Get-TasksProgressSummary -TasksPath $tmpTasks
Assert-True ($prog.Todo -eq 4 -and $prog.Done -eq 1) "checkbox variants TODO=4 DONE=1 (got T=$($prog.Todo) D=$($prog.Done))"
Remove-Item $tmpTasks -Force -ErrorAction SilentlyContinue

# Fenced checkboxes must be ignored
$fenceTasks = Join-Path ([IO.Path]::GetTempPath()) ("aiws-fence-" + [guid]::NewGuid().ToString("N") + ".md")
@(
    "- [ ] real one",
    "- [ ] real two",
    '```',
    "- [ ] fake inside fence",
    "- [x] also fake",
    '```',
    "~~~md",
    "- [ ] tilde fence fake",
    "~~~"
) | Set-Content -Path $fenceTasks -Encoding UTF8
$fp = Get-TasksProgressSummary -TasksPath $fenceTasks
Assert-True ($fp.Todo -eq 2 -and $fp.Done -eq 0) "skip fenced todos TODO=2 (got T=$($fp.Todo) D=$($fp.Done))"
Assert-True ($fp.OpenItems -notcontains "fake inside fence") "fence item not in OpenItems"
Remove-Item $fenceTasks -Force -ErrorAction SilentlyContinue

# Status derivation
Assert-True ((Get-DerivedModuleStatus -Todo 4 -Done 0) -eq "initialized") "status initialized"
Assert-True ((Get-DerivedModuleStatus -Todo 2 -Done 1) -eq "in_progress") "status in_progress"
Assert-True ((Get-DerivedModuleStatus -Todo 0 -Done 3) -eq "done") "status done"

# Forbidden roots
$threw = $false
try { Assert-AIWorkspaceRootSafe -RepositoryRoot "C:\Windows" } catch { $threw = $true }
Assert-True $threw "block C:\Windows"
$threw = $false
try { Assert-AIWorkspaceRootSafe -RepositoryRoot "D:\" } catch { $threw = $true }
Assert-True $threw "block drive root D:\"

# Bootstrap: without flag fails; with flag allows empty OR dir with README
$emptyDir = Join-Path ([IO.Path]::GetTempPath()) ("aiws-empty-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $emptyDir | Out-Null
try {
    $threw = $false
    try { Assert-AIWorkspaceRootSafe -RepositoryRoot $emptyDir } catch { $threw = $true }
    Assert-True $threw "empty dir rejected without bootstrap"
    $threw = $false
    try { Assert-AIWorkspaceRootSafe -RepositoryRoot $emptyDir -AllowEmptyBootstrap } catch { $threw = $true }
    Assert-True (-not $threw) "empty dir allowed with AllowEmptyBootstrap"
    Write-Utf8NoBomFile -Path (Join-Path $emptyDir "README.md") -Content "# hi"
    $threw = $false
    try { Assert-AIWorkspaceRootSafe -RepositoryRoot $emptyDir -AllowEmptyBootstrap } catch { $threw = $true }
    Assert-True (-not $threw) "README-only dir allowed with AllowEmptyBootstrap"
}
finally {
    Remove-Item -LiteralPath $emptyDir -Recurse -Force -ErrorAction SilentlyContinue
}

# Exit code helpers
Assert-True ((Get-AIWorkspaceExitCode -Kind Ok) -eq 0) "exit Ok=0"
Assert-True ((Get-AIWorkspaceExitCode -Kind Manifest) -eq 4) "exit Manifest=4"

# AsciiNames
$ascii = Normalize-AIWorkspaceName -Value "用户登录 Login" -AsciiOnly
Assert-True ($ascii -match '^[a-z0-9\-]+$' -and $ascii -match 'login') "AsciiOnly strips CJK"

# Missing root message before Get-Item
$threw = $false
$msg = ""
try { Resolve-AIRepositoryRoot -Root "D:\__aiws_no_such_dir_xyz__" -ScriptHome $PSScriptRoot } catch {
    $threw = $true
    $msg = $_.Exception.Message
}
Assert-True ($threw -and $msg -match "does not exist") "missing -Root friendly error"

# Home / global path helpers (cross-platform)
$homeDir = Get-AIWorkspaceHomeDirectory
Assert-True (-not [string]::IsNullOrWhiteSpace($homeDir)) "home directory resolved"
$gSkill = Get-AIWorkspaceGlobalSkillPath
Assert-True ($gSkill -like "*aiworkspace-manager") "global skill path shape"

# File lock: hold exclusive FileStream, second acquire must time out
$lockBundle = Join-Path ([IO.Path]::GetTempPath()) ("aiws-lock-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $lockBundle | Out-Null
$holder = $null
try {
    $lockDir = Ensure-AIWorkspaceLockDir -BundleRoot $lockBundle
    $lockPath = Join-Path $lockDir "t.lock"
    $holder = [System.IO.File]::Open(
        $lockPath,
        [System.IO.FileMode]::OpenOrCreate,
        [System.IO.FileAccess]::ReadWrite,
        [System.IO.FileShare]::None
    )
    $timeoutOk = $false
    try {
        Invoke-WithAIWorkspaceLock -BundleRoot $lockBundle -LockName "t" -TimeoutSeconds 1 -Action { "nope" } | Out-Null
    }
    catch {
        $timeoutOk = ($_.Exception.Message -match "Timeout acquiring")
    }
    Assert-True $timeoutOk "file lock contention times out"
}
finally {
    if ($null -ne $holder) { $holder.Dispose() }
    Remove-Item -LiteralPath $lockBundle -Recurse -Force -ErrorAction SilentlyContinue
}

# Manifest strict fail on drift
$manDir = Join-Path ([IO.Path]::GetTempPath()) ("aiws-man-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $manDir | Out-Null
try {
    Write-Utf8NoBomFile -Path (Join-Path $manDir "VERSION") -Content "1.3.0`n"
    Write-Utf8NoBomFile -Path (Join-Path $manDir "dummy.ps1") -Content "# x`n"
    $hash = (Get-FileHash -LiteralPath (Join-Path $manDir "dummy.ps1") -Algorithm SHA256).Hash.ToLowerInvariant()
    $man = [ordered]@{
        version = "1.3.0"
        files   = @(@{ name = "dummy.ps1"; sha256 = $hash; bytes = 1 }, @{ name = "VERSION"; sha256 = "deadbeef"; bytes = 1 })
    }
    Write-Utf8NoBomFile -Path (Join-Path $manDir "manifest.json") -Content ($man | ConvertTo-Json -Depth 6)
    $strictThrew = $false
    try { Test-AIWorkspaceManifest -ToolkitDir $manDir -Strict | Out-Null } catch { $strictThrew = $true }
    Assert-True $strictThrew "manifest Strict fails on hash drift"

    # Fix VERSION entry hash so only soft mode would pass if we fix - actually leave broken
    $soft = Test-AIWorkspaceManifest -ToolkitDir $manDir
    Assert-True (-not $soft) "manifest soft returns false on drift"
}
finally {
    Remove-Item -LiteralPath $manDir -Recurse -Force -ErrorAction SilentlyContinue
}

# Uninstall to temp SkillRoot
$fakeSkill = Join-Path ([IO.Path]::GetTempPath()) ("aiws-uninst-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path (Join-Path $fakeSkill "toolkit") -Force | Out-Null
Write-Utf8NoBomFile -Path (Join-Path $fakeSkill "SKILL.md") -Content "test"
& (Join-Path $PSScriptRoot "uninstall-cursor-global-skill.ps1") -Force -SkillRoot $fakeSkill
Assert-True (-not (Test-Path -LiteralPath $fakeSkill)) "uninstall moves skill root away"
$parentTrash = Join-Path (Split-Path -Parent $fakeSkill) ".trash"
$bakHit = @(Get-ChildItem -LiteralPath $parentTrash -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "aiworkspace-manager-*" })
Assert-True ($bakHit.Count -ge 1) "uninstall backup under .trash"
Remove-Item -LiteralPath $parentTrash -Recurse -Force -ErrorAction SilentlyContinue

# init on brand-new empty directory (no .git)
$emptyInit = Join-Path ([IO.Path]::GetTempPath()) ("aiws-boot-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $emptyInit | Out-Null
try {
    & (Join-Path $PSScriptRoot "init-workspace.ps1") -Root $emptyInit
    $eb = Get-AIWorkspaceBundlePath -RepositoryRoot $emptyInit
    Assert-True (Test-Path -LiteralPath $eb) "init bootstraps empty directory"
}
finally {
    Remove-Item -LiteralPath $emptyInit -Recurse -Force -ErrorAction SilentlyContinue
}

# Integration fixture
$tmpRoot = Join-Path ([IO.Path]::GetTempPath()) ("aiws-val-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tmpRoot | Out-Null
New-Item -ItemType Directory -Path (Join-Path $tmpRoot ".git") -Force | Out-Null
try {
    & (Join-Path $PSScriptRoot "init-workspace.ps1") -Root $tmpRoot
    $bundle = Get-AIWorkspaceBundlePath -RepositoryRoot $tmpRoot
    $docName = Get-AIWorkspaceProjectDocFileName
    Assert-True (Test-Path -LiteralPath (Join-Path $bundle $docName)) "project doc: $docName"
    Assert-True (Test-Path -LiteralPath (Join-Path $bundle (Join-Path "specs" ".gitkeep"))) "gitkeep specs"
    Assert-True (Test-Path -LiteralPath (Join-Path $bundle (Join-Path ".locks" ".gitkeep"))) "gitkeep .locks"

    $safeFile = Join-Path $bundle "璇璋.md"
    Write-Utf8NoBomFile -Path $safeFile -Content "keep me"
    & (Join-Path $PSScriptRoot "init-workspace.ps1") -Root $tmpRoot
    Assert-True (Test-Path -LiteralPath $safeFile) "do not delete 璇璋.md"

    if (-not $SkipWriteTest) {
        & (Join-Path $PSScriptRoot "auto-requirement.ps1") -Root $tmpRoot -Title "校验模块" -Requirement "smoke|with-pipe" -Priority P3
        $mods = @(Get-ChildItem -LiteralPath (Join-Path $bundle "specs") -Directory)
        Assert-True ($mods.Count -ge 1) "auto-requirement module"
        $cj = Get-ChildItem -LiteralPath (Join-Path $bundle "cache") -Filter "*.json" | Select-Object -First 1
        $cacheObj = (Read-Utf8File -Path $cj.FullName) | ConvertFrom-Json
        Assert-True ($cacheObj.status -eq "initialized") "new module status initialized"
        Assert-True ($null -ne $cacheObj.open_todo_count) "open_todo_count present"
        Assert-True ($null -ne $cacheObj.schema_version) "schema_version present"

        & (Join-Path $PSScriptRoot "new-module-spec.ps1") -Root $tmpRoot -ModuleName "mod-b"
        & (Join-Path $PSScriptRoot "new-bugfix.ps1") -Root $tmpRoot -Title "bug-a"
        & (Join-Path $PSScriptRoot "new-bugfix.ps1") -Root $tmpRoot -Title "bug-a" -FollowUpNote "second pass"
        $bugs = @(Get-ChildItem -LiteralPath (Join-Path $bundle "bugfix") -Filter "*.md")
        Assert-True ($bugs.Count -eq 1) "new-bugfix same-day still one file"
        $bugText = Read-Utf8File -Path $bugs[0].FullName
        Assert-True ($bugText -match '(?m)^## Follow-up') "bugfix appends Follow-up on second run"

        # Ambiguous prefix: login-a + login-b (no exact "login")
        New-Item -ItemType Directory -Path (Join-Path $bundle (Join-Path "specs" "login-a")) -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $bundle (Join-Path "specs" "login-b")) -Force | Out-Null
        Write-Utf8NoBomFile -Path (Join-Path (Join-Path $bundle (Join-Path "specs" "login-a")) "tasks.md") -Content "# t`n- [ ] a`n"
        Write-Utf8NoBomFile -Path (Join-Path (Join-Path $bundle (Join-Path "specs" "login-b")) "tasks.md") -Content "# t`n- [ ] b`n"
        $amb = $false
        try {
            & (Join-Path $PSScriptRoot "resume-workspace.ps1") -Root $tmpRoot -Module login | Out-Null
        }
        catch {
            $amb = ($_.Exception.Message -match "Ambiguous module prefix")
        }
        Assert-True $amb "ambiguous prefix throws without -ExactModule"
        & (Join-Path $PSScriptRoot "resume-workspace.ps1") -Root $tmpRoot -Module login-a -ExactModule | Out-Null
        Assert-True $true "ExactModule resolves login-a alone"

        # Corrupt cache
        $badMod = "badmod"
        New-Item -ItemType Directory -Path (Join-Path $bundle (Join-Path "specs" $badMod)) -Force | Out-Null
        Write-Utf8NoBomFile -Path (Join-Path (Join-Path $bundle (Join-Path "specs" $badMod)) "tasks.md") -Content "# Tasks`n`n## TODO`n- [ ] a`n"
        $bad = Join-Path $bundle (Join-Path "cache" "$badMod.json")
        Write-Utf8NoBomFile -Path $bad -Content "{not-json"
        $before = Get-FileHash -LiteralPath $bad -Algorithm SHA256
        & (Join-Path $PSScriptRoot "resume-workspace.ps1") -Root $tmpRoot -Module $badMod -ExactModule -SyncCache | Out-Null
        Assert-True (Test-Path -LiteralPath "$bad.bak") "corrupt cache .bak created"
        $after = Get-FileHash -LiteralPath $bad -Algorithm SHA256
        Assert-True ($before.Hash -eq $after.Hash) "corrupt cache not overwritten"

        $batch = Join-Path $tmpRoot "b.txt"
        Write-Utf8NoBomFile -Path $batch -Content @"
# this is a comment (hash+space)
# also comment with | inside because of space after hash
T1|req with | pipe inside|P1
#hash-title|must keep this|P2
"@
        & (Join-Path $PSScriptRoot "auto-requirement.ps1") -Root $tmpRoot -BatchFile $batch
        $hashMod = Join-Path $bundle (Join-Path "specs" "hash-title")
        Assert-True (Test-Path -LiteralPath $hashMod) "batch keeps #title|req (no space after #)"
        $falseMod = Join-Path $bundle (Join-Path "specs" "also")
        Assert-True (-not (Test-Path -LiteralPath $falseMod)) "batch # space line with | is comment"

        # Same title twice → uniquify -2 + capturable warning
        $dupWarn = $null
        $null = & (Join-Path $PSScriptRoot "auto-requirement.ps1") -Root $tmpRoot -Title "DupMod" -Requirement "first" -Priority P2 3>&1 | ForEach-Object { $dupWarn += "`n$_"; $_ }
        $null = & (Join-Path $PSScriptRoot "auto-requirement.ps1") -Root $tmpRoot -Title "DupMod" -Requirement "second" -Priority P2 3>&1 | ForEach-Object { $dupWarn += "`n$_"; $_ }
        Assert-True (Test-Path -LiteralPath (Join-Path $bundle (Join-Path "specs" "dupmod"))) "first DupMod folder"
        Assert-True (Test-Path -LiteralPath (Join-Path $bundle (Join-Path "specs" "dupmod-2"))) "second DupMod becomes dupmod-2"
        Assert-True ($dupWarn -match "already exists") "uniquify warning on warning stream"

        # Injection does not create ATX heading / real checkbox in spec
        $injTitle = "T1" + [char]10 + "## Injected"
        & (Join-Path $PSScriptRoot "auto-requirement.ps1") -Root $tmpRoot -Title $injTitle -Requirement "- [ ] fake" -Priority P3
        $injSpec = Get-ChildItem -LiteralPath (Join-Path $bundle "specs") -Directory | Where-Object { $_.Name -like "t1*" } | Select-Object -First 1
        $specBody = Read-Utf8File -Path (Join-Path $injSpec.FullName "spec.md")
        Assert-True ($specBody -notmatch '(?m)^## Injected') "no injected ATX heading in spec"
        Assert-True ($specBody -notmatch '(?m)^- \[ \] fake') "no injected real checkbox in spec"

        # SyncCache normalizes invalid priority/status and display matches disk
        $fixMod = "fixprio"
        New-Item -ItemType Directory -Path (Join-Path $bundle (Join-Path "specs" $fixMod)) -Force | Out-Null
        Write-Utf8NoBomFile -Path (Join-Path (Join-Path $bundle (Join-Path "specs" $fixMod)) "tasks.md") -Content "# t`n- [ ] a`n"
        $fixCache = Join-Path $bundle (Join-Path "cache" "$fixMod.json")
        Write-Utf8NoBomFile -Path $fixCache -Content (@{
                schema_version = 1; module = $fixMod; title = $fixMod; requirement = "r"
                priority = "P9"; status = "bogus"; open_todo_count = 1; done_count = 0
            } | ConvertTo-Json)
        $warnBuf = $null
        $null = & (Join-Path $PSScriptRoot "resume-workspace.ps1") -Root $tmpRoot -Module $fixMod -ExactModule -SyncCache `
            3>&1 2>&1 | ForEach-Object {
            $warnBuf += "`n$($_.ToString())"
            $_
        } | Out-String
        Assert-True ($warnBuf -match '修正缓存优先级 P9→P2') "WARN priority normalize"
        Assert-True ($warnBuf -match '修正缓存 status bogus→') "WARN status normalize"
        $fixed = (Read-Utf8File -Path $fixCache) | ConvertFrom-Json
        Assert-True ($fixed.priority -eq "P2") "cache priority written P2"
        Assert-True ($fixed.status -eq "initialized") "cache status written initialized"
        # Display uses same $priority/$status after SyncCache (Write-Host); disk is source of truth
    }
}
finally {
    if (Test-Path -LiteralPath $tmpRoot) {
        Remove-Item -LiteralPath $tmpRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Docs / release artifacts present in template repo (when running from skills/)
$repoRootGuess = Split-Path -Parent $PSScriptRoot
foreach ($doc in @("CHANGELOG.md", "LICENSE", "RELEASE.md", "README.md")) {
    $p = Join-Path $repoRootGuess $doc
    if (Test-Path -LiteralPath $p) {
        Assert-True $true "repo doc: $doc"
    }
    else {
        Write-Host "[WARN] missing repo doc (ok if validating installed toolkit only): $doc"
    }
}

Write-Host ""
if ($failed -gt 0) {
    Write-Host "FAILED: $failed check(s)"
    exit 1
}
Write-Host "All checks passed."
exit 0
