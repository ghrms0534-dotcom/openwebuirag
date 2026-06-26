#!/usr/bin/env bash
# Open WebUI RAG - 서비스 중지
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILE="$PROJECT_ROOT/docker/docker-compose.yml"

echo "Open WebUI RAG 서비스를 중지합니다."
docker compose -f "$COMPOSE_FILE" down
echo "중지 완료"