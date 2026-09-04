-- Allow sellers and buyers to leave the device condition unspecified.
-- The database may use a device_condition enum that does not contain a `none` value.
-- Therefore the UI label is "غير محدد" and the persisted value is NULL.

alter table public.listings
  alter column storage set default '',
  alter column ram set default '';

update public.listings
set storage = ''
where storage is null;

update public.listings
set ram = ''
where ram is null;

alter table public.listings
  alter column storage set not null,
  alter column ram set not null,
  alter column condition drop not null;

-- Existing valid condition enum/text values remain unchanged.
-- An unspecified condition is stored as NULL, never as the string `none`.
