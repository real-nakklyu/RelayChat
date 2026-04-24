# RelayChat

RelayChat is a production-oriented realtime messaging foundation with:

- `apps/web`: Next.js 16, React 19, TypeScript, Tailwind CSS, Supabase Auth/Storage/Postgres, Phoenix WebSocket client.
- `services/realtime`: Elixir/Phoenix channel service for typing, presence-style events, and message fanout.
- `services/analytics-python`: FastAPI ingestion service for analytics/data-science-ready events.
- `packages/shared-types`: shared TypeScript domain contracts.
- `supabase`: schema migrations, RLS policies, storage policies, seed notes, and security tests.

No frontend secret keys are required. The browser uses the Supabase publishable key or anon key and RLS. The Python analytics service uses a Supabase secret key or legacy service-role key only server-side.

## Local Setup

1. Copy environment examples:

```bash
cp .env.example .env
cp apps/web/.env.example apps/web/.env.local
```

2. Create a Supabase project or start Supabase locally.

3. Apply migrations:

```bash
supabase db push
```

4. Configure Supabase Auth:

- Enable email/password.
- Enable email confirmations for production.
- Set redirect URLs to `http://127.0.0.1:3000/auth/callback` and `https://<your-vercel-domain>/auth/callback`.

5. Run the web app:

```bash
npm.cmd --prefix apps/web run dev
```

6. Run the realtime service after installing Elixir:

```bash
cd services/realtime
mix setup
mix phx.server
```

7. Run analytics after creating a Python virtual environment:

```bash
pip install -r services/analytics-python/requirements.txt
cd services/analytics-python
uvicorn app.main:app --reload --port 8010
```

## Supabase Notes

The initial migration creates:

- Profiles, privacy settings, presence, notification preferences.
- Contact requests and contacts.
- Blocked users and reports.
- Direct conversations, participants, messages, read receipts, per-user deletions, and attachments.
- Analytics events and audit logs.
- Private `message-attachments` storage bucket with participant-only policies.
- RPC functions for username search, contact acceptance, and direct conversation creation.

Storage paths for chat attachments are `conversation_id/message_id/file-name`, which lets storage RLS check conversation membership.

## Deployment

### Frontend on Vercel

Set these Vercel environment variables:

- `NEXT_PUBLIC_SUPABASE_URL`
- `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`
- `NEXT_PUBLIC_SUPABASE_ANON_KEY`
- `NEXT_PUBLIC_REALTIME_WS_URL`
- `NEXT_PUBLIC_ANALYTICS_URL`
- `NEXT_PUBLIC_ANALYTICS_API_KEY`
- `NEXT_PUBLIC_MAX_UPLOAD_MB`

Use `apps/web` as the Vercel project root. See `docs/deployment-vercel-supabase.md` for the complete Vercel and Supabase runbook.

### Phoenix Realtime

Deploy `services/realtime` to Fly.io, Gigalixir, Render, or another Elixir-friendly host. Required variables:

- `NEXT_PUBLIC_SUPABASE_URL`
- `NEXT_PUBLIC_SUPABASE_ANON_KEY`
- `SUPABASE_JWT_SECRET`
- `SECRET_KEY_BASE`
- `APP_ORIGIN`
- `PHX_HOST`
- `PORT`

### Python Analytics

Deploy as a container or Python web service. Required variables:

- `NEXT_PUBLIC_SUPABASE_URL`
- `SUPABASE_SECRET_KEY` or legacy `SUPABASE_SERVICE_ROLE_KEY`
- `ANALYTICS_API_KEY`
- `ANALYTICS_ALLOWED_ORIGINS`
- `ANALYTICS_IP_SALT`

## Testing

```bash
npm.cmd --prefix apps/web run lint
npm.cmd --prefix apps/web run test
npm.cmd --prefix apps/web run build
python -m pytest services/analytics-python/tests
supabase test db
```

Elixir tests:

```bash
cd services/realtime
mix test
```

## Production Checklist

- Enable Supabase email confirmations and rate limits.
- Rotate all generated secrets before launch.
- Set strict Auth redirect URLs.
- Review RLS policies with `supabase test db` and staging users.
- Configure Storage malware scanning if your compliance posture requires it.
- Put Phoenix behind TLS and restrict `check_origin`.
- Add provider-level WAF/rate limits for auth, search, message send, uploads, and analytics.
- Verify `src/proxy.ts` is active in Vercel build output so Supabase SSR cookies refresh correctly.
- Configure backup retention and point-in-time recovery.
- Add operational dashboards for Phoenix socket errors, Supabase query latency, storage failures, reports, and audit logs.
- Create an abuse review process for reports and blocked-user telemetry.
