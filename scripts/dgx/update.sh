#!/usr/bin/env bash
# Open WebUI RAG - DGX 이미지 업데이트
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

echo "DGX 이미지를 업데이트합니다. 데이터 볼륨은 삭제하지 않습니다."

if [ -d "$PROJECT_ROOT/images" ]; then
  for tar in "$PROJECT_ROOT"/images/*.tar; do
    [ -f "$tar" ] || continue
    echo "이미지 로드: $(basename "$tar")"
    docker load -i "$tar"
  done
else
  echo "[ERROR] images 디렉터리가 없습니다."
  exit 1
fi

if [ "${1:-}" = "--update-models" ] && [ -f "$PROJECT_ROOT/models/embedding-cache.tar.gz" ]; then
  volume_name="openwebui-rag_open-webui"
  docker volume create "$volume_name" >/dev/null
  docker run --rm -v "$volume_name":/data -v "$PROJECT_ROOT/models":/models alpine \
    sh -c 'mkdir -p /data/cache && tar xzf /models/embedding-cache.tar.gz -C /data/cache' || true
  echo "모델 캐시 업데이트 완료"
fi

echo "업데이트 완료. 실행: ./scripts/start.sh airgap"