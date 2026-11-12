<#
.SYNOPSIS
Install Pester 5.5+ for CurrentUser (side-by-side with Windows built-in 3.4).
Does not run tests — use ./skills/run-tests.ps1 or ./scripts/verify-local.ps1.
#>
param(
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path (Join-Path $repoRoot "skills") "dependency-versions.ps1")
$RequiredVersion = $script:AIWorkspacePesterVersion

function Get-Pester5Module {
    return Get-Module -ListAvailable -Name Pester |
        Where-Object { $_.Version -eq $RequiredVersion } |
        Select-Object -First 1
}

function Ensure-Tls12 {
    try {
        [Net.ServicePointManager]::SecurityProtocol =
            [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    }
    catch { }
}

function Ensure-NuGetProvider {
    $nuget = Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue
    if ($nuget -and $nuget.Version -ge [version]"2.8.5.201") {
        return $true
    }
    Ensure-Tls12
    foreach ($scope in @("CurrentUser", $null)) {
        try {
            if ($null -eq $scope) {
                Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Confirm:$false | Out-Null
            }
            else {
                Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope $scope -Confirm:$false | Out-Null
            }
        }
        catch {
            Write-Warning "Install-PackageProvider $($scope): $($_.Exception.Message)"
        }
        $nuget = Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue
        if ($nuget -and $nuget.Version -ge [version]"2.8.5.201") {
            return $true
        }
    }
    return $false
}

$existing = Get-Pester5Module
if ($existing -and -not $Force) {
    Write-Host "Pester $($existing.Version) already available (OK)."
    exit 0
}

Write-Host "Installing Pester $RequiredVersion (CurrentUser)..."
Ensure-Tls12
if (-not (Ensure-NuGetProvider)) {
    Write-Warning "NuGet provider not ready; Install-Module may still succeed on PowerShell 7."
}

try {
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction SilentlyContinue
}
catch {
    Write-Warning "Set-PSRepository: $($_.Exception.Message)"
}

try {
    # Prefer Pester 5.x for stable Configuration API; allow override via -Force to get latest
    $installParams = @{
        Name               = "Pester"
        RequiredVersion    = $RequiredVersion
        Scope              = "CurrentUser"
        Force              = $true
        SkipPublisherCheck = $true
        AllowClobber       = $true
        Confirm            = $false
        ErrorAction        = "Stop"
    }
    try {
        Install-Module @installParams
    }
    catch {
        throw
    }
}
catch {
    Write-Host "Install-Module failed: $($_.Exception.Message)"
    Write-Host @"
Manual fix (pick one):
  1) Elevated PowerShell once:
       Install-PackageProvider NuGet -MinimumVersion 2.8.5.201 -Force
       Install-Module Pester -MinimumVersion 5.5.0 -Scope CurrentUser -Force -SkipPublisherCheck
  2) PowerShell 7:
       pwsh -File ./scripts/bootstrap-pester.ps1
"@
    exit 1
}

$after = Get-Pester5Module
if (-not $after) {
    Write-Error "Pester $RequiredVersion install failed."
    exit 1
}

Write-Host "Installed Pester $($after.Version)"
exit 0
