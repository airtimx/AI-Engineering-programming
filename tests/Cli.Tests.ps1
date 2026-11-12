#Requires -Version 5.1
BeforeAll {
    $repoRoot = Split-Path -Parent $PSScriptRoot
    $script:PSExe = (Get-Process -Id $PID).Path
    $script:Cli = Join-Path $repoRoot "skills/aiws.ps1"
    $script:Uninstall = Join-Path $repoRoot "skills/uninstall-global-skill.ps1"
}

Describe "aiws CLI" {
    It "prints help with exit code 0" {
        $out = & $PSExe -NoProfile -ExecutionPolicy Bypass -File $Cli help 2>&1
        $LASTEXITCODE | Should -Be 0
        ($out -join "`n") | Should -Match "AI Workspace CLI"
    }

    It "initializes an empty root and creates a module" {
        $root = Join-Path $TestDrive "project"
        New-Item -ItemType Directory -Path $root | Out-Null
        & $PSExe -NoProfile -ExecutionPolicy Bypass -File $Cli init -Root $root *> $null
        $LASTEXITCODE | Should -Be 0
        & $PSExe -NoProfile -ExecutionPolicy Bypass -File $Cli new -Root $root -Title "用户登录" -Requirement "手机号验证码登录" -Priority P1 *> $null
        $LASTEXITCODE | Should -Be 0
        Test-Path -LiteralPath (Join-Path $root "workspace/specs/用户登录/tasks.md") | Should -Be $true
    }
}

Describe "uninstall safety" {
    It "requires -Force in non-interactive mode" {
        $root = Join-Path $TestDrive "skill-root"
        New-Item -ItemType Directory -Path $root | Out-Null
        $env:AIWORKSPACE_NONINTERACTIVE = "1"
        try {
            $proc = Start-Process -FilePath $PSExe -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $Uninstall, "-IDE", "Cursor", "-SkillRoot", $root) -NoNewWindow -Wait -PassThru
        }
        finally {
            Remove-Item Env:AIWORKSPACE_NONINTERACTIVE -ErrorAction SilentlyContinue
        }
        $proc.ExitCode | Should -Not -Be 0
        Test-Path -LiteralPath $root | Should -Be $true
    }

    It "backs up and removes with -Force" {
        $root = Join-Path $TestDrive "skill-root-force"
        New-Item -ItemType Directory -Path $root | Out-Null
        & $PSExe -NoProfile -ExecutionPolicy Bypass -File $Uninstall -IDE Cursor -SkillRoot $root -Force *> $null
        $LASTEXITCODE | Should -Be 0
        Test-Path -LiteralPath $root | Should -Be $false
    }
}
