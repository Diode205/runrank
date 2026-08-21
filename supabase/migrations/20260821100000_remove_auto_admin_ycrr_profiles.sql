-- Reverts 20260612101000_auto_admin_ycrr_profiles.sql: new members (including
-- YCRR demo club signups) should default to non-admin like any other club.
-- Only an existing App Admin can grant the admin role via Admin Team.
drop trigger if exists set_ycrr_profile_admin_trigger on public.user_profiles;
drop function if exists public.set_ycrr_profile_admin();
