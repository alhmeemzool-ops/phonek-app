-- PhoneK: reconcile admin authorization with the live schema.
-- The live project uses shop_verification_requests (not shop_applications).
-- This migration is additive and preserves existing data and the existing
-- profiles protect_shop_verification_fields() trigger.

alter table public.profiles
  add column if not exists is_admin boolean not null default false;

update public.profiles p
set is_admin = true
from auth.users u
where p.id = u.id
  and lower(coalesce(u.email, '')) = 'alhmeemzool@gmail.com';

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public, auth
as $$
  select coalesce(
    (select p.is_admin = true from public.profiles p where p.id = auth.uid()),
    false
  )
  or coalesce((auth.jwt() -> 'app_metadata' ->> 'role'), '') = 'admin'
  or lower(coalesce((select u.email from auth.users u where u.id = auth.uid()), ''))
       = 'alhmeemzool@gmail.com';
$$;
revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to authenticated;

-- Existing shop_verification_requests is the authoritative shop workflow.
alter table public.shop_verification_requests enable row level security;
drop policy if exists "shop_verification_insert_own" on public.shop_verification_requests;
drop policy if exists "shop_verification_select_own" on public.shop_verification_requests;
drop policy if exists "shop_verification_update_admin" on public.shop_verification_requests;
create policy "shop_verification_insert_own"
on public.shop_verification_requests for insert to authenticated
with check (auth.uid() = user_id and status = 'pending');
create policy "shop_verification_select_own"
on public.shop_verification_requests for select to authenticated
using (auth.uid() = user_id or public.is_admin());
create policy "shop_verification_update_admin"
on public.shop_verification_requests for update to authenticated
using (public.is_admin())
with check (public.is_admin());

-- Preserve the existing profiles trigger/function. This separate trigger is
-- specifically for request-row moderation fields.
create or replace function public.protect_shop_verification_request_fields()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if tg_op = 'UPDATE' and not public.is_admin() then
    if new.status is distinct from old.status
       or new.reviewed_by is distinct from old.reviewed_by
       or new.reviewed_at is distinct from old.reviewed_at
       or new.rejection_reason is distinct from old.rejection_reason then
      raise exception 'Only an approved admin can change shop verification status'
        using errcode = 'P0001';
    end if;
  end if;
  return new;
end;
$$;
revoke all on function public.protect_shop_verification_request_fields() from public, anon, authenticated;
grant execute on function public.protect_shop_verification_request_fields() to postgres, service_role;
drop trigger if exists protect_shop_verification_request_fields on public.shop_verification_requests;
create trigger protect_shop_verification_request_fields
before update on public.shop_verification_requests
for each row execute function public.protect_shop_verification_request_fields();

-- Listing moderation fields and server-side protection.
alter table public.listings
  add column if not exists reviewed_at timestamptz,
  add column if not exists reviewed_by uuid references auth.users(id),
  add column if not exists rejection_reason text;
alter table public.listings enable row level security;
drop policy if exists "admins can update listings" on public.listings;
drop policy if exists "admins can manage listings" on public.listings;
drop policy if exists "admins can select listings" on public.listings;
drop policy if exists "Listings are viewable by everyone" on public.listings;
create policy "admins can update listings"
on public.listings for update to authenticated
using (public.is_admin())
with check (public.is_admin());
create policy "admins can select listings"
on public.listings for select to authenticated
using (public.is_admin() or status = 'active' or seller_id = auth.uid());
create policy "Listings are viewable by everyone"
on public.listings for select to anon, authenticated
using (status = 'active' or seller_id = auth.uid() or public.is_admin());

create or replace function public.protect_listing_moderation_fields()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if tg_op = 'UPDATE' and not public.is_admin() then
    if new.status is distinct from old.status
       or new.reviewed_at is distinct from old.reviewed_at
       or new.reviewed_by is distinct from old.reviewed_by
       or new.rejection_reason is distinct from old.rejection_reason then
      raise exception 'Only an approved admin can moderate listings'
        using errcode = 'P0001';
    end if;
  end if;
  return new;
end;
$$;
revoke all on function public.protect_listing_moderation_fields() from public, anon, authenticated;
grant execute on function public.protect_listing_moderation_fields() to postgres, service_role;
drop trigger if exists protect_listing_moderation_fields on public.listings;
create trigger protect_listing_moderation_fields
before update on public.listings
for each row execute function public.protect_listing_moderation_fields();

create table if not exists public.login_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  phone_e164 text,
  method text not null check (method in ('whatsapp_otp', 'google', 'other')),
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
revoke insert, update, delete on public.login_events from anon, authenticated;

-- Existing verification documents bucket is already private. Keep ownership
-- access and ensure the configured/admin role can read via the DB helper.
drop policy if exists "verification_documents_select_own_or_admin" on storage.objects;
create policy "verification_documents_select_own_or_admin"
on storage.objects for select to authenticated
using (
  bucket_id = 'verification-documents'
  and ((auth.uid())::text = (storage.foldername(name))[1] or public.is_admin())
);

notify pgrst, 'reload schema';
