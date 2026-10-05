-- Allow listing owners to edit their own listing data without granting moderation rights.
-- The existing protect_listing_moderation_fields trigger still prevents owners
-- from changing status/review fields.
drop policy if exists "sellers can update own listings" on public.listings;
create policy "sellers can update own listings"
on public.listings
for update
to authenticated
using (seller_id = auth.uid())
with check (seller_id = auth.uid());

notify pgrst, 'reload schema';
