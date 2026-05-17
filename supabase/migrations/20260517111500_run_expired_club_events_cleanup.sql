begin;

create or replace function public.run_expired_club_events_cleanup()
returns integer
language sql
security definer
set search_path = public
as $$
  select public.cleanup_expired_club_events(current_date, interval '24 hours');
$$;

grant execute on function public.run_expired_club_events_cleanup()
  to authenticated;

-- Run once when this migration is applied so existing old/cancelled rows are
-- cleared immediately, not only the next time the app opens Club Hub.
select public.run_expired_club_events_cleanup();

commit;
