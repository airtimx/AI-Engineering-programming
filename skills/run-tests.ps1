<#
.SYNOPSIS
Ensure Pester 5+ (side-by-side with Windows built-in 3.4) and run ./tests.
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
    $mods = @(Get-Module -ListAvailable -Name Pester | Where-Object { $_.Version -ge [version]"5.0.0" } | Sort-Object Version -Descending)
    if ($mods.Count -gt 0) { return $mods[0] }
    return $null
}

$pester5 = Get-Pester5Module
if (-not $pester5 -and -not $SkipInstall) {
    Write-Host "Pester 5 not found (Windows often ships 3.4 only). Installing for CurrentUser..."
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
    $pester5 = Get-Pester5Module
}

if (-not $pester5) {
    throw @"
Pester 5+ is required (found only built-in 3.x or nothing).
Fix:
  1) Run: powershell -File ./skills/run-tests.ps1
  2) Or manually: Install-Module Pester -MinimumVersion 5.5.0 -Scope CurrentUser -Force -SkipPublisherCheck
Then re-run this script. CI always installs Pester 5.
"@
}

Remove-Module Pester -Force -ErrorAction SilentlyContinue
Import-Module Pester -RequiredVersion $pester5.Version -Force
Write-Host "Using Pester $($pester5.Version)"

$cfg = New-PesterConfiguration
$cfg.Run.Path = $Path
$cfg.Run.Exit = $true
$cfg.Output.Verbosity = "Detailed"
Invoke-Pester -Configuration $cfg
