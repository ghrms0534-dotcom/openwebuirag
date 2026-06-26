#!/usr/bin/env bash
# Open WebUI RAG - 상태 확인
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILE="$PROJECT_ROOT/docker/docker-compose.yml"

if [ -f "$PROJECT_ROOT/config/env/airgap.env" ]; then
  export ENV_FILE=airgap
elif [ -f "$PROJECT_ROOT/config/env/local.env" ]; then
  export ENV_FILE=local
fi

echo "============================================="
echo "Open WebUI RAG 상태"
echo "============================================="
echo ""

echo "[서비스]"
docker compose -f "$COMPOSE_FILE" ps || true

echo ""
echo "[LLM 백엔드]"
if bash -c ':>/dev/tcp/localhost/8000' 2>/dev/null; then
  echo "  vLLM 8000: 연결됨"
else
  echo "  vLLM 8000: 감지 안 됨"
fi

if bash -c ':>/dev/tcp/localhost/11434' 2>/dev/null; then
  echo "  Ollama 11434: 연결됨"
else
  echo "  Ollama 11434: 감지 안 됨"
fi

echo ""
echo "[웹 접속]"
for url in http://localhost:3000 http://localhost; do
  code=$(curl -sf -o /dev/null -w '%{http_code}' --max-time 3 "$url" 2>/dev/null || echo 000)
  echo "  $url: $code"
done