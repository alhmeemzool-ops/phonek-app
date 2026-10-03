-- PhoneK Phase 3 security hardening.
-- Public seller data is copied into a safe projection table; private contact
-- fields remain only in profiles and are returned through an authenticated RPC.

create schema if not exists private;

drop view if exists public.public_shop_profiles;
drop view if exists public.public_seller_cards;

create table if not exists public.public_seller_cards (
  id uuid primary key,
  name text,
  avatar_url text,
  bio text,
  city text,
  is_verified_store boolean not null default false,
  is_shop boolean not null default false,
  rating numeric,
  completed_sales integer,
  reply_speed_label text,
  shop_city text,
  shop_address text,
  shop_latitude double precision,
  shop_longitude double precision,
  shop_verification_status text,
  shop_location_url text,
  shop_hours jsonb,
  payment_methods text[],
  merchant_badge_level integer not null default 0,
  merchant_sales_count integer not null default 0,
  merchant_rating numeric not null default 0
);

alter table public.public_seller_cards enable row level security;
revoke all on table public.public_seller_cards from anon, authenticated, public;
grant select on table public.public_seller_cards to anon, authenticated;

drop policy if exists "public seller cards are readable" on public.public_seller_cards;
create policy "public seller cards are readable"
on public.public_seller_cards for select
to anon, authenticated
using (true);

alter table public.profiles enable row level security;
drop policy if exists "Profiles are viewable by everyone" on public.profiles;
drop policy if exists "profiles_owner_or_admin_select" on public.profiles;
create policy "profiles_owner_or_admin_select"
on public.profiles for select
to authenticated
using ((select auth.uid()) = id or public.is_admin());

revoke all on table public.profiles from anon, public;
grant select, insert, update on table public.profiles to authenticated;

create or replace function private.sync_public_seller_card()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_table_name = 'profiles' then
    if tg_op = 'DELETE' then
      delete from public.public_seller_cards where id = old.id;
      return old;
    end if;

    insert into public.public_seller_cards (
      id,name,avatar_url,bio,city,is_verified_store,is_shop,rating,completed_sales,
      reply_speed_label,shop_city,shop_address,shop_latitude,shop_longitude,
      shop_verification_status,shop_location_url,shop_hours,payment_methods,
      merchant_badge_level,merchant_sales_count,merchant_rating
    )
    select
      new.id,new.name,new.avatar_url,new.bio,new.city,
      coalesce(new.is_verified_store,false),coalesce(new.is_shop,false),new.rating,
      coalesce(new.completed_sales,0),new.reply_speed_label,new.shop_city,new.shop_address,
      new.shop_latitude,new.shop_longitude,new.shop_verification_status,new.shop_location_url,
      new.shop_hours,new.payment_methods,coalesce(m.current_level,0),
      coalesce(m.completed_sales,new.completed_sales,0),
      coalesce(m.rating,new.rating,0::numeric)
    from (select 1) s
    left join public.merchant_badge_state m on m.profile_id = new.id
    on conflict (id) do update set
      name=excluded.name,avatar_url=excluded.avatar_url,bio=excluded.bio,city=excluded.city,
      is_verified_store=excluded.is_verified_store,is_shop=excluded.is_shop,rating=excluded.rating,
      completed_sales=excluded.completed_sales,reply_speed_label=excluded.reply_speed_label,
      shop_city=excluded.shop_city,shop_address=excluded.shop_address,
      shop_latitude=excluded.shop_latitude,shop_longitude=excluded.shop_longitude,
      shop_verification_status=excluded.shop_verification_status,
      shop_location_url=excluded.shop_location_url,shop_hours=excluded.shop_hours,
      payment_methods=excluded.payment_methods,merchant_badge_level=excluded.merchant_badge_level,
      merchant_sales_count=excluded.merchant_sales_count,merchant_rating=excluded.merchant_rating;
    return new;
  end if;

  if tg_op = 'DELETE' then
    delete from public.public_seller_cards where id = old.profile_id;
    return old;
  end if;

  insert into public.public_seller_cards (
    id,name,avatar_url,bio,city,is_verified_store,is_shop,rating,completed_sales,
    reply_speed_label,shop_city,shop_address,shop_latitude,shop_longitude,
    shop_verification_status,shop_location_url,shop_hours,payment_methods,
    merchant_badge_level,merchant_sales_count,merchant_rating
  )
  select
    p.id,p.name,p.avatar_url,p.bio,p.city,coalesce(p.is_verified_store,false),
    coalesce(p.is_shop,false),p.rating,coalesce(p.completed_sales,0),p.reply_speed_label,
    p.shop_city,p.shop_address,p.shop_latitude,p.shop_longitude,p.shop_verification_status,
    p.shop_location_url,p.shop_hours,p.payment_methods,coalesce(new.current_level,0),
    coalesce(new.completed_sales,p.completed_sales,0),coalesce(new.rating,p.rating,0::numeric)
  from public.profiles p
  where p.id = new.profile_id
  on conflict (id) do update set
    merchant_badge_level=excluded.merchant_badge_level,
    merchant_sales_count=excluded.merchant_sales_count,
    merchant_rating=excluded.merchant_rating;
  return new;
end;
$$;

revoke all on function private.sync_public_seller_card() from public, anon, authenticated;

drop trigger if exists trg_sync_public_seller_card_profile on public.profiles;
create trigger trg_sync_public_seller_card_profile
after insert or update or delete on public.profiles
for each row execute function private.sync_public_seller_card();

drop trigger if exists trg_sync_public_seller_card_badge on public.merchant_badge_state;
create trigger trg_sync_public_seller_card_badge
after insert or update or delete on public.merchant_badge_state
for each row execute function private.sync_public_seller_card();

insert into public.public_seller_cards (
  id,name,avatar_url,bio,city,is_verified_store,is_shop,rating,completed_sales,
  reply_speed_label,shop_city,shop_address,shop_latitude,shop_longitude,
  shop_verification_status,shop_location_url,shop_hours,payment_methods,
  merchant_badge_level,merchant_sales_count,merchant_rating
)
select
  p.id,p.name,p.avatar_url,p.bio,p.city,coalesce(p.is_verified_store,false),
  coalesce(p.is_shop,false),p.rating,coalesce(p.completed_sales,0),p.reply_speed_label,
  p.shop_city,p.shop_address,p.shop_latitude,p.shop_longitude,p.shop_verification_status,
  p.shop_location_url,p.shop_hours,p.payment_methods,coalesce(m.current_level,0),
  coalesce(m.completed_sales,p.completed_sales,0),coalesce(m.rating,p.rating,0::numeric)
from public.profiles p
left join public.merchant_badge_state m on m.profile_id = p.id
on conflict (id) do update set
  name=excluded.name,avatar_url=excluded.avatar_url,bio=excluded.bio,city=excluded.city,
  is_verified_store=excluded.is_verified_store,is_shop=excluded.is_shop,rating=excluded.rating,
  completed_sales=excluded.completed_sales,reply_speed_label=excluded.reply_speed_label,
  shop_city=excluded.shop_city,shop_address=excluded.shop_address,
  shop_latitude=excluded.shop_latitude,shop_longitude=excluded.shop_longitude,
  shop_verification_status=excluded.shop_verification_status,
  shop_location_url=excluded.shop_location_url,shop_hours=excluded.shop_hours,
  payment_methods=excluded.payment_methods,merchant_badge_level=excluded.merchant_badge_level,
  merchant_sales_count=excluded.merchant_sales_count,merchant_rating=excluded.merchant_rating;

create or replace function public.get_seller_contact(seller_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare result jsonb;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select jsonb_build_object('phone',p.phone,'whatsapp',p.whatsapp)
  into result
  from public.profiles p
  where p.id=seller_id;
  return coalesce(result,'{}'::jsonb);
end;
$$;

revoke execute on function public.get_seller_contact(uuid) from public, anon;
grant execute on function public.get_seller_contact(uuid) to authenticated;

revoke execute on function public.handle_new_user() from public, anon, authenticated;
revoke execute on function public.increment_view_count(uuid) from public, anon, authenticated;
revoke execute on function public.recalculate_merchant_badges(uuid) from public, anon, authenticated;
revoke execute on function public.is_admin() from public, anon;
grant execute on function public.is_admin() to authenticated;

create or replace function public.storage_object_exists(p_bucket text,p_name text)
returns boolean
language sql
stable
security definer
set search_path=''
as $$
  select public.is_admin()
  and exists (
    select 1 from storage.objects o
    where o.bucket_id=p_bucket and o.name=p_name
  );
$$;

revoke execute on function public.storage_object_exists(text,text) from public, anon;
grant execute on function public.storage_object_exists(text,text) to authenticated;

revoke insert, update, delete on table public.listings from anon;
grant select on table public.listings to anon;
grant select, insert, update, delete on table public.listings to authenticated;
