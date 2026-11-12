param([string]$ExpectedVersion = "")
$ErrorActionPreference = "Stop"
$ExpectedVersion = $ExpectedVersion.TrimStart('v', 'V')
$repoRoot = Split-Path -Parent $PSScriptRoot
$version = (Get-Content -LiteralPath (Join-Path $repoRoot "skills/VERSION") -Raw).Trim()
if ($ExpectedVersion -and ($ExpectedVersion -ne $version)) {
    throw "VERSION $version does not match $ExpectedVersion"
}

& (Join-Path $repoRoot "scripts/verify-local.ps1")
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$dist = Join-Path $repoRoot "dist"
New-Item -ItemType Directory -Path $dist -Force | Out-Null
$zip = Join-Path $dist "AIWorkspaceManager-$version.zip"
$docs = @(Get-ChildItem -LiteralPath $repoRoot -File -Filter "*.md" | Select-Object -ExpandProperty FullName)
$packagePaths = @(
    (Join-Path $repoRoot "skills")
    (Join-Path $repoRoot "scripts")
    (Join-Path $repoRoot ".cursor")
) + $docs
Compress-Archive -Path $packagePaths -DestinationPath $zip -Force
$hash = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLowerInvariant()
Write-Output "$hash  $(Split-Path -Leaf $zip)" | Set-Content -LiteralPath "$zip.sha256" -Encoding ascii
Write-Host "Release artifact: $zip"
Write-Host "SHA256: $hash"
exit 0
