-- Keep the dashboard's authenticated admin account aligned with DB-side RLS.
-- This is intentionally a narrow compatibility migration for the existing PhoneK admin.
update public.profiles p
set is_admin = true
from auth.users u
where p.id = u.id
  and lower(coalesce(u.email, '')) = 'alhmeemzool@gmail.com';

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    coalesce((select is_admin from public.profiles where id = auth.uid()), false)
    or lower(coalesce((select email from auth.users where id = auth.uid()), '')) = 'alhmeemzool@gmail.com';
$$;

revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to authenticated;

-- Refresh PostgREST's schema cache after migrations are applied.
notify pgrst, 'reload schema';
