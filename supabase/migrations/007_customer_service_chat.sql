DO $$ BEGIN alter type public.app_role add value if not exists 'customer_service'; EXCEPTION WHEN others THEN null; END $$;
-- Run the customer service section from full_setup.sql after this migration.
