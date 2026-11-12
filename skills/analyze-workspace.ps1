<#
.SYNOPSIS
Run PSScriptAnalyzer on skills/*.ps1 (local static gate).
#>
param(
    [string]$Path = ""
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "dependency-versions.ps1")
if ([string]::IsNullOrWhiteSpace($Path)) {
    $Path = $PSScriptRoot
}

$requiredVersion = $script:AIWorkspacePSScriptAnalyzerVersion
$mod = Get-Module -ListAvailable -Name PSScriptAnalyzer |
    Where-Object { $_.Version -eq $requiredVersion } |
    Select-Object -First 1
if (-not $mod) {
    Write-Host "Installing PSScriptAnalyzer $requiredVersion for CurrentUser..."
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    }
    catch { Write-Verbose "TLS 1.2 setup failed: $($_.Exception.Message)" }
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction SilentlyContinue
    Install-Module PSScriptAnalyzer -RequiredVersion $requiredVersion -Scope CurrentUser -Force -SkipPublisherCheck -Confirm:$false
}
Import-Module PSScriptAnalyzer -RequiredVersion $requiredVersion -Force

$issues = @(Invoke-ScriptAnalyzer -Path $Path -Recurse -Severity @("Error", "Warning") |
        Where-Object { $_.RuleName -notin @("PSAvoidUsingWriteHost", "PSUseApprovedVerbs", "PSAvoidUsingPositionalParameters") })

$issues | Format-Table -AutoSize RuleName, Severity, ScriptName, Line, Message
if ($issues.Count -gt 0) {
    Write-Host "PSScriptAnalyzer: $($issues.Count) issue(s)"
    exit 1
}
Write-Host "PSScriptAnalyzer: clean"
exit 0
