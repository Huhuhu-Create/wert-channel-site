# wert聊天室频道 · 官网主页

一个聊天室风格的 QQ 频道主页，展示频道简介 / 公告 / 实时帖子流 / 成员数 / 加入二维码，可托管到 GitHub Pages 并绑定域名。

## 文件说明

| 文件 | 作用 |
|------|------|
| `index.html` | 主页（聊天室风格），读取 `data.json` 渲染，每 60s 自动轮询刷新 |
| `fetch_channel.py` | Python 后端脚本：调用 `tencent-channel-cli` 实时拉取频道数据，生成 `data.json` |
| `data.json` | 由脚本生成的数据文件（**不要手改**，重跑脚本即更新） |
| `CNAME` | 绑定自定义域名用（没域名可删） |

## 一、生成本地数据（先跑一次）

```bash
# 1. 安装并登录腾讯频道 CLI（只需一次）
npm install -g tencent-channel-cli
tencent-channel-cli login        # 扫码授权

# 2. 运行抓取脚本，生成 data.json
python fetch_channel.py
```

脚本会输出 `data.json`，内含频道信息 + 最新帖子 + 评论。

> 想"实时"更新：用定时任务周期跑脚本（Windows 任务计划 / macOS crontab / GitHub Actions）。
> 例如每小时刷新一次，主页就会自动看到新帖子（HTTP 服务器下 60s 轮询生效）。

## 二、本地预览

**注意**：浏览器禁止 `file://` 直接 `fetch` 本地文件，必须用本地服务器：

```bash
cd wert-channel-site
python -m http.server 8080
# 浏览器打开 http://localhost:8080
```

## 三、部署到 GitHub Pages（可绑域名）

1. 在 GitHub 新建仓库（如 `wert-channel-site`）
2. 把本目录所有文件 push 上去
3. 仓库 **Settings → Pages → Build and deployment → Source 选 "Deploy from a branch" → 选 `main` 分支 `/root`**
4. 等 1~2 分钟，访问 `https://你的用户名.github.io/wert-channel-site`

### 绑定自己的域名
1. 编辑 `CNAME` 文件，把 `your-domain.example.com` 改成你的真实域名
2. 域名 DNS 加一条 `CNAME` 记录，指向 `你的用户名.github.io`
3. 回到 Pages 设置，填 Custom domain 并保存（GitHub 会自动签发 HTTPS 证书）

## 四、关于"实时数据"的真相

浏览器**无法直接调** QQ 频道 API（需登录态 + 无 CORS）。本方案的正确链路是：

```
tencent-channel-cli (需登录)
        │  fetch_channel.py 周期运行
        ▼
     data.json  ──►  index.html 每 60s 轮询  ──►  用户看到"实时"帖子流
        │
   GitHub Pages 托管（可绑域名）
```

若想要**无需手动跑脚本的真·实时**，可把 `fetch_channel.py` 改成部署在免费 Python 后端（Render / Vercel 函数），
由它对外提供 `/api/feeds` 接口，前端直接 `fetch` 该接口——那样数据永远最新。本仓库 `fetch_channel.py` 已封装好
`get_guild_info / get_feeds / get_feed_detail / get_comments`，迁移到后端只需包一层 HTTP 服务。

## 频道信息（实测）
- 频道名：wert聊天室频道
- 频道号：pd47256105
- 分享链接：https://pd.qq.com/s/g53fkmapy
- 频道主：wddshuo（QQ 365965379）
