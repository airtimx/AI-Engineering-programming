param(
    [Parameter(Mandatory = $true)]
    [string]$Title,
    [string]$Root = ".",
    [string]$FollowUpNote = ""
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "workspace-config.ps1")
Assert-AIWorkspaceToolkitReady -ToolkitDir $PSScriptRoot
$repoRoot = Resolve-AIRepositoryRoot -Root $Root -ScriptHome $PSScriptRoot -AllowEmptyBootstrap
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
$stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

if (Test-Path -LiteralPath $filePath) {
    $existing = Read-Utf8File -Path $filePath
    if ($null -eq $existing) { $existing = "" }
    $note = if ([string]::IsNullOrWhiteSpace($FollowUpNote)) {
        "二次/后续修复记录（自动追加）。请补充问题、根因与验证。"
    }
    else {
        $FollowUpNote.Trim()
    }
    $followCount = ([regex]::Matches($existing, '(?m)^## Follow-up\b')).Count
    $sectionTitle = if ($followCount -eq 0) { "## Follow-up" } else { "## Follow-up $($followCount + 1)" }
    $append = @"

$sectionTitle
- Recorded at: $stamp
- Note: $note
- [ ] 已复现问题
- [ ] 已应用修复
- [ ] 已验证预期行为
"@
    Write-Utf8NoBomFile -Path $filePath -Content ($existing.TrimEnd() + "`n" + $append.TrimStart())
    Write-Host "Appended $sectionTitle to existing bugfix: $filePath"
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
