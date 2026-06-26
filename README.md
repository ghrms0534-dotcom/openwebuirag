# Open WebUI RAG

Open WebUI 기반의 로컬 RAG 실행 환경입니다. 문서를 업로드하면 Tika가 텍스트를 추출하고, Qdrant에 벡터로 저장한 뒤, vLLM 또는 Ollama로 문서 기반 답변과 출처를 제공합니다.

## 구성

- Open WebUI: 채팅 UI와 RAG 오케스트레이션, `3000` 포트
- Nginx: 리버스 프록시, `80` 포트
- PostgreSQL: 사용자, 채팅, 메타데이터, Open WebUI 설정 저장
- Qdrant: 벡터 데이터베이스
- Apache Tika: PDF/DOCX/XLSX 등 문서 텍스트 추출
- vLLM 또는 Ollama: 외부에서 실행하는 LLM 백엔드

## 사전 요구사항

- Docker
- Docker Compose v2
- 실행 중인 LLM 백엔드 1개 이상
  - vLLM 확인: `curl http://localhost:8000/v1/models`
  - Ollama 확인: `curl http://localhost:11434/api/tags`

## 로컬 실행

```bash
cp config/env/local.env.example config/env/local.env
openssl rand -hex 32
```

생성된 값을 `config/env/local.env`의 `WEBUI_SECRET_KEY`에 넣습니다.

```bash
./scripts/start.sh local
```

접속:

- http://localhost:3000
- http://localhost

최초 접속 시 브라우저에서 관리자 계정을 생성해야 합니다. `start.sh`는 관리자 계정이 만들어질 때까지 기다린 뒤 RAG 설정을 DB에 적용합니다.

## 폐쇄망 / DGX 실행

인터넷 연결 환경에서 번들을 생성합니다.

```bash
./scripts/local/prepare-bundle.sh
```

DGX 서버로 전송합니다.

```bash
rsync -avP bundle/ user@<dgx-ip>:~/openwebui-rag/
```

DGX에서 설치하고 실행합니다.

```bash
cd ~/openwebui-rag
./scripts/dgx/install.sh
./scripts/start.sh airgap
```

## 자주 쓰는 명령

```bash
./scripts/status.sh
./scripts/stop.sh
./scripts/backup.sh
./scripts/restore.sh
```

로그 확인:

```bash
docker compose -f docker/docker-compose.yml logs open-webui
docker compose -f docker/docker-compose.yml logs -f open-webui
docker compose -f docker/docker-compose.yml logs postgres
docker compose -f docker/docker-compose.yml logs qdrant
docker compose -f docker/docker-compose.yml logs tika
```

## Git 주의사항

다음 실행 산출물은 커밋하지 않습니다.

- `config/env/*.env`
- `data/docs/*`
- `data/documents/*`
- `data/logs/*`
- `backups/`
- `bundle/`

위 항목은 `.gitignore`에 등록되어 있습니다.
