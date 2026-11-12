# 挂载 Git Remote（CI 守门）

本机可能没有 `gh`，Cursor Origin 命名空间也可能为空。用下列任一方式挂 remote 后即可 `git push`，触发 `.github/workflows/ci.yml`。

## GitHub（推荐）

1. 浏览器新建空仓库（不要勾选自动加 README）。  
2. 在本仓库根目录：

```powershell
git remote add origin https://github.com/<你>/<仓库名>.git
git push -u origin main
git tag -a v1.5.3 -m "toolkit 1.5.3"
git push origin --tags
```

若已安装 [GitHub CLI](https://cli.github.com/)：

```powershell
gh auth login
gh repo create <仓库名> --private --source=. --remote=origin --push
```

## Cursor Origin

若账号已开通 Origin：

```powershell
# 按 Origin 文档创建仓库后
git remote add origin https://origin.cursor.com/<namespace>/<repo>.git
git push -u origin main
```

## 验证

```powershell
git remote -v
./skills/aiws.ps1 doctor
# 推送后在 GitHub Actions 查看 CI：validate + Pester + analyzer + Trae hash sync
```

## 网络受限时

直连 `github.com:443` 被重置（`Recv failure: Connection was reset`、`Failed to connect ... port 443`）时，可临时走本机代理：

```powershell
git -c http.proxy=http://127.0.0.1:7897 push origin main
git -c http.proxy=http://127.0.0.1:7897 push origin v1.5.3
```

## Tag 触发 Release

推送 `v*` tag 会触发 `.github/workflows/release.yml`：`scripts/build-release.ps1 -ExpectedVersion <tag>` → 产出 `dist/AIWorkspaceManager-<版本>.zip` + `.sha256` → `gh release create`。

失败排查：运行日志需要登录（匿名 API 只能看到 `conclusion`，日志接口返回 403）；本地等价命令为：

```powershell
./scripts/build-release.ps1 -ExpectedVersion v1.5.3
```
