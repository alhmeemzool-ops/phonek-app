-- PhoneK: merchant stats, subscriptions, documents, and reports.

create table if not exists public.listing_events (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.listings(id) on delete cascade,
  seller_id uuid not null references auth.users(id) on delete cascade,
  actor_id uuid references auth.users(id) on delete set null,
  event_type text not null check (event_type in ('view','favorite','contact')),
  created_at timestamptz not null default now()
);
create index if not exists listing_events_listing_created_idx on public.listing_events(listing_id, created_at desc);
alter table public.listing_events enable row level security;
drop policy if exists listing_events_seller_read on public.listing_events;
create policy listing_events_seller_read on public.listing_events for select to authenticated using (auth.uid() = seller_id);

create or replace function public.record_listing_event(p_listing_id uuid, p_event_type text)
returns void language plpgsql security definer set search_path = ''
as $$
declare sid uuid; aid uuid;
begin
  if p_event_type not in ('view','favorite','contact') then raise exception 'invalid event'; end if;
  select seller_id into sid from public.listings where id = p_listing_id;
  aid := auth.uid();
  if sid is null or aid = sid then return; end if;
  if aid is not null and exists (select 1 from public.listing_events where listing_id = p_listing_id and actor_id = aid and event_type = p_event_type and created_at >= date_trunc('day', now())) then return; end if;
  insert into public.listing_events(listing_id, seller_id, actor_id, event_type) values (p_listing_id, sid, aid, p_event_type);
end;
$$;
revoke all on function public.record_listing_event(uuid, text) from public, anon;
grant execute on function public.record_listing_event(uuid, text) to authenticated;

create table if not exists public.shop_subscriptions (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending','active','rejected','ended')),
  requested_at timestamptz not null default now(),
  starts_at timestamptz,
  ends_at timestamptz,
  payment_proof_path text,
  document_path text,
  reviewed_by uuid references auth.users(id)
);
alter table public.shop_subscriptions add column if not exists document_path text;
alter table public.shop_subscriptions enable row level security;
drop policy if exists shop_subscriptions_owner_read on public.shop_subscriptions;
create policy shop_subscriptions_owner_read on public.shop_subscriptions for select to authenticated using (auth.uid() = shop_id or public.is_admin());
drop policy if exists shop_subscriptions_owner_insert on public.shop_subscriptions;
create policy shop_subscriptions_owner_insert on public.shop_subscriptions for insert to authenticated with check (auth.uid() = shop_id);
drop policy if exists shop_subscriptions_admin_all on public.shop_subscriptions;
create policy shop_subscriptions_admin_all on public.shop_subscriptions for all to authenticated using (public.is_admin()) with check (public.is_admin());
create or replace view public.public_active_subscriptions as select shop_id from public.shop_subscriptions where status = 'active' and ends_at > now();

create or replace function public.get_merchant_stats(p_days integer default 7)
returns table(listing_id uuid, event_type text, event_count bigint)
language sql stable security definer set search_path = ''
as $$
  select e.listing_id, e.event_type, count(*)::bigint
  from public.listing_events e
  where e.seller_id = auth.uid()
    and e.created_at >= now() - make_interval(days => greatest(1, least(coalesce(p_days, 7), 365)))
  group by e.listing_id, e.event_type
  order by e.listing_id, e.event_type;
$$;
revoke all on function public.get_merchant_stats(integer) from public, anon;
grant execute on function public.get_merchant_stats(integer) to authenticated;

create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references auth.users(id) on delete cascade,
  listing_id uuid references public.listings(id) on delete cascade,
  reported_user_id uuid references auth.users(id) on delete cascade,
  reason text not null check (reason in ('scam','wrong_info','prohibited','harassment','other')),
  details text not null default '',
  status text not null default 'open' check (status in ('open','reviewing','resolved','dismissed')),
  admin_note text,
  reviewed_by uuid references auth.users(id),
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  check (listing_id is not null or reported_user_id is not null)
);
alter table public.reports enable row level security;
drop policy if exists reports_insert_own on public.reports;
create policy reports_insert_own on public.reports for insert to authenticated with check (auth.uid() = reporter_id);
drop policy if exists reports_read_own on public.reports;
create policy reports_read_own on public.reports for select to authenticated using (auth.uid() = reporter_id or public.is_admin());
drop policy if exists reports_admin_update on public.reports;
create policy reports_admin_update on public.reports for update to authenticated using (public.is_admin()) with check (public.is_admin());
create index if not exists reports_status_created_idx on public.reports(status, created_at desc);
