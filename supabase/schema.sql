-- Starnova production schema for Supabase
create extension if not exists pgcrypto;
create type public.app_role as enum ('owner','user','jadibot','scriptbuyer','sewa','admin','support');
create type public.purchase_status as enum ('pending','paid','active','cancelled');
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  name text,
  role public.app_role not null default 'user',
  created_at timestamptz not null default now()
);
create table public.products (
  id text primary key,
  name text not null,
  plan text not null,
  description text,
  price numeric(12,2) not null default 0,
  active boolean not null default true,
  created_at timestamptz not null default now()
);
create table public.purchases (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  product_id text not null references public.products(id),
  product_name text not null,
  amount numeric(12,2) not null default 0,
  status public.purchase_status not null default 'pending',
  created_at timestamptz not null default now()
);
create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path = public as $$
begin insert into public.profiles(id,email,name) values(new.id,new.email,new.raw_user_meta_data->>'name'); return new; end; $$;
create trigger on_auth_user_created after insert on auth.users for each row execute procedure public.handle_new_user();
create or replace function public.is_staff() returns boolean language sql stable security definer set search_path = public as $$ select exists(select 1 from public.profiles where id=auth.uid() and role = 'owner'); $$;
alter table public.profiles enable row level security; alter table public.products enable row level security; alter table public.purchases enable row level security;
create policy "profiles self read" on public.profiles for select using (id=auth.uid() or public.is_staff());
create policy "products public read" on public.products for select using (active=true or public.is_staff());
create policy "purchases own read" on public.purchases for select using (user_id=auth.uid() or public.is_staff());
create policy "purchases own insert" on public.purchases for insert with check (user_id=auth.uid());
create policy "staff manage products" on public.products for all using (public.is_staff()) with check (public.is_staff());
create policy "staff manage purchases" on public.purchases for update using (public.is_staff());
insert into public.products(id,name,plan,description,price) values
('private','Sewa Bot','Private','Bot siap pakai untuk grup kecil.',79000),('public','Sewa Bot','Public','Bot siap pakai tanpa batas anggota.',149000),('jadi-bot','Jadi Bot','Nomor milikmu','Hubungkan nomor WhatsApp kamu.',99000),('script','Beli Script','Source code + License','Source code dan License Key bot.',899000) on conflict do nothing;
-- Setelah user owner dibuat pertama kali, jalankan:
-- update public.profiles set role='owner' where email='owner@domainmu.com';
