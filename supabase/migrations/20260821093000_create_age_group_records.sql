-- Supplemental/historical Age-Group Records, mirroring club_records but
-- scoped per age category (e.g. "18-29", "Under35") so each age band can
-- have its own top-3 leaderboard, separate from the overall club record.
CREATE TABLE IF NOT EXISTS public.age_group_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  distance TEXT NOT NULL CHECK (distance IN ('5K', '5M', '10K', '10M', 'Half M', 'Marathon', '20M')),
  age_group TEXT NOT NULL,
  age_at_race INTEGER,
  gender TEXT NOT NULL CHECK (gender IN ('M', 'F')),
  time_seconds INTEGER NOT NULL,
  runner_name TEXT NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  club TEXT,
  race_name TEXT NOT NULL,
  race_date DATE NOT NULL,
  is_historical BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_age_group_records_lookup
  ON public.age_group_records(club, gender, distance, age_group, time_seconds);
CREATE INDEX IF NOT EXISTS idx_age_group_records_user ON public.age_group_records(user_id);

ALTER TABLE public.age_group_records ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can view age group records" ON public.age_group_records;
DROP POLICY IF EXISTS "Admins can insert age group records" ON public.age_group_records;
DROP POLICY IF EXISTS "Admins can update age group records" ON public.age_group_records;
DROP POLICY IF EXISTS "Admins can delete age group records" ON public.age_group_records;

CREATE POLICY "Anyone can view age group records"
  ON public.age_group_records
  FOR SELECT
  USING (true);

CREATE POLICY "Admins can insert age group records"
  ON public.age_group_records
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.user_profiles
      WHERE user_profiles.id = auth.uid()
        AND user_profiles.is_admin = true
    )
  );

CREATE POLICY "Admins can update age group records"
  ON public.age_group_records
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.user_profiles
      WHERE user_profiles.id = auth.uid()
        AND user_profiles.is_admin = true
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.user_profiles
      WHERE user_profiles.id = auth.uid()
        AND user_profiles.is_admin = true
    )
  );

CREATE POLICY "Admins can delete age group records"
  ON public.age_group_records
  FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.user_profiles
      WHERE user_profiles.id = auth.uid()
        AND user_profiles.is_admin = true
    )
  );

CREATE OR REPLACE FUNCTION update_age_group_records_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS age_group_records_updated_at ON public.age_group_records;

CREATE TRIGGER age_group_records_updated_at
  BEFORE UPDATE ON public.age_group_records
  FOR EACH ROW
  EXECUTE FUNCTION update_age_group_records_updated_at();
