-- STARNOVA FULL SETUP (IDEMPOTENT)
-- Aman dijalankan ulang. Object yang sudah ada akan dipakai / dilewati.

create extension if not exists pgcrypto;

do $$ begin
  create type public.app_role as enum ('owner','user','jadibot','scriptbuyer','sewa','admin','support');
exception when duplicate_object then null;
end $$;

do $$ begin
  alter type public.app_role add value if not exists 'owner';
  alter type public.app_role add value if not exists 'user';
  alter type public.app_role add value if not exists 'jadibot';
  alter type public.app_role add value if not exists 'scriptbuyer';
  alter type public.app_role add value if not exists 'sewa';
  alter type public.app_role add value if not exists 'admin';
  alter type public.app_role add value if not exists 'support';
exception when others then null;
end $$;

do $$ begin
  create type public.purchase_status as enum ('pending','paid','active','cancelled');
exception when duplicate_object then null;
end $$;

do $$ begin
  alter type public.purchase_status add value if not exists 'pending';
  alter type public.purchase_status add value if not exists 'paid';
  alter type public.purchase_status add value if not exists 'active';
  alter type public.purchase_status add value if not exists 'cancelled';
exception when others then null;
end $$;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  username text,
  name text,
  display_name text,
  avatar text,
  provider text not null default 'email',
  role public.app_role not null default 'user',
  account_status text not null default 'active',
  last_activity timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.profiles add column if not exists username text;
alter table public.profiles add column if not exists display_name text;
alter table public.profiles add column if not exists avatar text;
alter table public.profiles add column if not exists provider text not null default 'email';
alter table public.profiles add column if not exists account_status text not null default 'active';
alter table public.profiles add column if not exists last_activity timestamptz;
alter table public.profiles add column if not exists updated_at timestamptz not null default now();

create table if not exists public.products (
  id text primary key,
  name text not null,
  plan text not null,
  description text,
  category text not null default 'Layanan',
  type text not null default 'script',
  price numeric(12,2) not null default 0,
  duration integer,
  stock integer,
  status text not null default 'active',
  image_icon text,
  plans jsonb not null default '[]'::jsonb,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.products add column if not exists category text not null default 'Layanan';
alter table public.products add column if not exists type text not null default 'script';
alter table public.products add column if not exists duration integer;
alter table public.products add column if not exists stock integer;
alter table public.products add column if not exists status text not null default 'active';
alter table public.products add column if not exists image_icon text;
alter table public.products add column if not exists plans jsonb not null default '[]'::jsonb;
alter table public.products add column if not exists updated_at timestamptz not null default now();

create table if not exists public.purchases (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  product_id text not null references public.products(id),
  product_name text not null,
  amount numeric(12,2) not null default 0,
  quantity integer not null default 1,
  duration integer,
  status public.purchase_status not null default 'pending',
  created_at timestamptz not null default now()
);

alter table public.purchases add column if not exists quantity integer not null default 1;
alter table public.purchases add column if not exists duration integer;

-- Constraint validation. Existing invalid rows tidak menghalangi setup.
do $$ begin
  alter table public.profiles add constraint username_format
    check (username is null or username ~ '^[a-z0-9_]{3,24}$');
exception when duplicate_object then null;
end $$;

do $$ begin
  alter table public.profiles add constraint account_status_valid
    check (account_status in ('active','suspended'));
exception when duplicate_object then null;
end $$;

do $$ begin
  alter table public.products add constraint product_type_valid
    check (type in ('rental','bot','script'));
exception when duplicate_object then null;
end $$;

do $$ begin
  alter table public.products add constraint product_status_valid
    check (status in ('active','inactive'));
exception when duplicate_object then null;
end $$;

create unique index if not exists profiles_username_unique
on public.profiles(lower(username))
where username is not null;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles(id,email,username,name,display_name,avatar,provider)
  values(
    new.id,
    new.email,
    null,
    new.raw_user_meta_data->>'name',
    new.raw_user_meta_data->>'name',
    coalesce(new.raw_user_meta_data->>'avatar_url',new.raw_user_meta_data->>'picture'),
    coalesce(new.raw_app_meta_data->>'provider','email')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

create or replace function public.is_username_available(
  candidate text,
  requesting_user uuid default auth.uid()
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select candidate ~ '^[a-z0-9_]{3,24}$'
  and not exists(
    select 1 from public.profiles
    where lower(username)=lower(candidate)
      and id<>requesting_user
  );
$$;

grant execute on function public.is_username_available(text,uuid) to authenticated;

create or replace function public.is_staff()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists(
    select 1 from public.profiles
    where id=auth.uid() and role='owner'
  );
$$;

grant execute on function public.is_staff() to authenticated;

alter table public.profiles enable row level security;
alter table public.products enable row level security;
alter table public.purchases enable row level security;

-- Drop policy lama supaya file dapat dijalankan ulang tanpa duplicate policy error.
drop policy if exists "profiles self read" on public.profiles;
drop policy if exists "profiles self update" on public.profiles;
drop policy if exists "owner manage profiles" on public.profiles;
drop policy if exists "products public read" on public.products;
drop policy if exists "owner manage products" on public.products;
drop policy if exists "staff manage products" on public.products;
drop policy if exists "purchases own read" on public.purchases;
drop policy if exists "purchases own insert" on public.purchases;
drop policy if exists "owner update purchases" on public.purchases;
drop policy if exists "staff manage purchases" on public.purchases;
drop policy if exists "owner delete purchases" on public.purchases;

create policy "profiles self read" on public.profiles for select
using (id=auth.uid() or public.is_staff());
create policy "profiles self update" on public.profiles for update
using (id=auth.uid()) with check (id=auth.uid());
create policy "owner manage profiles" on public.profiles for all
using (public.is_staff()) with check (public.is_staff());

create policy "products public read" on public.products for select
using (active=true or public.is_staff());
create policy "owner manage products" on public.products for all
using (public.is_staff()) with check (public.is_staff());

create policy "purchases own read" on public.purchases for select
using (user_id=auth.uid() or public.is_staff());
create policy "purchases own insert" on public.purchases for insert
with check (user_id=auth.uid());
create policy "owner update purchases" on public.purchases for update
using (public.is_staff()) with check (public.is_staff());
create policy "owner delete purchases" on public.purchases for delete
using (public.is_staff());

-- Product seed. Jika ID sudah ada, data produk diperbarui.
insert into public.products(id,name,plan,description,category,type,price,stock,status,image_icon,plans,active)
values
('private-bot','Private Bot','Private','WhatsApp Bot untuk grup dengan maksimal 6 member.','Sewa Bot','rental',25000,null,'active','bot','[{"duration":30,"price":25000},{"duration":90,"price":65000},{"duration":180,"price":110000},{"duration":365,"price":190000}]',true),
('public-bot','Public Bot','Public','WhatsApp Bot untuk grup tanpa batas jumlah member.','Sewa Bot','rental',45000,null,'active','public','[{"duration":30,"price":45000},{"duration":90,"price":120000},{"duration":180,"price":210000},{"duration":365,"price":380000}]',true),
('jadi-bot','Jadi Bot','Nomor milikmu','Jalankan bot menggunakan nomor WhatsApp milikmu.','Layanan','bot',99000,null,'active','phone','[]',true),
('script','Beli Script','Source code + License','Source code bot, License Key, dan dokumentasi aktivasi.','Script','script',899000,20,'active','code','[]',true)
on conflict (id) do update set
  name=excluded.name,plan=excluded.plan,description=excluded.description,
  category=excluded.category,type=excluded.type,price=excluded.price,
  stock=excluded.stock,status=excluded.status,image_icon=excluded.image_icon,
  plans=excluded.plans,active=excluded.active,updated_at=now();

create index if not exists profiles_role_idx on public.profiles(role);
create index if not exists purchases_user_id_idx on public.purchases(user_id);
create index if not exists purchases_product_id_idx on public.purchases(product_id);
create index if not exists purchases_status_idx on public.purchases(status);
create index if not exists purchases_created_at_idx on public.purchases(created_at desc);

-- Setelah user dibuat melalui /signup, jadikan owner dengan command berikut:
-- update public.profiles set role='owner' where email='email-owner@example.com';

-- Verifikasi:
-- select id,email,username,name,display_name,role,account_status from public.profiles;
-- select id,name,type,price,status,plans from public.products;
-- select id,user_id,product_name,amount,quantity,duration,status from public.purchases;

-- Avatar storage bucket
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do update set public = true;

drop policy if exists "avatar public read" on storage.objects;
drop policy if exists "avatar user upload" on storage.objects;
drop policy if exists "avatar user update" on storage.objects;
create policy "avatar public read" on storage.objects for select
using (bucket_id = 'avatars');
create policy "avatar user upload" on storage.objects for insert to authenticated
with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "avatar user update" on storage.objects for update to authenticated
using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text)
with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

-- Profile change cooldowns
alter table public.profiles add column if not exists username_changed_at timestamptz;
alter table public.profiles add column if not exists nickname_changed_at timestamptz;

create or replace function public.update_profile_identity(
  new_username text,
  new_display_name text
)
returns public.profiles
language plpgsql
security definer
set search_path = public
as $$
declare
  current_profile public.profiles;
  updated_profile public.profiles;
  normalized_username text := lower(trim(new_username));
  normalized_display_name text := trim(new_display_name);
begin
  select * into current_profile from public.profiles where id = auth.uid() for update;
  if current_profile.id is null then raise exception 'Profile tidak ditemukan'; end if;
  if normalized_username !~ '^[a-z0-9_]{3,24}$' then raise exception 'Username tidak valid'; end if;
  if normalized_display_name = '' then raise exception 'Nickname tidak boleh kosong'; end if;
  if normalized_username is distinct from lower(coalesce(current_profile.username, current_profile.name,'')) then
    if current_profile.username_changed_at is not null and current_profile.username_changed_at > now() - interval '7 days' then
      raise exception 'Username hanya dapat diganti setiap 7 hari';
    end if;
    if exists(select 1 from public.profiles where lower(username)=normalized_username and id<>auth.uid()) then
      raise exception 'Username sudah digunakan';
    end if;
  end if;
  if normalized_display_name is distinct from coalesce(current_profile.display_name,current_profile.name,'') then
    if current_profile.nickname_changed_at is not null and current_profile.nickname_changed_at > now() - interval '24 hours' then
      raise exception 'Nickname hanya dapat diganti setiap 24 jam';
    end if;
  end if;
  update public.profiles set username=normalized_username, name=normalized_username, display_name=normalized_display_name,
    username_changed_at=case when normalized_username is distinct from lower(coalesce(current_profile.username,current_profile.name,'')) then now() else current_profile.username_changed_at end,
    nickname_changed_at=case when normalized_display_name is distinct from coalesce(current_profile.display_name,current_profile.name,'') then now() else current_profile.nickname_changed_at end,
    updated_at=now() where id=auth.uid() returning * into updated_profile;
  return updated_profile;
end;
$$;
grant execute on function public.update_profile_identity(text,text) to authenticated;

-- Product variants / sub-products
create table if not exists public.sub_products (
  id uuid primary key default gen_random_uuid(),
  product_id text not null references public.products(id) on delete cascade,
  name text not null,
  description text,
  price numeric(12,2) not null default 0,
  duration integer,
  stock integer,
  status text not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.sub_products enable row level security;
drop policy if exists "sub products public read" on public.sub_products;
drop policy if exists "owner manage sub products" on public.sub_products;
create policy "sub products public read" on public.sub_products for select using (status='active');
create policy "owner manage sub products" on public.sub_products for all using (public.is_staff()) with check (public.is_staff());
create index if not exists sub_products_product_id_idx on public.sub_products(product_id);

alter table public.purchases add column if not exists sub_product_id uuid references public.sub_products(id);

-- Redeem codes / discount system
create table if not exists public.redeem_codes (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  discount_type text not null check (discount_type in ('percent','fixed')),
  discount_value numeric(12,2) not null default 0,
  max_uses integer,
  used_count integer not null default 0,
  starts_at timestamptz,
  expires_at timestamptz,
  min_account_age_days integer not null default 0,
  user_id uuid references public.profiles(id) on delete cascade,
  active boolean not null default true,
  created_at timestamptz not null default now()
);
create table if not exists public.redeem_redemptions (
  id uuid primary key default gen_random_uuid(),
  redeem_code_id uuid not null references public.redeem_codes(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  purchase_id uuid references public.purchases(id) on delete set null,
  created_at timestamptz not null default now(),
  unique(redeem_code_id,user_id)
);
alter table public.redeem_codes enable row level security;
alter table public.redeem_redemptions enable row level security;
drop policy if exists "owner manage redeem codes" on public.redeem_codes;
drop policy if exists "owner manage redemptions" on public.redeem_redemptions;
create policy "owner manage redeem codes" on public.redeem_codes for all using (public.is_staff()) with check (public.is_staff());
create policy "owner manage redemptions" on public.redeem_redemptions for all using (public.is_staff()) with check (public.is_staff());
create or replace function public.validate_redeem_code(input_code text, order_amount numeric)
returns jsonb language plpgsql security definer set search_path=public as $$
declare r public.redeem_codes; p public.profiles; discount numeric:=0;
begin
 select * into r from public.redeem_codes where upper(code)=upper(trim(input_code)) and active=true for update;
 if r.id is null then raise exception 'Redeem code tidak ditemukan atau tidak aktif'; end if;
 if r.starts_at is not null and now()<r.starts_at then raise exception 'Redeem code belum dapat digunakan'; end if;
 if r.expires_at is not null and now()>r.expires_at then raise exception 'Redeem code sudah kedaluwarsa'; end if;
 if r.max_uses is not null and r.used_count>=r.max_uses then raise exception 'Batas penggunaan redeem code sudah tercapai'; end if;
 if r.user_id is not null and r.user_id<>auth.uid() then raise exception 'Redeem code bukan untuk akun ini'; end if;
 if exists(select 1 from public.redeem_redemptions where redeem_code_id=r.id and user_id=auth.uid()) then raise exception 'Redeem code sudah pernah digunakan'; end if;
 select * into p from public.profiles where id=auth.uid();
 if p.created_at > now() - make_interval(days=>r.min_account_age_days) then raise exception 'Umur akun belum memenuhi syarat'; end if;
 if r.discount_type='percent' then discount:=least(order_amount,order_amount*r.discount_value/100); else discount:=least(order_amount,r.discount_value); end if;
 return jsonb_build_object('id',r.id,'code',r.code,'discount',discount,'final_amount',greatest(order_amount-discount,0),'discount_type',r.discount_type,'discount_value',r.discount_value);
end; $$;
grant execute on function public.validate_redeem_code(text,numeric) to authenticated;

-- Redeem constraints: minimum order and optional never-expire
alter table public.redeem_codes add column if not exists min_order_amount numeric(12,2) not null default 0;
alter table public.redeem_codes add column if not exists never_expires boolean not null default false;

create or replace function public.validate_redeem_code(input_code text, order_amount numeric)
returns jsonb language plpgsql security definer set search_path=public as $$
declare r public.redeem_codes; p public.profiles; discount numeric:=0;
begin
 select * into r from public.redeem_codes where upper(code)=upper(trim(input_code)) and active=true for update;
 if r.id is null then raise exception 'Redeem code tidak ditemukan atau tidak aktif'; end if;
 if r.min_order_amount > order_amount then raise exception 'Minimum pembelian untuk kode ini adalah %', r.min_order_amount; end if;
 if not coalesce(r.never_expires,false) and r.starts_at is not null and now()<r.starts_at then raise exception 'Redeem code belum dapat digunakan'; end if;
 if not coalesce(r.never_expires,false) and r.expires_at is not null and now()>r.expires_at then raise exception 'Redeem code sudah kedaluwarsa'; end if;
 if r.max_uses is not null and r.used_count>=r.max_uses then raise exception 'Batas penggunaan redeem code sudah tercapai'; end if;
 if r.user_id is not null and r.user_id<>auth.uid() then raise exception 'Redeem code bukan untuk akun ini'; end if;
 if exists(select 1 from public.redeem_redemptions where redeem_code_id=r.id and user_id=auth.uid()) then raise exception 'Redeem code sudah pernah digunakan'; end if;
 select * into p from public.profiles where id=auth.uid();
 if p.created_at > now() - make_interval(days=>r.min_account_age_days) then raise exception 'Umur akun belum memenuhi syarat'; end if;
 if r.discount_type='percent' then discount:=least(order_amount,order_amount*r.discount_value/100); else discount:=least(order_amount,r.discount_value); end if;
 return jsonb_build_object('id',r.id,'code',r.code,'discount',discount,'final_amount',greatest(order_amount-discount,0),'is_free',discount>=order_amount);
end; $$;

alter table public.redeem_codes add column if not exists max_accounts integer;
create or replace function public.validate_redeem_code(input_code text, order_amount numeric)
returns jsonb language plpgsql security definer set search_path=public as $$
declare r public.redeem_codes; p public.profiles; discount numeric:=0;
begin
 select * into r from public.redeem_codes where upper(code)=upper(trim(input_code)) and active=true for update;
 if r.id is null then raise exception 'Redeem code tidak ditemukan atau tidak aktif'; end if;
 if r.min_order_amount > order_amount then raise exception 'Minimum pembelian untuk kode ini adalah %', r.min_order_amount; end if;
 if not coalesce(r.never_expires,false) and r.starts_at is not null and now()<r.starts_at then raise exception 'Redeem code belum dapat digunakan'; end if;
 if not coalesce(r.never_expires,false) and r.expires_at is not null and now()>r.expires_at then raise exception 'Redeem code sudah kedaluwarsa'; end if;
 if r.max_uses is not null and r.used_count>=r.max_uses then raise exception 'Batas penggunaan redeem code sudah tercapai'; end if;
 if r.max_accounts is not null and (select count(*) from public.redeem_redemptions where redeem_code_id=r.id)>=r.max_accounts then raise exception 'Batas akun redeem code sudah tercapai'; end if;
 if r.user_id is not null and r.user_id<>auth.uid() then raise exception 'Redeem code bukan untuk akun ini'; end if;
 if exists(select 1 from public.redeem_redemptions where redeem_code_id=r.id and user_id=auth.uid()) then raise exception 'Redeem code sudah pernah digunakan'; end if;
 select * into p from public.profiles where id=auth.uid();
 if p.created_at > now() - make_interval(days=>r.min_account_age_days) then raise exception 'Umur akun belum memenuhi syarat'; end if;
 if r.discount_type='percent' then discount:=least(order_amount,order_amount*r.discount_value/100); else discount:=least(order_amount,r.discount_value); end if;
 return jsonb_build_object('id',r.id,'code',r.code,'discount',discount,'final_amount',greatest(order_amount-discount,0),'is_free',discount>=order_amount);
end; $$;


-- Maximum account age for redeem codes
alter table public.redeem_codes add column if not exists max_account_age_days integer;
create or replace function public.validate_redeem_code(input_code text, order_amount numeric)
returns jsonb language plpgsql security definer set search_path=public as $$
declare r public.redeem_codes; p public.profiles; discount numeric:=0;
begin
 select * into r from public.redeem_codes where upper(code)=upper(trim(input_code)) and active=true for update;
 if r.id is null then raise exception 'Redeem code tidak ditemukan atau tidak aktif'; end if;
 if r.min_order_amount > order_amount then raise exception 'Minimum pembelian untuk kode ini adalah %', r.min_order_amount; end if;
 if not coalesce(r.never_expires,false) and r.starts_at is not null and now()<r.starts_at then raise exception 'Redeem code belum dapat digunakan'; end if;
 if not coalesce(r.never_expires,false) and r.expires_at is not null and now()>r.expires_at then raise exception 'Redeem code sudah kedaluwarsa'; end if;
 if r.max_uses is not null and r.used_count>=r.max_uses then raise exception 'Batas penggunaan redeem code sudah tercapai'; end if;
 if r.max_accounts is not null and (select count(*) from public.redeem_redemptions where redeem_code_id=r.id)>=r.max_accounts then raise exception 'Batas akun redeem code sudah tercapai'; end if;
 if r.user_id is not null and r.user_id<>auth.uid() then raise exception 'Redeem code bukan untuk akun ini'; end if;
 if exists(select 1 from public.redeem_redemptions where redeem_code_id=r.id and user_id=auth.uid()) then raise exception 'Redeem code sudah pernah digunakan'; end if;
 select * into p from public.profiles where id=auth.uid();
 if p.created_at > now() - make_interval(days=>r.min_account_age_days) then raise exception 'Umur akun belum memenuhi syarat minimum'; end if;
 if r.max_account_age_days is not null and p.created_at < now() - make_interval(days=>r.max_account_age_days) then raise exception 'Umur akun melebihi batas maksimum'; end if;
 if r.discount_type='percent' then discount:=least(order_amount,order_amount*r.discount_value/100); else discount:=least(order_amount,r.discount_value); end if;
 return jsonb_build_object('id',r.id,'code',r.code,'discount',discount,'final_amount',greatest(order_amount-discount,0),'is_free',discount>=order_amount);
end; $$;

-- Customer service chat
DO $$ BEGIN alter type public.app_role add value if not exists 'customer_service'; EXCEPTION WHEN others THEN null; END $$;
create table if not exists public.cs_conversations (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references public.profiles(id) on delete cascade,
 assigned_to uuid references public.profiles(id) on delete set null, subject text not null default 'Bantuan Starnova',
 status text not null default 'open' check(status in ('open','claimed','resolved','confirmed')),
 rating integer check(rating between 1 and 5), rating_note text, claimed_at timestamptz, resolved_at timestamptz, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.cs_messages (
 id uuid primary key default gen_random_uuid(), conversation_id uuid not null references public.cs_conversations(id) on delete cascade,
 sender_id uuid not null references public.profiles(id) on delete cascade, body text not null default '', attachment_url text, created_at timestamptz not null default now()
);
alter table public.cs_conversations enable row level security; alter table public.cs_messages enable row level security;
drop policy if exists "cs conversation user read" on public.cs_conversations; drop policy if exists "cs conversation staff read" on public.cs_conversations; drop policy if exists "cs message participant read" on public.cs_messages; drop policy if exists "cs message participant insert" on public.cs_messages;
create policy "cs conversation user read" on public.cs_conversations for select using(user_id=auth.uid() or assigned_to=auth.uid());
create policy "cs conversation staff read" on public.cs_conversations for select using(exists(select 1 from public.profiles where id=auth.uid() and role='customer_service'));
create policy "cs conversation user insert" on public.cs_conversations for insert with check(user_id=auth.uid());
create policy "cs conversation participant update" on public.cs_conversations for update using(user_id=auth.uid() or assigned_to=auth.uid()) with check(user_id=auth.uid() or assigned_to=auth.uid());
create policy "cs message participant read" on public.cs_messages for select using(exists(select 1 from public.cs_conversations c where c.id=conversation_id and (c.user_id=auth.uid() or c.assigned_to=auth.uid() or exists(select 1 from public.profiles where id=auth.uid() and role='customer_service'))));
create policy "cs message participant insert" on public.cs_messages for insert with check(sender_id=auth.uid() and exists(select 1 from public.cs_conversations c where c.id=conversation_id and (c.user_id=auth.uid() or c.assigned_to=auth.uid())));
create or replace function public.claim_cs_ticket(ticket_id uuid) returns public.cs_conversations language plpgsql security definer set search_path=public as $$ declare result public.cs_conversations; begin if not exists(select 1 from public.profiles where id=auth.uid() and role='customer_service') then raise exception 'Akses customer service diperlukan'; end if; update public.cs_conversations set assigned_to=auth.uid(),status='claimed',claimed_at=now(),updated_at=now() where id=ticket_id and assigned_to is null and status='open' returning * into result; if result.id is null then raise exception 'Ticket sudah diklaim CS lain'; end if; return result; end; $$;
create or replace function public.resolve_cs_ticket(ticket_id uuid) returns public.cs_conversations language plpgsql security definer set search_path=public as $$ declare result public.cs_conversations; begin update public.cs_conversations set status='resolved',resolved_at=now(),updated_at=now() where id=ticket_id and assigned_to=auth.uid() returning * into result; if result.id is null then raise exception 'Ticket tidak dapat diselesaikan'; end if; return result; end; $$;
grant execute on function public.claim_cs_ticket(uuid) to authenticated; grant execute on function public.resolve_cs_ticket(uuid) to authenticated;
create index if not exists cs_conversations_status_idx on public.cs_conversations(status); create index if not exists cs_messages_conversation_idx on public.cs_messages(conversation_id,created_at);
insert into storage.buckets(id,name,public) values('chat-attachments','chat-attachments',true) on conflict(id) do update set public=true;
drop policy if exists "chat attachment read" on storage.objects; drop policy if exists "chat attachment upload" on storage.objects;
create policy "chat attachment read" on storage.objects for select using(bucket_id='chat-attachments');
create policy "chat attachment upload" on storage.objects for insert to authenticated with check(bucket_id='chat-attachments' and (storage.foldername(name))[1]=auth.uid()::text);
