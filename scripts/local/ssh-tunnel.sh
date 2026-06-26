#!/usr/bin/env bash
# Open WebUI RAG - SSH 터널
set -euo pipefail

GPU_SERVER="${1:-}"
BACKEND="${2:-ollama}"
SSH_PORT="${3:-22}"

if [ -z "$GPU_SERVER" ]; then
  printf "GPU 서버 주소(user@host): "
  read -r GPU_SERVER
fi

case "$BACKEND" in
  ollama) LOCAL_PORT=11434; REMOTE_PORT=11434 ;;
  vllm) LOCAL_PORT=8000; REMOTE_PORT=8000 ;;
  *) echo "[ERROR] 백엔드는 ollama 또는 vllm만 지원합니다."; exit 1 ;;
esac

echo "SSH 터널을 엽니다: localhost:${LOCAL_PORT} -> ${GPU_SERVER}:${REMOTE_PORT}"
ssh -p "$SSH_PORT" -L "${LOCAL_PORT}:localhost:${REMOTE_PORT}" "$GPU_SERVER" -fN

echo "SSH 터널 연결 완료"