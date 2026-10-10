-- Restore the two additive columns consumed by the current Flutter client.
-- This migration is safe to rerun and does not modify existing rows.
alter table public.listings
  add column if not exists accepts_swap boolean not null default false;

alter table public.chat_messages
  add column if not exists payload jsonb;

notify pgrst, 'reload schema';
