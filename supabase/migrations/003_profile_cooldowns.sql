alter table public.profiles add column if not exists username_changed_at timestamptz;
alter table public.profiles add column if not exists nickname_changed_at timestamptz;
-- Run the update_profile_identity function section from full_setup.sql after this migration.
