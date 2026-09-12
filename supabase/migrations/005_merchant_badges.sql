-- PhoneK merchant badge system.
-- Rules are monotonic: a merchant never loses an earned badge level.
-- Sales are sourced from profiles.completed_sales until a dedicated order
-- ledger is introduced. Identity/license status is verified from
-- shop_applications on the server.

alter table public.shop_applications
  add column if not exists license_document_url text,
  add column if not exists license_verification_status text not null default 'pending',
  add column if not exists license_verified_at timestamptz;

alter table public.shop_applications
  drop constraint if exists shop_applications_license_verification_status_check;

alter table public.shop_applications
  add constraint shop_applications_license_verification_status_check
  check (license_verification_status in ('pending','approved','rejected'));

create table if not exists public.merchant_badge_definitions (
  level integer primary key check (level between 1 and 10),
  name_ar text not null,
  name_en text not null,
  description_ar text not null,
  required_sales integer not null check (required_sales >= 0),
  min_rating numeric(3,2),
  requires_identity boolean not null default false,
  requires_license boolean not null default false,
  asset_path text not null,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

insert into public.merchant_badge_definitions
  (level, name_ar, name_en, description_ar, required_sales, min_rating, requires_identity, requires_license, asset_path)
values
  (1, 'بائع مبتدئ', 'Novice', 'يُمنح بمجرد تفعيل حساب التاجر بالهوية الشخصية، حتى مع 0 طلب.', 0, null, true, false, 'assets/badges/badge_level1.svg'),
  (2, 'بائع ناشئ', 'Emerging', 'إكمال 15 طلباً ناجحاً.', 15, null, true, false, 'assets/badges/badge_level2.svg'),
  (3, 'بائع صاعد', 'Rising', 'إكمال 40 طلباً ناجحاً.', 40, null, true, false, 'assets/badges/badge_level3.svg'),
  (4, 'بائع موثوق', 'Verified', 'إكمال 80 طلباً ناجحاً مع تقديم وتوثيق رخصة المحل الرسمية.', 80, null, true, true, 'assets/badges/badge_level4.svg'),
  (5, 'بائع متميز', 'Star', 'إكمال 150 طلباً ناجحاً مع تقييم عام أعلى من 4.2 نجمة.', 150, 4.20, true, false, 'assets/badges/badge_level5.svg'),
  (6, 'بائع محترف', 'Pro', 'إكمال 300 طلب ناجح.', 300, null, true, false, 'assets/badges/badge_level6.svg'),
  (7, 'بائع خبير', 'Expert', 'إكمال 600 طلب ناجح.', 600, null, true, false, 'assets/badges/badge_level7.svg'),
  (8, 'بائع نخبة', 'Elite', 'إكمال 1,200 طلب ناجح.', 1200, null, true, false, 'assets/badges/badge_level8.svg'),
  (9, 'بائع معتمد', 'Master', 'إكمال 2,500 طلب ناجح.', 2500, null, true, false, 'assets/badges/badge_level9.svg'),
  (10, 'تاجر أسطوري', 'Legendary', 'إكمال 5,000 طلب ناجح أو أكثر.', 5000, null, true, false, 'assets/badges/badge_level10.svg')
on conflict (level) do update set
  name_ar = excluded.name_ar,
  name_en = excluded.name_en,
  description_ar = excluded.description_ar,
  required_sales = excluded.required_sales,
  min_rating = excluded.min_rating,
  requires_identity = excluded.requires_identity,
  requires_license = excluded.requires_license,
  asset_path = excluded.asset_path,
  active = true;

create table if not exists public.merchant_badge_state (
  profile_id uuid primary key references public.profiles(id) on delete cascade,
  current_level integer not null default 0 check (current_level between 0 and 10),
  eligible_level integer not null default 0 check (eligible_level between 0 and 10),
  completed_sales integer not null default 0 check (completed_sales >= 0),
  rating numeric(3,2) not null default 0 check (rating between 0 and 5),
  identity_verified boolean not null default false,
  license_verified boolean not null default false,
  updated_at timestamptz not null default now()
);

create table if not exists public.merchant_badge_awards (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  badge_level integer not null references public.merchant_badge_definitions(level),
  sales_at_award integer not null default 0,
  awarded_at timestamptz not null default now(),
  source text not null default 'automatic',
  metadata jsonb not null default '{}'::jsonb,
  unique(profile_id, badge_level)
);

create index if not exists merchant_badge_awards_profile_idx
  on public.merchant_badge_awards(profile_id, badge_level);

alter table public.merchant_badge_definitions enable row level security;
alter table public.merchant_badge_state enable row level security;
alter table public.merchant_badge_awards enable row level security;

drop policy if exists "merchant_badge_definitions_read" on public.merchant_badge_definitions;
create policy "merchant_badge_definitions_read"
on public.merchant_badge_definitions for select
to anon, authenticated
using (active = true);

drop policy if exists "merchant_badge_state_read" on public.merchant_badge_state;
create policy "merchant_badge_state_read"
on public.merchant_badge_state for select
to authenticated
using (true);

drop policy if exists "merchant_badge_awards_read" on public.merchant_badge_awards;
create policy "merchant_badge_awards_read"
on public.merchant_badge_awards for select
to authenticated
using (true);

-- No client INSERT/UPDATE/DELETE policies are provided. Badge state and
-- award history are written only by the SECURITY DEFINER recalculation RPC.

create or replace function public.recalculate_merchant_badges(p_profile_id uuid)
returns public.merchant_badge_state
language plpgsql
security definer
set search_path = public
as $$
declare
  profile_row public.profiles%rowtype;
  latest_application public.shop_applications%rowtype;
  sales_count integer := 0;
  merchant_rating numeric(3,2) := 0;
  identity_ok boolean := false;
  license_ok boolean := false;
  candidate_level integer := 0;
  previous_level integer := 0;
  final_level integer := 0;
  result_row public.merchant_badge_state%rowtype;
begin
  select * into profile_row from public.profiles where id = p_profile_id;
  if not found then
    raise exception 'Profile not found';
  end if;

  sales_count := greatest(coalesce((to_jsonb(profile_row)->>'completed_sales')::integer, 0), 0);
  merchant_rating := least(greatest(coalesce((to_jsonb(profile_row)->>'rating')::numeric, 0), 0), 5);

  select * into latest_application
  from public.shop_applications
  where user_id = p_profile_id
  order by created_at desc
  limit 1;

  identity_ok := coalesce(latest_application.kyc_result = 'approved', false);
  license_ok := coalesce(latest_application.license_verification_status = 'approved', false);

  if identity_ok then candidate_level := 1; end if;
  if identity_ok and sales_count >= 15 then candidate_level := 2; end if;
  if identity_ok and sales_count >= 40 then candidate_level := 3; end if;
  if identity_ok and sales_count >= 80 and license_ok then candidate_level := 4; end if;
  if identity_ok and sales_count >= 150 and merchant_rating > 4.20 then candidate_level := 5; end if;
  if identity_ok and sales_count >= 300 then candidate_level := 6; end if;
  if identity_ok and sales_count >= 600 then candidate_level := 7; end if;
  if identity_ok and sales_count >= 1200 then candidate_level := 8; end if;
  if identity_ok and sales_count >= 2500 then candidate_level := 9; end if;
  if identity_ok and sales_count >= 5000 then candidate_level := 10; end if;

  select current_level into previous_level
  from public.merchant_badge_state
  where profile_id = p_profile_id;

  final_level := greatest(coalesce(previous_level, 0), candidate_level);

  insert into public.merchant_badge_state
    (profile_id, current_level, eligible_level, completed_sales, rating, identity_verified, license_verified, updated_at)
  values
    (p_profile_id, final_level, candidate_level, sales_count, merchant_rating, identity_ok, license_ok, now())
  on conflict (profile_id) do update set
    current_level = greatest(public.merchant_badge_state.current_level, excluded.current_level),
    eligible_level = excluded.eligible_level,
    completed_sales = excluded.completed_sales,
    rating = excluded.rating,
    identity_verified = excluded.identity_verified,
    license_verified = excluded.license_verified,
    updated_at = now();

  insert into public.merchant_badge_awards (profile_id, badge_level, sales_at_award, source, metadata)
  select p_profile_id, d.level, sales_count, 'automatic',
         jsonb_build_object('identity_verified', identity_ok, 'license_verified', license_ok, 'rating', merchant_rating)
  from public.merchant_badge_definitions d
  where d.active = true
    and d.level <= final_level
  on conflict (profile_id, badge_level) do nothing;

  select * into result_row
  from public.merchant_badge_state
  where profile_id = p_profile_id;

  return result_row;
end;
$$;

revoke all on function public.recalculate_merchant_badges(uuid) from public, anon, authenticated;
grant execute on function public.recalculate_merchant_badges(uuid) to service_role;

drop function if exists public.trg_recalculate_merchant_badges();
create or replace function public.trg_recalculate_merchant_badges()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.recalculate_merchant_badges(coalesce(new.id, new.user_id));
  return new;
end;
$$;

revoke all on function public.trg_recalculate_merchant_badges() from public, anon, authenticated;
grant execute on function public.trg_recalculate_merchant_badges() to service_role;

drop trigger if exists profiles_badge_recalculate on public.profiles;
create trigger profiles_badge_recalculate
after insert or update of completed_sales
on public.profiles
for each row execute function public.trg_recalculate_merchant_badges();

drop trigger if exists shop_application_badge_recalculate on public.shop_applications;
create trigger shop_application_badge_recalculate
after insert or update of kyc_result, license_verification_status
on public.shop_applications
for each row execute function public.trg_recalculate_merchant_badges();

-- Backfill all existing profiles without changing any already-earned level.
do $$
declare r record;
begin
  for r in select id from public.profiles loop
    perform public.recalculate_merchant_badges(r.id);
  end loop;
end;
$$;

comment on table public.merchant_badge_state is 'Current merchant badge state. current_level is monotonic and never decreases.';
comment on table public.merchant_badge_awards is 'Immutable history of earned merchant badge levels.';
comment on column public.merchant_badge_state.eligible_level is 'Level currently justified by live conditions; current_level can remain higher because badges never downgrade.';
