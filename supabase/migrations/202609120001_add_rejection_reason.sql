-- PhoneK: store an optional reason when an admin rejects a listing.
-- Safe for existing listings because the new column is nullable.
alter table public.listings
  add column if not exists rejection_reason text;

-- Ask PostgREST to refresh its schema cache after the table change.
notify pgrst, 'reload schema';
