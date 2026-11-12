<#
.SYNOPSIS
Diagnose toolkit version, manifests, dual-IDE install drift, and -Root resolution.
#>
param(
    [string]$Root = ".",
    [switch]$Json
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "workspace-config.ps1")

$issues = New-Object System.Collections.Generic.List[object]
$fixes = New-Object System.Collections.Generic.List[string]
$ver = Get-AIWorkspaceToolkitVersion
$repoSkills = $PSScriptRoot

function Add-Issue {
    param([string]$Code, [string]$Message, [string]$Fix = "")
    $issues.Add([ordered]@{ code = $Code; message = $Message; fix = $Fix }) | Out-Null
    if (-not [string]::IsNullOrWhiteSpace($Fix)) {
        $fixes.Add($Fix) | Out-Null
    }
}

Write-Host "=== AI Workspace Doctor (toolkit $ver) ==="

# Root resolution
$rootOk = $false
$resolvedRoot = $null
try {
    $resolvedRoot = Resolve-AIRepositoryRoot -Root $Root -ScriptHome $PSScriptRoot -SkipDetectConfirm
    $rootOk = $true
    Write-Host "[OK] Root: $resolvedRoot"
}
catch {
    Add-Issue -Code "root" -Message $_.Exception.Message -Fix "pwsh -File `"$repoSkills\aiws.ps1`" doctor -Root `"<你的项目根>`""
    Write-Host "[FAIL] Root: $($_.Exception.Message)"
}

$bundle = $null
if ($rootOk) {
    $bundle = Get-AIWorkspaceBundlePath -RepositoryRoot $resolvedRoot
    $bName = Resolve-AIWorkspaceBundleDirName -RepositoryRoot $resolvedRoot
    if (Test-Path -LiteralPath $bundle) {
        Write-Host "[OK] Bundle: $bundle (name=$bName)"
    }
    else {
        Add-Issue -Code "bundle" -Message "Bundle missing: $bundle" -Fix "pwsh -File `"$repoSkills\aiws.ps1`" init -Root `"$resolvedRoot`""
        Write-Host "[FAIL] Bundle missing: $bundle"
    }
}

# Dual IDE install + version/hash consistency vs this toolkit
foreach ($ide in @("Cursor", "Trae")) {
    $skill = Get-AIWorkspaceGlobalSkillPath -IDE $ide
    $tk = Join-Path $skill "toolkit"
    $verFile = Join-Path $tk "VERSION"
    if (-not (Test-Path -LiteralPath $skill)) {
        Add-Issue -Code "ide-$ide" -Message "$ide skill not installed at $skill" -Fix "pwsh -File `"$repoSkills\install-global-skill.ps1`" -IDE $ide"
        Write-Host "[WARN] ${ide}: not installed"
        continue
    }
    $ideVer = if (Test-Path -LiteralPath $verFile) { (Get-Content -LiteralPath $verFile -Raw).Trim() } else { "?" }
    $matchRepo = ($ideVer -eq $ver)
    $manOk = $false
    try {
        $manOk = [bool](Test-AIWorkspaceManifest -ToolkitDir $tk -Strict)
    }
    catch {
        $manOk = $false
        Add-Issue -Code "manifest-$ide" -Message "$ide manifest invalid: $($_.Exception.Message)" -Fix "pwsh -File `"$repoSkills\install-global-skill.ps1`" -IDE $ide"
    }
    if (-not $matchRepo) {
        Add-Issue -Code "version-$ide" -Message "$ide toolkit $ideVer != repo $ver" -Fix "pwsh -File `"$repoSkills\install-global-skill.ps1`" -IDE All"
        Write-Host "[FAIL] ${ide}: version $ideVer (repo $ver)"
    }
    elseif ($manOk) {
        Write-Host "[OK] ${ide}: v$ideVer + manifest"
    }
    else {
        Write-Host "[FAIL] ${ide}: v$ideVer but manifest drift"
    }
}

# Cursor vs Trae mutual version
$cVerPath = Join-Path (Get-AIWorkspaceGlobalSkillPath -IDE Cursor) (Join-Path "toolkit" "VERSION")
$tVerPath = Join-Path (Get-AIWorkspaceGlobalSkillPath -IDE Trae) (Join-Path "toolkit" "VERSION")
if ((Test-Path -LiteralPath $cVerPath) -and (Test-Path -LiteralPath $tVerPath)) {
    $cv = (Get-Content -LiteralPath $cVerPath -Raw).Trim()
    $tv = (Get-Content -LiteralPath $tVerPath -Raw).Trim()
    if ($cv -ne $tv) {
        Add-Issue -Code "ide-skew" -Message "Cursor ($cv) != Trae ($tv)" -Fix "pwsh -File `"$repoSkills\install-global-skill.ps1`" -IDE All"
        Write-Host "[FAIL] Cursor/Trae version skew: $cv vs $tv"
    }
    else {
        Write-Host "[OK] Cursor/Trae versions aligned ($cv)"
    }
}

# Batch example present
$ex = Join-Path $repoSkills "requirements.batch.example.txt"
if (Test-Path -LiteralPath $ex) {
    Write-Host "[OK] batch example present"
}
else {
    Write-Host "[WARN] requirements.batch.example.txt missing (template repo only)"
}

# UTF-8 BOM on toolkit scripts (PS 5.1)
$bomBad = @()
Get-ChildItem -LiteralPath $repoSkills -Filter "*.ps1" -ErrorAction SilentlyContinue | ForEach-Object {
    if (-not (Test-AIWorkspaceFileHasUtf8Bom -Path $_.FullName)) { $bomBad += $_.Name }
}
if ($bomBad.Count -eq 0) {
    Write-Host "[OK] skills/*.ps1 UTF-8 BOM"
}
else {
    Add-Issue -Code "bom" -Message ("Missing UTF-8 BOM: " + ($bomBad -join ", ")) -Fix "Re-save scripts as UTF-8 with BOM, or re-run install-global-skill.ps1 from a good checkout"
    Write-Host "[FAIL] missing UTF-8 BOM: $($bomBad -join ', ')"
}

# git remote (template repo only)
if ($rootOk -and (Test-Path -LiteralPath (Join-Path $resolvedRoot ".git"))) {
    Push-Location $resolvedRoot
    try {
        $remotes = @(git remote 2>$null)
        if ($remotes.Count -gt 0) {
            Write-Host "[OK] git remote: $($remotes -join ', ')"
        }
        else {
            # Warn only — many local templates have no remote yet; see REMOTE.md
            Write-Host "[WARN] no git remote (CI will not run until configured — see REMOTE.md)"
            $fixes.Add("See REMOTE.md — git remote add origin <url> && git push -u origin main") | Out-Null
        }
    }
    finally {
        Pop-Location
    }
}

Write-Host ""
if ($issues.Count -eq 0) {
    Write-Host "Doctor: all clear."
    if ($Json) {
        Write-AIWorkspaceJson ([ordered]@{ ok = $true; toolkit = $ver; root = $resolvedRoot; bundle = $bundle; issues = @() })
    }
    exit (Get-AIWorkspaceExitCode -Kind Ok)
}

Write-Host "Doctor found $($issues.Count) issue(s). Copy a fix command:"
$uniq = @($fixes | Select-Object -Unique)
foreach ($f in $uniq) {
    Write-Host "  $f"
}
if ($Json) {
    Write-AIWorkspaceJson ([ordered]@{
            ok      = $false
            toolkit = $ver
            root    = $resolvedRoot
            bundle  = $bundle
            issues  = @($issues)
            fixes   = $uniq
        })
}
exit (Get-AIWorkspaceExitCode -Kind Fail)
