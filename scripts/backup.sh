#!/usr/bin/env bash
# Open WebUI RAG - 데이터 백업
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILE="$PROJECT_ROOT/docker/docker-compose.yml"
BACKUP_DIR="$PROJECT_ROOT/backups"
DATE="$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

if [ -f "$PROJECT_ROOT/config/env/airgap.env" ]; then
  export ENV_FILE=airgap
elif [ -f "$PROJECT_ROOT/config/env/local.env" ]; then
  export ENV_FILE=local
fi

for env_file in "$PROJECT_ROOT/config/env/local.env" "$PROJECT_ROOT/config/env/airgap.env"; do
  if [ -f "$env_file" ]; then
    POSTGRES_PASSWORD=$(grep '^POSTGRES_PASSWORD=' "$env_file" 2>/dev/null | cut -d= -f2- || echo openwebui)
    break
  fi
done
export PGPASSWORD="${POSTGRES_PASSWORD:-openwebui}"

echo "Open WebUI RAG 백업을 시작합니다."

postgres_file="$BACKUP_DIR/postgres-${DATE}.sql"
if docker compose -f "$COMPOSE_FILE" exec -T postgres pg_dump -U openwebui openwebui > "$postgres_file"; then
  echo "PostgreSQL 백업 완료: $postgres_file"
else
  rm -f "$postgres_file"
  echo "[WARN] PostgreSQL 백업 실패"
fi

qdrant_cid=$(docker compose -f "$COMPOSE_FILE" ps -q qdrant 2>/dev/null | head -1 || true)
if [ -n "$qdrant_cid" ]; then
  docker run --rm --volumes-from "$qdrant_cid" -v "$BACKUP_DIR":/backup alpine \
    tar czf "/backup/qdrant-${DATE}.tar.gz" /qdrant/storage >/dev/null
  echo "Qdrant 백업 완료: $BACKUP_DIR/qdrant-${DATE}.tar.gz"
else
  echo "[WARN] Qdrant 컨테이너가 없어 건너뜁니다."
fi

if [ -d "$PROJECT_ROOT/data/logs" ]; then
  tar czf "$BACKUP_DIR/logs-${DATE}.tar.gz" -C "$PROJECT_ROOT/data" logs >/dev/null 2>&1 || true
  echo "로그 백업 완료: $BACKUP_DIR/logs-${DATE}.tar.gz"
fi

find "$BACKUP_DIR" -name '*.tar.gz' -mtime +30 -delete 2>/dev/null || true
find "$BACKUP_DIR" -name 'postgres-*.sql' -mtime +30 -delete 2>/dev/null || true

echo "백업 완료: $BACKUP_DIR"