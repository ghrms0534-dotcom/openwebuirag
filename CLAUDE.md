# Open WebUI RAG 작업 메모

이 프로젝트는 Open WebUI, Qdrant, PostgreSQL, Apache Tika를 Docker Compose로 묶은 로컬 RAG 실행 환경입니다. LLM은 vLLM 또는 Ollama를 외부에서 실행하고, Open WebUI가 해당 백엔드에 연결합니다.

## 자주 쓰는 명령

```bash
./scripts/start.sh local
./scripts/start.sh airgap
./scripts/status.sh
./scripts/stop.sh
./scripts/backup.sh
./scripts/restore.sh
```

## 로컬 모드

- `config/env/local.env`를 사용합니다.
- vLLM은 `localhost:8000`, Ollama는 `localhost:11434`로 연결합니다.
- GPU 서버가 따로 있으면 SSH 터널을 먼저 열어야 합니다.

```bash
./scripts/local/ssh-tunnel.sh user@gpu-server ollama
ssh -L 8000:localhost:8000 user@gpu-server -fN
```

## 폐쇄망 / DGX 모드

인터넷 환경에서 번들을 만들고 DGX로 복사합니다.

```bash
./scripts/local/prepare-bundle.sh
rsync -avP bundle/ user@<dgx-ip>:~/openwebui-rag/
```

DGX에서 설치합니다.

```bash
cd ~/openwebui-rag
./scripts/dgx/install.sh
./scripts/start.sh airgap
```

## 주요 파일

- `docker/docker-compose.yml`: 서비스 오케스트레이션
- `config/env/*.env.example`: 환경변수 예제
- `scripts/start.sh`: 컨테이너 시작, 관리자 계정 대기, RAG 설정 적용
- `scripts/backup.sh`: PostgreSQL, Qdrant, 로그 백업
- `scripts/restore.sh`: 백업 복원
- `config/functions/logging_filter.py`: LLM 오류 로그 필터

## 주의사항

- 실제 `.env` 파일은 커밋하지 않습니다.
- `data/docs`, `data/documents`, `data/logs`, `backups`, `bundle`은 실행 산출물이므로 커밋하지 않습니다.
- Open WebUI 설정은 DB 값이 환경변수보다 우선할 수 있으므로 `start.sh`에서 필요한 RAG 설정을 다시 적용합니다.