alter table public.redeem_codes add column if not exists min_order_amount numeric(12,2) not null default 0;
alter table public.redeem_codes add column if not exists never_expires boolean not null default false;
-- Run the latest validate_redeem_code section from full_setup.sql after this migration.
alter table public.redeem_codes add column if not exists max_accounts integer;

alter table public.redeem_codes add column if not exists max_account_age_days integer;
