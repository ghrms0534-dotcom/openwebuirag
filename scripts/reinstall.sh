#!/usr/bin/env bash
# Open WebUI RAG - 클린 재설치
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILE="$PROJECT_ROOT/docker/docker-compose.yml"
MODE="${1:-local}"

case "$MODE" in local|airgap) ;; *) echo "사용법: $0 [local|airgap]"; exit 1 ;; esac

echo "컨테이너와 볼륨을 삭제하고 다시 설치합니다. 모든 데이터가 삭제됩니다. 계속하려면 y를 입력하세요."
read -r answer
[ "$answer" != "y" ] && [ "$answer" != "Y" ] && echo "취소" && exit 0

export ENV_FILE="$MODE"
docker compose -f "$COMPOSE_FILE" down -v --remove-orphans || true
docker image rm openwebui-rag-tika:latest 2>/dev/null || true
"$PROJECT_ROOT/scripts/start.sh" "$MODE"