# Starnova Platform

Production-ready React/Vite foundation for Starnova, deployable to Vercel, with Supabase Auth, database, role-based access, purchases, and an admin workspace.

## Run locally

```bash
npm install
cp .env.example .env.local
npm run dev
```

## Supabase setup

1. Create a Supabase project.
2. Open SQL Editor and run `supabase/schema.sql`.
3. Create the first account from `/login`.
4. Promote that account to owner:

```sql
update public.profiles set role = 'owner' where email = 'your-email@example.com';
```

5. Add the environment variables from `.env.example`.

The role model is `user`, `support`, `admin`, and `owner`. Only `admin` and `owner` can access `/admin`; all sensitive access is enforced again by Supabase RLS, not only by the frontend.

## Vercel

Import this repository into Vercel. The included `vercel.json` handles SPA routes. Add the same environment variables in Vercel Project Settings.

## Environment

- `VITE_SUPABASE_URL`
- `VITE_SUPABASE_ANON_KEY`

The existing visual work is preserved in `legacy-landing.html`, `legacy-admin.html`, `legacy-styles.css`, and `legacy-admin.css`. The Vite app uses a React implementation with the same Starnova visual language and responsive behavior.
