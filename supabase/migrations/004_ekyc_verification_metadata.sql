alter table public.shop_applications
  add column if not exists kyc_provider text,
  add column if not exists kyc_session_id text,
  add column if not exists kyc_result text not null default 'pending',
  add column if not exists kyc_verified_at timestamptz,
  add column if not exists location_accuracy_m double precision,
  add column if not exists consented_at timestamptz;

alter table public.shop_applications
  drop constraint if exists shop_applications_kyc_result_check;

alter table public.shop_applications
  add constraint shop_applications_kyc_result_check
  check (kyc_result in ('pending','approved','rejected','review'));

create index if not exists shop_applications_kyc_session_idx
  on public.shop_applications(kyc_session_id);

comment on column public.shop_applications.kyc_session_id is
  'Provider session/reference only. Never store raw biometric templates or faceprints here.';
comment on column public.shop_applications.kyc_result is
  'Server-verified eKYC result. Client capture alone must never set this to approved.';
