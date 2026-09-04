-- Allow sellers and buyers to leave the device condition unspecified.
alter table public.listings
drop constraint if exists listings_condition_check;

alter table public.listings
add constraint listings_condition_check check (
  condition in (
    'none',
    'newDevice',
    'new',
    'excellent',
    'minorScratches',
    'minor_scratches',
    'cracked'
  )
);

alter table public.listings
alter column storage set default '',
alter column ram set default '';

-- Keep existing rows valid while making the new state available to new listings.
update public.listings
set storage = ''
where storage is null;

update public.listings
set ram = ''
where ram is null;

update public.listings
set condition = 'none'
where condition is null or trim(condition) = '';

alter table public.listings
alter column storage set not null,
alter column ram set not null,
alter column condition set not null;

-- The old insert/update policies already permit the owner to write these values.
-- Run this migration in the linked Supabase project before publishing listings with none.

-- End of migration.
