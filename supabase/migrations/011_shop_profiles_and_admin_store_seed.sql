-- PhoneK: complete public shop profile fields and admin-store permissions.
-- Public store data is exposed through a dedicated safe view rather than a
-- broad profiles SELECT policy, so private profile/admin fields stay private.

alter table public.profiles
  add column if not exists shop_address text,
  add column if not exists shop_location_url text,
  add column if not exists shop_hours jsonb not null default '{}'::jsonb,
  add column if not exists payment_methods text[] not null default '{}'::text[];

drop policy if exists "public_can_read_active_shop_profiles" on public.profiles;

create or replace view public.public_shop_profiles as
select
  id,
  name,
  city,
  phone,
  whatsapp,
  bio,
  avatar_url,
  is_shop,
  is_verified_store,
  completed_sales,
  rating,
  reply_speed_label,
  shop_address,
  shop_location_url,
  shop_hours,
  payment_methods
from public.profiles
where is_shop = true;

grant select on public.public_shop_profiles to anon, authenticated;

-- Admins may maintain store presentation details.
drop policy if exists "admins_update_shop_profile_details" on public.profiles;
create policy "admins_update_shop_profile_details"
on public.profiles for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

-- A verified shop owner may maintain their own presentation fields.
drop policy if exists "shop_owner_update_shop_profile_details" on public.profiles;
create policy "shop_owner_update_shop_profile_details"
on public.profiles for update
to authenticated
using (auth.uid() = id and is_shop = true)
with check (auth.uid() = id and is_shop = true);

-- Admin badge management. The normal badge recalculation remains the source
-- of earned levels; this policy allows the admin management screen to operate.
drop policy if exists "admins_update_badge_state" on public.merchant_badge_state;
create policy "admins_update_badge_state"
on public.merchant_badge_state for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

notify pgrst, 'reload schema';
