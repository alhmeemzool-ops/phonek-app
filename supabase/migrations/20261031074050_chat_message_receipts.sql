-- WhatsApp-style chat delivery/read receipts.
-- The RPCs are intentionally narrow: a participant can only advance the
-- status of messages sent by the other participant, and only forward.

create or replace function public.mark_chat_message_delivered(p_message_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_sender uuid;
  v_thread uuid;
begin
  if auth.uid() is null then
    raise exception 'غير مصرح';
  end if;

  select m.sender_id, m.thread_id
    into v_sender, v_thread
  from public.chat_messages m
  where m.id = p_message_id;

  if v_sender is null or v_thread is null then
    return;
  end if;

  if v_sender = auth.uid() then
    return;
  end if;

  if not exists (
    select 1
    from public.chat_threads t
    where t.id = v_thread
      and (t.buyer_id = auth.uid() or t.seller_id = auth.uid())
  ) then
    raise exception 'غير مصرح';
  end if;

  update public.chat_messages
     set status = 'delivered'
   where id = p_message_id
     and sender_id <> auth.uid()
     and status = 'sent';
end;
$$;

create or replace function public.mark_chat_message_read(p_message_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_sender uuid;
  v_thread uuid;
begin
  if auth.uid() is null then
    raise exception 'غير مصرح';
  end if;

  select m.sender_id, m.thread_id
    into v_sender, v_thread
  from public.chat_messages m
  where m.id = p_message_id;

  if v_sender is null or v_thread is null then
    return;
  end if;

  if v_sender = auth.uid() then
    return;
  end if;

  if not exists (
    select 1
    from public.chat_threads t
    where t.id = v_thread
      and (t.buyer_id = auth.uid() or t.seller_id = auth.uid())
  ) then
    raise exception 'غير مصرح';
  end if;

  update public.chat_messages
     set status = 'read'
   where id = p_message_id
     and sender_id <> auth.uid()
     and status in ('sent', 'delivered');
end;
$$;

revoke all on function public.mark_chat_message_delivered(uuid) from public, anon;
revoke all on function public.mark_chat_message_read(uuid) from public, anon;
grant execute on function public.mark_chat_message_delivered(uuid) to authenticated;
grant execute on function public.mark_chat_message_read(uuid) to authenticated;
