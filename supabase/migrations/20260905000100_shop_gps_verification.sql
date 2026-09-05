-- Store evidence that a shop location was captured from the device GPS.
alter table public.profiles
  add column if not exists shop_location_accuracy_m double precision,
  add column if not exists shop_location_captured_at timestamptz;

alter table public.shop_verification_requests
  add column if not exists location_accuracy_m double precision,
  add column if not exists location_captured_at timestamptz;

alter table public.shop_verification_requests
  drop constraint if exists shop_location_accuracy_check;
alter table public.shop_verification_requests
  add constraint shop_location_accuracy_check
  check (location_accuracy_m is null or (location_accuracy_m >= 0 and location_accuracy_m <= 50));

create index if not exists profiles_shop_location_captured_idx
  on public.profiles (shop_location_captured_at desc);
