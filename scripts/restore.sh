#!/usr/bin/env bash
# Open WebUI RAG - 데이터 복원
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILE="$PROJECT_ROOT/docker/docker-compose.yml"
BACKUP_DIR="$PROJECT_ROOT/backups"
RESTORE_DATE="${1:-}"

if [ -z "$RESTORE_DATE" ]; then
  latest=$(ls -1 "$BACKUP_DIR"/postgres-*.sql 2>/dev/null | sort | tail -1 || true)
  if [ -z "$latest" ]; then
    echo "[ERROR] 복원할 PostgreSQL 백업이 없습니다: $BACKUP_DIR"
    exit 1
  fi
  RESTORE_DATE=$(basename "$latest" | sed 's/^postgres-//;s/\.sql$//')
fi

postgres_file="$BACKUP_DIR/postgres-${RESTORE_DATE}.sql"
qdrant_file="$BACKUP_DIR/qdrant-${RESTORE_DATE}.tar.gz"

[ ! -f "$postgres_file" ] && echo "[ERROR] PostgreSQL 백업 없음: $postgres_file" && exit 1

echo "복원 대상: $RESTORE_DATE"
echo "기존 데이터가 덮어써질 수 있습니다. 계속하려면 y를 입력하세요."
read -r answer
[ "$answer" != "y" ] && [ "$answer" != "Y" ] && echo "복원 취소" && exit 0

if [ -f "$PROJECT_ROOT/config/env/airgap.env" ]; then
  export ENV_FILE=airgap
elif [ -f "$PROJECT_ROOT/config/env/local.env" ]; then
  export ENV_FILE=local
fi

docker compose -f "$COMPOSE_FILE" up -d postgres qdrant
sleep 5

docker compose -f "$COMPOSE_FILE" exec -T postgres psql -U openwebui -d postgres -c "DROP DATABASE IF EXISTS openwebui WITH (FORCE);"
docker compose -f "$COMPOSE_FILE" exec -T postgres psql -U openwebui -d postgres -c "CREATE DATABASE openwebui OWNER openwebui;"
docker compose -f "$COMPOSE_FILE" exec -T postgres psql -U openwebui -d openwebui < "$postgres_file"
echo "PostgreSQL 복원 완료"

if [ -f "$qdrant_file" ]; then
  qdrant_cid=$(docker compose -f "$COMPOSE_FILE" ps -q qdrant 2>/dev/null | head -1 || true)
  if [ -n "$qdrant_cid" ]; then
    docker run --rm --volumes-from "$qdrant_cid" -v "$BACKUP_DIR":/backup alpine \
      sh -c "rm -rf /qdrant/storage/* && tar xzf /backup/$(basename "$qdrant_file") -C /" >/dev/null
    echo "Qdrant 복원 완료"
  fi
fi

echo "복원 완료. 서비스 시작: ./scripts/start.sh ${ENV_FILE:-local}"