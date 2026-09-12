-- PhoneK: reconcile admin authorization, moderation protections, and private review media.
-- This migration is additive/idempotent and preserves all existing data.

-- Keep the schema dependency explicit for installations that skipped an earlier
-- compatibility migration.
alter table public.profiles
  add column if not exists is_admin boolean not null default false;

-- The configured account is seeded when its profile already exists. The JWT
-- email fallback below also permits recovery when the profile row is absent;
-- it does not grant ordinary users an admin flag or client-side privilege.
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
    (select p.is_admin = true
       from public.profiles p
      where p.id = auth.uid()),
    false
  )
  or lower(coalesce((select u.email from auth.users u where u.id = auth.uid()), ''))
       = 'alhmeemzool@gmail.com';
$$;

revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to authenticated;

-- Do not rely on a client update policy alone: this trigger prevents a normal
-- user from changing moderation/verification fields through any other policy.
create or replace function public.protect_shop_verification_fields()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if tg_op = 'UPDATE' and not public.is_admin() then
    if new.verification_status is distinct from old.verification_status
       or new.liveness_status is distinct from old.liveness_status
       or new.identity_match_status is distinct from old.identity_match_status
       or new.kyc_result is distinct from old.kyc_result
       or new.kyc_verified_at is distinct from old.kyc_verified_at
       or new.face_photo_path is distinct from old.face_photo_path
       or new.liveness_video_path is distinct from old.liveness_video_path
       or new.identity_photo_path is distinct from old.identity_photo_path
       or new.reviewer_id is distinct from old.reviewer_id
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

revoke all on function public.protect_shop_verification_fields() from public, anon, authenticated;
grant execute on function public.protect_shop_verification_fields() to postgres, service_role;

drop trigger if exists protect_shop_verification_fields on public.shop_applications;
create trigger protect_shop_verification_fields
before update on public.shop_applications
for each row execute function public.protect_shop_verification_fields();

alter table public.shop_applications enable row level security;
drop policy if exists "shop_applications_owner_select" on public.shop_applications;
drop policy if exists "shop_applications_owner_insert" on public.shop_applications;
drop policy if exists "shop_applications_admin_update" on public.shop_applications;
drop policy if exists "admins can read shop applications" on public.shop_applications;
create policy "shop_applications_owner_select"
on public.shop_applications for select to authenticated
using (auth.uid() = user_id or public.is_admin());
create policy "shop_applications_owner_insert"
on public.shop_applications for insert to authenticated
with check (auth.uid() = user_id);
create policy "shop_applications_admin_update"
on public.shop_applications for update to authenticated
using (public.is_admin())
with check (public.is_admin());

-- Ensure the moderation columns used by the app are present and constrained.
alter table public.listings
  add column if not exists reviewed_at timestamptz,
  add column if not exists reviewed_by uuid references auth.users(id),
  add column if not exists rejection_reason text;

alter table public.listings enable row level security;
drop policy if exists "admins can update listings" on public.listings;
drop policy if exists "admins can manage listings" on public.listings;
drop policy if exists "admins can select listings" on public.listings;
create policy "admins can update listings"
on public.listings for update to authenticated
using (public.is_admin())
with check (public.is_admin());
create policy "admins can select listings"
on public.listings for select to authenticated
using (public.is_admin() or status = 'active' or seller_id = auth.uid());

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

-- login_events remains service-role write only; admins can read it through RLS.
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

-- Review media must stay private. Existing objects are not deleted.
do $$
begin
  if to_regclass('storage.buckets') is not null then
    update storage.buckets
       set public = false
     where id = 'shop-application-media';
  end if;
end $$;

do $$
begin
  if to_regclass('storage.objects') is not null then
    drop policy if exists "shop application media admin read" on storage.objects;
    create policy "shop application media admin read"
      on storage.objects for select to authenticated
      using (bucket_id = 'shop-application-media' and public.is_admin());
  end if;
end $$;

notify pgrst, 'reload schema';
