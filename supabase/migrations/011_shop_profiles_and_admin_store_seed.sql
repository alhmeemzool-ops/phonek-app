-- PhoneK: complete public shop profile fields and admin-store permissions.
-- The configured admin store is provisioned by the authenticated app workflow so
-- the existing profile protection trigger can evaluate public.is_admin().

alter table public.profiles
  add column if not exists shop_address text,
  add column if not exists shop_location_url text,
  add column if not exists shop_hours jsonb not null default '{}'::jsonb,
  add column if not exists payment_methods text[] not null default '{}'::text[];

drop policy if exists "public_can_read_active_shop_profiles" on public.profiles;
create policy "public_can_read_active_shop_profiles"
on public.profiles for select
to anon, authenticated
using (is_shop = true);

drop policy if exists "admins_update_shop_profile_details" on public.profiles;
create policy "admins_update_shop_profile_details"
on public.profiles for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "shop_owner_update_shop_profile_details" on public.profiles;
create policy "shop_owner_update_shop_profile_details"
on public.profiles for update
to authenticated
using (auth.uid() = id and is_shop = true)
with check (auth.uid() = id and is_shop = true);

drop policy if exists "admins_update_badge_state" on public.merchant_badge_state;
create policy "admins_update_badge_state"
on public.merchant_badge_state for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

notify pgrst, 'reload schema';
