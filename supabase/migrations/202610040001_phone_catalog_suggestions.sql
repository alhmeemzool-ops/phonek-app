-- Visitor-submitted catalog suggestions. Anonymous visitors may suggest a brand/model;
-- only admins can review or change the moderation status.
create table if not exists public.phone_catalog_suggestions (
  id uuid primary key default gen_random_uuid(),
  brand text,
  model text,
  suggested_by uuid references auth.users(id) on delete set null,
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  created_at timestamptz not null default now()
);

alter table public.phone_catalog_suggestions enable row level security;

create policy "catalog suggestions insert"
on public.phone_catalog_suggestions
for insert
to anon, authenticated
with check (
  length(coalesce(brand,'')) between 1 and 80
  and (model is null or length(model) between 1 and 160)
  and status = 'pending'
);

create policy "catalog suggestions admin read"
on public.phone_catalog_suggestions
for select
to authenticated
using (public.is_admin());

create policy "catalog suggestions admin update"
on public.phone_catalog_suggestions
for update
to authenticated
using (public.is_admin())
with check (public.is_admin());
