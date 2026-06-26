#!/usr/bin/env bash
# Open WebUI RAG - 폐쇄망 배포 번들 생성
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUTPUT_DIR="$PROJECT_ROOT/bundle"
COMPOSE_FILE="$PROJECT_ROOT/docker/docker-compose.yml"
TARGET_PLATFORM="${TARGET_PLATFORM:-linux/arm64}"

mkdir -p "$OUTPUT_DIR/images" "$OUTPUT_DIR/config" "$OUTPUT_DIR/scripts" "$OUTPUT_DIR/docker" "$OUTPUT_DIR/models"

echo "폐쇄망 배포 번들을 생성합니다: $OUTPUT_DIR"

IMAGES=(
  "ghcr.io/open-webui/open-webui:v0.8.8"
  "postgres:16-alpine"
  "qdrant/qdrant:v1.17.0"
  "nginx:1.27-alpine"
)

for image in "${IMAGES[@]}"; do
  name=$(echo "$image" | tr '/:' '__')
  echo "이미지 저장: $image"
  docker pull --platform "$TARGET_PLATFORM" "$image"
  docker save "$image" -o "$OUTPUT_DIR/images/${name}.tar"
done

echo "Tika 이미지 빌드 및 저장"
docker build --platform "$TARGET_PLATFORM" -t openwebui-rag-tika:latest "$PROJECT_ROOT/docker/tika"
docker save openwebui-rag-tika:latest -o "$OUTPUT_DIR/images/openwebui-rag-tika_latest.tar"

cp -R "$PROJECT_ROOT/config" "$OUTPUT_DIR/"
cp -R "$PROJECT_ROOT/scripts" "$OUTPUT_DIR/"
cp -R "$PROJECT_ROOT/docker" "$OUTPUT_DIR/"
cp "$PROJECT_ROOT/README.md" "$OUTPUT_DIR/"
cp "$COMPOSE_FILE" "$OUTPUT_DIR/docker/docker-compose.yml"

volume_name="openwebui-rag_open-webui"
if docker volume inspect "$volume_name" >/dev/null 2>&1; then
  docker run --rm -v "$volume_name":/data:ro -v "$OUTPUT_DIR/models":/out alpine \
    tar czf /out/embedding-cache.tar.gz -C /data/cache embedding 2>/dev/null || true
fi

cat > "$OUTPUT_DIR/VERSION.txt" <<EOF
Open WebUI RAG 폐쇄망 배포 번들
생성일: $(date '+%Y-%m-%d %H:%M:%S')
대상 플랫폼: $TARGET_PLATFORM
EOF

echo "번들 생성 완료: $OUTPUT_DIR"
echo "전송 예: rsync -avP bundle/ user@<dgx-ip>:~/openwebui-rag/"