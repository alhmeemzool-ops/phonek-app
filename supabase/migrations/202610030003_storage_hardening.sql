-- PhoneK storage hardening.
-- listing-images: public read, authenticated owner-only upload/delete, max 3 MiB.
-- verification-documents: authenticated owner/admin write access only.

update storage.buckets
set file_size_limit=3145728,
    allowed_mime_types=array['image/jpeg','image/png','image/webp']
where id='listing-images';

drop policy if exists "Authenticated users upload own listing images" on storage.objects;
create policy "Authenticated users upload own listing images"
on storage.objects for insert
to authenticated
with check (
  bucket_id='listing-images'
  and (storage.foldername(name))[1]=(select auth.uid()::text)
);

drop policy if exists "Users delete own listing images" on storage.objects;
create policy "Users delete own listing images"
on storage.objects for delete
to authenticated
using (
  bucket_id='listing-images'
  and (storage.foldername(name))[1]=(select auth.uid()::text)
);

drop policy if exists verification_documents_insert_own on storage.objects;
create policy verification_documents_insert_own
on storage.objects for insert
to authenticated
with check (
  bucket_id='verification-documents'
  and (storage.foldername(name))[1]=(select auth.uid()::text)
);

drop policy if exists verification_documents_delete_own_or_admin on storage.objects;
create policy verification_documents_delete_own_or_admin
on storage.objects for delete
to authenticated
using (
  bucket_id='verification-documents'
  and (
    (storage.foldername(name))[1]=(select auth.uid()::text)
    or public.is_admin()
  )
);
