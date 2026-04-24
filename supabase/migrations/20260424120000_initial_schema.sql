create extension if not exists "pgcrypto";
create extension if not exists "citext";

create type public.email_visibility as enum ('hidden', 'everyone', 'contacts');
create type public.audience_visibility as enum ('everyone', 'contacts', 'nobody');
create type public.contact_request_status as enum ('pending', 'accepted', 'rejected', 'cancelled');
create type public.conversation_kind as enum ('direct');
create type public.message_delivery_status as enum ('sent', 'delivered', 'read');
create type public.attachment_kind as enum ('image', 'file');
create type public.report_status as enum ('open', 'reviewing', 'closed');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username citext unique not null,
  display_name text,
  avatar_path text,
  bio text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint username_format check (username ~ '^[a-zA-Z0-9_]{3,24}$'),
  constraint display_name_length check (display_name is null or char_length(display_name) <= 80),
  constraint bio_length check (bio is null or char_length(bio) <= 280)
);

create table public.privacy_settings (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  email_visibility public.email_visibility not null default 'hidden',
  last_seen_visibility public.audience_visibility not null default 'contacts',
  profile_photo_visibility public.audience_visibility not null default 'everyone',
  updated_at timestamptz not null default now()
);

create table public.notification_preferences (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  browser_notifications boolean not null default false,
  message_notifications boolean not null default true,
  contact_request_notifications boolean not null default true,
  sound_enabled boolean not null default true,
  updated_at timestamptz not null default now()
);

create table public.user_presence (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  status text not null default 'offline',
  last_seen_at timestamptz not null default now(),
  typing_conversation_id uuid,
  updated_at timestamptz not null default now(),
  constraint presence_status check (status in ('online', 'away', 'offline'))
);

create table public.contact_requests (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid not null references public.profiles(id) on delete cascade,
  addressee_id uuid not null references public.profiles(id) on delete cascade,
  status public.contact_request_status not null default 'pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint no_self_contact_request check (requester_id <> addressee_id),
  unique (requester_id, addressee_id)
);

create table public.contacts (
  owner_id uuid not null references public.profiles(id) on delete cascade,
  contact_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (owner_id, contact_id),
  constraint no_self_contact check (owner_id <> contact_id)
);

create table public.blocked_users (
  blocker_id uuid not null references public.profiles(id) on delete cascade,
  blocked_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  constraint no_self_block check (blocker_id <> blocked_id)
);

create table public.conversations (
  id uuid primary key default gen_random_uuid(),
  kind public.conversation_kind not null default 'direct',
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.conversation_participants (
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  last_read_message_id uuid,
  archived_at timestamptz,
  muted_until timestamptz,
  created_at timestamptz not null default now(),
  primary key (conversation_id, user_id)
);

create table public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  body text,
  delivery_status public.message_delivery_status not null default 'sent',
  edited_at timestamptz,
  deleted_for_everyone_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint message_body_length check (body is null or char_length(body) between 1 and 4000)
);

create table public.message_reads (
  message_id uuid not null references public.messages(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  read_at timestamptz not null default now(),
  primary key (message_id, user_id)
);

create table public.message_deletions (
  message_id uuid not null references public.messages(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  deleted_at timestamptz not null default now(),
  primary key (message_id, user_id)
);

create table public.message_attachments (
  id uuid primary key default gen_random_uuid(),
  message_id uuid not null references public.messages(id) on delete cascade,
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  uploader_id uuid not null references public.profiles(id) on delete cascade,
  storage_bucket text not null default 'message-attachments',
  storage_path text not null,
  file_name text not null,
  mime_type text not null,
  size_bytes bigint not null,
  kind public.attachment_kind not null,
  created_at timestamptz not null default now(),
  constraint attachment_size_limit check (size_bytes > 0 and size_bytes <= 26214400),
  constraint attachment_mime_allowlist check (
    mime_type in (
      'image/jpeg', 'image/png', 'image/webp', 'image/gif',
      'application/pdf', 'text/plain', 'text/csv',
      'application/zip',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
    )
  ),
  unique (storage_bucket, storage_path)
);

create table public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  reported_id uuid not null references public.profiles(id) on delete cascade,
  conversation_id uuid references public.conversations(id) on delete set null,
  message_id uuid references public.messages(id) on delete set null,
  reason text not null,
  details text,
  status public.report_status not null default 'open',
  created_at timestamptz not null default now(),
  constraint no_self_report check (reporter_id <> reported_id),
  constraint report_reason_length check (char_length(reason) between 3 and 120),
  constraint report_details_length check (details is null or char_length(details) <= 2000)
);

create table public.analytics_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete set null,
  anonymous_id text,
  event_name text not null,
  properties jsonb not null default '{}'::jsonb,
  ip_hash text,
  user_agent text,
  created_at timestamptz not null default now(),
  constraint event_name_format check (event_name ~ '^[a-zA-Z0-9_.:-]{2,80}$')
);

create table public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references public.profiles(id) on delete set null,
  action text not null,
  target_table text,
  target_id uuid,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index profiles_username_trgm_like_idx on public.profiles (username);
create index contacts_contact_id_idx on public.contacts (contact_id);
create index contact_requests_addressee_status_idx on public.contact_requests (addressee_id, status);
create index contact_requests_requester_status_idx on public.contact_requests (requester_id, status);
create index conversation_participants_user_idx on public.conversation_participants (user_id, conversation_id);
create index messages_conversation_created_idx on public.messages (conversation_id, created_at desc);
create index messages_sender_idx on public.messages (sender_id);
create index message_attachments_message_idx on public.message_attachments (message_id);
create index blocked_users_blocked_idx on public.blocked_users (blocked_id);
create index analytics_events_user_created_idx on public.analytics_events (user_id, created_at desc);
create index audit_logs_actor_created_idx on public.audit_logs (actor_id, created_at desc);

create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger profiles_updated_at before update on public.profiles
for each row execute function public.set_updated_at();
create trigger privacy_updated_at before update on public.privacy_settings
for each row execute function public.set_updated_at();
create trigger notification_updated_at before update on public.notification_preferences
for each row execute function public.set_updated_at();
create trigger contact_requests_updated_at before update on public.contact_requests
for each row execute function public.set_updated_at();
create trigger conversations_updated_at before update on public.conversations
for each row execute function public.set_updated_at();
create trigger messages_updated_at before update on public.messages
for each row execute function public.set_updated_at();

create or replace function public.handle_new_auth_user()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  base_username text;
  final_username text;
begin
  base_username := coalesce(nullif(regexp_replace(split_part(new.email, '@', 1), '[^a-zA-Z0-9_]', '', 'g'), ''), 'user');
  if new.raw_user_meta_data ? 'username' and (new.raw_user_meta_data->>'username') ~ '^[a-zA-Z0-9_]{3,24}$' then
    base_username := new.raw_user_meta_data->>'username';
  end if;
  final_username := base_username;
  if exists (select 1 from public.profiles where username = final_username) then
    final_username := left(base_username, 18) || '_' || substring(new.id::text, 1, 5);
  end if;
  insert into public.profiles (id, username, display_name)
  values (new.id, final_username, new.raw_user_meta_data->>'display_name');
  insert into public.privacy_settings (user_id) values (new.id);
  insert into public.notification_preferences (user_id) values (new.id);
  insert into public.user_presence (user_id) values (new.id);
  return new;
end;
$$;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_auth_user();

create or replace function public.is_contact(a uuid, b uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.contacts
    where owner_id = a and contact_id = b
  );
$$;

create or replace function public.has_block_between(a uuid, b uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.blocked_users
    where (blocker_id = a and blocked_id = b) or (blocker_id = b and blocked_id = a)
  );
$$;

create or replace function public.is_conversation_participant(conversation uuid, candidate uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.conversation_participants
    where conversation_id = conversation and user_id = candidate
  );
$$;

create or replace function public.can_view_profile_photo(viewer uuid, target uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select case ps.profile_photo_visibility
    when 'everyone' then not public.has_block_between(viewer, target)
    when 'contacts' then public.is_contact(target, viewer) and not public.has_block_between(viewer, target)
    else viewer = target
  end
  from public.privacy_settings ps
  where ps.user_id = target;
$$;

create or replace function public.accept_contact_request(request_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  req public.contact_requests%rowtype;
begin
  select * into req from public.contact_requests where id = request_id for update;
  if req.id is null or req.addressee_id <> auth.uid() or req.status <> 'pending' then
    raise exception 'contact request is not actionable';
  end if;
  if public.has_block_between(req.requester_id, req.addressee_id) then
    raise exception 'blocked users cannot become contacts';
  end if;
  update public.contact_requests set status = 'accepted' where id = request_id;
  insert into public.contacts (owner_id, contact_id) values (req.requester_id, req.addressee_id)
  on conflict do nothing;
  insert into public.contacts (owner_id, contact_id) values (req.addressee_id, req.requester_id)
  on conflict do nothing;
  insert into public.audit_logs(actor_id, action, target_table, target_id)
  values (auth.uid(), 'contact_request.accept', 'contact_requests', request_id);
end;
$$;

create or replace function public.create_direct_conversation(other_user uuid)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  existing_conversation uuid;
  new_conversation uuid;
begin
  if other_user = auth.uid() or public.has_block_between(auth.uid(), other_user) then
    raise exception 'conversation not allowed';
  end if;

  select cp1.conversation_id into existing_conversation
  from public.conversation_participants cp1
  join public.conversation_participants cp2 on cp2.conversation_id = cp1.conversation_id
  join public.conversations c on c.id = cp1.conversation_id and c.kind = 'direct'
  where cp1.user_id = auth.uid() and cp2.user_id = other_user
  limit 1;

  if existing_conversation is not null then
    return existing_conversation;
  end if;

  insert into public.conversations (created_by) values (auth.uid()) returning id into new_conversation;
  insert into public.conversation_participants (conversation_id, user_id)
  values (new_conversation, auth.uid()), (new_conversation, other_user);
  return new_conversation;
end;
$$;

create or replace function public.search_profiles(query text, limit_count int default 10)
returns table (
  id uuid,
  username citext,
  display_name text,
  avatar_path text,
  bio text,
  is_contact boolean
) language sql stable security definer set search_path = public as $$
  select p.id, p.username, p.display_name,
    case when public.can_view_profile_photo(auth.uid(), p.id) then p.avatar_path else null end as avatar_path,
    p.bio,
    public.is_contact(auth.uid(), p.id) as is_contact
  from public.profiles p
  where auth.uid() is not null
    and p.id <> auth.uid()
    and p.username ilike replace(query, '%', '\%') || '%'
    and not public.has_block_between(auth.uid(), p.id)
  order by p.username
  limit greatest(1, least(limit_count, 25));
$$;

create or replace function public.log_sensitive_action()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.audit_logs(actor_id, action, target_table, target_id, metadata)
  values (auth.uid(), tg_table_name || '.' || lower(tg_op), tg_table_name, coalesce(new.id, old.id), '{}'::jsonb);
  return coalesce(new, old);
end;
$$;

create trigger audit_profile_update after update on public.profiles
for each row execute function public.log_sensitive_action();
create trigger audit_privacy_update after update on public.privacy_settings
for each row execute function public.log_sensitive_action();

create or replace function public.log_block_action()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.audit_logs(actor_id, action, target_table, metadata)
  values (
    auth.uid(),
    'blocked_users.' || lower(tg_op),
    'blocked_users',
    jsonb_build_object('blocker_id', new.blocker_id, 'blocked_id', new.blocked_id)
  );
  return new;
end;
$$;

create trigger audit_block_insert after insert on public.blocked_users
for each row execute function public.log_block_action();

alter table public.profiles enable row level security;
alter table public.privacy_settings enable row level security;
alter table public.notification_preferences enable row level security;
alter table public.user_presence enable row level security;
alter table public.contact_requests enable row level security;
alter table public.contacts enable row level security;
alter table public.blocked_users enable row level security;
alter table public.conversations enable row level security;
alter table public.conversation_participants enable row level security;
alter table public.messages enable row level security;
alter table public.message_reads enable row level security;
alter table public.message_deletions enable row level security;
alter table public.message_attachments enable row level security;
alter table public.reports enable row level security;
alter table public.analytics_events enable row level security;
alter table public.audit_logs enable row level security;

create policy "profiles visible to signed-in non-blocked users" on public.profiles
for select using (auth.uid() is not null and (id = auth.uid() or not public.has_block_between(auth.uid(), id)));
create policy "users update own profile" on public.profiles
for update using (id = auth.uid()) with check (id = auth.uid());

create policy "users read own privacy" on public.privacy_settings
for select using (user_id = auth.uid());
create policy "users update own privacy" on public.privacy_settings
for update using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "users read own notifications" on public.notification_preferences
for select using (user_id = auth.uid());
create policy "users update own notifications" on public.notification_preferences
for update using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "presence visible when allowed" on public.user_presence
for select using (
  user_id = auth.uid()
  or (
    not public.has_block_between(auth.uid(), user_id)
    and exists (
      select 1 from public.privacy_settings ps
      where ps.user_id = user_presence.user_id
      and (ps.last_seen_visibility = 'everyone' or (ps.last_seen_visibility = 'contacts' and public.is_contact(user_presence.user_id, auth.uid())))
    )
  )
);
create policy "users upsert own presence" on public.user_presence
for all using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "request participants can read contact requests" on public.contact_requests
for select using (requester_id = auth.uid() or addressee_id = auth.uid());
create policy "users send contact requests" on public.contact_requests
for insert with check (requester_id = auth.uid() and not public.has_block_between(requester_id, addressee_id));
create policy "addressee updates request" on public.contact_requests
for update using (addressee_id = auth.uid() or requester_id = auth.uid())
with check (addressee_id = auth.uid() or requester_id = auth.uid());

create policy "users read own contacts" on public.contacts
for select using (owner_id = auth.uid());
create policy "users delete own contacts" on public.contacts
for delete using (owner_id = auth.uid());

create policy "users read own blocks" on public.blocked_users
for select using (blocker_id = auth.uid());
create policy "users block others" on public.blocked_users
for insert with check (blocker_id = auth.uid());
create policy "users unblock others" on public.blocked_users
for delete using (blocker_id = auth.uid());

create policy "participants read conversations" on public.conversations
for select using (public.is_conversation_participant(id, auth.uid()));
create policy "users create conversations" on public.conversations
for insert with check (created_by = auth.uid());

create policy "participants read participants" on public.conversation_participants
for select using (public.is_conversation_participant(conversation_id, auth.uid()));
create policy "creator adds participants" on public.conversation_participants
for insert with check (user_id = auth.uid() or public.is_conversation_participant(conversation_id, auth.uid()));
create policy "participants update own participant row" on public.conversation_participants
for update using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "participants read messages" on public.messages
for select using (
  public.is_conversation_participant(conversation_id, auth.uid())
  and not exists (
    select 1 from public.message_deletions md
    where md.message_id = messages.id and md.user_id = auth.uid()
  )
);
create policy "participants send messages" on public.messages
for insert with check (
  sender_id = auth.uid()
  and public.is_conversation_participant(conversation_id, auth.uid())
  and not exists (
    select 1
    from public.conversation_participants cp
    where cp.conversation_id = messages.conversation_id
      and cp.user_id <> auth.uid()
      and public.has_block_between(auth.uid(), cp.user_id)
  )
);
create policy "senders edit or delete messages for everyone" on public.messages
for update using (sender_id = auth.uid()) with check (sender_id = auth.uid());

create policy "participants read receipts" on public.message_reads
for select using (
  exists (
    select 1 from public.messages m
    where m.id = message_reads.message_id and public.is_conversation_participant(m.conversation_id, auth.uid())
  )
);
create policy "participants mark messages read" on public.message_reads
for insert with check (
  user_id = auth.uid()
  and exists (
    select 1 from public.messages m
    where m.id = message_reads.message_id and public.is_conversation_participant(m.conversation_id, auth.uid())
  )
);

create policy "users hide messages for themselves" on public.message_deletions
for insert with check (
  user_id = auth.uid()
  and exists (
    select 1 from public.messages m
    where m.id = message_deletions.message_id and public.is_conversation_participant(m.conversation_id, auth.uid())
  )
);

create policy "participants read attachments" on public.message_attachments
for select using (public.is_conversation_participant(conversation_id, auth.uid()));
create policy "participants create attachments" on public.message_attachments
for insert with check (
  uploader_id = auth.uid()
  and public.is_conversation_participant(conversation_id, auth.uid())
);

create policy "users create reports" on public.reports
for insert with check (reporter_id = auth.uid());
create policy "users read own reports" on public.reports
for select using (reporter_id = auth.uid());

create policy "users create own analytics events" on public.analytics_events
for insert with check (user_id = auth.uid() or user_id is null);

create policy "users read own audit logs" on public.audit_logs
for select using (actor_id = auth.uid());

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'message-attachments',
  'message-attachments',
  false,
  26214400,
  array[
    'image/jpeg', 'image/png', 'image/webp', 'image/gif',
    'application/pdf', 'text/plain', 'text/csv',
    'application/zip',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
  ]
) on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'profile-avatars',
  'profile-avatars',
  false,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp', 'image/gif']
) on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create policy "participants read stored attachments" on storage.objects
for select using (
  bucket_id = 'message-attachments'
  and public.is_conversation_participant((storage.foldername(name))[1]::uuid, auth.uid())
);

create policy "participants upload stored attachments" on storage.objects
for insert with check (
  bucket_id = 'message-attachments'
  and owner = auth.uid()
  and public.is_conversation_participant((storage.foldername(name))[1]::uuid, auth.uid())
);

create policy "uploaders update stored attachments" on storage.objects
for update using (bucket_id = 'message-attachments' and owner = auth.uid())
with check (bucket_id = 'message-attachments' and owner = auth.uid());

create policy "uploaders delete stored attachments" on storage.objects
for delete using (bucket_id = 'message-attachments' and owner = auth.uid());

create policy "allowed viewers read profile avatars" on storage.objects
for select using (
  bucket_id = 'profile-avatars'
  and exists (
    select 1 from public.profiles p
    where p.avatar_path = storage.objects.name
      and (p.id = auth.uid() or public.can_view_profile_photo(auth.uid(), p.id))
  )
);

create policy "users upload own profile avatars" on storage.objects
for insert with check (
  bucket_id = 'profile-avatars'
  and owner = auth.uid()
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy "users update own profile avatars" on storage.objects
for update using (
  bucket_id = 'profile-avatars'
  and owner = auth.uid()
) with check (
  bucket_id = 'profile-avatars'
  and owner = auth.uid()
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy "users delete own profile avatars" on storage.objects
for delete using (bucket_id = 'profile-avatars' and owner = auth.uid());
