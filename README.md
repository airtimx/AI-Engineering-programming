# AI Skill Workspace

可复用 AI 工作区脚手架（**toolkit v1.5.3**，MIT）。

**产品边界**：只做 specs/cache 脚手架与 Skill 安装；**不**自动改业务代码、不自动开 PR（`-SuggestCommit` 仅打印文案）。多人用 `claim`/`release`/`who` 轻量认领，不是完整项目管理。

## 5 分钟故事线（复制即用）

在项目根（或本仓库）打开终端：

```powershell
# 0) 可选：装到 Cursor + Trae 全局 Skill
./skills/aiws.ps1 install -IDE All

# 1) 初始化工作区捆（新项目目录名为 workspace/；旧项目仍识别 codestatrFirst/）
./skills/aiws.ps1 init

# 2) 新建模块（生成 specs 三件套 + cache）
./skills/aiws.ps1 new -Title "用户登录" -Requirement "手机号验证码登录" -Priority P1

# 3) 打开生成的 tasks.md，勾选完成的条目，例如：
#    workspace/specs/用户登录/tasks.md   （或 legacy: codestatrFirst/specs/...）

# 4) 续接 / 同步进度
./skills/aiws.ps1 resume -SyncCache

# 5) 其它电脑：git pull 后同样 resume（勿只拷贝 cache/）
./skills/aiws.ps1 resume -SyncCache
```

只需记住一个入口：`./skills/aiws.ps1`（`init` | `new` | `resume` | `status` | `install` | `doctor`）。

出问题先跑：

```powershell
./skills/aiws.ps1 doctor
./scripts/verify-local.ps1          # 本地一键：Pester 5 + validate + analyzer
./skills/validate-workspace.ps1 -Quiet   # 安静自检（无沙盒路径刷屏）
```

> **`manifest.json`**：由 `install-global-skill.ps1` **安装时**写入 `%USERPROFILE%\.cursor\skills\...\toolkit\`（或 Trae 对应路径），**仓库不提交**该文件。

---

## 它做什么 / 不做什么

- **做**：在 `workspace/`（或兼容旧名 `codestatrFirst/`）生成 specs/cache/bugfix 骨架与续接状态。  
- **不做**：自动开 PR/Issue、改业务代码（刻意保持薄；可用 `-SuggestCommit` 只打印建议文案）。

**支持矩阵**：Windows PowerShell 5.1（主）、PowerShell 7+ Windows；Linux/macOS 为 CI 冒烟/尽力，非第一方对等支持。对话触发依赖 Cursor / Trae Skill；脚本可独立跑。

## 统一入口速查

```powershell
./skills/aiws.ps1 init [-Root D:\proj]
./skills/aiws.ps1 new -Title "..." -Requirement "..." [-Owner 你] [-AsciiNames]
./skills/aiws.ps1 new -BatchFile .\skills\requirements.batch.example.txt
./skills/aiws.ps1 resume [-Module 登录] [-SyncCache] [-SuggestCommit] [-Json]
./skills/aiws.ps1 status
./skills/aiws.ps1 claim -Module 登录 [-Owner 你]   # 轻量认领
./skills/aiws.ps1 who
./skills/aiws.ps1 install -IDE All          # 或 Cursor / Trae（安装时强制 .ps1 UTF-8 BOM）
./skills/aiws.ps1 uninstall -IDE All -Force
./skills/aiws.ps1 doctor
```

挂 Git remote / 开 CI：见 [REMOTE.md](REMOTE.md)。

底层脚本仍可用（`init-workspace.ps1` 等）。安装器正式名：`install-global-skill.ps1`；旧名 `install-cursor-global-skill.ps1` 为 deprecated 包装。

## 批量文件

- 整行以 `#` 开头 → **注释**（不再支持 `#title|req` 当数据）。  
- 数据行：`title|requirement|priority(optional)`  
- 示例：`skills/requirements.batch.example.txt`

## 跨设备（写死）

1. 提交 **`workspace/specs/**`（或 legacy `codestatrFirst/specs/**`）与 **`…/cache/*.json`**  
2. 其它机器 `git pull` → `./skills/aiws.ps1 resume -SyncCache`  
3. **勿只拷贝 cache/**  

可选 `owner` 字段：`-Owner 你` 或环境变量 `AIWORKSPACE_OWNER`（写入 cache，便于多人辨认）。

## 危险旋钮

- `AIWORKSPACE_ALLOW_ANY_ROOT=1`：关闭路径防护（仅排错）。  
- 全局 toolkit 默认严格 `manifest.json`；临时忽略：`AIWORKSPACE_STRICT_MANIFEST=0`。

## 退出码

| 码 | 含义 |
|----|------|
| 0 | 成功 |
| 1 | 失败 |
| 2 | 用法/歧义 |
| 3 | 锁超时 |
| 4 | 全局 manifest 漂移 |

## 质量门禁（本地一键）

```powershell
./scripts/verify-local.ps1
# 或分步：
./scripts/bootstrap-pester.ps1          # 装 Pester 5.5+（兼容本机自带 3.4）
./skills/validate-workspace.ps1 -Quiet  # 推荐 Quiet
./skills/run-tests.ps1                  # Invoke-Pester tests/
./skills/analyze-workspace.ps1
```

CI（Windows + Ubuntu）：bootstrap → validate → **Invoke-Pester `tests/`** → analyzer。  
[RELEASE.md](RELEASE.md) · [CHANGELOG.md](CHANGELOG.md) · [LICENSE](LICENSE) · [使用说明.md](使用说明.md) · [REMOTE.md](REMOTE.md)
