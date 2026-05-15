begin;

-- Supabase Data API release hardening.
--
-- Existing projects historically exposed public tables to PostgREST through
-- implicit grants. Newer Supabase projects require explicit grants. These
-- grants preserve authenticated app access while RLS policies remain the
-- actual row-level enforcement layer.

grant usage on schema public to anon, authenticated;

grant select, insert, update, delete
  on all tables in schema public
  to authenticated;

grant usage, select
  on all sequences in schema public
  to authenticated;

alter default privileges in schema public
  grant select, insert, update, delete on tables to authenticated;

alter default privileges in schema public
  grant usage, select on sequences to authenticated;

-- Pre-login registration needs the club list, and invite validation is exposed
-- only through a security-definer RPC that returns a row only on an exact match.
grant select on table public.app_clubs to anon;

grant execute on function public.validate_club_member_invite(text, text, text)
  to anon, authenticated;

grant execute on function public.claim_club_member_invite(uuid)
  to authenticated;

commit;
