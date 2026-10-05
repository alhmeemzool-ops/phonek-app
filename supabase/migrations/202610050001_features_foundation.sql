-- PhoneK feature foundation: swaps, wanted, voice, referrals, analytics, offers, subscriptions, accessories, repairs
-- All statements are rerunnable. Apply after the existing migrations.

alter table public.listings add column if not exists accepts_swap boolean not null default false;
alter table public.chat_messages add column if not exists payload jsonb;

do $$
declare c record;
begin
  for c in
    select conname from pg_constraint
    where conrelid='public.chat_messages'::regclass
      and contype='c'
      and pg_get_constraintdef(oid) ilike '%type%'
  loop
    execute format('alter table public.chat_messages drop constraint if exists %I', c.conname);
  end loop;
end $$;
alter table public.chat_messages add constraint chat_messages_type_allowed
  check (type in ('text','image','location','priceOffer','offer','swap','voice'));

create table if not exists public.wanted_requests (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
 model_text text not null check (char_length(model_text) between 1 and 80),
 max_price integer not null check (max_price > 0), city text not null,
 notes text check (notes is null or char_length(notes)<=300),
 status text not null default 'open' check(status in ('open','closed')), created_at timestamptz not null default now()
);
alter table public.wanted_requests enable row level security;
drop policy if exists wanted_read_open on public.wanted_requests;
create policy wanted_read_open on public.wanted_requests for select using (status='open' or auth.uid()=user_id);
drop policy if exists wanted_insert_own on public.wanted_requests;
create policy wanted_insert_own on public.wanted_requests for insert with check(auth.uid()=user_id);
drop policy if exists wanted_update_own on public.wanted_requests;
create policy wanted_update_own on public.wanted_requests for update using(auth.uid()=user_id) with check(auth.uid()=user_id);
drop policy if exists wanted_delete_own on public.wanted_requests;
create policy wanted_delete_own on public.wanted_requests for delete using(auth.uid()=user_id);

create table if not exists public.invite_codes(user_id uuid primary key references auth.users(id) on delete cascade, code text unique not null);
create table if not exists public.referrals(invitee_id uuid primary key references auth.users(id) on delete cascade, inviter_id uuid not null references auth.users(id) on delete cascade, created_at timestamptz not null default now(), check(invitee_id<>inviter_id));
create table if not exists public.feature_credits(user_id uuid primary key references auth.users(id) on delete cascade, days_available integer not null default 0 check(days_available>=0));
create table if not exists public.listing_boosts(listing_id uuid not null references public.listings(id) on delete cascade, starts_at timestamptz not null, ends_at timestamptz not null, primary key(listing_id,starts_at), check(ends_at>starts_at));
alter table public.invite_codes enable row level security; alter table public.referrals enable row level security; alter table public.feature_credits enable row level security; alter table public.listing_boosts enable row level security;
drop policy if exists invite_codes_own on public.invite_codes; create policy invite_codes_own on public.invite_codes for select using(auth.uid()=user_id);
drop policy if exists referrals_own on public.referrals; create policy referrals_own on public.referrals for select using(auth.uid()=invitee_id or auth.uid()=inviter_id);
drop policy if exists credits_own on public.feature_credits; create policy credits_own on public.feature_credits for select using(auth.uid()=user_id);
drop policy if exists boosts_public on public.listing_boosts; create policy boosts_public on public.listing_boosts for select using(true);

create table if not exists public.listing_events(
 id uuid primary key default gen_random_uuid(), listing_id uuid not null references public.listings(id) on delete cascade,
 seller_id uuid not null references auth.users(id) on delete cascade, actor_id uuid references auth.users(id) on delete set null,
 event_type text not null check(event_type in('view','favorite','contact')), created_at timestamptz not null default now()
);
create index if not exists listing_events_listing_created_idx on public.listing_events(listing_id,created_at desc);
alter table public.listing_events enable row level security;
drop policy if exists listing_events_seller_read on public.listing_events;
create policy listing_events_seller_read on public.listing_events for select using(auth.uid()=seller_id);

create table if not exists public.shop_offers(
 id uuid primary key default gen_random_uuid(), shop_id uuid not null references auth.users(id) on delete cascade,
 title text not null, discount_percent integer not null check(discount_percent between 1 and 90),
 starts_at timestamptz not null, ends_at timestamptz not null, check(ends_at>starts_at)
);
create table if not exists public.shop_offer_items(
 offer_id uuid not null references public.shop_offers(id) on delete cascade,
 listing_id uuid not null references public.listings(id) on delete cascade, primary key(offer_id,listing_id)
);
alter table public.shop_offers enable row level security; alter table public.shop_offer_items enable row level security;
drop policy if exists shop_offers_public_read on public.shop_offers;
create policy shop_offers_public_read on public.shop_offers for select using(ends_at>now());
drop policy if exists shop_offers_owner_write on public.shop_offers;
create policy shop_offers_owner_write on public.shop_offers for all using(auth.uid()=shop_id) with check(auth.uid()=shop_id);
drop policy if exists shop_offer_items_public_read on public.shop_offer_items;
create policy shop_offer_items_public_read on public.shop_offer_items for select using(exists(select 1 from public.shop_offers o where o.id=offer_id and o.ends_at>now()));
drop policy if exists shop_offer_items_owner_write on public.shop_offer_items;
create policy shop_offer_items_owner_write on public.shop_offer_items for all using(exists(select 1 from public.shop_offers o where o.id=offer_id and o.shop_id=auth.uid())) with check(exists(select 1 from public.shop_offers o where o.id=offer_id and o.shop_id=auth.uid()));

create table if not exists public.shop_subscriptions(
 id uuid primary key default gen_random_uuid(), shop_id uuid not null references auth.users(id) on delete cascade,
 status text not null default 'pending' check(status in('pending','active','rejected','ended')),
 requested_at timestamptz not null default now(), starts_at timestamptz, ends_at timestamptz,
 payment_proof_path text, reviewed_by uuid references auth.users(id)
);
alter table public.shop_subscriptions enable row level security;
drop policy if exists shop_subscriptions_owner_read on public.shop_subscriptions;
create policy shop_subscriptions_owner_read on public.shop_subscriptions for select using(auth.uid()=shop_id);
create or replace view public.public_active_subscriptions as
 select shop_id from public.shop_subscriptions where status='active' and ends_at>now();

create table if not exists public.accessories(
 id uuid primary key default gen_random_uuid(), seller_id uuid not null references auth.users(id) on delete cascade,
 title text not null, category text not null check(category in('جرابات','شواحن','شاشات','قطع غيار أخرى')),
 price integer not null check(price>=0), city text not null, description text not null default '',
 image_urls text[] not null default '{}', status text not null default 'pending_review' check(status in('pending_review','active','rejected','expired')),
 created_at timestamptz not null default now()
);
alter table public.accessories enable row level security;
drop policy if exists accessories_public_active on public.accessories;
create policy accessories_public_active on public.accessories for select using(status='active' or auth.uid()=seller_id);
drop policy if exists accessories_owner_insert on public.accessories;
create policy accessories_owner_insert on public.accessories for insert with check(auth.uid()=seller_id);
drop policy if exists accessories_owner_update on public.accessories;
create policy accessories_owner_update on public.accessories for update using(auth.uid()=seller_id) with check(auth.uid()=seller_id);
drop policy if exists accessories_owner_delete on public.accessories;
create policy accessories_owner_delete on public.accessories for delete using(auth.uid()=seller_id);

create table if not exists public.repair_shops(
 id uuid primary key default gen_random_uuid(), name text not null, city text not null, address text not null,
 phone text not null, whatsapp text, working_hours text not null, services text not null, created_at timestamptz not null default now()
);
create table if not exists public.repair_shop_ratings(
 shop_id uuid not null references public.repair_shops(id) on delete cascade, user_id uuid not null references auth.users(id) on delete cascade,
 stars integer not null check(stars between 1 and 5), primary key(shop_id,user_id)
);
alter table public.repair_shops enable row level security; alter table public.repair_shop_ratings enable row level security;
drop policy if exists repair_shops_public_read on public.repair_shops; create policy repair_shops_public_read on public.repair_shops for select using(true);
drop policy if exists repair_ratings_public_read on public.repair_shop_ratings; create policy repair_ratings_public_read on public.repair_shop_ratings for select using(true);
drop policy if exists repair_ratings_own_write on public.repair_shop_ratings;
create policy repair_ratings_own_write on public.repair_shop_ratings for all using(auth.uid()=user_id) with check(auth.uid()=user_id);

create or replace function public.record_listing_event(p_listing_id uuid,p_event_type text)
returns void language plpgsql security definer set search_path='' as $$
declare sid uuid; aid uuid;
begin
 if p_event_type not in('view','favorite','contact') then raise exception 'invalid event'; end if;
 select seller_id into sid from public.listings where id=p_listing_id;
 aid:=auth.uid(); if sid is null or aid=sid then return; end if;
 if aid is not null and exists(select 1 from public.listing_events where listing_id=p_listing_id and actor_id=aid and event_type=p_event_type and created_at>=date_trunc('day',now())) then return; end if;
 insert into public.listing_events(listing_id,seller_id,actor_id,event_type) values(p_listing_id,sid,aid,p_event_type);
end $$;
revoke all on function public.record_listing_event(uuid,text) from public,anon; grant execute on function public.record_listing_event(uuid,text) to authenticated;

create or replace function public.respond_to_swap(p_message_id uuid,p_accept boolean)
returns void language plpgsql security definer set search_path='' as $$
declare t public.chat_threads; m public.chat_messages; p jsonb;
begin
 select * into t from public.chat_threads where id=(select thread_id from public.chat_messages where id=p_message_id);
 select * into m from public.chat_messages where id=p_message_id;
 if t.seller_id<>auth.uid() or m.type<>'swap' or coalesce(m.payload->>'status','pending')<>'pending' then raise exception 'غير مسموح'; end if;
 p:=coalesce(m.payload,'{}'::jsonb)||jsonb_build_object('status',case when p_accept then 'accepted' else 'rejected' end);
 update public.chat_messages set payload=p where id=p_message_id;
end $$;
revoke all on function public.respond_to_swap(uuid,boolean) from public,anon; grant execute on function public.respond_to_swap(uuid,boolean) to authenticated;

create or replace function public.start_wanted_chat(p_request_id uuid,p_listing_id uuid)
returns uuid language plpgsql security definer set search_path='' as $$
declare r public.wanted_requests; l public.listings; tid uuid; mid uuid;
begin
 select * into r from public.wanted_requests where id=p_request_id;
 select * into l from public.listings where id=p_listing_id;
 if r.id is null or l.id is null or r.status<>'open' or l.status<>'active' or l.seller_id<>auth.uid() or r.user_id=auth.uid() then raise exception 'غير مسموح'; end if;
 insert into public.chat_threads(listing_id,buyer_id,seller_id) values(l.id,r.user_id,auth.uid())
 on conflict(listing_id,buyer_id) do update set seller_id=excluded.seller_id returning id into tid;
 insert into public.chat_messages(thread_id,sender_id,text,type,status) values(tid,auth.uid(),'عندي هذا الهاتف لطلبك: '||r.model_text,'text','sent') returning id into mid;
 return tid;
end $$;
revoke all on function public.start_wanted_chat(uuid,uuid) from public,anon; grant execute on function public.start_wanted_chat(uuid,uuid) to authenticated;

create or replace function public.get_or_create_invite_code()
returns text language plpgsql security definer set search_path='' as $$
declare c text;
begin
 select code into c from public.invite_codes where user_id=auth.uid();
 if c is null then c:=upper(substr(replace(gen_random_uuid()::text,'-',''),1,8)); insert into public.invite_codes(user_id,code) values(auth.uid(),c) on conflict(user_id) do update set code=excluded.code returning code into c; end if;
 return c;
end $$;
revoke all on function public.get_or_create_invite_code() from public,anon; grant execute on function public.get_or_create_invite_code() to authenticated;

create or replace function public.redeem_invite_code(p_code text)
returns void language plpgsql security definer set search_path='' as $$
declare inviter uuid;
begin
 select user_id into inviter from public.invite_codes where upper(code)=upper(trim(p_code));
 if inviter is null or inviter=auth.uid() then raise exception 'كود غير صالح'; end if;
 if exists(select 1 from public.referrals where invitee_id=auth.uid()) then raise exception 'تم استخدام كود من قبل'; end if;
 insert into public.referrals(invitee_id,inviter_id) values(auth.uid(),inviter);
 insert into public.feature_credits(user_id,days_available) values(inviter,1) on conflict(user_id) do update set days_available=public.feature_credits.days_available+1;
 insert into public.feature_credits(user_id,days_available) values(auth.uid(),0) on conflict do nothing;
end $$;
revoke all on function public.redeem_invite_code(text) from public,anon; grant execute on function public.redeem_invite_code(text) to authenticated;

create or replace function public.use_feature_credit(p_listing_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare c integer;
begin
 select days_available into c from public.feature_credits where user_id=auth.uid();
 if coalesce(c,0)<1 then raise exception 'لا يوجد رصيد تمييز'; end if;
 if not exists(select 1 from public.listings where id=p_listing_id and seller_id=auth.uid() and status='active') then raise exception 'الإعلان غير متاح'; end if;
 update public.feature_credits set days_available=days_available-1 where user_id=auth.uid();
 insert into public.listing_boosts(listing_id,starts_at,ends_at) values(p_listing_id,now(),now()+interval '24 hours');
end $$;
revoke all on function public.use_feature_credit(uuid) from public,anon; grant execute on function public.use_feature_credit(uuid) to authenticated;

create or replace function public.get_merchant_stats(p_days integer)
returns table(listing_id uuid,event_type text,event_count bigint) language sql security definer set search_path='' as $$
 select e.listing_id,e.event_type,count(*) from public.listing_events e
 join public.listings l on l.id=e.listing_id
 where l.seller_id=auth.uid() and e.created_at>=now()-make_interval(days=>greatest(1,p_days))
 group by e.listing_id,e.event_type
 order by e.listing_id,e.event_type
$$;
revoke all on function public.get_merchant_stats(integer) from public,anon; grant execute on function public.get_merchant_stats(integer) to authenticated;


insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values
('chat-voice','chat-voice',false,2097152,array['audio/mp4','audio/aac','audio/ogg']),
('subscription-proofs','subscription-proofs',false,5242880,array['image/jpeg','image/png','image/webp'])
on conflict(id) do update set file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;

drop policy if exists chat_voice_upload on storage.objects;
create policy chat_voice_upload on storage.objects for insert to authenticated
with check(bucket_id='chat-voice' and exists(select 1 from public.chat_threads t where t.id=(storage.foldername(name))[1]::uuid and (t.buyer_id=auth.uid() or t.seller_id=auth.uid())));
drop policy if exists chat_voice_read on storage.objects;
create policy chat_voice_read on storage.objects for select to authenticated
using(bucket_id='chat-voice' and exists(select 1 from public.chat_threads t where t.id=(storage.foldername(name))[1]::uuid and (t.buyer_id=auth.uid() or t.seller_id=auth.uid())));
drop policy if exists subscription_proof_upload on storage.objects;
create policy subscription_proof_upload on storage.objects for insert to authenticated
with check(bucket_id='subscription-proofs' and (storage.foldername(name))[1]=auth.uid()::text);
drop policy if exists subscription_proof_read on storage.objects;
create policy subscription_proof_read on storage.objects for select to authenticated
using(bucket_id='subscription-proofs' and ((storage.foldername(name))[1]=auth.uid()::text or exists(select 1 from public.profiles p where p.id=auth.uid() and public.is_admin())));


drop policy if exists shop_subscriptions_owner_insert on public.shop_subscriptions;
create policy shop_subscriptions_owner_insert on public.shop_subscriptions for insert with check(auth.uid()=shop_id);
drop policy if exists shop_subscriptions_admin_all on public.shop_subscriptions;
create policy shop_subscriptions_admin_all on public.shop_subscriptions for all using(public.is_admin()) with check(public.is_admin());
grant select on public.public_active_subscriptions to anon,authenticated;

drop policy if exists accessories_admin_moderate on public.accessories;
create policy accessories_admin_moderate on public.accessories for all using(public.is_admin()) with check(public.is_admin());

drop policy if exists repair_shops_admin_write on public.repair_shops;
create policy repair_shops_admin_write on public.repair_shops for all using(public.is_admin()) with check(public.is_admin());

drop policy if exists shop_offer_items_owner_validated_write on public.shop_offer_items;
create policy shop_offer_items_owner_validated_write on public.shop_offer_items for insert to authenticated
with check(exists(select 1 from public.shop_offers o join public.listings l on l.id=listing_id where o.id=offer_id and o.shop_id=auth.uid() and l.seller_id=auth.uid() and l.status='active' and coalesce(l.price_on_call,false)=false));
