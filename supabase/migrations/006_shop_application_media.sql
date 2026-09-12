-- Secure media references for merchant application review.
-- Files must be uploaded to a PRIVATE Supabase Storage bucket by the client/server flow;
-- these columns store object paths only, never public URLs or raw biometric templates.
alter table public.shop_applications
  add column if not exists face_photo_path text,
  add column if not exists liveness_video_path text,
  add column if not exists identity_photo_path text,
  add column if not exists reviewed_by uuid,
  add column if not exists reviewed_at timestamptz,
  add column if not exists rejection_reason text;

create index if not exists shop_applications_status_idx
  on public.shop_applications(verification_status);

create index if not exists shop_applications_user_idx
  on public.shop_applications(user_id);

comment on column public.shop_applications.face_photo_path is 'Private Storage object path; access must be admin-only.';
comment on column public.shop_applications.liveness_video_path is 'Private Storage object path; access must be admin-only.';
comment on column public.shop_applications.identity_photo_path is 'Private Storage object path; access must be admin-only.';
