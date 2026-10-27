<#
.SYNOPSIS
Ensure Pester 5.5+ (side-by-side with Windows built-in 3.4) and Invoke-Pester on ./tests.
#>
param(
    [string]$Path = "",
    [switch]$SkipInstall
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($Path)) {
    $Path = Join-Path $repoRoot "tests"
}

function Get-Pester5Module {
    # Prefer 5.x (stable Configuration + return object); allow 6+ only if no 5.x
    $all = @(Get-Module -ListAvailable -Name Pester | Where-Object { $_.Version -ge [version]"5.5.0" } | Sort-Object Version -Descending)
    $v5 = @($all | Where-Object { $_.Version -lt [version]"6.0.0" })
    if ($v5.Count -gt 0) { return $v5[0] }
    if ($all.Count -gt 0) { return $all[0] }
    return $null
}

$pester5 = Get-Pester5Module
if (-not $pester5 -and -not $SkipInstall) {
    $boot = Join-Path $repoRoot (Join-Path "scripts" "bootstrap-pester.ps1")
    if (Test-Path -LiteralPath $boot) {
        Write-Host "Delegating install to scripts/bootstrap-pester.ps1 ..."
        & $boot
        if ($LASTEXITCODE -ne 0 -and $null -ne $LASTEXITCODE) {
            exit $LASTEXITCODE
        }
    }
    else {
        Write-Host "Pester 5.5+ not found. Installing for CurrentUser..."
        try {
            [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
        }
        catch { }
        try {
            $nuget = Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue
            if (-not $nuget -or $nuget.Version -lt [version]"2.8.5.201") {
                Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Confirm:$false | Out-Null
            }
        }
        catch {
            Write-Warning "NuGet provider install failed: $($_.Exception.Message)"
        }
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction SilentlyContinue
        Install-Module -Name Pester -MinimumVersion 5.5.0 -Scope CurrentUser -Force -SkipPublisherCheck -AllowClobber -Confirm:$false
    }
    $pester5 = Get-Pester5Module
}

if (-not $pester5) {
    Write-Host @"
Pester 5.5+ is required (found only built-in 3.x or nothing).
Fix:
  powershell -File ./scripts/bootstrap-pester.ps1
  powershell -File ./skills/run-tests.ps1
"@
    exit 1
}

Remove-Module Pester -Force -ErrorAction SilentlyContinue
Import-Module Pester -RequiredVersion $pester5.Version -Force
Write-Host "Using Pester $($pester5.Version)"
Write-Host "Invoke-Pester path: $Path"

if (-not (Test-Path -LiteralPath $Path)) {
    Write-Host "Test path not found: $Path"
    exit 1
}

$cfg = New-PesterConfiguration
$cfg.Run.Path = $Path
$cfg.Run.Exit = $false
$cfg.Output.Verbosity = "Detailed"
# Pester 5 returns result by default; Pester 6 needs PassThru
if ($null -ne $cfg.Run.PSObject.Properties["PassThru"]) {
    $cfg.Run.PassThru = $true
}
$result = $null
try {
    $result = Invoke-Pester -Configuration $cfg -PassThru -ErrorAction SilentlyContinue
}
catch {
    # Older Pester 5 Configuration path may not accept -PassThru with -Configuration
}
if ($null -eq $result) {
    $result = Invoke-Pester -Configuration $cfg
}

if ($null -eq $result) {
    Write-Host "Invoke-Pester returned no result object."
    exit 1
}
# Pester may return an array of run results
if ($result -is [System.Array]) {
    $result = $result | Select-Object -Last 1
}

$failed = 0
$passed = 0
$total = 0
if ($null -ne $result.PSObject.Properties["FailedCount"]) { $failed = [int]$result.FailedCount }
if ($null -ne $result.PSObject.Properties["PassedCount"]) { $passed = [int]$result.PassedCount }
if ($null -ne $result.PSObject.Properties["TotalCount"]) { $total = [int]$result.TotalCount }
Write-Host "Pester: Passed=$passed Failed=$failed Total=$total"
if ($failed -gt 0 -or $total -eq 0) {
    if ($total -eq 0) { Write-Host "No tests discovered/executed (treat as failure)." }
    exit 1
}
exit 0
