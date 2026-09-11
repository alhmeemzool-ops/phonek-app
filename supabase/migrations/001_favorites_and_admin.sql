-- PhoneK production support tables/columns.
-- Safe to run on an existing Supabase project.

alter table public.profiles
  add column if not exists is_admin boolean not null default false;

create table if not exists public.favorites (
  user_id uuid not null references auth.users(id) on delete cascade,
  listing_id uuid not null references public.listings(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, listing_id)
);

alter table public.favorites enable row level security;

create policy "Users can read their own favorites"
on public.favorites for select
to authenticated
using (auth.uid() = user_id);

create policy "Users can add their own favorites"
on public.favorites for insert
to authenticated
with check (auth.uid() = user_id);

create policy "Users can remove their own favorites"
on public.favorites for delete
to authenticated
using (auth.uid() = user_id);

create index if not exists favorites_listing_id_idx
  on public.favorites(listing_id);
