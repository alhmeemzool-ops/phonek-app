-- Ensure chat voice storage exists with the same contract used by the Flutter chat client.
insert into storage.buckets (id,name,public,file_size_limit,allowed_mime_types)
values ('chat-voice','chat-voice',false,2097152,array['audio/mp4','audio/aac','audio/ogg'])
on conflict (id) do update set public=false,file_size_limit=2097152,allowed_mime_types=excluded.allowed_mime_types;

drop policy if exists chat_voice_upload on storage.objects;
create policy chat_voice_upload on storage.objects
for insert to authenticated
with check (
  bucket_id='chat-voice'
  and exists (
    select 1 from public.chat_threads t
    where t.id=(storage.foldername(name))[1]::uuid
      and (t.buyer_id=auth.uid() or t.seller_id=auth.uid())
  )
);

drop policy if exists chat_voice_read on storage.objects;
create policy chat_voice_read on storage.objects
for select to authenticated
using (
  bucket_id='chat-voice'
  and exists (
    select 1 from public.chat_threads t
    where t.id=(storage.foldername(name))[1]::uuid
      and (t.buyer_id=auth.uid() or t.seller_id=auth.uid())
  )
);
