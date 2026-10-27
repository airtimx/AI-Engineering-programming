<#
.SYNOPSIS
One-shot local gate: bootstrap Pester 5 → validate-workspace → Invoke-Pester tests/.
#>
param(
    [switch]$SkipBootstrap,
    [switch]$SkipValidate,
    [switch]$SkipPester,
    [switch]$SkipAnalyzer
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

function Invoke-Step {
    param(
        [string]$Name,
        [scriptblock]$Action
    )
    Write-Host ""
    Write-Host "=== $Name ==="
    & $Action
    $code = $LASTEXITCODE
    if ($null -eq $code) { $code = 0 }
    if ($code -ne 0) {
        Write-Host "FAILED: $Name (exit $code)"
        exit $code
    }
    Write-Host "OK: $Name"
}

Write-Host "AI Workspace local verify (repo: $repoRoot)"

if (-not $SkipBootstrap) {
    Invoke-Step "bootstrap-pester" {
        & (Join-Path $PSScriptRoot "bootstrap-pester.ps1")
    }
}

if (-not $SkipValidate) {
    Invoke-Step "validate-workspace" {
        & (Join-Path $repoRoot "skills\validate-workspace.ps1")
    }
}

if (-not $SkipPester) {
    Invoke-Step "Invoke-Pester tests/" {
        & (Join-Path $repoRoot "skills\run-tests.ps1") -SkipInstall
    }
}

if (-not $SkipAnalyzer) {
    Invoke-Step "PSScriptAnalyzer" {
        & (Join-Path $repoRoot "skills\analyze-workspace.ps1")
    }
}

Write-Host ""
Write-Host "All local gates passed."
exit 0
