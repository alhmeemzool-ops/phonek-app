-- Align admin RLS with the same server-side helper used by monitoring.
-- The known admin account is also accepted when its profile row has not yet
-- been created; the existing profile flag remains the preferred source.
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    coalesce((select is_admin from public.profiles where id = auth.uid()), false)
    or lower(coalesce(auth.jwt() ->> 'email', '')) = 'alhmeemzool@gmail.com';
$$;

revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to authenticated;

-- Keep shop applications readable by the applicant and by admins, and allow
-- applicants to submit their own application. Admin updates remain protected.
do $$
begin
  if to_regclass('public.shop_applications') is not null then
    drop policy if exists "shop_applications_owner_select" on public.shop_applications;
    create policy "shop_applications_owner_select"
      on public.shop_applications for select to authenticated
      using (auth.uid() = user_id or public.is_admin());

    drop policy if exists "shop_applications_owner_insert" on public.shop_applications;
    create policy "shop_applications_owner_insert"
      on public.shop_applications for insert to authenticated
      with check (auth.uid() = user_id);

    drop policy if exists "shop_applications_admin_update" on public.shop_applications;
    create policy "shop_applications_admin_update"
      on public.shop_applications for update to authenticated
      using (public.is_admin())
      with check (public.is_admin());
  end if;
end $$;

-- Refresh PostgREST after the policy/function changes.
notify pgrst, 'reload schema';
