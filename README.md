# Medical History

Family medical-history platform with a Flutter client, a Next.js administrator console, and Supabase persistence.

## Features

- Family and member profiles
- Doctors, visits, medication records, and medical documents
- Appointments with persistent Supabase storage
- Email/password, Google, and biometric authentication
- Local-first medical document storage and viewing
- Google Drive backup/restore with optional Cloudinary fallback
- Role-protected web administrator console

## Project structure

- `lib/` — Flutter application
- `admin_panel/` — Next.js administrator console
- `supabase_schema.sql` — database, RLS, admin, and storage policies
- `test/` — Flutter tests

## Supabase setup

1. Create a Supabase project.
2. Run `supabase_schema.sql` in the Supabase SQL editor.
3. Create an application user, then grant the intended console account admin access:

```sql
UPDATE public.profiles
SET is_admin = true
WHERE email = 'admin@example.com';
```

Only accounts with `profiles.is_admin = true` can enter the admin console or read cross-user data.

## Flutter configuration

Run with compile-time configuration instead of committing credentials:

```powershell
flutter run `
  --dart-define=SUPABASE_URL=https://your-project.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=your-publishable-anon-key `
  --dart-define=CLOUDINARY_CLOUD_NAME=your-cloud-name `
  --dart-define=CLOUDINARY_UPLOAD_PRESET=your-unsigned-upload-preset `
  --dart-define=GOOGLE_WEB_CLIENT_ID=your-web-oauth-client-id.apps.googleusercontent.com
```

When Supabase variables are absent, the app uses its local mock repository.

Medical PDFs and images are saved in the app's private local documents
directory. If Google Drive is connected, they are embedded in the next Drive
backup. Otherwise, the app attempts a Cloudinary upload using the unsigned
upload preset. Keep that preset restricted to the
`medical_history/documents` folder and configure Cloudinary access controls
appropriate for sensitive health records.

For Android Google Sign-In, create an Android OAuth client for
`com.medicalhistory.app` with the SHA-1 of every signing certificate. Pass
the separate **Web application** OAuth client ID as `GOOGLE_WEB_CLIENT_ID`
and configure that same Web client ID and secret in Supabase.

## Admin console

```powershell
Copy-Item admin_panel/.env.example admin_panel/.env.local
cd admin_panel
npm install
npm run dev
```

Fill `admin_panel/.env.local` before starting. Never expose a Supabase service-role key in `NEXT_PUBLIC_*` variables.

## Validation

```powershell
flutter analyze
flutter test
cd admin_panel
npm run build
```
