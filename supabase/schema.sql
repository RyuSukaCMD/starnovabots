-- Starnova production schema for Supabase
create extension if not exists pgcrypto;
create type public.app_role as enum ('owner','user','jadibot','scriptbuyer','sewa','admin','support');
create type public.purchase_status as enum ('pending','paid','active','cancelled');
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  username text unique,
  name text,
  display_name text,
  avatar text,
  provider text not null default 'email',
  role public.app_role not null default 'user',
  account_status text not null default 'active' check (account_status in ('active','suspended')),
  last_activity timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint username_format check (username is null or username ~ '^[a-z0-9_]{3,24}$')
);
create table public.products (
  id text primary key,
  name text not null,
  plan text not null,
  description text,
  category text not null default 'Layanan',
  type text not null default 'script' check (type in ('rental','bot','script')),
  price numeric(12,2) not null default 0,
  duration integer,
  stock integer,
  status text not null default 'active' check (status in ('active','inactive')),
  image_icon text,
  plans jsonb not null default '[]'::jsonb,
  active boolean not null default true,
  created_at timestamptz not null default now()
);
create table public.purchases (
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
create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path = public as $$
begin insert into public.profiles(id,email,username,name,display_name,avatar,provider) values(new.id,new.email,null,new.raw_user_meta_data->>'name',new.raw_user_meta_data->>'name',coalesce(new.raw_user_meta_data->>'avatar_url',new.raw_user_meta_data->>'picture'),coalesce(new.raw_app_meta_data->>'provider','email')); return new; end; $$;
create trigger on_auth_user_created after insert on auth.users for each row execute procedure public.handle_new_user();
create or replace function public.is_username_available(candidate text, current_user uuid default auth.uid()) returns boolean language sql stable security definer set search_path = public as $$ select candidate ~ '^[a-z0-9_]{3,24}$' and not exists(select 1 from public.profiles where lower(username)=lower(candidate) and id<>current_user); $$;
create or replace function public.is_staff() returns boolean language sql stable security definer set search_path = public as $$ select exists(select 1 from public.profiles where id=auth.uid() and role = 'owner'); $$;
grant execute on function public.is_username_available(text, uuid) to authenticated;
alter table public.profiles enable row level security; alter table public.products enable row level security; alter table public.purchases enable row level security;
create policy "profiles self read" on public.profiles for select using (id=auth.uid() or public.is_staff());
create policy "profiles self update" on public.profiles for update using (id=auth.uid()) with check (id=auth.uid());
create policy "owner manage profiles" on public.profiles for all using (public.is_staff()) with check (public.is_staff());
create policy "products public read" on public.products for select using (active=true or public.is_staff());
create policy "purchases own read" on public.purchases for select using (user_id=auth.uid() or public.is_staff());
create policy "purchases own insert" on public.purchases for insert with check (user_id=auth.uid());
create policy "staff manage products" on public.products for all using (public.is_staff()) with check (public.is_staff());
create policy "staff manage purchases" on public.purchases for update using (public.is_staff());
insert into public.products(id,name,plan,description,category,type,price,duration,stock,status,image_icon,plans) values
('private-bot','Private Bot','Private','WhatsApp Bot untuk grup dengan maksimal 6 member.','Sewa Bot','rental',25000,null,null,'active','bot','[{"duration":30,"price":25000},{"duration":90,"price":65000},{"duration":180,"price":110000},{"duration":365,"price":190000}]'),
('public-bot','Public Bot','Public','WhatsApp Bot untuk grup tanpa batas jumlah member.','Sewa Bot','rental',45000,null,null,'active','public','[{"duration":30,"price":45000},{"duration":90,"price":120000},{"duration":180,"price":210000},{"duration":365,"price":380000}]'),
('jadi-bot','Jadi Bot','Nomor milikmu','Jalankan bot menggunakan nomor WhatsApp milikmu.','Layanan','bot',99000,null,null,'active','phone','[]'),
('script','Beli Script','Source code + License','Source code bot, License Key, dan dokumentasi aktivasi.','Script','script',899000,null,20,'active','code','[]') on conflict (id) do update set name=excluded.name,plan=excluded.plan,description=excluded.description,category=excluded.category,type=excluded.type,price=excluded.price,duration=excluded.duration,stock=excluded.stock,status=excluded.status,image_icon=excluded.image_icon,plans=excluded.plans,active=true;
-- Setelah user owner dibuat pertama kali, jalankan:
-- update public.profiles set role='owner' where email='owner@domainmu.com';
