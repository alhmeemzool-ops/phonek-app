create table if not exists public.push_tokens (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
 token text not null, platform text not null default 'android', enabled boolean not null default true,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(), last_seen_at timestamptz not null default now(),
 unique(user_id,token));
create index if not exists push_tokens_user_id_idx on public.push_tokens(user_id);
alter table public.push_tokens enable row level security;
drop policy if exists "users manage own push tokens" on public.push_tokens;
create policy "users manage own push tokens" on public.push_tokens for all to authenticated using(auth.uid()=user_id) with check(auth.uid()=user_id);

create table if not exists public.notification_preferences (
 user_id uuid primary key references auth.users(id) on delete cascade, messages boolean not null default true,
 offers boolean not null default true, listings boolean not null default true, system boolean not null default true, updated_at timestamptz not null default now());
alter table public.notification_preferences enable row level security;
drop policy if exists "users manage own notification preferences" on public.notification_preferences;
create policy "users manage own notification preferences" on public.notification_preferences for all to authenticated using(auth.uid()=user_id) with check(auth.uid()=user_id);

create table if not exists public.notification_log (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
 event_key text not null, title text not null, body text not null, data jsonb not null default '{}'::jsonb, created_at timestamptz not null default now(),
 unique(user_id,event_key));
alter table public.notification_log enable row level security;
drop policy if exists "users read own notification log" on public.notification_log;
create policy "users read own notification log" on public.notification_log for select to authenticated using(auth.uid()=user_id);