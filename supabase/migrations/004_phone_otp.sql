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

create index if not exists phone_otp_phone_created_idx on public.phone_otp_challenges(phone_e164, created_at desc);

alter table public.phone_otp_challenges enable row level security;
drop policy if exists "No direct OTP access" on public.phone_otp_challenges;
create policy "No direct OTP access" on public.phone_otp_challenges for all to authenticated, anon using (false) with check (false);

create table if not exists public.phone_otp_rate_limits (
  key_hash text primary key,
  window_started_at timestamptz not null,
  request_count integer not null default 0
);

alter table public.phone_otp_rate_limits enable row level security;
drop policy if exists "No direct OTP rate limit access" on public.phone_otp_rate_limits;
create policy "No direct OTP rate limit access" on public.phone_otp_rate_limits for all to authenticated, anon using (false) with check (false);

create or replace function public.find_auth_user_by_phone(p_phone text)
returns uuid
language sql
security definer
set search_path = public, auth
stable
as $$
  select id from auth.users where phone = p_phone limit 1;
$$;

create or replace function public.consume_otp_ip_quota(p_key_hash text, p_window_seconds integer default 3600, p_max_requests integer default 10)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  current_row public.phone_otp_rate_limits%rowtype;
  current_time timestamptz := now();
begin
  select * into current_row from public.phone_otp_rate_limits where key_hash = p_key_hash for update;
  if not found then
    insert into public.phone_otp_rate_limits(key_hash, window_started_at, request_count) values (p_key_hash, current_time, 1);
    return true;
  end if;
  if current_time - current_row.window_started_at >= make_interval(secs => p_window_seconds) then
    update public.phone_otp_rate_limits set window_started_at = current_time, request_count = 1 where key_hash = p_key_hash;
    return true;
  end if;
  if current_row.request_count >= p_max_requests then return false; end if;
  update public.phone_otp_rate_limits set request_count = request_count + 1 where key_hash = p_key_hash;
  return true;
end;
$$;

revoke all on table public.phone_otp_challenges from anon, authenticated;
revoke all on table public.phone_otp_rate_limits from anon, authenticated;
revoke all on function public.find_auth_user_by_phone(text) from public, anon, authenticated;
revoke all on function public.consume_otp_ip_quota(text, integer, integer) from public, anon, authenticated;
grant execute on function public.find_auth_user_by_phone(text) to service_role;
grant execute on function public.consume_otp_ip_quota(text, integer, integer) to service_role;

comment on table public.phone_otp_challenges is 'Server-only OTP challenge records; plaintext OTPs are never persisted.';
