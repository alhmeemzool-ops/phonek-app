-- Admin operational monitoring: login events and privileged visibility for moderation.
create table if not exists public.login_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  phone_e164 text,
  method text not null check (method in ('whatsapp_otp','google','other')),
  success boolean not null default true,
  created_at timestamptz not null default now()
);

create index if not exists login_events_created_at_idx on public.login_events(created_at desc);
create index if not exists login_events_user_id_idx on public.login_events(user_id);

alter table public.login_events enable row level security;
drop policy if exists "admins can read login events" on public.login_events;
create policy "admins can read login events"
on public.login_events for select to authenticated
using (public.is_admin());

-- Login events are written by the trusted phone-OTP Edge Function using the
-- service role. No client insert policy is intentionally exposed.

-- Admins need operational visibility into active conversations for moderation.
-- The blocks are conditional so this migration remains safe if chat tables are
-- provided by an external/base schema in a deployment.
do $$
begin
  if to_regclass('public.chat_threads') is not null then
    alter table public.chat_threads enable row level security;
    drop policy if exists "admins can read chat threads" on public.chat_threads;
    create policy "admins can read chat threads"
      on public.chat_threads for select to authenticated
      using (public.is_admin() or auth.uid() = buyer_id or auth.uid() = seller_id);
  end if;

  if to_regclass('public.chat_messages') is not null then
    alter table public.chat_messages enable row level security;
    drop policy if exists "admins can read chat messages" on public.chat_messages;
    create policy "admins can read chat messages"
      on public.chat_messages for select to authenticated
      using (
        public.is_admin()
        or exists (
          select 1 from public.chat_threads t
          where t.id = chat_messages.thread_id
            and (auth.uid() = t.buyer_id or auth.uid() = t.seller_id)
        )
      );
  end if;
end $$;
