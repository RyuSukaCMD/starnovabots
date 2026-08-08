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
