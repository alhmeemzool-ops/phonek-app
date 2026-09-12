-- PhoneK: store an optional reason when an admin rejects a listing.
alter table public.listings
  add column if not exists rejection_reason text;

notify pgrst, 'reload schema';
