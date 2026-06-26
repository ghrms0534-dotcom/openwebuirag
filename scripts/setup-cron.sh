#!/usr/bin/env bash
# Open WebUI RAG - 자동 백업 cron 설정
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP_SCRIPT="$PROJECT_ROOT/scripts/backup.sh"
CRON_LOG="$PROJECT_ROOT/backups/cron.log"
CRON_TAG="# openwebui-rag-backup"
CRON_ENTRY="0 3 * * * cd $PROJECT_ROOT && $BACKUP_SCRIPT >> $CRON_LOG 2>&1 $CRON_TAG"

case "${1:-install}" in
  --status|status)
    crontab -l 2>/dev/null | grep "$CRON_TAG" || echo "등록된 자동 백업 cron이 없습니다."
    ;;
  --remove|remove)
    (crontab -l 2>/dev/null | grep -v "$CRON_TAG" || true) | crontab -
    echo "자동 백업 cron 제거 완료"
    ;;
  install|*)
    mkdir -p "$PROJECT_ROOT/backups"
    (crontab -l 2>/dev/null | grep -v "$CRON_TAG" || true; echo "$CRON_ENTRY") | crontab -
    echo "자동 백업 cron 등록 완료: 매일 03:00"
    ;;
esac