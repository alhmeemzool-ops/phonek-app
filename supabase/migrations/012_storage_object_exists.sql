-- Avoid noisy 400 responses when old verification rows point to removed files.
-- Only an approved admin can use this helper, since it checks private objects.
create or replace function public.storage_object_exists(
  p_bucket text,
  p_name text
)
returns boolean
language sql
stable
security definer
set search_path = public, storage, auth
as $$
  select public.is_admin()
    and exists (
      select 1
      from storage.objects o
      where o.bucket_id = p_bucket
        and o.name = p_name
    );
$$;

revoke all on function public.storage_object_exists(text, text) from public, anon, authenticated;
grant execute on function public.storage_object_exists(text, text) to authenticated;

notify pgrst, 'reload schema';
