-- Run this migration for an existing Supabase project.
-- New installs should run supabase/schema.sql instead.
alter type public.app_role add value if not exists 'jadibot';
alter type public.app_role add value if not exists 'scriptbuyer';
alter type public.app_role add value if not exists 'sewa';
create or replace function public.is_staff() returns boolean language sql stable security definer set search_path = public as $$ select exists(select 1 from public.profiles where id=auth.uid() and role = 'owner'); $$;
