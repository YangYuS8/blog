#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

fail=0

echo -e "${YELLOW}[check] 必改项占位符检查...${NC}"

check_placeholder() {
  local pattern="$1"; local where="$2"; local suggest="$3"
  if grep -RIn --exclude-dir node_modules --exclude-dir .git --exclude-dir public --exclude-dir .deploy --exclude '*.lock' -e "$pattern" . > /dev/null; then
    echo -e "${RED}未替换占位符: $pattern (${where})${NC}"
    echo -e "  建议: $suggest"
    fail=1
  fi
}

# 1) BLOG_IMAGE 默认 OWNER
if grep -RIn "BLOG_IMAGE=ghcr.io/OWNER/hexo-blog:latest" .env .env.example 2>/dev/null | grep -q .; then
  echo -e "${RED}未替换 BLOG_IMAGE=ghcr.io/OWNER/hexo-blog:latest${NC}"
  echo "  建议: 将 OWNER 改为你的 GitHub 账户，如 ghcr.io/yourname/hexo-blog:latest"
  fail=1
fi

# 2) 站点域名 example 占位
check_placeholder "https://blog.example.com" "_config.yml / .env" "将其替换为你的域名，例如 https://blog.yourdomain.com"
check_placeholder "https://blog.example.com/comment/" "_config.yml / .env" "替换为你的评论路径，如 https://blog.yourdomain.com/comment/"

# 3) 主题中的 YourName 占位
check_placeholder "YourName" "_config.fluid.yml" "替换为你的名字或站点名"

# 4) README 徽章仓库占位
check_placeholder "<your-account>/<your-repo>" "README.md 徽章链接" "替换为你的 GitHub 仓库路径"

# 5) Dockerfile maintainer 占位
check_placeholder "YourName <you@example.com>" "Dockerfile LABEL maintainer" "改为你的姓名与邮箱，或删除该标签"

if [ $fail -eq 0 ]; then
  echo -e "${GREEN}[ok] 未发现必须替换的占位符。${NC}"
  exit 0
else
  echo -e "${YELLOW}[warn] 请根据上述建议完成替换后再提交。${NC}"
  exit 1
fi
