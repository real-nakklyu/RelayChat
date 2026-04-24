# RelayChat Realtime Service

Phoenix owns realtime fanout while Supabase remains the system of record.

The socket requires a Supabase user JWT. The service uses `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` or the legacy anon key for Supabase REST authorization checks:

```ts
new Socket("wss://realtime.example.com/socket", { params: { token: session.access_token } })
```

Channels are named `conversation:<conversation_id>`. On join, the service calls Supabase REST with the user's JWT, so Postgres RLS verifies membership.

Events:

- `typing`: broadcast to other participants.
- `new_message`: broadcast after a message insert succeeds in Supabase.
- `message_updated`: broadcast after edit/delete-for-everyone.

Run:

```bash
mix setup
mix phx.server
```
