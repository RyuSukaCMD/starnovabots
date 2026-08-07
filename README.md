# Starnova Bots

Landing page, store, authentication, dan admin workspace untuk layanan WhatsApp Bot Starnova.

Stack:

- Vite
- React 18
- React Router
- Supabase Auth
- Supabase PostgreSQL + Row Level Security
- Vercel
- CSS dan inline SVG

## 1. Prasyarat

Pastikan sudah terpasang:

- Node.js 18 atau lebih baru
- npm 9 atau lebih baru
- Akun GitHub
- Akun Supabase
- Akun Vercel

Cek versi:

```bash
node -v
npm -v
```

## 2. Clone repository

```bash
git clone https://github.com/RyuSukaCMD/starnovabots.git
cd starnovabots
```

Install dependency:

```bash
npm install
```

## 3. Buat project Supabase

1. Buka https://supabase.com/dashboard
2. Buat project baru.
3. Masuk ke **Project Settings → API**.
4. Salin:
   - Project URL
   - anon public key

Jangan gunakan `service_role key` di frontend.

## 4. Konfigurasi environment

Buat file `.env.local` di root project:

```env
VITE_SUPABASE_URL=https://YOUR_PROJECT.supabase.co
VITE_SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_KEY
```

File `.env.local` tidak boleh di-commit ke GitHub. File tersebut sudah masuk `.gitignore`.

## 5. Setup database Supabase

Untuk database baru:

1. Masuk ke Supabase Dashboard.
2. Buka **SQL Editor**.
3. Buka file `supabase/schema.sql`.
4. Copy seluruh isinya.
5. Paste ke SQL Editor.
6. Klik **Run**.

Schema membuat:

- `profiles`
- `products`
- `purchases`
- enum role
- enum status pembelian
- trigger profile otomatis setelah user dibuat
- Row Level Security
- policy user dan owner
- data produk awal

Untuk project Supabase yang sudah menggunakan schema lama, jalankan juga:

```text
supabase/migrations/001_add_roles.sql
```

## 6. Role user

Role yang digunakan:

```text
owner
user
jadibot
scriptbuyer
sewa
```

Role legacy yang masih dikenali untuk migrasi lama:

```text
admin
support
```

Hanya role `owner` yang dapat membuka:

```text
/admin
```

Setelah membuat akun owner melalui Sign Up, jalankan query ini di Supabase SQL Editor:

```sql
update public.profiles
set role = 'owner'
where email = 'email-owner@example.com';
```

Verifikasi:

```sql
select id, email, name, role
from public.profiles
where email = 'email-owner@example.com';
```

## 7. Aktifkan login OTP Email

Di Supabase:

1. Buka **Authentication → Providers**.
2. Aktifkan **Email**.
3. Atur email confirmation sesuai kebutuhan.
4. Pastikan SMTP production dikonfigurasi jika ingin mengirim email ke user nyata.

Flow aplikasi:

1. User membuka `/login`.
2. User memasukkan email.
3. Supabase mengirim OTP.
4. User memasukkan 6 digit OTP.
5. Session disimpan oleh Supabase.

## 8. Aktifkan Google OAuth

### Google Cloud Console

1. Buka https://console.cloud.google.com
2. Buat atau pilih project.
3. Buka **APIs & Services → OAuth consent screen**.
4. Konfigurasi consent screen.
5. Buka **Credentials → Create Credentials → OAuth client ID**.
6. Pilih **Web application**.
7. Tambahkan authorized redirect URI:

```text
https://YOUR_PROJECT.supabase.co/auth/v1/callback
```

8. Salin Client ID dan Client Secret.

### Supabase

1. Buka **Authentication → Providers → Google**.
2. Aktifkan Google.
3. Masukkan Client ID dan Client Secret.
4. Simpan konfigurasi.

### URL aplikasi

Buka **Authentication → URL Configuration** dan tambahkan:

```text
http://localhost:5173/login
http://localhost:5173/signup
https://YOUR_VERCEL_DOMAIN.vercel.app/login
https://YOUR_VERCEL_DOMAIN.vercel.app/signup
```

Jika memakai custom domain, tambahkan juga:

```text
https://domainmu.com/login
https://domainmu.com/signup
```

## 9. Username user

Setelah login, user yang belum memiliki username akan melihat modal:

```text
Bagaimana kami memanggilmu?
```

Username disimpan ke:

```text
public.profiles.name
```

Username tersebut digunakan untuk greeting personal, misalnya:

```text
Selamat datang kembali, Raka.
```

Untuk Google OAuth, nama dari metadata Google digunakan jika tersedia. Jika tidak tersedia, user diminta melengkapi username secara manual.

## 10. Jalankan lokal

```bash
npm run dev
```

Buka:

```text
http://localhost:5173
```

Route utama:

```text
/          Landing page dan store
/login     Sign In dengan OTP atau Google
/signup    Sign Up dengan OTP atau Google
/admin     Admin panel owner
```

Route yang tidak dikenal akan menampilkan custom 404.

## 11. Build production

```bash
npm run build
```

Preview hasil build:

```bash
npm run preview
```

## 12. Deploy ke Vercel

### Melalui dashboard

1. Buka https://vercel.com/new
2. Import repository `RyuSukaCMD/starnovabots`.
3. Framework akan terdeteksi sebagai Vite.
4. Tambahkan environment variables:

```env
VITE_SUPABASE_URL=https://YOUR_PROJECT.supabase.co
VITE_SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_KEY
```

5. Klik **Deploy**.
6. Salin domain Vercel.
7. Tambahkan domain tersebut ke Supabase Authentication URL Configuration.
8. Tambahkan callback Google OAuth sesuai project Supabase.

### Melalui Vercel CLI

```bash
npm install -g vercel
vercel login
vercel
vercel --prod
```

`vercel.json` sudah tersedia untuk SPA rewrite.

## 13. Produk dan order

Produk dikelola dari tabel:

```text
public.products
```

Order disimpan ke:

```text
public.purchases
```

Kolom penting order:

- `id`
- `user_id`
- `product_id`
- `product_name`
- `amount`
- `status`
- `created_at`

Status order:

```text
pending
paid
active
cancelled
```

User hanya dapat melihat order miliknya sendiri. Owner dapat melihat dan mengelola data order melalui RLS.

## 14. Payment gateway

Saat ini flow pembelian sudah membuat record order ke database. Payment gateway belum diaktifkan karena membutuhkan credential merchant.

Untuk production payment, tambahkan backend/serverless function yang memvalidasi webhook dari Midtrans atau Xendit. Jangan pernah menaruh secret key payment gateway di frontend atau pada variable `VITE_*`.

Secret yang hanya boleh ada di server:

```env
MIDTRANS_SERVER_KEY=...
XENDIT_SECRET_KEY=...
```

## 15. Security checklist

Sebelum production:

- Isi `.env.local` hanya di lokal.
- Tambahkan environment variable di Vercel.
- Jangan commit `.env` atau `.env.local`.
- Jangan expose Supabase `service_role key`.
- Jalankan SQL schema dan migration.
- Pastikan akun owner sudah dipromosikan.
- Pastikan Google OAuth redirect URI benar.
- Pastikan RLS aktif pada semua tabel.
- Gunakan SMTP production untuk OTP.
- Tambahkan payment webhook server-side jika memakai payment gateway.
- Revoke Personal Access Token GitHub yang sudah tidak digunakan.

## 16. Struktur project

```text
.
├── index.html
├── package.json
├── vite.config.js
├── vercel.json
├── .env.example
├── src
│   ├── App.jsx
│   ├── LegacyPages.jsx
│   ├── app.css
│   ├── main.jsx
│   ├── auth
│   │   └── AuthContext.jsx
│   └── lib
│       └── supabase.js
├── supabase
│   ├── schema.sql
│   └── migrations
│       └── 001_add_roles.sql
├── legacy-landing.html
├── legacy-admin.html
├── legacy-styles.css
└── legacy-admin.css
```

## 17. Git workflow

```bash
git status
git add .
git commit -m "describe your change"
git push origin main
```

Repository production:

```text
https://github.com/RyuSukaCMD/starnovabots
```
