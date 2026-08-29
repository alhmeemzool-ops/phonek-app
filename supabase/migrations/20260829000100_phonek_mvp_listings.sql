-- PhoneK MVP: profiles, listings, and listing image storage.
-- Apply this migration in the linked Supabase project before using production data.

create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null default 'مستخدم PhoneK',
  phone text,
  whatsapp text,
  bio text,
  avatar_url text,
  city text,
  is_shop boolean not null default false,
  is_verified_store boolean not null default false,
  rating numeric(2,1) not null default 0 check (rating >= 0 and rating <= 5),
  completed_sales integer not null default 0 check (completed_sales >= 0),
  reply_speed_label text not null default 'يرد عادة خلال ساعات',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.listings (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid not null references public.profiles(id) on delete cascade,
  title text not null check (char_length(trim(title)) between 2 and 120),
  brand text not null check (char_length(trim(brand)) between 1 and 60),
  price integer not null default 0 check (price >= 0),
  price_is_negotiable boolean not null default true,
  price_on_call boolean not null default false,
  old_price integer check (old_price is null or old_price >= 0),
  storage text not null default '',
  ram text not null default '',
  battery_health_percent integer check (battery_health_percent is null or battery_health_percent between 1 and 100),
  condition text not null default 'excellent' check (condition in ('newDevice', 'new', 'excellent', 'minorScratches', 'minor_scratches', 'cracked')),
  damage_notes text,
  has_box boolean not null default false,
  has_charger boolean not null default false,
  has_invoice boolean not null default false,
  has_earphones boolean not null default false,
  warranty text not null default 'none' check (warranty in ('none', 'storeWarranty', 'store_warranty', 'agentWarranty', 'agent_warranty')),
  city text not null default '',
  image_urls jsonb not null default '[]'::jsonb,
  status text not null default 'pendingReview' check (status in ('active', 'sold', 'frozen', 'expired', 'pendingReview', 'pending_review')),
  description text not null default '',
  view_count integer not null default 0 check (view_count >= 0),
  is_featured boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists listings_status_created_at_idx
  on public.listings (status, created_at desc);
create index if not exists listings_seller_id_idx
  on public.listings (seller_id);

alter table public.profiles enable row level security;
alter table public.listings enable row level security;

-- Profiles are public enough for seller cards, but only the owner can write them.
drop policy if exists profiles_select_public on public.profiles;
create policy profiles_select_public on public.profiles
  for select using (true);

drop policy if exists profiles_insert_own on public.profiles;
create policy profiles_insert_own on public.profiles
  for insert with check (auth.uid() = id);

drop policy if exists profiles_update_own on public.profiles;
create policy profiles_update_own on public.profiles
  for update using (auth.uid() = id) with check (auth.uid() = id);

-- Active listings are public. Sellers can manage only their own listings.
drop policy if exists listings_select_active_or_own on public.listings;
create policy listings_select_active_or_own on public.listings
  for select using (status = 'active' or auth.uid() = seller_id);

drop policy if exists listings_insert_own on public.listings;
create policy listings_insert_own on public.listings
  for insert with check (auth.uid() = seller_id);

drop policy if exists listings_update_own on public.listings;
create policy listings_update_own on public.listings
  for update using (auth.uid() = seller_id) with check (auth.uid() = seller_id);

drop policy if exists listings_delete_own on public.listings;
create policy listings_delete_own on public.listings
  for delete using (auth.uid() = seller_id);

insert into storage.buckets (id, name, public)
values ('listing-images', 'listing-images', true)
on conflict (id) do update set public = excluded.public;

-- Every uploaded object must live under the authenticated user's UUID directory.
drop policy if exists listing_images_public_read on storage.objects;
create policy listing_images_public_read on storage.objects
  for select using (bucket_id = 'listing-images');

drop policy if exists listing_images_insert_own on storage.objects;
create policy listing_images_insert_own on storage.objects
  for insert with check (
    bucket_id = 'listing-images'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

drop policy if exists listing_images_update_own on storage.objects;
create policy listing_images_update_own on storage.objects
  for update using (
    bucket_id = 'listing-images'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

drop policy if exists listing_images_delete_own on storage.objects;
create policy listing_images_delete_own on storage.objects
  for delete using (
    bucket_id = 'listing-images'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

create or replace function public.set_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

drop trigger if exists listings_set_updated_at on public.listings;
create trigger listings_set_updated_at
  before update on public.listings
  for each row execute function public.set_updated_at();

-- Create a profile row for new authenticated users without trusting client-supplied IDs.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, name)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', new.email, 'مستخدم PhoneK')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
