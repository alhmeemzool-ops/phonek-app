-- In-app notification inbox for PhoneK.
create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  title text not null,
  body text not null default '',
  type text not null default 'system',
  action_route text,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists notifications_user_created_at_idx
  on public.notifications (user_id, created_at desc);

alter table public.notifications enable row level security;

drop policy if exists notifications_select_own_or_public on public.notifications;
create policy notifications_select_own_or_public on public.notifications
  for select using (user_id is null or auth.uid() = user_id);

drop policy if exists notifications_update_own on public.notifications;
create policy notifications_update_own on public.notifications
  for update using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- Inserts should be performed by a trusted admin/server workflow.
-- No client insert policy is intentionally exposed here.
