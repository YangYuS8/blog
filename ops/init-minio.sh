#!/usr/bin/env bash
set -euo pipefail

# 初始化 MinIO：创建桶、设置公开策略（可选只读）、生成子路径
# 依赖：mc (MinIO Client)。若未安装，可用 docker 方式临时执行。

ENDPOINT="${MINIO_ENDPOINT:-http://127.0.0.1:9000}"
ACCESS_KEY="${MINIO_ROOT_USER:-minioadmin}"
SECRET_KEY="${MINIO_ROOT_PASSWORD:-minioadmin}"
BUCKET="${MINIO_BUCKET:-blog}"
PUBLIC_PREFIX="${MINIO_PUBLIC_PREFIX:-https://cdn.example.com}" # 供前端引用的域名/反代

echo "[+] 配置 mc alias -> minio"
if ! command -v mc >/dev/null 2>&1; then
  echo "未检测到 mc，临时用 docker 运行..."
  docker run --rm -e MC_HOST_minio="http://$ACCESS_KEY:$SECRET_KEY@${ENDPOINT#http://}" minio/mc:latest \
    mc mb -p minio/${BUCKET} || true
  docker run --rm -e MC_HOST_minio="http://$ACCESS_KEY:$SECRET_KEY@${ENDPOINT#http://}" minio/mc:latest \
    mc anonymous set download minio/${BUCKET}
  echo "[✓] 桶 ${BUCKET} 就绪 (匿名可读)"
  exit 0
fi

mc alias set minio "$ENDPOINT" "$ACCESS_KEY" "$SECRET_KEY" --api s3v4
mc mb -p minio/${BUCKET} || true
mc anonymous set download minio/${BUCKET}
echo "[✓] 桶 ${BUCKET} 就绪 (匿名可读)"
echo "示例直链：${PUBLIC_PREFIX}/${BUCKET}/path/to/image.png"
