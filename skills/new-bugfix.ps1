param(
    [Parameter(Mandatory = $true)]
    [string]$Title,
    [string]$Root = "."
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "workspace-config.ps1")
$repoRoot = Resolve-AIRepositoryRoot -Root $Root -ScriptHome $PSScriptRoot
& (Join-Path $PSScriptRoot "init-workspace.ps1") -Root $repoRoot
$WorkspaceBundle = Get-AIWorkspaceBundlePath -RepositoryRoot $repoRoot

if ([string]::IsNullOrWhiteSpace($Title)) {
    throw "Title cannot be empty or whitespace."
}

$safeTitle = Normalize-AIWorkspaceName -Value $Title -FallbackPrefix "bug"
$bugfixDir = Join-Path $WorkspaceBundle "bugfix"
if (-not (Test-Path -LiteralPath $bugfixDir)) {
    New-Item -ItemType Directory -Path $bugfixDir | Out-Null
}

$date = Get-Date -Format "yyyy-MM-dd"
$filePath = Join-Path $bugfixDir "$date-$safeTitle.md"

if (Test-Path -LiteralPath $filePath) {
    Write-Host "Bugfix file already exists: $filePath"
    exit 0
}

Write-Utf8NoBomFile -Path $filePath -Content @"
# Bugfix - $Title

## Problem
- 描述用户反馈的问题。

## Impact
- Affected modules:
- Risk level:

## Root Cause
- 说明根因。

## Fix
- 说明修复方案。

## Validation
- [ ] 已复现问题
- [ ] 已应用修复
- [ ] 已验证预期行为
"@

Write-Host "Created bugfix file: $filePath"
