<#
.SYNOPSIS
Run PSScriptAnalyzer on skills/*.ps1 (local static gate).
#>
param(
    [string]$Path = ""
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($Path)) {
    $Path = $PSScriptRoot
}

$mod = Get-Module -ListAvailable -Name PSScriptAnalyzer | Sort-Object Version -Descending | Select-Object -First 1
if (-not $mod) {
    Write-Host "Installing PSScriptAnalyzer for CurrentUser..."
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    }
    catch { }
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction SilentlyContinue
    Install-Module PSScriptAnalyzer -Scope CurrentUser -Force -SkipPublisherCheck -Confirm:$false
}
Import-Module PSScriptAnalyzer -Force

$issues = @(Invoke-ScriptAnalyzer -Path $Path -Recurse -Severity @("Error", "Warning") |
        Where-Object { $_.RuleName -notin @("PSAvoidUsingWriteHost", "PSUseApprovedVerbs", "PSAvoidUsingPositionalParameters") })

$issues | Format-Table -AutoSize RuleName, Severity, ScriptName, Line, Message
if ($issues.Count -gt 0) {
    Write-Host "PSScriptAnalyzer: $($issues.Count) issue(s)"
    exit 1
}
Write-Host "PSScriptAnalyzer: clean"
exit 0
