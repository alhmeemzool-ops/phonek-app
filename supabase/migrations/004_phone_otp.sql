-- PhoneK: first-party OTP engine for phone verification/login.
-- OTP values are never stored in plaintext. Delivery is handled by the Edge Function.

create extension if not exists pgcrypto;

alter table public.profiles
  add column if not exists phone_verified boolean not null default false;

create table if not exists public.phone_otp_challenges (
  id uuid primary key default gen_random_uuid(),
  phone_e164 text not null,
  code_hash text not null,
  purpose text not null default 'login' check (purpose in ('login', 'verify_phone')),
  attempts integer not null default 0 check (attempts >= 0),
  max_attempts integer not null default 5 check (max_attempts between 1 and 10),
  expires_at timestamptz not null,
  consumed_at timestamptz,
  last_sent_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create index if not exists phone_otp_phone_created_idx
  on public.phone_otp_challenges(phone_e164, created_at desc);

alter table public.phone_otp_challenges enable row level security;

-- OTP rows are server-only. The mobile/web client must use the Edge Function.
drop policy if exists "No direct OTP access" on public.phone_otp_challenges;

create policy "No direct OTP access"
  on public.phone_otp_challenges
  for all
  to authenticated, anon
  using (false)
  with check (false);

create or replace function public.hash_phone_otp(p_code text, p_secret text)
returns text
language sql
immutable
strict
as $$
  select encode(digest(p_secret || ':' || p_code, 'sha256'), 'hex');
$$;

revoke all on table public.phone_otp_challenges from anon, authenticated;
revoke all on function public.hash_phone_otp(text, text) from public, anon, authenticated;

comment on table public.phone_otp_challenges is 'Server-side OTP challenge records; plaintext OTPs are never persisted.';
