-- Add gender column to user_profiles
-- Run in Supabase SQL editor.

ALTER TABLE public.user_profiles
  ADD COLUMN IF NOT EXISTS gender text;
