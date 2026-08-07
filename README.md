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

Login production memakai dua opsi: OTP email dan Google OAuth. Aktifkan Email provider di Supabase Auth, lalu aktifkan Google provider dan isi Client ID/Secret di Supabase. Tambahkan URL callback `https://domainmu.com/login` dan URL preview/local yang digunakan ke Authentication > URL Configuration. Tidak ada password yang dikelola oleh UI. Role model adalah `owner`, `user`, `jadibot`, `scriptbuyer`, dan `sewa` (role legacy `admin`/`support` tetap dikenali untuk migrasi). Hanya `owner` dapat mengakses `/admin`; semua akses sensitif tetap ditegakkan oleh Supabase RLS, bukan hanya frontend. User tanpa username akan diminta mengisi username setelah login, lalu nilainya disimpan ke `profiles.name` dan dipakai untuk sapaan personal.

## Vercel

Import this repository into Vercel. The included `vercel.json` handles SPA routes. Add the same environment variables in Vercel Project Settings.

## Environment

- `VITE_SUPABASE_URL`
- `VITE_SUPABASE_ANON_KEY`

The existing visual work is preserved in `legacy-landing.html`, `legacy-admin.html`, `legacy-styles.css`, and `legacy-admin.css`. The Vite app uses a React implementation with the same Starnova visual language and responsive behavior.
