# RelayChat Analytics Service

FastAPI ingestion endpoint for product analytics and data-science-ready events.

Run:

```bash
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8010
```

Post an event:

```bash
curl -X POST http://localhost:8010/events \
  -H "content-type: application/json" \
  -H "x-analytics-key: $ANALYTICS_API_KEY" \
  -d '{"event_name":"message.sent","properties":{"source":"web"}}'
```

Events are written to `public.analytics_events` using the Supabase secret key or legacy service-role key on the server only.
