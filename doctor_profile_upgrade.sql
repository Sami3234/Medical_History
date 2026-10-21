-- Run this once in Supabase SQL Editor.
-- Adds editable professional profile fields without deleting existing data.

ALTER TABLE public.doctors
  ADD COLUMN IF NOT EXISTS avatar_url TEXT,
  ADD COLUMN IF NOT EXISTS email TEXT,
  ADD COLUMN IF NOT EXISTS qualification TEXT,
  ADD COLUMN IF NOT EXISTS license_number TEXT,
  ADD COLUMN IF NOT EXISTS experience_years INTEGER,
  ADD COLUMN IF NOT EXISTS notes TEXT,
  ADD COLUMN IF NOT EXISTS availability TEXT,
  ADD COLUMN IF NOT EXISTS is_favorite BOOLEAN DEFAULT false NOT NULL;

ALTER TABLE public.doctors
  DROP CONSTRAINT IF EXISTS doctors_experience_years_range;

ALTER TABLE public.doctors
  ADD CONSTRAINT doctors_experience_years_range
  CHECK (
    experience_years IS NULL OR
    (experience_years >= 0 AND experience_years <= 80)
  );

CREATE INDEX IF NOT EXISTS doctors_user_name_idx
  ON public.doctors (user_id, name);

CREATE INDEX IF NOT EXISTS doctors_user_specialization_idx
  ON public.doctors (user_id, specialization);

