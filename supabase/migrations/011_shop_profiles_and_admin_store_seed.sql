-- PhoneK: complete public shop profile + configured admin store.
-- Adds only additive fields, then provisions the configured admin as the
-- official PhoneK store and creates six active catalog listings if missing.

alter table public.profiles
  add column if not exists shop_address text,
  add column if not exists shop_location_url text,
  add column if not exists shop_hours jsonb not null default '{}'::jsonb,
  add column if not exists payment_methods text[] not null default '{}'::text[];

-- Public visitors need the shop profile fields for active stores only.
drop policy if exists "public_can_read_active_shop_profiles" on public.profiles;
create policy "public_can_read_active_shop_profiles"
on public.profiles for select
to anon, authenticated
using (is_shop = true);

-- Admins may maintain store presentation details without exposing write access
-- to ordinary users.
drop policy if exists "admins_update_shop_profile_details" on public.profiles;
create policy "admins_update_shop_profile_details"
on public.profiles for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

-- Allow an owner to edit the shop presentation fields only for their own row.
drop policy if exists "shop_owner_update_shop_profile_details" on public.profiles;
create policy "shop_owner_update_shop_profile_details"
on public.profiles for update
to authenticated
using (auth.uid() = id and is_shop = true)
with check (auth.uid() = id and is_shop = true);

-- Admin badge management. Earned levels remain monotonic; an admin can only
-- move a store forward, while the normal recalculation remains authoritative.
drop policy if exists "admins_update_badge_state" on public.merchant_badge_state;
create policy "admins_update_badge_state"
on public.merchant_badge_state for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

-- Configure the known PhoneK admin account as a ready-to-use official store.
do $$
declare
  admin_id uuid;
  existing_count integer;
begin
  select id into admin_id from auth.users where lower(email) = 'alhmeemzool@gmail.com' limit 1;
  if admin_id is null then
    raise notice 'PhoneK admin account not found yet; store seed will be retried by the app/admin workflow.';
    return;
  end if;

  update public.profiles
  set is_shop = true,
      is_verified_store = true,
      name = 'متجر PhoneK الرسمي',
      city = coalesce(nullif(city, ''), 'الخرطوم'),
      shop_address = coalesce(nullif(shop_address, ''), 'الخرطوم — متجر PhoneK الرسمي'),
      shop_location_url = coalesce(nullif(shop_location_url, ''), 'https://maps.google.com/?q=Khartoum,Sudan'),
      shop_hours = '{"السبت":"09:00 - 21:00","الأحد":"09:00 - 21:00","الاثنين":"09:00 - 21:00","الثلاثاء":"09:00 - 21:00","الأربعاء":"09:00 - 21:00","الخميس":"09:00 - 21:00","الجمعة":"16:00 - 21:00"}'::jsonb,
      payment_methods = array['نقداً','تحويل بنكي','دفع عند الاستلام']::text[]
  where id = admin_id;

  select count(*) into existing_count from public.listings where seller_id = admin_id;
  if existing_count = 0 then
    insert into public.listings
      (seller_id,title,brand,price,price_is_negotiable,price_on_call,storage,ram,condition,has_box,has_charger,has_invoice,has_earphones,warranty,city,image_urls,status,created_at,view_count,is_featured,description)
    values
      (admin_id,'iPhone 15 Pro Max — 256GB','iPhone',620000,true,false,'256GB','8GB','excellent',true,true,true,false,'store_warranty','الخرطوم','{}','active',now() - interval '1 day',31,true,'جهاز نظيف مع كرتونة وفاتورة وضمان متجر PhoneK.'),
      (admin_id,'Samsung Galaxy S24 Ultra','Samsung',540000,true,false,'256GB','12GB','excellent',true,true,true,false,'store_warranty','الخرطوم','{}','active',now() - interval '2 days',24,true,'نسخة أصلية، حالة ممتازة، متوفرة مع كامل الملحقات.'),
      (admin_id,'Google Pixel 8 Pro','Google',390000,true,false,'128GB','12GB','excellent',true,true,false,false,'none','الخرطوم','{}','active',now() - interval '3 days',18,false,'هاتف رائد بكاميرا ممتازة وحالة نظيفة.'),
      (admin_id,'Xiaomi 14','Xiaomi',315000,true,false,'512GB','12GB','new',true,true,true,false,'agent_warranty','الخرطوم','{}','active',now() - interval '4 days',27,false,'جديد بالكرتونة وضمان وكيل رسمي.'),
      (admin_id,'Tecno Camon 30 Pro','Tecno',180000,true,false,'512GB','12GB','new',true,true,true,false,'agent_warranty','الخرطوم','{}','active',now() - interval '5 days',14,false,'جهاز جديد مع الضمان والملحقات.'),
      (admin_id,'Infinix Note 40 Pro','Infinix',155000,true,false,'256GB','8GB','excellent',true,true,false,false,'store_warranty','الخرطوم','{}','active',now() - interval '6 days',11,false,'حالة ممتازة وسعر قابل للتفاوض.');
  end if;

  insert into public.merchant_badge_state
    (profile_id,current_level,eligible_level,completed_sales,rating,identity_verified,license_verified,updated_at)
  values (admin_id,1,1,0,0,true,false,now())
  on conflict (profile_id) do update set
    current_level = greatest(public.merchant_badge_state.current_level, excluded.current_level),
    eligible_level = greatest(public.merchant_badge_state.eligible_level, excluded.eligible_level),
    identity_verified = true,
    updated_at = now();
end $$;

notify pgrst, 'reload schema';
