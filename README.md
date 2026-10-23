# AI Skill Workspace

可复用 AI 工作区脚手架（**toolkit v1.4.0**，MIT）。业务文档在 **`codestatrFirst/`**（可用环境变量 `AIWORKSPACE_BUNDLE_DIR` 改名）；仓库根 **`skills/`** 为 PowerShell 工具包。

**支持矩阵**：Windows PowerShell 5.1（主）、PowerShell 7+ Windows；Linux/macOS 尽力。依赖 Cursor 全局/项目 Skill 做对话触发，脚本本身可在终端独立运行。

**产品范围**：生成 specs/cache/bugfix 骨架与续接状态，**不**自动开 PR/Issue/改业务代码（刻意保持薄）。

## 快速开始

```powershell
./skills/init-workspace.ps1
./skills/auto-requirement.ps1 -Title "用户登录" -Requirement "手机号验证码登录" -Priority P1
./skills/resume-workspace.ps1 -SyncCache
./skills/resume-workspace.ps1 -Json          # 机器可读
./skills/validate-workspace.ps1
./skills/run-tests.ps1                       # Pester 5
./skills/analyze-workspace.ps1               # PSScriptAnalyzer
```

其它项目（含已有 README/src、尚无 `.git` 的目录也可被 **init** 引导）：

```powershell
pwsh -NoProfile -File "…/skills/init-workspace.ps1" -Root "D:\path\to\project"
```

### 危险逃逸口（标红）

**`AIWORKSPACE_ALLOW_ANY_ROOT=1` 关闭路径防护。** 仅排错使用。

### 全局 Skill 一致性（标红）

安装到 `~/.cursor/skills/.../toolkit` 后，**默认严格校验** `manifest.json`（漂移 exit 4）。  
临时忽略：`$env:AIWORKSPACE_STRICT_MANIFEST="0"`。务必从本仓库跑 `install-cursor-global-skill.ps1` 更新。

## Cursor 安装

```powershell
./skills/install-cursor-global-skill.ps1
./skills/uninstall-cursor-global-skill.ps1 -Force   # 非交互必须 -Force
```

## 跨设备

1. 提交本仓库（或 `git init` + 配置 `origin`）  
2. 其它机器 `git pull`  
3. `./skills/resume-workspace.ps1 -SyncCache`  

**勿只拷贝 `cache/`**。歧义前缀用 `-ExactModule`；`-AllowAmbiguousPrefix` 仅取**第一个**匹配并警告。

## 批量

```powershell
./skills/auto-requirement.ps1 -BatchFile .\skills\requirements.batch.txt
# 中途失败后：
./skills/auto-requirement.ps1 -BatchFile .\skills\requirements.batch.txt -ResumeBatch
```

进度写入 `codestatrFirst/cache/.batch-progress.json`（已 gitignore）。

注释：`#` 或 `# ` 开头；数据 `#tag|req|P1`（`#` 后无空格）。

同名 `-Title` → `name-2` + Warning（不覆盖）。`-AsciiNames` 或 `AIWORKSPACE_ASCII_NAMES=1` 强制 ASCII 目录名。

## 退出码

| 码 | 含义 |
|----|------|
| 0 | 成功 |
| 1 | 失败 |
| 2 | 用法/歧义 |
| 3 | 锁超时 |
| 4 | 全局 manifest 漂移 |

## 质量门禁

- `validate-workspace.ps1` · `run-tests.ps1` · `analyze-workspace.ps1`  
- CI：validate + Pester + PSScriptAnalyzer（Windows）+ Ubuntu 冒烟  
- [RELEASE.md](RELEASE.md) · [CHANGELOG.md](CHANGELOG.md) · [LICENSE](LICENSE)
