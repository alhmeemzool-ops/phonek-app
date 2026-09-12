-- Ensure the configured PhoneK administrator is represented in the profile role.
-- This is intentionally idempotent and keeps authorization server-side.
-- Define the helper first because the profiles protection trigger calls it.
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public, auth
as $$
  select coalesce(
    (select p.is_admin = true from public.profiles p where p.id = auth.uid()),
    false
  )
  or coalesce((auth.jwt() -> 'app_metadata' ->> 'role'), '') = 'admin'
  or lower(coalesce((select u.email from auth.users u where u.id = auth.uid()), ''))
       = 'alhmeemzool@gmail.com';
$$;

revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to authenticated;

-- The existing protection trigger intentionally rejects role changes made by
-- an end-user session. This migration runs as the database owner, so suspend
-- user triggers only for this idempotent bootstrap update and restore them
-- before completing the migration.
alter table public.profiles disable trigger user;
update public.profiles p
set is_admin = true
from auth.users u
where p.id = u.id
  and lower(coalesce(u.email, '')) = 'alhmeemzool@gmail.com'
  and p.is_admin is distinct from true;
alter table public.profiles enable trigger user;

notify pgrst, 'reload schema';
