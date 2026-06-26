#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
COMPOSE_FILE="$PROJECT_ROOT/docker/docker-compose.yml"

MODE="${1:-local}"
case "$MODE" in
  local|airgap) ;;
  *) echo "사용법: $0 [local|airgap]"; exit 1 ;;
esac

export ENV_FILE="$MODE"
ENV_PATH="$PROJECT_ROOT/config/env/${ENV_FILE}.env"
COMPOSE_ARGS=(-f "$COMPOSE_FILE")

if [ ! -f "$ENV_PATH" ]; then
  echo "[ERROR] 환경 파일이 없습니다: $ENV_PATH"
  echo "        cp config/env/${ENV_FILE}.env.example config/env/${ENV_FILE}.env"
  exit 1
fi

if grep -q '<' "$ENV_PATH" 2>/dev/null; then
  echo "[ERROR] WEBUI_SECRET_KEY가 설정되지 않았습니다: $ENV_PATH"
  echo "        생성 명령: openssl rand -hex 32"
  exit 1
fi

if [ "$MODE" = "airgap" ]; then
  VLLM_UP=false
  OLLAMA_UP=false
  bash -c ':>/dev/tcp/localhost/8000' 2>/dev/null && VLLM_UP=true
  bash -c ':>/dev/tcp/localhost/11434' 2>/dev/null && OLLAMA_UP=true

  if $VLLM_UP; then
    sed -i 's/^ENABLE_OPENAI_API=.*/ENABLE_OPENAI_API=true/' "$ENV_PATH"
  else
    sed -i 's/^ENABLE_OPENAI_API=.*/ENABLE_OPENAI_API=false/' "$ENV_PATH"
  fi

  if $OLLAMA_UP; then
    sed -i 's/^ENABLE_OLLAMA_API=.*/ENABLE_OLLAMA_API=true/' "$ENV_PATH"
  else
    sed -i 's/^ENABLE_OLLAMA_API=.*/ENABLE_OLLAMA_API=false/' "$ENV_PATH"
  fi
fi

POSTGRES_PASSWORD=$(grep '^POSTGRES_PASSWORD=' "$ENV_PATH" 2>/dev/null | cut -d= -f2- || echo "openwebui")
export POSTGRES_PASSWORD
export PGPASSWORD="$POSTGRES_PASSWORD"

mkdir -p "$PROJECT_ROOT/data/documents" "$PROJECT_ROOT/data/logs"

echo "== Open WebUI RAG =="
echo "[1/6] 컨테이너 시작 ($MODE)"
docker compose "${COMPOSE_ARGS[@]}" up -d --build

CONTAINER=$(docker compose "${COMPOSE_ARGS[@]}" ps -q open-webui)
if [ -z "$CONTAINER" ]; then
  echo "[ERROR] open-webui 컨테이너를 찾지 못했습니다"
  exit 1
fi

echo "[2/6] Open WebUI 준비 대기"
SECONDS=0
while ! docker exec "$CONTAINER" bash -c ':>/dev/tcp/localhost/8080' 2>/dev/null; do
  STATUS=$(docker inspect "$CONTAINER" --format='{{.State.Status}}' 2>/dev/null || echo "not found")
  if [ "$STATUS" != "running" ]; then
    echo "[ERROR] open-webui 컨테이너가 중지되었습니다 (상태: $STATUS)"
    exit 1
  fi
  printf "\r  대기 중... %s초" "$SECONDS"
  sleep 3
done
printf "\r  준비 완료: %s초\n" "$SECONDS"

if [ "$MODE" = "airgap" ]; then
  ACCESS_URL="http://$(hostname -I 2>/dev/null | awk '{print $1}' || echo localhost)"
else
  ACCESS_URL="http://localhost:3000"
fi

echo "[3/6] 접속 주소: $ACCESS_URL"
echo "[4/6] 관리자 계정 생성 대기"
while true; do
  ADMIN_EXISTS=$(docker compose "${COMPOSE_ARGS[@]}" exec -T postgres psql -U openwebui -d openwebui -tAc \
    "SELECT COUNT(*) FROM \"user\" WHERE role = 'admin'" 2>/dev/null | tr -d '[:space:]' || echo "0")
  [ "${ADMIN_EXISTS:-0}" != "0" ] && break
  printf "\r  브라우저에서 최초 관리자 계정을 생성하세요: %s" "$ACCESS_URL"
  sleep 5
done
printf "\n"

echo "[5/6] RAG 설정 적용"
if docker compose "${COMPOSE_ARGS[@]}" exec -T postgres psql -U openwebui -d openwebui &>/dev/null <<'PSQL'
UPDATE config SET data = (
  jsonb_set(jsonb_set(jsonb_set(jsonb_set(jsonb_set(jsonb_set(jsonb_set(jsonb_set(jsonb_set(data::jsonb,
    '{rag,chunk_size}', '400'),
    '{rag,chunk_overlap}', '80'),
    '{rag,chunk_min_size_target}', '150'),
    '{rag,top_k}', '8'),
    '{rag,top_k_reranker}', '8'),
    '{rag,reranking_model}', '""'),
    '{rag,relevance_threshold}', '0.1'),
    '{rag,enable_hybrid_search}', 'true'),
    '{rag,template}', to_jsonb('당신은 내부 문서를 기반으로 답변하는 전문 분석가입니다. 항상 한국어로 답변하세요.

[지침]
1. 제공된 컨텍스트의 관련 정보를 모두 활용하세요.
2. 출처는 [문서명] 형식으로 표시하세요.
3. 표나 목록이 적절하면 사용하세요.
4. 관련 정보가 없으면 제공된 문서에서 답을 찾을 수 없다고 말하세요.
5. 문서에 없는 내용을 추측하거나 지어내지 마세요.

[컨텍스트]
{{CONTEXT}}

[질문]
{{QUERY}}

[답변]'::text)
  )
)::json;
PSQL
then
  echo "  적용 완료"
else
  echo "  건너뜀: config 테이블이 아직 준비되지 않았습니다. 필요하면 Admin UI에서 확인하세요."
fi

echo "[6/6] 로깅 필터 등록"
FILTER_FILE="$PROJECT_ROOT/config/functions/logging_filter.py"
if [ -f "$FILTER_FILE" ]; then
  TMPFILE=$(mktemp)
  cat > "$TMPFILE" <<'SQL_HEADER'
INSERT INTO function (id, user_id, name, type, content, meta, valves, is_active, is_global, created_at, updated_at)
VALUES (
  'llm_query_logger',
  (SELECT id FROM "user" WHERE role = 'admin' LIMIT 1),
  'LLM Query Logger',
  'filter',
  $fn$
SQL_HEADER
  cat "$FILTER_FILE" >> "$TMPFILE"
  cat >> "$TMPFILE" <<'SQL_FOOTER'
$fn$,
  '{"description": "LLM 질의응답 로그를 JSONL로 기록"}',
  '{}',
  true,
  true,
  EXTRACT(EPOCH FROM NOW())::bigint * 1000000000,
  EXTRACT(EPOCH FROM NOW())::bigint * 1000000000
)
ON CONFLICT (id) DO UPDATE SET
  content = EXCLUDED.content,
  is_active = true,
  is_global = true,
  updated_at = EXTRACT(EPOCH FROM NOW())::bigint * 1000000000;
SQL_FOOTER
  docker compose "${COMPOSE_ARGS[@]}" exec -T postgres psql -U openwebui -d openwebui &>/dev/null < "$TMPFILE" || true
  rm -f "$TMPFILE"
fi

echo "완료: $ACCESS_URL"