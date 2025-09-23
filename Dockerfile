## Multi-stage build for Hexo static site
## Stage 1: Build site
FROM node:20-alpine AS builder
WORKDIR /app

# Enable corepack to use pnpm without global install
RUN corepack enable

COPY package.json pnpm-lock.yaml* ./
RUN pnpm install --frozen-lockfile=false

COPY . .

# Build static site
RUN npx hexo generate

## Stage 2: Nginx minimal image serving static files
FROM nginx:1.27-alpine AS runtime
LABEL maintainer="you <you@example.com>"
LABEL org.opencontainers.image.source="https://github.com/yourname/yourrepo"

## Copy custom nginx config
COPY docker/nginx.conf /etc/nginx/conf.d/default.conf

## Copy built site
COPY --from=builder /app/public /usr/share/nginx/html

## Healthcheck (simple index.html existence)
HEALTHCHECK --interval=30s --timeout=3s --retries=3 CMD [ -f /usr/share/nginx/html/index.html ] || exit 1

EXPOSE 80
CMD ["nginx","-g","daemon off;"]
