-- ==============================================================================
-- Medical History Database Schema for Supabase
-- Project: https://fqcnpqrdxwttcxrcdnyg.supabase.co
-- ==============================================================================

-- 1. Enable UUID Extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. Profiles Table (linked with Supabase Auth users)
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT,
  full_name TEXT,
  avatar_url TEXT,
  phone TEXT,
  created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

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
  visit_date TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL,
  symptoms TEXT,
  diagnosis TEXT,
  treatment TEXT,
  notes TEXT,
  follow_up_date TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 7. Medications Table
CREATE TABLE IF NOT EXISTS public.medications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  visit_id UUID NOT NULL REFERENCES public.visits(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  dosage TEXT,
  frequency TEXT,
  duration TEXT,
  instructions TEXT,
  created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
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
ALTER TABLE public.med_files ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.appointments ENABLE ROW LEVEL SECURITY;

-- Profiles: Users can only read/update their own profile
CREATE POLICY "Users can view own profile" ON public.profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users can update own profile" ON public.profiles FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Users can insert own profile" ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id);

-- Families: Users manage only their own families
CREATE POLICY "Users manage own families" ON public.families FOR ALL USING (auth.uid() = user_id);

-- Members: Users manage members belonging to their families
CREATE POLICY "Users manage own family members" ON public.members FOR ALL USING (
  EXISTS (
    SELECT 1 FROM public.families
    WHERE families.id = members.family_id
      AND families.user_id = auth.uid()
  )
);

-- Doctors: Users manage only their own doctors
CREATE POLICY "Users manage own doctors" ON public.doctors FOR ALL USING (auth.uid() = user_id);

-- Visits: Users manage visits for their family members
CREATE POLICY "Users manage own visits" ON public.visits FOR ALL USING (
  EXISTS (
    SELECT 1 FROM public.members
    JOIN public.families ON families.id = members.family_id
    WHERE members.id = visits.member_id
      AND families.user_id = auth.uid()
  )
);

-- Medications: Users manage medications for visits of their members
CREATE POLICY "Users manage medications" ON public.medications FOR ALL USING (
  EXISTS (
    SELECT 1 FROM public.visits
    JOIN public.members ON members.id = visits.member_id
    JOIN public.families ON families.id = members.family_id
    WHERE visits.id = medications.visit_id
      AND families.user_id = auth.uid()
  )
);

-- Med Files: Users manage files for their family members
CREATE POLICY "Users manage med files" ON public.med_files FOR ALL USING (
  EXISTS (
    SELECT 1 FROM public.members
    JOIN public.families ON families.id = members.family_id
    WHERE members.id = med_files.member_id
      AND families.user_id = auth.uid()
  )
);

-- Appointments: Users manage their own appointments
CREATE POLICY "Users manage own appointments" ON public.appointments FOR ALL USING (auth.uid() = user_id);

-- ==============================================================================
-- Storage Buckets Setup
-- ==============================================================================
INSERT INTO storage.buckets (id, name, public)
VALUES 
  ('prescriptions', 'prescriptions', true),
  ('reports', 'reports', true),
  ('avatars', 'avatars', true)
ON CONFLICT (id) DO NOTHING;

-- Public read access for storage objects in these buckets
CREATE POLICY "Public Access Prescriptions" ON storage.objects FOR SELECT USING (bucket_id = 'prescriptions');
CREATE POLICY "Public Access Reports" ON storage.objects FOR SELECT USING (bucket_id = 'reports');
CREATE POLICY "Public Access Avatars" ON storage.objects FOR SELECT USING (bucket_id = 'avatars');

-- Authenticated upload access
CREATE POLICY "Authenticated users can upload objects" ON storage.objects FOR INSERT WITH CHECK (
  auth.role() = 'authenticated'
);
