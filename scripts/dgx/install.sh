#!/usr/bin/env bash
# Open WebUI RAG - DGX 최초 설치
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENV_FILE="$PROJECT_ROOT/config/env/airgap.env"

echo "DGX 설치를 시작합니다."

command -v docker >/dev/null || { echo "[ERROR] Docker가 필요합니다."; exit 1; }
docker compose version >/dev/null || { echo "[ERROR] Docker Compose v2가 필요합니다."; exit 1; }

if [ -d "$PROJECT_ROOT/images" ]; then
  for tar in "$PROJECT_ROOT"/images/*.tar; do
    [ -f "$tar" ] || continue
    echo "이미지 로드: $(basename "$tar")"
    docker load -i "$tar"
  done
fi

if [ ! -f "$ENV_FILE" ]; then
  cp "$PROJECT_ROOT/config/env/airgap.env.example" "$ENV_FILE"
  secret=$(openssl rand -hex 32)
  pass=$(openssl rand -hex 16)
  sed -i "s|^WEBUI_SECRET_KEY=.*|WEBUI_SECRET_KEY=$secret|" "$ENV_FILE"
  sed -i "s|^POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=$pass|" "$ENV_FILE"
  sed -i "s|openwebui:openwebui@postgres|openwebui:$pass@postgres|" "$ENV_FILE"
  echo "airgap.env 생성 완료"
fi

cache_tar="$PROJECT_ROOT/models/embedding-cache.tar.gz"
if [ -f "$cache_tar" ]; then
  volume_name="openwebui-rag_open-webui"
  docker volume create "$volume_name" >/dev/null
  docker run --rm -v "$volume_name":/data -v "$PROJECT_ROOT/models":/models alpine \
    sh -c 'mkdir -p /data/cache && tar xzf /models/embedding-cache.tar.gz -C /data/cache' || true
  echo "임베딩 캐시 복원 완료"
fi

echo "설치 완료. 실행: ./scripts/start.sh airgap"