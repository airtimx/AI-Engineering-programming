<#
.SYNOPSIS
Unified AI Workspace CLI: init | new | resume | status | claim | release | who | install | uninstall | doctor | help
#>
param(
    [Parameter(Position = 0)]
    [ValidateSet("init", "new", "resume", "install", "uninstall", "doctor", "status", "claim", "release", "who", "help", "")]
    [string]$Command = "help",

    [string]$Root = ".",
    [string]$Title = "",
    [string]$Requirement = "",
    [string]$Module = "",
    [string]$BatchFile = "",
    [ValidateSet("P0", "P1", "P2", "P3")]
    [string]$Priority = "P2",
    [ValidateSet("Cursor", "Trae", "All")]
    [string]$IDE = "All",
    [string]$Owner = "",
    [switch]$SyncCache,
    [switch]$Json,
    [switch]$Force,
    [switch]$SuggestCommit,
    [switch]$AsciiNames,
    [switch]$ResumeBatch
)

$ErrorActionPreference = "Stop"
$here = $PSScriptRoot

function Show-AIWSHelp {
    @"
AI Workspace CLI (aiws.ps1) — 只记这一个入口

产品边界（刻意薄）:
  做：specs/cache/bugfix 脚手架、续接、双端 Skill、轻量认领 owner
  不做：自动改业务代码、自动开 GitHub PR/Issue（可用 -SuggestCommit 只打印文案）

用法:
  ./skills/aiws.ps1 init [-Root <项目>]
  ./skills/aiws.ps1 new -Title "登录" -Requirement "手机号登录" [-Priority P1] [-Owner 你]
  ./skills/aiws.ps1 resume [-Module 登录] [-SyncCache] [-SuggestCommit] [-Json]
  ./skills/aiws.ps1 status
  ./skills/aiws.ps1 claim -Module 登录 [-Owner 你] [-Force]
  ./skills/aiws.ps1 release -Module 登录 [-Force]
  ./skills/aiws.ps1 who [-Module 登录]
  ./skills/aiws.ps1 install [-IDE All|Cursor|Trae]
  ./skills/aiws.ps1 uninstall [-IDE All|Cursor|Trae] -Force
  ./skills/aiws.ps1 doctor [-Root <项目>] [-Json]

故事线:
  ./skills/aiws.ps1 init
  ./skills/aiws.ps1 new -Title "用户登录" -Requirement "手机号验证码登录" -Priority P1
  ./skills/aiws.ps1 claim -Module 用户登录
  # 编辑 workspace/specs/<模块>/tasks.md 勾选后:
  ./skills/aiws.ps1 resume -SyncCache -SuggestCommit

退出码契约（入口与 deprecated wrapper 均须遵守）:
  0 成功 · 1 失败 · 2 用法/歧义 · 3 锁超时 · 4 全局 manifest 漂移
  成功路径显式 exit 0；转发子进程用 exit `$LASTEXITCODE（勿留残留码）
"@ | Write-Host
}

if ([string]::IsNullOrWhiteSpace($Command) -or $Command -eq "help") {
    Show-AIWSHelp
    exit 0
}

switch ($Command) {
    "init" {
        & (Join-Path $here "init-workspace.ps1") -Root $Root
    }
    "new" {
        if (-not [string]::IsNullOrWhiteSpace($BatchFile)) {
            & (Join-Path $here "auto-requirement.ps1") -Root $Root -BatchFile $BatchFile -ResumeBatch:$ResumeBatch -AsciiNames:$AsciiNames -Json:$Json
        }
        else {
            if ([string]::IsNullOrWhiteSpace($Title) -or [string]::IsNullOrWhiteSpace($Requirement)) {
                throw "new 需要 -Title 与 -Requirement（或 -BatchFile）。见: ./skills/aiws.ps1 help"
            }
            if (-not [string]::IsNullOrWhiteSpace($Owner)) {
                $env:AIWORKSPACE_OWNER = $Owner
            }
            & (Join-Path $here "auto-requirement.ps1") -Root $Root -Title $Title -Requirement $Requirement -Priority $Priority -AsciiNames:$AsciiNames -Json:$Json
        }
    }
    "resume" {
        & (Join-Path $here "resume-workspace.ps1") -Root $Root -Module $Module -SyncCache:$SyncCache -Json:$Json -SuggestCommit:$SuggestCommit
    }
    "status" {
        & (Join-Path $here "resume-workspace.ps1") -Root $Root -Module $Module -Json:$Json -DashboardOnly
    }
    "claim" {
        & (Join-Path $here "claim-module.ps1") claim -Root $Root -Module $Module -Owner $Owner -Force:$Force -Json:$Json
    }
    "release" {
        & (Join-Path $here "claim-module.ps1") release -Root $Root -Module $Module -Owner $Owner -Force:$Force -Json:$Json
    }
    "who" {
        & (Join-Path $here "claim-module.ps1") who -Root $Root -Module $Module -Json:$Json
    }
    "install" {
        & (Join-Path $here "install-global-skill.ps1") -IDE $IDE
    }
    "uninstall" {
        & (Join-Path $here "uninstall-global-skill.ps1") -IDE $IDE -Force:$Force
    }
    "doctor" {
        & (Join-Path $here "doctor-workspace.ps1") -Root $Root -Json:$Json
    }
    default {
        Show-AIWSHelp
        exit 2
    }
}

$code = $LASTEXITCODE
if ($null -eq $code) { exit 0 }
exit $code
