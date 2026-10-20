-- ==============================================================================
-- Medical History Database Schema for Supabase
-- Project: https://fqcnpqrdxwttcxrcdnyg.supabase.co
-- ==============================================================================

-- 1. Enable UUID Extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 2. Profiles Table (linked with Supabase Auth users)
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT,
  full_name TEXT,
  avatar_url TEXT,
  phone TEXT,
  is_admin BOOLEAN DEFAULT false NOT NULL,
  created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS is_admin BOOLEAN DEFAULT false NOT NULL;

CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(
    (SELECT profiles.is_admin FROM public.profiles WHERE profiles.id = auth.uid()),
    false
  );
$$;

REVOKE ALL ON FUNCTION public.is_admin() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated;

CREATE OR REPLACE FUNCTION public.protect_admin_flag()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NOT NULL
      AND NEW.is_admin IS DISTINCT FROM OLD.is_admin
      AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'Only an administrator can change administrator access';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS protect_profile_admin_flag ON public.profiles;
CREATE TRIGGER protect_profile_admin_flag
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.protect_admin_flag();

-- Trigger to automatically create a profile row when a new user signs up
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name, avatar_url)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(NEW.email, '@', 1)),
    NEW.raw_user_meta_data->>'avatar_url'
  )
  ON CONFLICT (id) DO UPDATE
  SET email = EXCLUDED.email,
      full_name = COALESCE(EXCLUDED.full_name, profiles.full_name),
      updated_at = timezone('utc'::text, now());
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 3. Families Table
CREATE TABLE IF NOT EXISTS public.families (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  family_id TEXT NOT NULL,
  name TEXT NOT NULL,
  contact TEXT,
  address TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 4. Members Table
CREATE TABLE IF NOT EXISTS public.members (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  family_id UUID NOT NULL REFERENCES public.families(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  relation TEXT NOT NULL,
  dob DATE,
  gender TEXT,
  blood_group TEXT,
  allergies TEXT,
  notes TEXT,
  avatar_url TEXT,
  created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 5. Doctors Table
CREATE TABLE IF NOT EXISTS public.doctors (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  specialization TEXT,
  hospital TEXT,
  phone TEXT,
  address TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 6. Visits Table
CREATE TABLE IF NOT EXISTS public.visits (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  member_id UUID NOT NULL REFERENCES public.members(id) ON DELETE CASCADE,
  doctor_id UUID REFERENCES public.doctors(id) ON DELETE SET NULL,
  doctor_name TEXT,
  hospital TEXT,
  visit_date TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL,
  symptoms TEXT,
  diagnosis TEXT,
  treatment TEXT,
  notes TEXT,
  follow_up_date TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Ensure columns exist if table was already created
ALTER TABLE public.visits ADD COLUMN IF NOT EXISTS doctor_name TEXT;
ALTER TABLE public.visits ADD COLUMN IF NOT EXISTS hospital TEXT;
ALTER TABLE public.members ADD COLUMN IF NOT EXISTS avatar_url TEXT;
ALTER TABLE public.members ADD COLUMN IF NOT EXISTS emergency_contact TEXT;
ALTER TABLE public.members ADD COLUMN IF NOT EXISTS parent_id UUID REFERENCES public.members(id) ON DELETE SET NULL;
ALTER TABLE public.doctors ADD COLUMN IF NOT EXISTS availability TEXT;
ALTER TABLE public.doctors ADD COLUMN IF NOT EXISTS is_favorite BOOLEAN DEFAULT false NOT NULL;

-- Doctors assigned to a member independently of a visit.
CREATE TABLE IF NOT EXISTS public.member_doctors (
  member_id UUID NOT NULL REFERENCES public.members(id) ON DELETE CASCADE,
  doctor_id UUID NOT NULL REFERENCES public.doctors(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL,
  PRIMARY KEY (member_id, doctor_id)
);

-- Revocable, expiring read-only member share links. Store only a hash of the token.
CREATE TABLE IF NOT EXISTS public.member_share_links (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  member_id UUID NOT NULL REFERENCES public.members(id) ON DELETE CASCADE,
  owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  token_hash TEXT NOT NULL UNIQUE,
  scope JSONB NOT NULL DEFAULT '{"profile": true, "visits": true, "documents": true}'::jsonb,
  expires_at TIMESTAMPTZ NOT NULL,
  revoked_at TIMESTAMPTZ,
  last_accessed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Resolve a share token without exposing the token hash or requiring the viewer
-- to have an account. Tokens are short-lived and can be revoked by the owner.
CREATE OR REPLACE FUNCTION public.get_shared_member_record(p_token TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  link_row public.member_share_links;
  result JSONB;
BEGIN
  SELECT * INTO link_row
  FROM public.member_share_links
  WHERE token_hash = encode(digest(trim(p_token), 'sha256'), 'hex')
    AND revoked_at IS NULL
    AND expires_at > now()
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  UPDATE public.member_share_links
  SET last_accessed_at = now()
  WHERE id = link_row.id;

  SELECT jsonb_build_object(
    'member', CASE WHEN COALESCE((link_row.scope->>'profile')::boolean, false)
      THEN to_jsonb(m) - 'family_id' - 'user_id' ELSE '{}'::jsonb END,
    'visits', CASE WHEN COALESCE((link_row.scope->>'visits')::boolean, false)
      THEN COALESCE((
        SELECT jsonb_agg((to_jsonb(v) - 'member_id' - 'user_id') ORDER BY v.visit_date DESC)
        FROM public.visits v WHERE v.member_id = m.id
      ), '[]'::jsonb) ELSE '[]'::jsonb END,
    'documents', CASE WHEN COALESCE((link_row.scope->>'documents')::boolean, false)
      THEN COALESCE((
        SELECT jsonb_agg((to_jsonb(f) - 'file_url' - 'member_id') ORDER BY f.created_at DESC)
        FROM public.med_files f WHERE f.member_id = m.id
      ), '[]'::jsonb) ELSE '[]'::jsonb END
  ) INTO result
  FROM public.members m
  WHERE m.id = link_row.member_id;

  RETURN result;
END;
$$;

REVOKE ALL ON FUNCTION public.get_shared_member_record(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_shared_member_record(TEXT) TO anon, authenticated;

-- Allows an authenticated user to permanently remove their own account.
CREATE OR REPLACE FUNCTION public.delete_my_account()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
  DELETE FROM auth.users WHERE id = auth.uid();
END;
$$;

REVOKE ALL ON FUNCTION public.delete_my_account() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.delete_my_account() TO authenticated;

-- 7. Medications Table
CREATE TABLE IF NOT EXISTS public.medications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  visit_id UUID REFERENCES public.visits(id) ON DELETE CASCADE,
  member_id UUID REFERENCES public.members(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  dosage TEXT,
  frequency TEXT,
  timing TEXT,
  duration TEXT,
  instructions TEXT,
  notes TEXT,
  is_active BOOLEAN DEFAULT true NOT NULL,
  taken_today BOOLEAN DEFAULT false NOT NULL,
  created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.medications ADD COLUMN IF NOT EXISTS member_id UUID REFERENCES public.members(id) ON DELETE CASCADE;
ALTER TABLE public.medications ALTER COLUMN visit_id DROP NOT NULL;
ALTER TABLE public.medications ADD COLUMN IF NOT EXISTS timing TEXT;
ALTER TABLE public.medications ADD COLUMN IF NOT EXISTS notes TEXT;
ALTER TABLE public.medications ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true NOT NULL;
ALTER TABLE public.medications ADD COLUMN IF NOT EXISTS taken_today BOOLEAN DEFAULT false NOT NULL;

-- 7b. Vitals and vaccine records
CREATE TABLE IF NOT EXISTS public.vitals (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  member_id UUID NOT NULL REFERENCES public.members(id) ON DELETE CASCADE,
  type TEXT NOT NULL,
  value TEXT NOT NULL,
  unit TEXT NOT NULL,
  recorded_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL,
  notes TEXT,
  status TEXT DEFAULT 'Normal' NOT NULL
);

CREATE TABLE IF NOT EXISTS public.vaccines (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  member_id UUID NOT NULL REFERENCES public.members(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  dose TEXT,
  administered_date DATE DEFAULT CURRENT_DATE NOT NULL,
  next_due_date DATE,
  administered_by TEXT,
  notes TEXT,
  status TEXT DEFAULT 'Completed' NOT NULL
);

-- 8. Medical Files / Documents Table
CREATE TABLE IF NOT EXISTS public.med_files (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  member_id UUID NOT NULL REFERENCES public.members(id) ON DELETE CASCADE,
  visit_id UUID REFERENCES public.visits(id) ON DELETE SET NULL,
  file_url TEXT NOT NULL,
  file_type TEXT NOT NULL,
  file_size INTEGER,
  description TEXT,
  created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.med_files ADD COLUMN IF NOT EXISTS file_hash TEXT;
ALTER TABLE public.med_files ADD COLUMN IF NOT EXISTS ocr_text TEXT;

-- 9. Appointments Table
CREATE TABLE IF NOT EXISTS public.appointments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  member_id UUID REFERENCES public.members(id) ON DELETE CASCADE,
  doctor_id UUID REFERENCES public.doctors(id) ON DELETE SET NULL,
  doctor_name TEXT NOT NULL,
  specialty TEXT,
  hospital TEXT,
  appointment_time TIMESTAMPTZ NOT NULL,
  status TEXT DEFAULT 'upcoming',
  reminder_set BOOLEAN DEFAULT true,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- ==============================================================================
-- Row Level Security (RLS) Policies
-- ==============================================================================

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.families ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.doctors ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.visits ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.medications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vitals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vaccines ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.med_files ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.appointments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.member_share_links ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.member_doctors ENABLE ROW LEVEL SECURITY;

-- Profiles: Users can only read/update their own profile
DROP POLICY IF EXISTS "Users can view own profile" ON public.profiles;
CREATE POLICY "Users can view own profile" ON public.profiles FOR SELECT USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
CREATE POLICY "Users can update own profile" ON public.profiles FOR UPDATE USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can insert own profile" ON public.profiles;
CREATE POLICY "Users can insert own profile" ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "Admins can view profiles" ON public.profiles;
CREATE POLICY "Admins can view profiles" ON public.profiles FOR SELECT USING (public.is_admin());

DROP POLICY IF EXISTS "Admins can update profiles" ON public.profiles;
CREATE POLICY "Admins can update profiles" ON public.profiles
FOR UPDATE USING (public.is_admin()) WITH CHECK (public.is_admin());

-- Families: Users manage only their own families
DROP POLICY IF EXISTS "Users manage own families" ON public.families;
CREATE POLICY "Users manage own families" ON public.families FOR ALL USING (auth.uid() = user_id);

-- Members: Users manage members belonging to their families
DROP POLICY IF EXISTS "Users manage own family members" ON public.members;
CREATE POLICY "Users manage own family members" ON public.members FOR ALL USING (
  EXISTS (
    SELECT 1 FROM public.families
    WHERE families.id = members.family_id
      AND families.user_id = auth.uid()
  )
);

-- Doctors: Users manage only their own doctors
DROP POLICY IF EXISTS "Users manage own doctors" ON public.doctors;
CREATE POLICY "Users manage own doctors" ON public.doctors FOR ALL USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users manage member doctors" ON public.member_doctors;
CREATE POLICY "Users manage member doctors" ON public.member_doctors FOR ALL USING (
  EXISTS (
    SELECT 1 FROM public.members
    JOIN public.families ON families.id = members.family_id
    WHERE members.id = member_doctors.member_id
      AND families.user_id = auth.uid()
  )
  AND EXISTS (
    SELECT 1 FROM public.doctors
    WHERE doctors.id = member_doctors.doctor_id
      AND doctors.user_id = auth.uid()
  )
) WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.members
    JOIN public.families ON families.id = members.family_id
    WHERE members.id = member_doctors.member_id
      AND families.user_id = auth.uid()
  )
  AND EXISTS (
    SELECT 1 FROM public.doctors
    WHERE doctors.id = member_doctors.doctor_id
      AND doctors.user_id = auth.uid()
  )
);

-- Visits: Users manage visits for their family members
DROP POLICY IF EXISTS "Users manage own visits" ON public.visits;
CREATE POLICY "Users manage own visits" ON public.visits FOR ALL USING (
  EXISTS (
    SELECT 1 FROM public.members
    JOIN public.families ON families.id = members.family_id
    WHERE members.id = visits.member_id
      AND families.user_id = auth.uid()
  )
);

-- Medications: Users manage medications for visits of their members
DROP POLICY IF EXISTS "Users manage medications" ON public.medications;
CREATE POLICY "Users manage medications" ON public.medications FOR ALL USING (
  EXISTS (
    SELECT 1 FROM public.visits
    JOIN public.members ON members.id = visits.member_id
    JOIN public.families ON families.id = members.family_id
    WHERE visits.id = medications.visit_id
      AND families.user_id = auth.uid()
  )
  OR EXISTS (
    SELECT 1 FROM public.members
    JOIN public.families ON families.id = members.family_id
    WHERE members.id = medications.member_id
      AND families.user_id = auth.uid()
  )
);

DROP POLICY IF EXISTS "Users manage member vitals" ON public.vitals;
CREATE POLICY "Users manage member vitals" ON public.vitals FOR ALL USING (
  EXISTS (
    SELECT 1 FROM public.members
    JOIN public.families ON families.id = members.family_id
    WHERE members.id = vitals.member_id
      AND families.user_id = auth.uid()
  )
);

DROP POLICY IF EXISTS "Users manage member vaccines" ON public.vaccines;
CREATE POLICY "Users manage member vaccines" ON public.vaccines FOR ALL USING (
  EXISTS (
    SELECT 1 FROM public.members
    JOIN public.families ON families.id = members.family_id
    WHERE members.id = vaccines.member_id
      AND families.user_id = auth.uid()
  )
);

-- Med Files: Users manage files for their family members
DROP POLICY IF EXISTS "Users manage med files" ON public.med_files;
CREATE POLICY "Users manage med files" ON public.med_files FOR ALL USING (
  EXISTS (
    SELECT 1 FROM public.members
    JOIN public.families ON families.id = members.family_id
    WHERE members.id = med_files.member_id
      AND families.user_id = auth.uid()
  )
);

-- Appointments: Users manage their own appointments
DROP POLICY IF EXISTS "Users manage own appointments" ON public.appointments;
CREATE POLICY "Users manage own appointments" ON public.appointments FOR ALL USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users manage own member share links" ON public.member_share_links;
CREATE POLICY "Users manage own member share links" ON public.member_share_links
FOR ALL USING (auth.uid() = owner_id) WITH CHECK (auth.uid() = owner_id);

DROP POLICY IF EXISTS "Admins manage families" ON public.families;
CREATE POLICY "Admins manage families" ON public.families FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Admins manage members" ON public.members;
CREATE POLICY "Admins manage members" ON public.members FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Admins manage doctors" ON public.doctors;
CREATE POLICY "Admins manage doctors" ON public.doctors FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Admins manage visits" ON public.visits;
CREATE POLICY "Admins manage visits" ON public.visits FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Admins manage medications" ON public.medications;
CREATE POLICY "Admins manage medications" ON public.medications FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Admins manage vitals" ON public.vitals;
CREATE POLICY "Admins manage vitals" ON public.vitals FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Admins manage vaccines" ON public.vaccines;
CREATE POLICY "Admins manage vaccines" ON public.vaccines FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Admins manage med files" ON public.med_files;
CREATE POLICY "Admins manage med files" ON public.med_files FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Admins manage appointments" ON public.appointments;
CREATE POLICY "Admins manage appointments" ON public.appointments FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

-- ==============================================================================
-- Optional Supabase Storage Setup (Note: Cloudinary handles images & avatars)
-- ==============================================================================
DO $$
BEGIN
  INSERT INTO storage.buckets (id, name, public)
  VALUES
    ('prescriptions', 'prescriptions', false),
    ('reports', 'reports', false),
    ('avatars', 'avatars', true)
  ON CONFLICT (id) DO UPDATE SET public = EXCLUDED.public;
EXCEPTION WHEN OTHERS THEN
  NULL; -- Ignore if storage permissions differ
END $$;

DROP POLICY IF EXISTS "Users upload own medical objects" ON storage.objects;
CREATE POLICY "Users upload own medical objects" ON storage.objects
FOR INSERT TO authenticated
WITH CHECK (
  bucket_id IN ('prescriptions', 'reports', 'avatars')
  AND (storage.foldername(name))[1] = auth.uid()::text
);

DROP POLICY IF EXISTS "Users view own medical objects" ON storage.objects;
CREATE POLICY "Users view own medical objects" ON storage.objects
FOR SELECT TO authenticated
USING (
  bucket_id IN ('prescriptions', 'reports', 'avatars')
  AND (storage.foldername(name))[1] = auth.uid()::text
);

DROP POLICY IF EXISTS "Users delete own medical objects" ON storage.objects;
CREATE POLICY "Users delete own medical objects" ON storage.objects
FOR DELETE TO authenticated
USING (
  bucket_id IN ('prescriptions', 'reports', 'avatars')
  AND (storage.foldername(name))[1] = auth.uid()::text
);
