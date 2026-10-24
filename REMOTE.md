# 挂载 Git Remote（CI 守门）

本机可能没有 `gh`，Cursor Origin 命名空间也可能为空。用下列任一方式挂 remote 后即可 `git push`，触发 `.github/workflows/ci.yml`。

## GitHub（推荐）

1. 浏览器新建空仓库（不要勾选自动加 README）。  
2. 在本仓库根目录：

```powershell
git remote add origin https://github.com/<你>/<仓库名>.git
git push -u origin main
git tag -a v1.5.1 -m "toolkit 1.5.1"
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
