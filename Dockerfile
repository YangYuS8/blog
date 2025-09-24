## Multi-stage build for Hexo static site
## Stage 1: Build site
FROM node:20-alpine AS builder
WORKDIR /app

# Enable corepack to use pnpm without global install
RUN corepack enable

COPY package.json pnpm-lock.yaml* ./
RUN pnpm install --frozen-lockfile=false

COPY . .

# 可通过构建参数传入 Git 短哈希
ARG GIT_COMMIT=unknown
ENV GIT_COMMIT_SHA=$GIT_COMMIT

# 将 commit 信息写入局部片段（短哈希），供主题 footer 引用
RUN SHORT_SHA=$(printf "%s" "$GIT_COMMIT_SHA" | cut -c1-7); \
	mkdir -p source/_includes; \
	echo "<span id=\"build-revision\">Build: ${SHORT_SHA}</span>" > source/_includes/build_revision.ejs; \
	npx hexo generate

## Stage 2: Nginx minimal image serving static files
FROM nginx:1.27-alpine AS runtime
ARG REPO_URL
LABEL maintainer="YourName <you@example.com>"
LABEL org.opencontainers.image.source=${REPO_URL:-"https://github.com/OWNER/REPO"}

## Copy custom nginx config
COPY docker/nginx.conf /etc/nginx/conf.d/default.conf

## Copy built site
COPY --from=builder /app/public /usr/share/nginx/html

## Healthcheck (simple index.html existence)
HEALTHCHECK --interval=30s --timeout=3s --retries=3 CMD [ -f /usr/share/nginx/html/index.html ] || exit 1

EXPOSE 80
CMD ["nginx","-g","daemon off;"]
