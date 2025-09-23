#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${SCRIPT_DIR}/.."
cd "$PROJECT_ROOT"
echo "[1/3] 拉取最新镜像"
docker compose pull
echo "[2/3] 启动/更新容器"
docker compose up -d --remove-orphans
echo "[3/3] 清理旧镜像"
docker image prune -f || true
echo "完成。"