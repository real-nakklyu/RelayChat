# Vercel and Supabase Deployment Runbook

## 1. Create Supabase

Create a Supabase project, then link locally:

```bash
supabase login
supabase link --project-ref <project-ref>
supabase db push
```

In Supabase Auth:

- Enable Email provider.
- Enable email confirmations.
- Enable secure email change with double confirmation.
- Add redirect URLs:
  - `http://127.0.0.1:3000/auth/callback`
  - `https://<your-vercel-domain>/auth/callback`

The migration creates the `message-attachments` and `profile-avatars` private buckets plus RLS policies.

## 2. Configure Vercel

Recommended project root: `apps/web`.

Required Vercel environment variables:

```bash
NEXT_PUBLIC_SUPABASE_URL=
NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=
NEXT_PUBLIC_SUPABASE_ANON_KEY=
NEXT_PUBLIC_REALTIME_WS_URL=
NEXT_PUBLIC_ANALYTICS_URL=
NEXT_PUBLIC_ANALYTICS_API_KEY=
NEXT_PUBLIC_MAX_UPLOAD_MB=25
```

Use the publishable key for new Supabase projects. `NEXT_PUBLIC_SUPABASE_ANON_KEY` is supported as a compatibility fallback.

Pull variables locally:

```bash
cd apps/web
vercel link
vercel env pull .env.local --yes
```

Validate before production:

```bash
npm ci
npm run lint
npm run test
npm run build
```

Deploy preview:

```bash
vercel
```

Deploy production:

```bash
vercel --prod
```

## 3. Deploy Realtime

Deploy `services/realtime` to an Elixir host. Required variables:

```bash
NEXT_PUBLIC_SUPABASE_URL=
NEXT_PUBLIC_SUPABASE_ANON_KEY=
SUPABASE_JWT_SECRET=
SECRET_KEY_BASE=
APP_ORIGIN=https://<your-vercel-domain>
PHX_HOST=<realtime-host>
PORT=4000
```

After deploy, set `NEXT_PUBLIC_REALTIME_WS_URL=wss://<realtime-host>/socket` in Vercel.

## 4. Deploy Analytics

Deploy `services/analytics-python` as a Python web service. Required variables:

```bash
NEXT_PUBLIC_SUPABASE_URL=
SUPABASE_SERVICE_ROLE_KEY=
ANALYTICS_API_KEY=
ANALYTICS_ALLOWED_ORIGINS=https://<your-vercel-domain>
ANALYTICS_IP_SALT=
```

Set `NEXT_PUBLIC_ANALYTICS_URL` and `NEXT_PUBLIC_ANALYTICS_API_KEY` in Vercel to point to that service.

## 5. Final Checks

- Create two verified users.
- Confirm profile rows, privacy rows, notification rows, and presence rows are created.
- Send and accept a contact request.
- Create a direct conversation.
- Send text, image, and file attachments.
- Confirm blocked users cannot create conversations or send messages.
- Confirm private storage URLs are signed and expire.
- Review `audit_logs`, `reports`, and `analytics_events`.
