# AI Skill Workspace

可复用 AI 工作区脚手架（**toolkit v1.3.0**，MIT）。业务与文档一律在 **`codestatrFirst/`**；仓库根 **`skills/`** 仅放 PowerShell 工具。

**支持**：Windows PowerShell 5.1+、PowerShell 7+（Win；Linux/macOS 尽力支持）。

## 快速开始

```powershell
git init   # 本仓库若尚无 Git
./skills/init-workspace.ps1
./skills/auto-requirement.ps1 -Title "用户登录" -Requirement "手机号验证码登录" -Priority P1
./skills/resume-workspace.ps1 -SyncCache
./skills/validate-workspace.ps1
```

其它项目：

```powershell
pwsh -NoProfile -File "…/skills/init-workspace.ps1" -Root "D:\path\to\project"
```

`-Root` 须像项目目录（含 `.git` / 已有 `codestatrFirst` / 本仓库 `skills`）。盘符根、系统路径、UNC 会被拒绝。

### 危险逃逸口（标红）

**`AIWORKSPACE_ALLOW_ANY_ROOT=1` 会关闭路径防护。** 仅在受控排错时使用；正常流程不要设置。设置后每次解析 `-Root` 都会打印红色 SECURITY 横幅。详见 [RELEASE.md](RELEASE.md)。

## Cursor 全局安装

**必须从本模板仓库运行**（勿在 `~/.cursor/.../toolkit` 里跑安装器）：

```powershell
./skills/install-cursor-global-skill.ps1
```

写入 `%USERPROFILE%\.cursor\skills\aiworkspace-manager\`（非 Windows 为 `$HOME/.cursor/...`）与 **`toolkit/manifest.json`（SHA256）**。  
漂移硬失败：`$env:AIWORKSPACE_STRICT_MANIFEST="1"`。卸载：`./skills/uninstall-cursor-global-skill.ps1`。

## 跨设备续接

1. 使用本仓库 Git（或 `git init` + remote）提交（含 `codestatrFirst/**/.gitkeep`）  
2. 其它电脑 `git pull`  
3. `./skills/resume-workspace.ps1 -SyncCache`  
4. 按 `tasks.md` 未完成项继续  

**勿只拷贝 `cache/`**。模块前缀歧义时用 `-ExactModule`。

## 质量门禁

- 本地：`./skills/validate-workspace.ps1` + Pester `tests/`  
- CI：`.github/workflows/ci.yml`（Windows 全量 + Ubuntu pwsh 冒烟）  
- 发布清单：[RELEASE.md](RELEASE.md) · 变更：[CHANGELOG.md](CHANGELOG.md) · 许可：[LICENSE](LICENSE)

## 并发

写 cache / 创建模块时使用 `codestatrFirst/.locks/*.lock`（跨进程文件锁）。

## cache.status

`initialized` | `in_progress` | `done` | `unknown`
