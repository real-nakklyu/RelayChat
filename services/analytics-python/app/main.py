import hashlib
import os
from pathlib import Path
from typing import Any

import httpx
from dotenv import load_dotenv
from fastapi import FastAPI, Header, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

load_dotenv(Path(__file__).resolve().parents[1] / ".env.local")


class AnalyticsEvent(BaseModel):
    event_name: str = Field(pattern=r"^[a-zA-Z0-9_.:-]{2,80}$")
    user_id: str | None = None
    anonymous_id: str | None = None
    properties: dict[str, Any] = Field(default_factory=dict)


def env(name: str, default: str = "") -> str:
    return os.getenv(name, default)


app = FastAPI(title="RelayChat Analytics", version="0.1.0")
allowed_origins = [origin.strip() for origin in env("ANALYTICS_ALLOWED_ORIGINS", "http://localhost:3000").split(",")]
app.add_middleware(
    CORSMiddleware,
    allow_origins=allowed_origins,
    allow_credentials=False,
    allow_methods=["POST", "GET"],
    allow_headers=["*"],
)


@app.get("/health")
def health() -> dict[str, bool | str]:
    return {"ok": True, "service": "relaychat-analytics"}


@app.post("/events", status_code=202)
async def create_event(
    event: AnalyticsEvent,
    request: Request,
    x_analytics_key: str | None = Header(default=None),
) -> dict[str, bool]:
    configured_key = env("ANALYTICS_API_KEY")
    if configured_key and x_analytics_key != configured_key:
        raise HTTPException(status_code=401, detail="Invalid analytics key")

    supabase_url = env("NEXT_PUBLIC_SUPABASE_URL")
    server_key = env("SUPABASE_SECRET_KEY") or env("SUPABASE_SERVICE_ROLE_KEY")
    if not supabase_url or not server_key:
        raise HTTPException(status_code=500, detail="Analytics storage is not configured")

    ip = request.client.host if request.client else ""
    ip_hash = hashlib.sha256(f"{ip}:{env('ANALYTICS_IP_SALT', 'dev')}".encode()).hexdigest() if ip else None
    payload = {
        "event_name": event.event_name,
        "user_id": event.user_id,
        "anonymous_id": event.anonymous_id,
        "properties": event.properties,
        "ip_hash": ip_hash,
        "user_agent": request.headers.get("user-agent"),
    }

    async with httpx.AsyncClient(timeout=5) as client:
        response = await client.post(
            f"{supabase_url}/rest/v1/analytics_events",
            headers={
                "apikey": server_key,
                "authorization": f"Bearer {server_key}",
                "content-type": "application/json",
                "prefer": "return=minimal",
            },
            json=payload,
        )

    if response.status_code >= 400:
        raise HTTPException(status_code=502, detail="Failed to store analytics event")
    return {"accepted": True}
