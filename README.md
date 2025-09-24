# Hexo 博客模板（Fluid 主题 + Docker 部署）

<p align="center">
  <img src="https://img.shields.io/badge/Hexo-8.x-brightgreen?logo=hexo" alt="Hexo">
  <img src="https://img.shields.io/badge/Theme-Fluid-blue" alt="Theme Fluid">
  <a href="https://github.com/YangYuS8/blog/actions/workflows/docker-deploy.yml">
    <img src="https://github.com/YangYuS8/blog/actions/workflows/docker-deploy.yml/badge.svg" alt="Build">
  </a>
</p>

轻量、可直接复用的 Hexo 模板仓库：集成 Fluid 主题、Prism 代码高亮、Feed/Sitemap、本地搜索、Waline 评论；通过 GitHub Actions 构建多架构镜像并推送 GHCR，配合 Watchtower 自动更新。

## 使用前准备（Use this template）
- 在 GitHub 上点击 `Use this template`，从本模板创建你自己的仓库（推荐方式）。
- 将本文件顶部构建徽章中的仓库路径替换为你的 `<your-account>/<your-repo>`。
- 在 `.env` 中将 `BLOG_IMAGE` 修改为你的镜像命名空间，例如：`ghcr.io/<your-account>/hexo-blog:latest`。

## 快速开始
```bash
git clone https://github.com/<your-account>/<your-repo>.git blog
cd blog
cp .env.example .env
# 修改 .env 中的密码与域名；确认 BLOG_IMAGE=ghcr.io/<your-account>/hexo-blog:latest
docker compose up -d
```

本地写作预览：
```bash
pnpm install
make new t="第一篇文章"
make serve  # http://localhost:4000
```

模板健康检查（可选）：
```bash
bash ops/check-template.sh  # 打印仍未替换的占位符与建议
```

## 必改项（5 分钟配置）
- `.env`：
  - `MYSQL_ROOT_PASSWORD` / `MYSQL_PASSWORD` / `ADMIN_PASSWORD`（强随机密码）
  - `SITE_URL` 与 `WALINE_PUBLIC_URL`（例如 `https://blog.example.com` 与其 `/comment/`）
  - `BLOG_IMAGE`（建议设为 `ghcr.io/<your-account>/hexo-blog:latest`）
- `/_config.yml`：
  - `title` / `subtitle` / `author`
  - `url`（与你的 `SITE_URL` 一致）
  - `waline.serverURL`（与你的 `WALINE_PUBLIC_URL` 一致）
- `/_config.fluid.yml`：
  - `navbar.logo.text` / `footer.content` 中的名字占位符（或保持默认）

## CI/CD（已默认启用）
- 分支 `main` 推送即触发 `.github/workflows/docker-deploy.yml`：
  - 构建多架构镜像
  - 推送 `ghcr.io/<your-account>/hexo-blog`（由 `BLOG_IMAGE` 指定）
- 服务器侧运行 `watchtower` 自动拉取最新镜像

## 生产部署建议
1) 在服务器执行：
```bash
git clone https://github.com/<your-account>/<your-repo>.git /opt/hexo
cd /opt/hexo && cp .env.example .env && vi .env  # 按上文“必改项”配置
docker compose up -d
```
2) 外层反向代理（Nginx/Caddy）将域名指向 blog 容器的 80 端口。
3) 强制立即更新：
```bash
make update-local
```

## 图片与附件（推荐唯一方式）
- 使用 PicGo（S3 插件）上传到 MinIO/S3，文章直接粘贴外链。
- 可选：`docker-compose.minio.yml` 启动 MinIO，并执行 `make minio-init` 初始化桶策略。

## 常用命令
```bash
make new t="标题"   # 新文章
make serve          # 本地预览
make build          # 生成静态内容
make docker-build   # 本地构建镜像
make update-local   # 拉取最新镜像并重启
make backup-db      # 备份数据库
```

## License
该模板仅用于个人/团队博客搭建。文章内容版权归作者。