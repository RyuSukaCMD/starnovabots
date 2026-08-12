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
alter table public.purchases add column if not exists sub_product_id uuid references public.sub_products(id);
