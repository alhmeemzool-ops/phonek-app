-- Harden the admin/shop-application path after production RLS failures.
-- Keeps admin access server-side while allowing the configured admin account
-- to recover even if its profiles.is_admin flag was not seeded.

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (select p.is_admin from public.profiles p where p.id = auth.uid()),
    false
  )
  or lower(coalesce((auth.jwt() ->> 'email'), '')) = 'alhmeemzool@gmail.com';
$$;

revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to authenticated;

-- Ensure all fields used by the shop-application client/admin review flow exist.
alter table public.shop_applications
  add column if not exists kyc_provider text,
  add column if not exists kyc_session_id text,
  add column if not exists kyc_result text not null default 'pending',
  add column if not exists kyc_verified_at timestamptz,
  add column if not exists location_accuracy_m double precision,
  add column if not exists consented_at timestamptz,
  add column if not exists face_photo_path text,
  add column if not exists liveness_video_path text,
  add column if not exists identity_photo_path text,
  add column if not exists reviewed_by uuid references auth.users(id),
  add column if not exists reviewed_at timestamptz;

-- Rebuild the owner/admin policies with the hardened admin helper.
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

create index if not exists shop_applications_created_at_idx
  on public.shop_applications(created_at desc);
