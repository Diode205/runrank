-- Add membership_type column to user_profiles
-- Run this in Supabase SQL editor (or psql) on your project.

ALTER TABLE public.user_profiles
  ADD COLUMN IF NOT EXISTS membership_type text;

-- Restrict values to known tiers (allow NULL)
-- Note: this will fail if a constraint with the same name already exists.
ALTER TABLE public.user_profiles
  ADD CONSTRAINT membership_type_valid
  CHECK (
    membership_type IS NULL OR
    membership_type IN ('1st Claim','2nd Claim','Social','Full-Time Education')
  );
