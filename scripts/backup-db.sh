#!/usr/bin/env bash
set -euo pipefail

# Waline MariaDB 自动备份脚本
# 功能:
#  1. 进入 waline-db 容器执行 mysqldump 导出指定库
#  2. 以 时间戳 命名 SQL 文件并 gzip 压缩
#  3. 维护最近 N 份备份 (默认 7)
#  4. 可选: 输出完成信息
#
# 使用:
#  chmod +x scripts/backup-db.sh
#  ./scripts/backup-db.sh            # 使用默认值
#  RETAIN=14 ./scripts/backup-db.sh  # 保留 14 份
#
# 可加入宿主机 cron:
#  0 3 * * * /path/to/repo/scripts/backup-db.sh >> /var/log/waline-backup.log 2>&1

DB_CONTAINER=${DB_CONTAINER:-waline-db}
DATABASE=${MYSQL_DATABASE:-waline}
USER=${MYSQL_USER:-root}
PASSWORD_ENV=${MYSQL_PASSWORD:-}
ROOT_PASSWORD_ENV=${MYSQL_ROOT_PASSWORD:-}
BACKUP_DIR=${BACKUP_DIR:-backups}
RETAIN=${RETAIN:-7}

mkdir -p "${BACKUP_DIR}"

timestamp=$(date +%Y%m%d-%H%M%S)
dump_file="${BACKUP_DIR}/waline-${timestamp}.sql"

# 若主机环境未提供密码，尝试从容器环境读取
if [ -z "${PASSWORD_ENV}" ] || [ -z "${ROOT_PASSWORD_ENV}" ]; then
  if docker ps --format '{{.Names}}' | grep -qw "${DB_CONTAINER}"; then
    # 读取容器内 env（某些 mariadb 镜像会把变量改名前缀，兼容 MYSQL_ / MARIADB_）
    CONTAINER_ENV=$(docker exec "${DB_CONTAINER}" env | sed 's/=/="/;s/$/"/') || true
    if [ -z "${PASSWORD_ENV}" ]; then
      PASSWORD_ENV=$(docker exec "${DB_CONTAINER}" sh -c 'echo $MYSQL_PASSWORD') || true
      [ -z "${PASSWORD_ENV}" ] && PASSWORD_ENV=$(docker exec "${DB_CONTAINER}" sh -c 'echo $MARIADB_PASSWORD') || true
    fi
    if [ -z "${ROOT_PASSWORD_ENV}" ]; then
      ROOT_PASSWORD_ENV=$(docker exec "${DB_CONTAINER}" sh -c 'echo $MYSQL_ROOT_PASSWORD') || true
      [ -z "${ROOT_PASSWORD_ENV}" ] && ROOT_PASSWORD_ENV=$(docker exec "${DB_CONTAINER}" sh -c 'echo $MARIADB_ROOT_PASSWORD') || true
    fi
  fi
fi

# 优先使用普通用户（若存在且有密码），其次使用 root
if [ -n "${PASSWORD_ENV}" ] && [ "${USER}" != "root" ]; then
  AUTH="-u${USER} -p${PASSWORD_ENV}"
elif [ -n "${ROOT_PASSWORD_ENV}" ]; then
  USER=root
  AUTH="-u${USER} -p${ROOT_PASSWORD_ENV}"
else
  echo "[WARN] 未检测到有效密码，将尝试无密码连接 (可能失败)" >&2
  AUTH="-u${USER}"
fi

echo "[INFO] 备份数据库: ${DATABASE} (容器: ${DB_CONTAINER}) -> ${dump_file}.gz"

if ! docker ps --format '{{.Names}}' | grep -qw "${DB_CONTAINER}"; then
  echo "[ERROR] 容器 ${DB_CONTAINER} 不存在或未运行" >&2
  exit 1
fi

# 执行导出
if ! docker exec "${DB_CONTAINER}" sh -c "mysqldump ${AUTH} --single-transaction --quick --lock-tables=false ${DATABASE}" > "${dump_file}"; then
  echo "[ERROR] mysqldump 执行失败" >&2
  rm -f "${dump_file}"
  exit 1
fi

gzip "${dump_file}"

echo "[INFO] 压缩完成: ${dump_file}.gz"

# 清理旧备份
total=$(ls -1 ${BACKUP_DIR}/waline-*.sql.gz 2>/dev/null | wc -l || true)
if [ "${total}" -gt "${RETAIN}" ]; then
  remove_count=$(( total - RETAIN ))
  echo "[INFO] 超出保留数 ${RETAIN}，删除最旧的 ${remove_count} 个备份"
  ls -1t ${BACKUP_DIR}/waline-*.sql.gz | tail -n ${remove_count} | xargs -r rm -f
fi

echo "[INFO] 当前备份文件数: $(ls -1 ${BACKUP_DIR}/waline-*.sql.gz 2>/dev/null | wc -l || true)"
echo "[INFO] 完成"
