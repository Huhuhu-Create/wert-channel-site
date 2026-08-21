# wert频道主页 - 部署到云端 教程

目标: 把 `api_server.py` 放到永远在线的云服务器, 主页(Pages)直接拉云端数据,
不再依赖你这台 Windows 开机。

## 架构
```
浏览器 → GitHub Pages 主页 → 云端URL(8000) api_server.py → 腾讯频道CLI → 腾讯API
                              ↑ 这台机器 24/7 在线
```

## 关键点: 云端必须有 CLI 登录态
api_server.py 内部调用 `tencent-channel-cli` 拉数据。云端是台新机器, 没有登录态。
两种解决:

### 方案1 (推荐, 持久磁盘平台): Railway / Fly.io / VPS
1. 云端装 cli: `npm install -g tencent-channel-cli`
2. 首次登录: `python cloud_login_once.py` → 生成二维码 → 手机QQ扫码授权
   (登录态存进云端 `~/.qqcli`, 持久磁盘不会丢)
3. 启动: `python api_server.py`
之后永久可用, 不用再登录。

### 方案2 (Render 免费层, 无持久磁盘): 每次部署需重新登录
Render 免费层每次部署清空磁盘, 登录态会丢。两种对策:
- 用 Render 的 **Persistent Disk**(付费) 挂到 `~/.qqcli`
- 或部署后手动跑一次 `cloud_login_once.py`

## 部署步骤 (以 Railway 为例, 有免费额度 + 持久卷)
1. 注册 railway.app, 连 GitHub 仓库 Huhuhu-Create/wert-channel-site
2. New Project → Deploy from GitHub repo
3. 加一个 Volume, 挂载路径 `/root/.qqcli` (保存登录态)
4. 自动识别 railway.json 启动 `python api_server.py`
5. 部署后第一次: 进 Railway 的 Shell, 跑 `python cloud_login_once.py` 扫码登录
6. 拿到公网地址 如 `https://wert-production.up.railway.app`
7. 改本仓库 `api-config.json` 的 public_api 为
   `https://wert-production.up.railway.app/api/feeds`, 推 GitHub
8. Pages 主页立即改用云端数据 ✅

## 环境变量
- `PORT` (默认 8000, 云平台通常自动注入)
- `HOST` (默认 0.0.0.0)

## 文件清单
- api_server.py      实时后端(http.server 标准库, 调 CLI)
- cloud_login_once.py 云端首次登录(生成二维码扫码)
- fetch_channel.py   CLI 封装(被 api_server 复用)
- index.html         聊天室主页
- Procfile / railway.json / Dockerfile  部署配置
- DEPLOY.md          本文件

## 重要安全提醒
- 登录态 = 你的 QQ 登录凭证, 只在你自己的云服务器/账号下使用
- 不要把 `~/.qqcli` 目录、token 提交进 git
- 仓库 .gitignore 已排除 .env / 凭据类文件
- 若用 Render 免费层 + 公开 repo, 切勿把 token 写进代码或日志
