#!/usr/bin/env bash
# Open WebUI RAG - LLM 오류 로그 조회
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_FILE="$PROJECT_ROOT/data/logs/errors.jsonl"
N=50
FOLLOW=false

while [ $# -gt 0 ]; do
  case "$1" in
    -n) N="${2:-50}"; shift 2 ;;
    --follow|-f) FOLLOW=true; shift ;;
    *) echo "[ERROR] 알 수 없는 옵션: $1"; exit 1 ;;
  esac
done

if [ ! -f "$LOG_FILE" ]; then
  echo "오류 로그가 없습니다: $LOG_FILE"
  exit 0
fi

if $FOLLOW; then
  tail -f "$LOG_FILE"
else
  tail -n "$N" "$LOG_FILE"
fi