#!/usr/bin/env bash
# Open WebUI RAG - 최근 질의응답 로그 조회
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILE="$PROJECT_ROOT/docker/docker-compose.yml"
LIMIT="${1:-20}"

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

docker compose -f "$COMPOSE_FILE" exec -T postgres psql -U openwebui -d openwebui -c \
"SELECT to_timestamp(created_at/1000000000)::text AS time, role, left(content, 200) AS content FROM message ORDER BY created_at DESC LIMIT ${LIMIT};" 2>/dev/null || \
  echo "메시지 테이블을 조회하지 못했습니다. Open WebUI 버전에 따라 테이블 구조가 다를 수 있습니다."