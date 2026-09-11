-- Admin moderation hardening for PhoneK.
-- The helper is SECURITY DEFINER so RLS checks can safely ask whether the
-- current authenticated user is an admin without recursively reading profiles.
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce((select is_admin from public.profiles where id = auth.uid()), false);
$$;

revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to authenticated;

alter table public.listings add column if not exists reviewed_at timestamptz;
alter table public.listings add column if not exists reviewed_by uuid references auth.users(id);
alter table public.listings add column if not exists rejection_reason text;

-- Replace broad/legacy admin write policies with an explicit server-side check.
drop policy if exists "admins can update listings" on public.listings;
drop policy if exists "admins can manage listings" on public.listings;
create policy "admins can update listings"
on public.listings
for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

-- Admins need to see pending listings even when normal users only see active rows.
drop policy if exists "admins can select listings" on public.listings;
create policy "admins can select listings"
on public.listings
for select
to authenticated
using (public.is_admin() or status = 'active' or seller_id = auth.uid());
