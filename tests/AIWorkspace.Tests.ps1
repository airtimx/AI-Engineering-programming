#Requires -Version 5.1
# Pester 5+ unit tests for AI Workspace helpers
BeforeAll {
    $skills = Join-Path (Split-Path -Parent $PSScriptRoot) "skills"
    . (Join-Path $skills "workspace-config.ps1")
}

Describe "Normalize-AIWorkspaceName" {
    It "throws on whitespace" {
        { Normalize-AIWorkspaceName -Value "   " } | Should -Throw
    }
    It "keeps CJK and lowercases ASCII" {
        (Normalize-AIWorkspaceName -Value "用户 Login") | Should -Match "login"
    }
}

Describe "Get-DerivedModuleStatus" {
    It "initialized when no done" {
        Get-DerivedModuleStatus -Todo 3 -Done 0 | Should -Be "initialized"
    }
    It "in_progress when mixed" {
        Get-DerivedModuleStatus -Todo 1 -Done 2 | Should -Be "in_progress"
    }
    It "done when only done" {
        Get-DerivedModuleStatus -Todo 0 -Done 2 | Should -Be "done"
    }
}

Describe "Get-TasksProgressSummary" {
    It "parses list variants" {
        $p = Join-Path $TestDrive "t.md"
        @(
            "- [ ] a"
            "* [ ] b"
            "1. [x] c"
            "- [ ] (none)"
        ) | Set-Content -Path $p -Encoding utf8
        $s = Get-TasksProgressSummary -TasksPath $p
        $s.Todo | Should -Be 2
        $s.Done | Should -Be 1
    }
    It "skips fenced checkboxes" {
        $p = Join-Path $TestDrive "fence.md"
        @(
            "- [ ] keep"
            '```'
            "- [ ] fake inside fence"
            '```'
            "- [x] done-out"
        ) | Set-Content -Path $p -Encoding utf8
        $s = Get-TasksProgressSummary -TasksPath $p
        $s.Todo | Should -Be 1
        $s.Done | Should -Be 1
        $s.OpenItems | Should -Not -Contain "fake inside fence"
    }
}

Describe "Write-ModuleCacheJson locking" {
    It "writes schema under lock" {
        $bundle = Join-Path $TestDrive "codestatrFirst"
        New-Item -ItemType Directory -Path $bundle | Out-Null
        $fields = New-AIWorkspaceCacheSchema -ModuleName "m1" -Title "T" -Requirement "R" -Priority "P1"
        $path = Write-ModuleCacheJson -BundleRoot $bundle -ModuleName "m1" -Fields $fields
        Test-Path -LiteralPath $path | Should -Be $true
        $obj = (Get-Content -LiteralPath $path -Raw -Encoding utf8) | ConvertFrom-Json
        $obj.schema_version | Should -Be 1
        Test-Path -LiteralPath (Join-Path $bundle (Join-Path ".locks" ".gitkeep")) | Should -Be $true
    }
}

Describe "Test-AIWorkspaceManifest -Strict" {
    It "throws when hash drifts" {
        $dir = Join-Path $TestDrive "tk"
        New-Item -ItemType Directory -Path $dir | Out-Null
        Set-Content -Path (Join-Path $dir "VERSION") -Value "1.5.1" -Encoding utf8
        Set-Content -Path (Join-Path $dir "a.ps1") -Value "hi" -Encoding utf8
        $man = @{
            version = "1.5.1"
            files   = @(@{ name = "a.ps1"; sha256 = "00"; bytes = 2 }, @{ name = "VERSION"; sha256 = "00"; bytes = 1 })
        } | ConvertTo-Json -Depth 5
        Set-Content -Path (Join-Path $dir "manifest.json") -Value $man -Encoding utf8
        { Test-AIWorkspaceManifest -ToolkitDir $dir -Strict } | Should -Throw
    }
}

Describe "Protect-AIWorkspaceMarkdownText" {
    It "strips ATX injection from inline title" {
        $t = Protect-AIWorkspaceMarkdownText -Value "T1`n## Injected" -Mode Inline
        $t | Should -Not -Match '##'
        $t.Contains([string]::new([char]0xFF03, 2)) | Should -Be $true
    }
    It "neutralizes checkbox injection" {
        $t = Protect-AIWorkspaceMarkdownText -Value "- [ ] fake" -Mode Block
        $t | Should -Not -Match '\[ \]'
        $t | Should -Match '［ ］'
    }
}

Describe "Path safety" {
    It "rejects Windows system root" {
        { Assert-AIWorkspaceRootSafe -RepositoryRoot "C:\Windows" } | Should -Throw
    }
    It "allows empty dir with AllowEmptyBootstrap" {
        $d = Join-Path $TestDrive "empty-boot"
        New-Item -ItemType Directory -Path $d | Out-Null
        { Assert-AIWorkspaceRootSafe -RepositoryRoot $d -AllowEmptyBootstrap } | Should -Not -Throw
    }
}

Describe "Runtime info" {
    It "returns toolkit version" {
        $r = Get-AIWorkspaceRuntimeInfo
        $r.Toolkit | Should -Be "1.5.1"
        $r.PSVersion | Should -Not -BeNullOrEmpty
    }
}
