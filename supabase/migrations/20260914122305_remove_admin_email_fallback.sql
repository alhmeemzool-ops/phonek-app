-- Admin authorization is derived only from the profile flag or JWT app_metadata role.
-- The prerequisite admin verification was completed before applying this migration.
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (select p.is_admin = true from public.profiles p where p.id = auth.uid()),
    false
  )
  or coalesce((auth.jwt() -> 'app_metadata' ->> 'role'), '') = 'admin';
$$;
