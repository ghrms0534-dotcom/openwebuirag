"""
Open WebUI RAG - LLM 오류 로거(Filter Function)
오류가 감지되면 사용자, 모델, 질문, 오류 사유, 응답 시간을 JSONL 파일로 기록합니다.
"""

import json
import os
import re
import time
from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field


class Filter:
    class Valves(BaseModel):
        pipelines: list = ["*"]
        priority: int = 0
        log_dir: str = Field(
            default="/app/backend/data/logs",
            description="오류 로그 저장 경로",
        )

    def __init__(self):
        self.valves = self.Valves()
        self._start_times: dict = {}

    def inlet(self, body: dict, __user__: Optional[dict] = None) -> dict:
        try:
            chat_id = body.get("metadata", {}).get("chat_id", "") or body.get("chat_id", "")
            self._start_times[chat_id] = time.time()
        except Exception:
            pass
        return body

    def outlet(self, body: dict, __user__: Optional[dict] = None) -> dict:
        try:
            chat_id = body.get("metadata", {}).get("chat_id", "") or body.get("chat_id", "")
            start = self._start_times.pop(chat_id, None)
            latency = round(time.time() - start, 2) if start else None

            messages = body.get("messages", [])
            assistant_msg = ""
            user_msg = ""
            for msg in reversed(messages):
                role = msg.get("role")
                if role == "assistant" and not assistant_msg:
                    assistant_msg = re.sub(
                        r"<details[^>]*>.*?</details>", "", msg.get("content", ""), flags=re.DOTALL
                    ).strip()
                elif role == "user" and not user_msg:
                    content = msg.get("content", "")
                    match = re.search(r"\[Question\]\s*(.+?)\s*\[Answer\]", content, re.DOTALL)
                    user_msg = match.group(1).strip() if match else content
                if assistant_msg and user_msg:
                    break

            error_reason = None
            error_patterns = [
                (r"model failed to load|resource limitations", "모델 로드 실패 또는 GPU 메모리 부족"),
                (r"server disconnected|disconnected", "LLM 서버 연결 끊김"),
                (r"connection refused", "LLM 서버 연결 거부"),
                (r"timed out|timeout", "LLM 응답 시간 초과"),
                (r"^\d{3}:.*", assistant_msg),
            ]
            for pattern, reason in error_patterns:
                if re.search(pattern, assistant_msg, re.IGNORECASE):
                    error_reason = reason if reason != assistant_msg else assistant_msg
                    break

            if not error_reason and body.get("error"):
                error_reason = str(body["error"])

            if error_reason:
                user_info = ""
                if __user__:
                    user_info = __user__.get("email", "") or __user__.get("name", "")

                entry = {
                    "timestamp": datetime.now().isoformat(timespec="seconds"),
                    "user": user_info,
                    "model": body.get("model", ""),
                    "question": user_msg[:200],
                    "error": error_reason[:300],
                    "latency_sec": latency,
                }

                os.makedirs(self.valves.log_dir, exist_ok=True)
                log_path = os.path.join(self.valves.log_dir, "errors.jsonl")
                with open(log_path, "a", encoding="utf-8") as f:
                    f.write(json.dumps(entry, ensure_ascii=False) + "\n")
        except Exception:
            pass

        return body