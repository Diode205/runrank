begin;

create or replace function public.cleanup_expired_club_events(
  p_finished_before date default current_date,
  p_cancelled_grace interval default interval '24 hours'
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  deleted_count integer := 0;
begin
  create temporary table if not exists expired_club_event_ids (
    id uuid primary key
  ) on commit drop;

  truncate table expired_club_event_ids;

  insert into expired_club_event_ids (id)
  select ce.id
  from public.club_events ce
  where ce.date < p_finished_before
     or (
       coalesce(ce.is_cancelled, false) = true
       and coalesce(ce.cancelled_at, ce.created_at, now()) + p_cancelled_grace < now()
     )
  on conflict (id) do nothing;

  if not exists (select 1 from expired_club_event_ids) then
    return 0;
  end if;

  if to_regclass('public.event_comment_reactions') is not null
     and to_regclass('public.event_comments') is not null then
    delete from public.event_comment_reactions ecr
    using public.event_comments ec, expired_club_event_ids expired
    where ecr.comment_id = ec.id
      and ec.event_id = expired.id;
  end if;

  if to_regclass('public.event_host_message_reactions') is not null
     and to_regclass('public.event_host_messages') is not null then
    delete from public.event_host_message_reactions ehmr
    using public.event_host_messages ehm, expired_club_event_ids expired
    where ehmr.message_id = ehm.id
      and ehm.event_id = expired.id;
  end if;

  if to_regclass('public.event_comments') is not null then
    delete from public.event_comments ec
    using expired_club_event_ids expired
    where ec.event_id = expired.id;
  end if;

  if to_regclass('public.event_host_messages') is not null then
    delete from public.event_host_messages ehm
    using expired_club_event_ids expired
    where ehm.event_id = expired.id;
  end if;

  if to_regclass('public.club_event_responses') is not null then
    delete from public.club_event_responses cer
    using expired_club_event_ids expired
    where cer.event_id = expired.id;
  end if;

  -- Tables such as runners_banquet_reservations already use
  -- ON DELETE CASCADE where they reference club_events.
  delete from public.club_events ce
  using expired_club_event_ids expired
  where ce.id = expired.id;

  get diagnostics deleted_count = row_count;
  return deleted_count;
end;
$$;

grant execute on function public.cleanup_expired_club_events(date, interval)
  to authenticated;

commit;
