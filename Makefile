# Makefile for Hexo + Docker Deployment
# 使用: make <target>
# 若使用 zsh/bash: TAB 补全可查看可用命令

# ================= 基础变量 =================
SHELL := /bin/bash
HEXO := npx hexo
IMAGE := ghcr.io/yangyus8/hexo-blog:latest
DOCKER_COMPOSE := docker compose
DEPLOY_PATH ?= /opt/hexo

# 默认目标
.DEFAULT_GOAL := help

# ================= 开发本地 =================
.PHONY: install
install: ## 安装依赖 (pnpm)
	pnpm install

.PHONY: clean
clean: ## 清理 Hexo 缓存与已生成文件
	$(HEXO) clean

.PHONY: build
build: ## 生成静态文件 (public/)
	$(HEXO) generate

.PHONY: serve
serve: ## 本地启动预览 http://localhost:4000
	$(HEXO) server

.PHONY: new
new: ## 新建文章: make new t="标题"
ifndef t
	@echo "用法: make new t=标题" && exit 1
endif
	$(HEXO) new post "$(t)"

# ================= 质量/调试 =================
.PHONY: doctor
doctor: ## Hexo Doctor 检查
	$(HEXO) doctor || true

.PHONY: list-posts
list-posts: ## 列出已生成的文章路径 (abbrlink 确认)
	@find public/post -maxdepth 2 -name index.html 2>/dev/null || echo "尚未生成或无 post/ 目录"

# ================= Docker 本地构建与运行 =================
.PHONY: docker-build
docker-build: ## 本地构建多阶段镜像 (不推送)
	docker build -t $(IMAGE) .

.PHONY: docker-run
docker-run: docker-build ## 以本地镜像运行 (端口 8080)
	docker run --rm -p 8080:80 $(IMAGE)
	@echo "打开 http://localhost:8080"

# ================= 服务器相关（方案二） =================
.PHONY: remote-init
remote-init: ## 首次在服务器创建目录并上传 docker-compose.yml (需设 env: SSH_HOST SSH_USER)
ifndef SSH_HOST
	@echo "缺少 SSH_HOST 环境变量" && exit 1
endif
ifndef SSH_USER
	@echo "缺少 SSH_USER 环境变量" && exit 1
endif
	scp docker-compose.yml $$SSH_USER@$$SSH_HOST:$(DEPLOY_PATH)/

.PHONY: remote-up
remote-up: ## 服务器上拉起/更新 (需: SSH_HOST SSH_USER 已配置 compose、已由 CI 推送镜像)
	ssh $$SSH_USER@$$SSH_HOST 'cd $(DEPLOY_PATH) && $(DOCKER_COMPOSE) pull && $(DOCKER_COMPOSE) up -d --remove-orphans'

.PHONY: update-local
update-local: ## （本地/内网服务器）拉取最新镜像并重启 (ops/update.sh)
	bash ops/update.sh

.PHONY: watchtower-logs
watchtower-logs: ## 查看 watchtower 日志 (自动更新监控)
	docker logs -f watchtower || echo "watchtower 未运行"

.PHONY: remote-logs
remote-logs: ## 服务器查看所有容器日志 (可加 f=容器名 只看某个)
ifndef SSH_HOST
	@echo "缺少 SSH_HOST" && exit 1
endif
ifndef SSH_USER
	@echo "缺少 SSH_USER" && exit 1
endif
	@if [ -z "$$f" ]; then \
	  ssh $$SSH_USER@$$SSH_HOST 'docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}"'; \
	else \
	  ssh $$SSH_USER@$$SSH_HOST "docker logs -f $$f"; \
	fi

.PHONY: remote-shell
remote-shell: ## 进入服务器 blog 容器交互: make remote-shell c=hexo-blog
ifndef SSH_HOST
	@echo "缺少 SSH_HOST" && exit 1
endif
ifndef SSH_USER
	@echo "缺少 SSH_USER" && exit 1
endif
	ssh $$SSH_USER@$$SSH_HOST "docker exec -it $${c:-hexo-blog} /bin/sh"

.PHONY: prune
prune: ## 本地清理无用 Docker 镜像/缓存
	docker image prune -f
	docker builder prune -f || true

# ================= 数据库备份 =================
.PHONY: backup-db
backup-db: ## 备份 Waline 数据库 (本地/服务器同理，可设置 RETAIN=14 BACKUP_DIR=backups)
	bash ops/backup-db.sh

# ================= 实用信息 =================
.PHONY: help
help: ## 显示所有可用目标
	@echo "可用命令:" && echo && \
	grep -E '^[a-zA-Z0-9_-]+:.*?##' Makefile | sort | awk 'BEGIN {FS":.*?##"}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}' && echo && \
	echo "示例:" && \
	echo "  make new t=你好世界" && \
	echo "  make build" && \
	echo "  make docker-build" && \
	echo "  make remote-up SSH_HOST=server SSH_USER=root" && \
	echo "  make remote-logs SSH_HOST=server SSH_USER=root f=waline"
