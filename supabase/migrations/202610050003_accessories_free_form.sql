-- PhoneK accessories: free-form listings and delivery settings.
-- This migration is intentionally not executed automatically.

alter table public.accessories
  alter column category drop not null,
  alter column price drop not null;

alter table public.accessories
  drop constraint if exists accessories_category_check;

alter table public.accessories
  drop constraint if exists accessories_price_check;

alter table public.accessories
  add column if not exists delivery_scope text not null default 'all_states'
    check (delivery_scope in ('all_states', 'within_state')),
  add column if not exists delivery_fee_payer text not null default 'free'
    check (delivery_fee_payer in ('free', 'buyer'));

update public.accessories
set category = null
where category is not null;

update public.accessories
set price = null
where price = 0;

create index if not exists accessories_city_status_created_idx
  on public.accessories(city, status, created_at desc);
