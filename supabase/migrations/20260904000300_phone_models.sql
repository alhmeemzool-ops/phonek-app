-- PhoneK: shared custom phone models.
-- Apply this migration in Supabase before using custom model persistence.

create table if not exists public.phone_models (
  id uuid primary key default gen_random_uuid(),
  brand text not null check (char_length(trim(brand)) between 1 and 60),
  model text not null check (char_length(trim(model)) between 2 and 100),
  model_key text not null check (char_length(trim(model_key)) between 2 and 100),
  created_by uuid not null references auth.users(id) on delete restrict,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (brand, model_key)
);

create index if not exists phone_models_brand_active_idx
  on public.phone_models (brand, is_active, model);

alter table public.phone_models enable row level security;

drop policy if exists phone_models_select_active on public.phone_models;
create policy phone_models_select_active on public.phone_models
  for select using (is_active = true);

drop policy if exists phone_models_insert_authenticated on public.phone_models;
create policy phone_models_insert_authenticated on public.phone_models
  for insert with check (auth.uid() = created_by);

-- Keep the fixed seed list in the client; this table stores only additions.
