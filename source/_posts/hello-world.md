---
title: 快速上手：Hexo 博客模板使用指南
date: 2025-09-24 00:00:00
updated: 2025-09-24 00:00:00
categories: [指南]
tags: [模板, 部署, CI, Docker, Waline]
toc: true
comments: true
# description: 用 5 分钟完成模板初始化与首次部署，包含必改项清单与常用命令。
abbrlink: 4a17b156
---

这是一篇“开箱即用”的模板引导，带你用 5 分钟完成初始化、写作预览与首次部署。

## 模板包含什么
- 主题：Fluid（自适应、TOC、深浅色）
- 插件：Feed/Atom、Sitemap、本地搜索、abbrlink（短链）、Prism 代码高亮、markdown-it 增强、Neat 压缩、字数/时长统计
- 评论：Waline（可按篇开启/关闭），同域子路径 `/comment/`
- 构建与发布：GitHub Actions 多架构构建 → GHCR；Watchtower 自动拉取更新
- 部署：多阶段 Docker（Node 构建 → Nginx 运行），`docker-compose.yml`

## 使用前准备（Use this template）
1. 在 GitHub 点击 `Use this template`，从本模板创建你自己的仓库。
2. 编辑 README 顶部徽章中的仓库路径为你的 `<your-account>/<your-repo>`。
3. 复制并修改环境：
	 ```bash
	 cp .env.example .env
	 # 必改：强随机密码与域名
	 # BLOG_IMAGE=ghcr.io/<your-account>/hexo-blog:latest
	 ```
4. 运行健康检查（可选）：
	 ```bash
	 bash scripts/check-template.sh
	 ```

## 必改项（清单）
- `.env`：`MYSQL_ROOT_PASSWORD`/`MYSQL_PASSWORD`/`ADMIN_PASSWORD`
- `.env`：`SITE_URL` 与 `WALINE_PUBLIC_URL`（如 `https://blog.example.com` 和其 `/comment/`）
- `.env`：`BLOG_IMAGE=ghcr.io/<your-account>/hexo-blog:latest`
- `/_config.yml`：`title/subtitle/author/url` 及 `waline.serverURL`
- `/_config.fluid.yml`：`navbar.logo.text`、`footer.content` 中的名字占位

## 本地写作与预览
```bash
pnpm install
make new t="我的第一篇文章"
make serve   # http://localhost:4000
```
建议在文章中使用 `<!-- more -->` 插入摘要分隔，`description` 可在 Front Matter 自定义。

## CI/CD（默认启用）
- 推送到 `main` 分支将触发工作流：
	- 构建多架构镜像
	- 推送至 `ghcr.io/<your-account>/hexo-blog`（由 `BLOG_IMAGE` 指定）
- 服务器侧 Watchtower 轮询并自动拉取新版镜像

## 生产部署（最短路径）
```bash
git clone https://github.com/<your-account>/<your-repo>.git /opt/hexo
cd /opt/hexo && cp .env.example .env && vi .env  # 填好上文“必改项”
docker compose up -d
```
将你的域名通过外层反向代理（Nginx/Caddy）指向 blog 容器的 `80` 端口。

## 图片与附件（推荐唯一方式）
- 使用 PicGo（S3 插件）上传到 MinIO/S3，文章直接粘贴外链。
- 可选：叠加 `docker-compose.minio.yml` 启动 MinIO，并执行：
	```bash
	make minio-init
	```

## 常用命令速查
```bash
make new t="标题"   # 新文章
make serve          # 本地预览
make build          # 生成静态内容
make docker-build   # 本地构建镜像
make update-local   # 拉取最新镜像并重启
make backup-db      # 备份数据库
```

---
祝写作愉快！可以删掉本篇“指南”，从你的第一篇文章开始。 🚀
