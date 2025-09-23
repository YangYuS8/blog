#!/usr/bin/env bash
set -euo pipefail
# Wrapper to stay backward compatible if someone still calls old path
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Directly include original logic (duplicated for clarity)
# Waline MariaDB 自动备份脚本 (migrated from scripts/)
DB_CONTAINER=${DB_CONTAINER:-waline-db}
DATABASE=${MYSQL_DATABASE:-waline}
USER=${MYSQL_USER:-root}
PASSWORD_ENV=${MYSQL_PASSWORD:-}
ROOT_PASSWORD_ENV=${MYSQL_ROOT_PASSWORD:-}
BACKUP_DIR=${BACKUP_DIR:-backups}
RETAIN=${RETAIN:-7}
mkdir -p "${BACKUP_DIR}"
TS=$(date +%Y%m%d-%H%M%S)
DUMP_FILE="${BACKUP_DIR}/waline-${TS}.sql"
if [ -n "${PASSWORD_ENV}" ] && [ "${USER}" != "root" ]; then
  AUTH="-u${USER} -p${PASSWORD_ENV}"
elif [ -n "${ROOT_PASSWORD_ENV}" ]; then
  USER=root
  AUTH="-u${USER} -p${ROOT_PASSWORD_ENV}"
else
  echo "[WARN] 未在环境变量中检测到 MYSQL_PASSWORD 或 MYSQL_ROOT_PASSWORD，尝试无密码连接。" >&2
  AUTH="-u${USER}"
fi
echo "[INFO] 备份数据库: ${DATABASE} -> ${DUMP_FILE}.gz"
if ! docker ps --format '{{.Names}}' | grep -qw "${DB_CONTAINER}"; then
  echo "[ERROR] 容器 ${DB_CONTAINER} 不存在或未运行" >&2; exit 1; fi
if ! docker exec "${DB_CONTAINER}" sh -c "mysqldump ${AUTH} --single-transaction --quick --lock-tables=false ${DATABASE}" > "${DUMP_FILE}"; then
  echo "[ERROR] mysqldump 执行失败" >&2; rm -f "${DUMP_FILE}"; exit 1; fi
gzip "${DUMP_FILE}" || { echo "[ERROR] gzip 失败" >&2; exit 1; }
# 清理旧备份
TOTAL=$(ls -1 ${BACKUP_DIR}/waline-*.sql.gz 2>/dev/null | wc -l || true)
if [ "${TOTAL}" -gt "${RETAIN}" ]; then
  REMOVE=$(( TOTAL - RETAIN ))
  echo "[INFO] 超出保留数 ${RETAIN}，删除最旧 ${REMOVE} 个"; ls -1t ${BACKUP_DIR}/waline-*.sql.gz | tail -n ${REMOVE} | xargs -r rm -f; fi
echo "[INFO] 当前备份文件数: $(ls -1 ${BACKUP_DIR}/waline-*.sql.gz 2>/dev/null | wc -l || true)"; echo "[INFO] 完成"