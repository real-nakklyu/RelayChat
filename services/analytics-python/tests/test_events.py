import os

from fastapi.testclient import TestClient
import respx
from httpx import Response

from app.main import app


def test_health():
    client = TestClient(app)
    assert client.get("/health").json()["ok"] is True


@respx.mock
def test_create_event(monkeypatch):
    monkeypatch.setenv("NEXT_PUBLIC_SUPABASE_URL", "https://example.supabase.co")
    monkeypatch.setenv("SUPABASE_SERVICE_ROLE_KEY", "service-key")
    monkeypatch.setenv("ANALYTICS_API_KEY", "secret")
    route = respx.post("https://example.supabase.co/rest/v1/analytics_events").mock(return_value=Response(201))

    client = TestClient(app)
    response = client.post(
        "/events",
        headers={"x-analytics-key": "secret"},
        json={"event_name": "message.sent", "properties": {"conversation_id": "123"}},
    )

    assert response.status_code == 202
    assert route.called


def test_rejects_invalid_event_name(monkeypatch):
    os.environ["ANALYTICS_API_KEY"] = ""
    client = TestClient(app)
    response = client.post("/events", json={"event_name": "../bad"})
    assert response.status_code == 422
