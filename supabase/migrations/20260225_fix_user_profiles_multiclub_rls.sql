-- Fix user_profiles SELECT policy to avoid infinite recursion
-- The previous "Users can view profiles in their club" policy
-- referenced user_profiles inside its USING clause, which causes
-- Postgres error 42P17 (infinite recursion detected in policy).

BEGIN;

ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;

-- Drop the recursive SELECT policy if present
DROP POLICY IF EXISTS "Users can view profiles in their club" ON public.user_profiles;

-- Restore a simple, non-recursive SELECT policy.
-- This allows any authenticated user to read profiles, while
-- other policies still control who can update rows.
CREATE POLICY "Anyone can view user profiles"
  ON public.user_profiles
  FOR SELECT
  USING (true);

COMMIT;
