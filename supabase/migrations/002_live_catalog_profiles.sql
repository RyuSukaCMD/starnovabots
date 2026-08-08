-- Migration for existing projects. Run after 001_add_roles.sql.
alter table public.profiles add column if not exists username text;
alter table public.profiles add column if not exists display_name text;
alter table public.profiles add column if not exists avatar text;
alter table public.profiles add column if not exists provider text not null default 'email';
alter table public.profiles add column if not exists account_status text not null default 'active';
alter table public.profiles add column if not exists last_activity timestamptz;
alter table public.profiles add column if not exists updated_at timestamptz not null default now();
create unique index if not exists profiles_username_unique on public.profiles(lower(username)) where username is not null;
alter table public.products add column if not exists category text not null default 'Layanan';
alter table public.products add column if not exists type text not null default 'script';
alter table public.products add column if not exists duration integer;
alter table public.products add column if not exists stock integer;
alter table public.products add column if not exists status text not null default 'active';
alter table public.products add column if not exists image_icon text;
alter table public.products add column if not exists plans jsonb not null default '[]'::jsonb;
alter table public.purchases add column if not exists quantity integer not null default 1;
alter table public.purchases add column if not exists duration integer;
create or replace function public.is_username_available(candidate text, requesting_user uuid default auth.uid()) returns boolean language sql stable security definer set search_path=public as $$ select candidate ~ '^[a-z0-9_]{3,24}$' and not exists(select 1 from public.profiles where lower(username)=lower(candidate) and id<>requesting_user); $$;
