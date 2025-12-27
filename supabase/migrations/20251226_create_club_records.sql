-- Create club_records table to track top performances
-- This table stores the official club records for each distance

CREATE TABLE IF NOT EXISTS public.club_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  distance TEXT NOT NULL CHECK (distance IN ('5K', '5M', '10K', '10M', 'Half M', 'Marathon')),
  time_seconds INTEGER NOT NULL,
  runner_name TEXT NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  race_name TEXT NOT NULL,
  race_date DATE NOT NULL,
  is_historical BOOLEAN DEFAULT false, -- for old records by non-members
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_club_records_distance ON public.club_records(distance);
CREATE INDEX IF NOT EXISTS idx_club_records_time ON public.club_records(distance, time_seconds);
CREATE INDEX IF NOT EXISTS idx_club_records_user ON public.club_records(user_id);

-- Enable RLS
ALTER TABLE public.club_records ENABLE ROW LEVEL SECURITY;

-- Policy: Everyone can view records
CREATE POLICY "Anyone can view club records"
  ON public.club_records
  FOR SELECT
  USING (true);

-- Policy: Only admins can insert records
CREATE POLICY "Admins can insert club records"
  ON public.club_records
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.user_profiles
      WHERE user_profiles.id = auth.uid()
        AND user_profiles.is_admin = true
    )
  );

-- Policy: Only admins can update records
CREATE POLICY "Admins can update club records"
  ON public.club_records
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

-- Policy: Only admins can delete records
CREATE POLICY "Admins can delete club records"
  ON public.club_records
  FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.user_profiles
      WHERE user_profiles.id = auth.uid()
        AND user_profiles.is_admin = true
    )
  );

-- Function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_club_records_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER club_records_updated_at
  BEFORE UPDATE ON public.club_records
  FOR EACH ROW
  EXECUTE FUNCTION update_club_records_updated_at();
