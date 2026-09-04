-- Secure shop verification workflow.
-- Admin access is granted only through Supabase Auth app_metadata.role = 'admin'.

alter table public.profiles
  add column if not exists shop_city text,
  add column if not exists shop_address text,
  add column if not exists shop_latitude double precision,
  add column if not exists shop_longitude double precision,
  add column if not exists shop_verification_status text not null default 'none';

alter table public.profiles
drop constraint if exists profiles_shop_verification_status_check;

alter table public.profiles
add constraint profiles_shop_verification_status_check
check (shop_verification_status in ('none', 'pending', 'approved', 'rejected'));

-- Only a trusted Auth app_metadata role can activate or reject a shop.
drop policy if exists profiles_update_admin_verification on public.profiles;
create policy profiles_update_admin_verification on public.profiles
  for update using (coalesce(auth.jwt() -> 'app_metadata' ->> 'role', '') = 'admin')
  with check (coalesce(auth.jwt() -> 'app_metadata' ->> 'role', '') = 'admin');

create or replace function public.protect_shop_verification_fields()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if coalesce(auth.jwt() -> 'app_metadata' ->> 'role', '') <> 'admin' then
    if new.is_shop = true
       or new.shop_verification_status not in ('none', 'pending')
       or (tg_op = 'UPDATE' and new.is_shop is distinct from old.is_shop) then
      raise exception 'Only an approved admin can change shop verification status';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists protect_shop_verification_fields_trigger on public.profiles;
create trigger protect_shop_verification_fields_trigger
  before insert or update on public.profiles
  for each row execute function public.protect_shop_verification_fields();

create table if not exists public.shop_verification_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  shop_name text not null,
  phone text not null,
  city text not null,
  address text not null,
  latitude double precision,
  longitude double precision,
  identity_image_path text not null,
  identity_video_path text not null,
  status text not null default 'pending',
  rejection_reason text,
  reviewed_by uuid references auth.users(id),
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint shop_verification_status_check
    check (status in ('pending', 'approved', 'rejected'))
);

create index if not exists shop_verification_requests_status_created_idx
  on public.shop_verification_requests (status, created_at desc);
create index if not exists shop_verification_requests_user_idx
  on public.shop_verification_requests (user_id, created_at desc);

create table if not exists public.shop_verification_audit (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.shop_verification_requests(id) on delete cascade,
  admin_id uuid not null references auth.users(id),
  action text not null check (action in ('approved', 'rejected')),
  reason text,
  created_at timestamptz not null default now()
);

create index if not exists shop_verification_audit_request_idx
  on public.shop_verification_audit (request_id, created_at desc);

alter table public.shop_verification_requests enable row level security;

alter table public.shop_verification_audit enable row level security;

drop policy if exists shop_verification_audit_admin_only on public.shop_verification_audit;
create policy shop_verification_audit_admin_only on public.shop_verification_audit
  for all using (coalesce(auth.jwt() -> 'app_metadata' ->> 'role', '') = 'admin')
  with check (coalesce(auth.jwt() -> 'app_metadata' ->> 'role', '') = 'admin');

drop policy if exists shop_verification_insert_own on public.shop_verification_requests;
create policy shop_verification_insert_own on public.shop_verification_requests
  for insert with check (auth.uid() = user_id and status = 'pending');

drop policy if exists shop_verification_select_own on public.shop_verification_requests;
create policy shop_verification_select_own on public.shop_verification_requests
  for select using (
    auth.uid() = user_id
    or coalesce(auth.jwt() -> 'app_metadata' ->> 'role', '') = 'admin'
  );

drop policy if exists shop_verification_update_admin on public.shop_verification_requests;
create policy shop_verification_update_admin on public.shop_verification_requests
  for update using (coalesce(auth.jwt() -> 'app_metadata' ->> 'role', '') = 'admin')
  with check (coalesce(auth.jwt() -> 'app_metadata' ->> 'role', '') = 'admin');

-- Keep updated_at correct for review changes.
drop trigger if exists shop_verification_requests_set_updated_at on public.shop_verification_requests;
create trigger shop_verification_requests_set_updated_at
  before update on public.shop_verification_requests
  for each row execute function public.set_updated_at();

insert into storage.buckets (id, name, public)
values ('verification-documents', 'verification-documents', false)
on conflict (id) do update set public = false;

drop policy if exists verification_documents_insert_own on storage.objects;
create policy verification_documents_insert_own on storage.objects
  for insert with check (
    bucket_id = 'verification-documents'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

drop policy if exists verification_documents_select_own_or_admin on storage.objects;
create policy verification_documents_select_own_or_admin on storage.objects
  for select using (
    bucket_id = 'verification-documents'
    and (
      auth.uid()::text = (storage.foldername(name))[1]
      or coalesce(auth.jwt() -> 'app_metadata' ->> 'role', '') = 'admin'
    )
  );

drop policy if exists verification_documents_delete_own_or_admin on storage.objects;
create policy verification_documents_delete_own_or_admin on storage.objects
  for delete using (
    bucket_id = 'verification-documents'
    and (
      auth.uid()::text = (storage.foldername(name))[1]
      or coalesce(auth.jwt() -> 'app_metadata' ->> 'role', '') = 'admin'
    )
  );

-- Admin role must be assigned manually in Supabase Auth app_metadata by a trusted owner.
-- Never accept an admin flag from the client application.
