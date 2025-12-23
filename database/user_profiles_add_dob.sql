-- Add date_of_birth column to user_profiles
-- Run in Supabase SQL editor.

ALTER TABLE public.user_profiles
  ADD COLUMN IF NOT EXISTS date_of_birth text;
