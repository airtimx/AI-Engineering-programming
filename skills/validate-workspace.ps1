<#
.SYNOPSIS
Smoke + regression matrix for AI Workspace toolkit. Exit 0 = OK.
.PARAMETER Quiet
Only print [OK]/[FAIL]/EXPECT-ERROR lines and final summary (hide sandbox Ready:/Exists: noise).
.PARAMETER VerboseSandbox
With -Quiet, still show child-script host output (init/auto/resume paths).
#>
param(
    [string]$Root = ".",
    [switch]$SkipWriteTest,
    [switch]$Quiet,
    [switch]$VerboseSandbox
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "workspace-config.ps1")
$resolvedRoot = Resolve-AIRepositoryRoot -Root $Root -ScriptHome $PSScriptRoot -AllowEmptyBootstrap -SkipDetectConfirm

$failed = 0
function Assert-True([bool]$Cond, [string]$Msg) {
    if ($Cond) { Write-Host "[OK] $Msg" }
    else { Write-Host "[FAIL] $Msg"; $script:failed++ }
}

# Quiet: shadow Write-Host so child scripts (init/auto/...) do not spam sandbox paths.
# Assert-True / EXPECT-ERROR / banner still pass through.
if ($Quiet -and -not $VerboseSandbox) {
    function Write-Host {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
            "PSAvoidOverwritingBuiltInCmdlets",
            "",
            Justification = "Intentional local output shim filters child-script noise while preserving validate assertions."
        )]
        [CmdletBinding()]
        param(
            [Parameter(Position = 0, ValueFromRemainingArguments = $true)]
            [object[]]$Object,
            [ConsoleColor]$ForegroundColor,
            [ConsoleColor]$BackgroundColor,
            [switch]$NoNewline
        )
        $msg = ""
        if ($null -ne $Object) {
            $msg = ($Object | ForEach-Object { "$_" }) -join " "
        }
        $keep = ($msg -match '^\[(OK|FAIL|WARN)\]') -or
            ($msg -match '^EXPECT-ERROR:') -or
            ($msg -match '^(FAILED:|All checks passed)') -or
            ($msg -match '^=== validate-workspace')
        if ($keep) {
            $splat = @{ Object = $Object }
            if ($PSBoundParameters.ContainsKey("ForegroundColor")) { $splat["ForegroundColor"] = $ForegroundColor }
            if ($PSBoundParameters.ContainsKey("BackgroundColor")) { $splat["BackgroundColor"] = $BackgroundColor }
            if ($NoNewline) { $splat["NoNewline"] = $true }
            Microsoft.PowerShell.Utility\Write-Host @splat
        }
    }
}

$ver = Get-AIWorkspaceToolkitVersion
$rt = Get-AIWorkspaceRuntimeInfo
Write-Host "=== validate-workspace (toolkit $ver | PS $($rt.PSVersion) $($rt.Edition) / $($rt.OS) | root $resolvedRoot) ==="

foreach ($f in @(
        "workspace-config.ps1", "init-workspace.ps1", "auto-requirement.ps1",
        "new-module-spec.ps1", "new-bugfix.ps1", "resume-workspace.ps1",
        "validate-workspace.ps1", "aiws.ps1", "doctor-workspace.ps1", "claim-module.ps1",
        "install-global-skill.ps1", "uninstall-global-skill.ps1",
        "install-cursor-global-skill.ps1", "uninstall-cursor-global-skill.ps1",
        "run-tests.ps1", "analyze-workspace.ps1", "dependency-versions.ps1", "VERSION", "requirements.batch.example.txt"
    )) {
    Assert-True (Test-Path -LiteralPath (Join-Path $PSScriptRoot $f)) "present: $f"
}

# PS 5.1 requires UTF-8 BOM on scripts that may contain non-ASCII
$bomFail = 0
Get-ChildItem -LiteralPath $PSScriptRoot -Filter "*.ps1" | ForEach-Object {
    if (-not (Test-AIWorkspaceFileHasUtf8Bom -Path $_.FullName)) {
        Write-Host "[FAIL] missing UTF-8 BOM: $($_.Name)"
        $bomFail++
    }
}
Assert-True ($bomFail -eq 0) "all skills/*.ps1 have UTF-8 BOM"

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
$gSkill = Get-AIWorkspaceGlobalSkillPath -IDE Cursor
Assert-True ($gSkill -like "*aiworkspace-manager" -and $gSkill -match '[\\/]\.cursor[\\/]skills[\\/]') "global Cursor skill path shape"
$gTrae = Get-AIWorkspaceGlobalSkillPath -IDE Trae
Assert-True ($gTrae -like "*aiworkspace-manager" -and $gTrae -match '[\\/]\.trae-cn[\\/]skills[\\/]') "global Trae skill path shape"
Assert-True (Test-AIWorkspaceIsGlobalToolkitPath -ToolkitDir (Join-Path $gTrae "toolkit")) "Trae toolkit path is global"
try { Resolve-AIWorkspaceIdeName -IDE "Foo" | Out-Null; Assert-True $false "bad IDE should throw" }
catch { Assert-True $true "bad IDE throws" }

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
    try {
        # Negative test: use EXPECT-ERROR so readers do not mistake for a real failure
        Test-AIWorkspaceManifest -ToolkitDir $manDir -Strict -ErrorLabel "EXPECT-ERROR" | Out-Null
    }
    catch { $strictThrew = $true }
    Assert-True $strictThrew "manifest Strict fails on hash drift"

    # Soft mode: suppress WARN noise from expected drift (still assert false)
    $prevWarn = $WarningPreference
    $WarningPreference = "SilentlyContinue"
    try { $soft = Test-AIWorkspaceManifest -ToolkitDir $manDir }
    finally { $WarningPreference = $prevWarn }
    Assert-True (-not $soft) "manifest soft returns false on drift"
}
finally {
    Remove-Item -LiteralPath $manDir -Recurse -Force -ErrorAction SilentlyContinue
}

# Uninstall to temp SkillRoot (deprecated wrapper must forward exit code)
$fakeSkill = Join-Path ([IO.Path]::GetTempPath()) ("aiws-uninst-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path (Join-Path $fakeSkill "toolkit") -Force | Out-Null
Write-Utf8NoBomFile -Path (Join-Path $fakeSkill "SKILL.md") -Content "test"
& (Join-Path $PSScriptRoot "uninstall-cursor-global-skill.ps1") -Force -SkillRoot $fakeSkill
$uninstCode = $LASTEXITCODE
Assert-True (($null -eq $uninstCode) -or ($uninstCode -eq 0)) "uninstall wrapper exit 0"
Assert-True (-not (Test-Path -LiteralPath $fakeSkill)) "uninstall moves skill root away"
$parentTrash = Join-Path (Split-Path -Parent $fakeSkill) ".trash"
$bakHit = @(Get-ChildItem -LiteralPath $parentTrash -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "aiworkspace-manager-*" })
Assert-True ($bakHit.Count -ge 1) "uninstall backup under .trash"

# Repo scripts for local one-shot verify
$scriptsDir = Join-Path (Split-Path -Parent $PSScriptRoot) "scripts"
if (Test-Path -LiteralPath $scriptsDir) {
    Assert-True (Test-Path -LiteralPath (Join-Path $scriptsDir "bootstrap-pester.ps1")) "present: scripts/bootstrap-pester.ps1"
    Assert-True (Test-Path -LiteralPath (Join-Path $scriptsDir "verify-local.ps1")) "present: scripts/verify-local.ps1"
}
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
# this is a comment
#hash-title|formerly data now comment|P2
T1|req with | pipe inside|P1
HashTitle|must create this|P2
"@
        $bv = Test-AIWorkspaceBatchFile -Path $batch
        Assert-True ($bv.Ok -and $bv.Items -eq 2) "batch validate example shape"
        & (Join-Path $PSScriptRoot "auto-requirement.ps1") -Root $tmpRoot -BatchFile $batch
        $hashMod = Join-Path $bundle (Join-Path "specs" "hashtitle")
        Assert-True (Test-Path -LiteralPath $hashMod) "batch creates HashTitle (not #hash-title)"
        $hashCommentMod = Join-Path $bundle (Join-Path "specs" "hash-title")
        Assert-True (-not (Test-Path -LiteralPath $hashCommentMod)) "batch #line is always comment"
        $falseMod = Join-Path $bundle (Join-Path "specs" "also")
        Assert-True (-not (Test-Path -LiteralPath $falseMod)) "batch comment with | ignored"

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

# Trae project rule + installed toolkit hash == repo skills/ (prevent stale Trae copies)
$traeRule = Join-Path $repoRootGuess (Join-Path ".trae" (Join-Path "rules" "aiworkspace-p0.mdc"))
if (Test-Path -LiteralPath $traeRule) {
    Assert-True $true "trae rule: .trae/rules/aiworkspace-p0.mdc"
    $ruleText = [System.IO.File]::ReadAllText($traeRule)
    Assert-True ($ruleText -match '(?i)trae-cn' -or $ruleText -match '(?i)-IDE Trae') "trae rule mentions Trae install path"
}
else {
    Write-Host "[WARN] missing .trae/rules/aiworkspace-p0.mdc (ok if validating installed toolkit only)"
}

$srcGlobalMd = Join-Path $repoRootGuess (Join-Path ".cursor" (Join-Path "skills" (Join-Path "aiworkspace-manager" "SKILL.global.md")))
if ((Test-Path -LiteralPath $srcGlobalMd) -and -not $SkipWriteTest) {
    $traeInstall = Join-Path ([IO.Path]::GetTempPath()) ("aiws-trae-inst-" + [guid]::NewGuid().ToString("N"))
    $traeSkillRoot = Join-Path $traeInstall "aiworkspace-manager"
    try {
        & (Join-Path $PSScriptRoot "install-global-skill.ps1") -IDE Trae -SourceRepo $repoRootGuess -SkillRoot $traeSkillRoot
        $tk = Join-Path $traeSkillRoot "toolkit"
        Assert-True (Test-Path -LiteralPath (Join-Path $tk "manifest.json")) "Trae install writes manifest"
        $skillMd = [System.IO.File]::ReadAllText((Join-Path $traeSkillRoot "SKILL.md"))
        Assert-True ($skillMd -match '(?i)trae-cn') "Trae SKILL.md uses .trae-cn paths"
        $hashMismatch = 0
        $compareNames = @(
            "workspace-config.ps1", "init-workspace.ps1", "auto-requirement.ps1",
            "new-module-spec.ps1", "new-bugfix.ps1", "resume-workspace.ps1",
            "validate-workspace.ps1", "aiws.ps1", "doctor-workspace.ps1", "claim-module.ps1",
            "install-global-skill.ps1", "uninstall-global-skill.ps1",
            "run-tests.ps1", "analyze-workspace.ps1", "VERSION"
        )
        foreach ($n in $compareNames) {
            $repoFile = Join-Path $PSScriptRoot $n
            $instFile = Join-Path $tk $n
            if (-not (Test-Path -LiteralPath $repoFile)) { continue }
            if (-not (Test-Path -LiteralPath $instFile)) {
                $hashMismatch++
                Write-Host "[FAIL] Trae toolkit missing: $n"
                continue
            }
            $h1 = (Get-FileHash -LiteralPath $repoFile -Algorithm SHA256).Hash
            $h2 = (Get-FileHash -LiteralPath $instFile -Algorithm SHA256).Hash
            if ($h1 -ne $h2) {
                $hashMismatch++
                Write-Host "[FAIL] Trae hash drift: $n"
            }
        }
        Assert-True ($hashMismatch -eq 0) "Trae skill toolkit hashes match repo skills/"
        & (Join-Path $PSScriptRoot "uninstall-global-skill.ps1") -IDE Trae -Force -SkillRoot $traeSkillRoot
        Assert-True (-not (Test-Path -LiteralPath $traeSkillRoot)) "Trae uninstall removes skill root"

        # New init prefers workspace/ when no legacy bundle
        $fresh = Join-Path ([IO.Path]::GetTempPath()) ("aiws-ws-" + [guid]::NewGuid().ToString("N"))
        New-Item -ItemType Directory -Path $fresh | Out-Null
        try {
            & (Join-Path $PSScriptRoot "init-workspace.ps1") -Root $fresh
            Assert-True (Test-Path -LiteralPath (Join-Path $fresh "workspace")) "new init creates workspace/"
            Assert-True (-not (Test-Path -LiteralPath (Join-Path $fresh "codestatrFirst"))) "new init does not create legacy name"
        }
        finally {
            Remove-Item -LiteralPath $fresh -Recurse -Force -ErrorAction SilentlyContinue
        }

        # Claim / release / conflict (own fixture; prior $tmpRoot already cleaned)
        $claimRoot = Join-Path ([IO.Path]::GetTempPath()) ("aiws-claim-" + [guid]::NewGuid().ToString("N"))
        New-Item -ItemType Directory -Path $claimRoot | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $claimRoot ".git") -Force | Out-Null
        try {
            & (Join-Path $PSScriptRoot "auto-requirement.ps1") -Root $claimRoot -Title "ClaimMe" -Requirement "own" -Priority P2
            $claimBundle = Get-AIWorkspaceBundlePath -RepositoryRoot $claimRoot
            & (Join-Path $PSScriptRoot "claim-module.ps1") claim -Root $claimRoot -Module claimme -Owner alice
            Assert-True ((Get-AIWorkspaceModuleOwner -BundleRoot $claimBundle -ModuleName "claimme") -eq "alice") "claim sets owner alice"
            $takeFail = $false
            try {
                & (Join-Path $PSScriptRoot "claim-module.ps1") claim -Root $claimRoot -Module claimme -Owner bob | Out-Null
            }
            catch {
                $takeFail = ($_.Exception.Message -match "claimed by")
            }
            Assert-True $takeFail "claim conflict without -Force"
            & (Join-Path $PSScriptRoot "claim-module.ps1") claim -Root $claimRoot -Module claimme -Owner bob -Force
            Assert-True ((Get-AIWorkspaceModuleOwner -BundleRoot $claimBundle -ModuleName "claimme") -eq "bob") "claim -Force take over"
            & (Join-Path $PSScriptRoot "claim-module.ps1") release -Root $claimRoot -Module claimme -Owner bob
            Assert-True ([string]::IsNullOrWhiteSpace((Get-AIWorkspaceModuleOwner -BundleRoot $claimBundle -ModuleName "claimme"))) "release clears owner"
        }
        finally {
            Remove-Item -LiteralPath $claimRoot -Recurse -Force -ErrorAction SilentlyContinue
        }

        # Installer copies .ps1 with BOM into toolkit
        $bomInst = Join-Path ([IO.Path]::GetTempPath()) ("aiws-bom-" + [guid]::NewGuid().ToString("N"))
        $bomSkill = Join-Path $bomInst "aiworkspace-manager"
        try {
            & (Join-Path $PSScriptRoot "install-global-skill.ps1") -IDE Cursor -SourceRepo $repoRootGuess -SkillRoot $bomSkill
            $installedPs1 = Join-Path (Join-Path $bomSkill "toolkit") "workspace-config.ps1"
            Assert-True (Test-AIWorkspaceFileHasUtf8Bom -Path $installedPs1) "install writes toolkit .ps1 with UTF-8 BOM"
        }
        finally {
            if (Test-Path -LiteralPath $bomInst) {
                Remove-Item -LiteralPath $bomInst -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
    finally {
        if (Test-Path -LiteralPath $traeInstall) {
            Remove-Item -LiteralPath $traeInstall -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Write-Host ""
if ($failed -gt 0) {
    Write-Host "FAILED: $failed check(s)"
    exit 1
}
Write-Host "All checks passed."
exit 0
