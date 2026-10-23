# Token footprint: CJK (~1 token/char) + other (~0.25). Scans skill files.
param([string]$Root = ".")

$ErrorActionPreference = "Stop"

$repoRoot = if ($Root -ne ".") {
    (Get-Item -LiteralPath $Root).FullName
}
else {
    (Get-Item -LiteralPath (Join-Path $PSScriptRoot "..\..\..\..")).FullName
}

function Get-SmartTokenEstimate {
    param([string]$Text)
    if ([string]::IsNullOrEmpty($Text)) { return 0 }
    $cjk = 0
    $other = 0
    foreach ($ch in $Text.ToCharArray()) {
        $code = [int]$ch
        # CJK Unified + common fullwidth / kana / hangul rough band
        if (($code -ge 0x3400 -and $code -le 0x9FFF) -or
            ($code -ge 0xF900 -and $code -le 0xFAFF) -or
            ($code -ge 0x3040 -and $code -le 0x30FF) -or
            ($code -ge 0xAC00 -and $code -le 0xD7AF)) {
            $cjk++
        }
        else {
            $other++
        }
    }
    return [int][math]::Ceiling($cjk + ($other / 4.0))
}

function Get-TextStats {
    param([string]$Path, [string]$Label)
    if (-not (Test-Path -LiteralPath $Path)) {
        return [pscustomobject]@{ Label = $Label; Chars = 0; EstTokens = 0; NaiveDiv4 = 0; Exists = $false }
    }
    $text = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
    [pscustomobject]@{
        Label     = $Label
        Chars     = $text.Length
        EstTokens = Get-SmartTokenEstimate -Text $text
        NaiveDiv4 = [int][math]::Ceiling($text.Length / 4.0)
        Exists    = $true
    }
}

$items = @(
    Get-TextStats (Join-Path $repoRoot "skills\aiworkspace-manager.skill.md") "legacy-skill-md"
    Get-TextStats (Join-Path $repoRoot ".cursor\rules\aiworkspace-p0.mdc") "cursor-rule-pointer"
    Get-TextStats (Join-Path $repoRoot ".cursor\skills\aiworkspace-manager\SKILL.md") "cursor-skill-SKILL.md"
    Get-TextStats (Join-Path $repoRoot ".cursor\skills\aiworkspace-manager\reference.md") "cursor-skill-reference.md"
)

Write-Host ""
Write-Host "=== Token footprint (CJK=1, other=chars/4) ==="
Write-Host "Repository: $repoRoot"
$items | Where-Object Exists | Format-Table Label, Chars, EstTokens, NaiveDiv4 -AutoSize

$skill = ($items | Where-Object Label -eq "cursor-skill-SKILL.md").EstTokens
$ref = ($items | Where-Object Label -eq "cursor-skill-reference.md").EstTokens
Write-Host "On-demand SKILL.md ~ $skill tokens; +reference ~ $($skill + $ref)"
Write-Host "Naive chars/4 shown for comparison (often underestimates CJK)."
Write-Host ""
