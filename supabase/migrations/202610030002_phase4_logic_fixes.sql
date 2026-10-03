-- PhoneK Phase 4 logic fixes.

create or replace function public.get_chat_participants(p_thread_id uuid)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  current_user_id uuid := auth.uid();
  other_user_id uuid;
  other_name text;
begin
  if current_user_id is null then raise exception 'Authentication required'; end if;

  select case when t.buyer_id=current_user_id then t.seller_id else t.buyer_id end
  into other_user_id
  from public.chat_threads t
  where t.id=p_thread_id
    and (t.buyer_id=current_user_id or t.seller_id=current_user_id);

  if other_user_id is null then raise exception 'Chat thread not found'; end if;

  select coalesce(nullif(trim(p.name),''),'مستخدم PhoneK')
  into other_name
  from public.profiles p
  where p.id=other_user_id;

  return jsonb_build_object(
    'other_user_id',other_user_id,
    'other_user_name',coalesce(other_name,'مستخدم PhoneK')
  );
end;
$$;

revoke execute on function public.get_chat_participants(uuid) from public,anon;
grant execute on function public.get_chat_participants(uuid) to authenticated;

create or replace function public.increment_listing_view(p_listing_id uuid)
returns void
language sql
security definer
set search_path=''
as $$
  update public.listings
  set view_count=coalesce(view_count,0)+1
  where id=p_listing_id
    and status='active'
    and seller_id is distinct from auth.uid();
$$;

revoke execute on function public.increment_listing_view(uuid) from public;
grant execute on function public.increment_listing_view(uuid) to anon,authenticated;
