# 杨与S8的博客站

基于 **Hexo 8 + Fluid 主题**，容器化部署，镜像托管于 GitHub Container Registry (GHCR)。

## 功能特性

- Fluid 主题：自适应、TOC、暗色模式
- 稳定短链接：`hexo-abbrlink`（permalink `post/:abbrlink/`）
- SEO & 订阅：`sitemap.xml`、`atom.xml`
- 本地搜索：`hexo-generator-searchdb`
- 代码高亮：Prism 预处理 + 复制按钮
- Markdown-it 增强：emoji / footnote / task list
- 文章字数 & 阅读时长：`hexo-symbols-count-time`
- 压缩优化：`hexo-neat` (HTML/CSS/JS)
- 评论系统：Waline (MariaDB 持久化)，通过同域子路径 `/comment/` 反代
- 自动更新：GitHub Actions 构建多架构镜像 + 服务器 `watchtower` 轮询拉取
- 构建信息：页脚显示镜像构建 commit 短哈希

## 目录结构（关键部分）

```
Dockerfile                # 多阶段构建 (Node -> Nginx)
docker-compose.yml        # 生产编排 (blog + waline + waline-db + watchtower)
docker/nginx.conf         # Nginx + /comment/ 反代 Waline
.dockerignore             # 精简构建上下文
_config.yml               # Hexo 主配置 (插件、permalink 等)
_config.fluid.yml         # 主题配置（页脚、Prism、Waline）
ops/backup-db.sh          # MariaDB 备份脚本
ops/update.sh             # 手动拉取最新镜像脚本
Makefile                  # 常用指令封装
.env.example              # 环境变量模板（复制为 .env）
```

## 服务器部署步骤（内网 pull 模式）

> 假设：服务器已安装 Docker & Docker Compose Plugin，外层有一层公网反向代理（或隧道）转发到此服务器 80 端口。

### 1. 克隆仓库 / 或仅复制编排文件
```bash
git clone https://github.com/YangYuS8/blog.git /opt/hexo
cd /opt/hexo
```

### 2. 准备 `.env`
复制模板并修改强随机密码：
```bash
cp .env.example .env
vi .env
```
最重要的字段：
- `MYSQL_ROOT_PASSWORD`
- `MYSQL_PASSWORD`
- `ADMIN_PASSWORD` (Waline 后台管理员)

### 3. 启动（首次）
```bash
docker compose up -d
```
常见验证：
```bash
curl -I http://127.0.0.1/        # 返回 200
curl -I http://127.0.0.1/comment/ # Waline 反代 (应 200 或 404 json)
docker compose ps
```

### 4. 自动更新机制

GitHub Actions 在 `main` 分支有内容或构建相关文件变动时构建并推送镜像：
```
ghcr.io/yangyus8/hexo-blog:latest
```
服务器上的 `watchtower` 每 30 分钟轮询检测该镜像标签更新，若有新版：
1. 拉取最新镜像
2. 重建 `blog` 服务（其它容器不会被动更新）
3. 清理旧镜像（启用了 `WATCHTOWER_CLEANUP=true`）

查看日志：
```bash
docker logs -f watchtower
```

### 5. 手动强制更新（无需等待轮询）
```bash
make update-local    # 或: bash ops/update.sh
```

### 6. 数据库备份
`ops/backup-db.sh` 支持自动保留最近 N 份（默认 7 份）。
```bash
make backup-db                 # 立即备份 -> backups/*.sql.gz
RETAIN=14 make backup-db       # 自定义保留数量
BACKUP_DIR=db_bak make backup-db
```
恢复示例：
```bash
gunzip -c backups/waline-2025XXXX-XXXXXX.sql.gz | \
	docker exec -i waline-db sh -c 'mysql -uwaline -p"$MYSQL_PASSWORD" waline'
```

推荐 cron：
```
0 3 * * * /opt/hexo/ops/backup-db.sh >> /var/log/waline-backup.log 2>&1
```

### 7. 日常运维命令
```bash
make watchtower-logs   # 观察自动更新
make backup-db         # 立即备份
make prune             # 清理本地构建残留（若有）
docker compose ps      # 查看容器状态
docker compose logs -f blog
```

### 8. 修改文章 & 发布流程
本地写作：
```bash
pnpm install           # 首次
make new t="我的第一篇文章"
make serve             # localhost:4000 预览
git add source/_posts/*.md
git commit -m "feat(post): 新文章 - 我的第一篇文章"
git push
```
Push 后：
1. GitHub Actions 触发构建 -> 推送新镜像
2. 服务器 watchtower 轮询获取新镜像 -> 重启 blog
3. 几分钟内生效（或手动 `make update-local`）

### 9. 页脚构建信息
CI 通过 `--build-arg GIT_COMMIT` 注入完整 SHA，构建阶段截取短哈希写入 `source/_includes/build_revision.ejs`，主题页脚调用：
```
©2025 杨与S8 Build: abc1234
```

### 10. 安全与加固建议（可选）
| 项目 | 建议 |
|------|------|
| MariaDB 访问 | 仅容器网络内可访问，不暴露 3306 端口 |
| 随机秘钥 | 保证 `.env` 中密码长度≥24 且含多类型字符 |
| 反向代理 | 外层启用 HTTPS、HSTS、HTTP/2、Gzip/ Brotli |
| 备份异地 | `rsync` / 对象存储周期上传 `backups/*.gz` |
| 最小化镜像 | 运行阶段使用 `nginx:alpine` 已较小，如需更小可自制 distroless 静态镜像 |
| watchtower 时间 | 视需求可调长（如 3600 秒）降低拉取频率 |

## 故障排查速查表

| 现象 | 排查 | 解决 |
|------|------|------|
| 页脚不显示 Build | 查看生成的 `public/index.html` 内是否含 `build-revision` | 确认 CI 传了 `GIT_COMMIT`，重新构建 |
| Waline 无法加载 | `curl -I http://127.0.0.1/comment/` | 检查 Nginx 反代、`waline` 容器是否健康 |
| 新文章迟迟不更新 | `docker logs watchtower` | 手动 `make update-local` 或调低轮询间隔 |
| 备份为空 | 查看 `backups/` 目录权限 | 确保挂载路径写入正常 |
| 构建失败找不到 nginx.conf | 确认 `.dockerignore` 未忽略 `docker/` | 调整后重新 push |

## 开发快捷命令（Makefile）

| 命令 | 说明 |
|------|------|
| `make new t="标题"` | 新文章 |
| `make serve` | 本地预览 |
| `make build` | 生成静态文件 |
| `make docker-build` | 本地构建 Docker 镜像 |
| `make update-local` | 服务器/本地拉取最新镜像并重启 |
| `make backup-db` | 立即备份 MariaDB |
| `make watchtower-logs` | 观察自动更新日志 |
| `make reset-site confirm=YES` | 清空文章与生成产物（保留配置与依赖）|
| `make reset-all confirm=ALL` | 更激进：清空文章/生成/数据库文件（不动配置），回到写作骨架 |
| `make delete-post abbr=XXXX force=YES` | 通过 abbrlink 删除单篇文章（安全防护需 force=YES）|

### 重置 / 清空说明

> 危险操作，务必先做好备份（文章 markdown + 数据库 + 主题定制）。

| 目标 | 会删除 | 保留 | 典型场景 |
|------|--------|------|----------|
| `reset-site` | `public/`, `db.json`, `source/_posts/*` | `_config*.yml`, `package.json`, 依赖、主题、`ops/` 脚本 | 重新开始写作但保留所有配置/插件 |
| `reset-all`  | 同上 + 重新创建空 posts 目录 | 同上 | 给他人交付“干净骨架”或演示初始化 |

执行示例：
```bash
make reset-site confirm=YES
# 或
make reset-all confirm=ALL
```
执行后可用：
```bash
make new t="Hello"
make serve
```

### 按 abbrlink 删除单篇文章

> 适用于已开启 `hexo-abbrlink` 且 front-matter 中存在 `abbrlink: <值>` 的文章。

命令格式：
```bash
make delete-post abbr=<短链接值>
```
保护机制：
1. 不带 `force=YES` 时只提示即将删除的文件路径；不会真的删除。  
2. 匹配到多个同 abbrlink 文件会直接终止（需手工排查冲突）。

真正删除：
```bash
make delete-post abbr=4a17b156 force=YES
```
删除后重新生成：
```bash
make clean && make build
```
可再推送：
```bash
git add .
git commit -m "chore: remove post 4a17b156"
git push
```

## License

个人博客项目，未特别声明的代码与配置默认遵循仓库内已有开源依赖的原始协议；文章内容版权归作者所有。若引用请注明出处。

---
欢迎 Issue / PR 反馈与改进。🚀