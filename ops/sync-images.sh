#!/usr/bin/env bash
set -euo pipefail

SRC_DIR=${1:-source/images}
ENDPOINT="${MINIO_ENDPOINT:-http://127.0.0.1:9000}"
ACCESS_KEY="${MINIO_ROOT_USER:-minioadmin}"
SECRET_KEY="${MINIO_ROOT_PASSWORD:-minioadmin}"
BUCKET="${MINIO_BUCKET:-blog}"

if [ ! -d "$SRC_DIR" ]; then
  echo "源目录不存在: $SRC_DIR" >&2
  exit 1
fi

echo "[+] 同步 $SRC_DIR -> minio/${BUCKET}/images/"
if command -v mc >/dev/null 2>&1; then
  mc alias set minio "$ENDPOINT" "$ACCESS_KEY" "$SECRET_KEY" --api s3v4 >/dev/null
  mc mb -p minio/${BUCKET} >/dev/null 2>&1 || true
  mc mirror --overwrite --remove "$SRC_DIR" "minio/${BUCKET}/images/"
else
  echo "未检测到 mc，临时使用 docker 运行 mc..."
  docker run --rm \
    -e MC_HOST_minio="http://$ACCESS_KEY:$SECRET_KEY@${ENDPOINT#http://}" \
    -v "$(pwd)/$SRC_DIR:/work" \
    minio/mc:latest \
    sh -c "mc mb -p minio/${BUCKET} || true && mc mirror --overwrite --remove /work minio/${BUCKET}/images/"
fi
echo "[✓] 完成"
