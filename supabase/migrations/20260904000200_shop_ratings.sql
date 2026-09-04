-- PhoneK: verified-shop ratings.
-- Apply this migration in Supabase before using production ratings.

alter table public.profiles
  add column if not exists rating_count integer not null default 0;

create table if not exists public.shop_ratings (
  shop_id uuid not null references public.profiles(id) on delete cascade,
  reviewer_id uuid not null references auth.users(id) on delete cascade,
  stars integer not null check (stars between 1 and 5),
  comment text check (comment is null or char_length(trim(comment)) <= 300),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (shop_id, reviewer_id),
  check (shop_id <> reviewer_id)
);

create index if not exists shop_ratings_shop_id_idx
  on public.shop_ratings (shop_id, created_at desc);

alter table public.shop_ratings enable row level security;

drop policy if exists shop_ratings_select_public on public.shop_ratings;
create policy shop_ratings_select_public on public.shop_ratings
  for select using (true);

drop policy if exists shop_ratings_insert_own on public.shop_ratings;
create policy shop_ratings_insert_own on public.shop_ratings
  for insert with check (auth.uid() = reviewer_id);

drop policy if exists shop_ratings_update_own on public.shop_ratings;
create policy shop_ratings_update_own on public.shop_ratings
  for update using (auth.uid() = reviewer_id) with check (auth.uid() = reviewer_id);

drop policy if exists shop_ratings_delete_own on public.shop_ratings;
create policy shop_ratings_delete_own on public.shop_ratings
  for delete using (auth.uid() = reviewer_id);

create or replace function public.refresh_shop_rating(p_shop_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.profiles
  set rating = coalesce((select round(avg(stars)::numeric, 1) from public.shop_ratings where shop_id = p_shop_id), 0),
      rating_count = (select count(*) from public.shop_ratings where shop_id = p_shop_id),
      updated_at = now()
  where id = p_shop_id;
end;
$$;

create or replace function public.sync_shop_rating_profile()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.refresh_shop_rating(coalesce(new.shop_id, old.shop_id));
  if tg_op = 'UPDATE' and new.shop_id <> old.shop_id then
    perform public.refresh_shop_rating(old.shop_id);
  end if;
  return coalesce(new, old);
end;
$$;

drop trigger if exists shop_ratings_sync_profile on public.shop_ratings;
create trigger shop_ratings_sync_profile
after insert or update or delete on public.shop_ratings
for each row execute function public.sync_shop_rating_profile();

update public.profiles p
set rating = coalesce((select round(avg(r.stars)::numeric, 1) from public.shop_ratings r where r.shop_id = p.id), 0),
    rating_count = (select count(*) from public.shop_ratings r where r.shop_id = p.id)
where p.is_shop = true;
