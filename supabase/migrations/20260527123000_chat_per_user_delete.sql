begin;

alter table public.chat_participants
  add column if not exists deleted_at timestamptz;

create index if not exists chat_participants_user_visibility_idx
  on public.chat_participants (user_id, archived_at, deleted_at, left_at);

create or replace function public.delete_chat_thread(target_thread_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (
    select 1
    from public.chat_participants cp
    where cp.thread_id = target_thread_id
      and cp.user_id = auth.uid()
      and cp.left_at is null
  ) then
    raise exception 'Not allowed to delete this chat';
  end if;

  update public.chat_participants
  set deleted_at = now(),
      archived_at = null
  where thread_id = target_thread_id
    and user_id = auth.uid();
end;
$$;

create or replace function public.cleanup_old_chat_threads(
  inactive_after interval default interval '30 days',
  archived_after interval default interval '30 days'
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  deleted_count integer := 0;
begin
  with stale_threads as (
    select ct.id
    from public.chat_threads ct
    where ct.updated_at < now() - inactive_after
  ),
  fully_archived_or_deleted_threads as (
    select ct.id
    from public.chat_threads ct
    where exists (
      select 1
      from public.chat_participants cp
      where cp.thread_id = ct.id
    )
    and not exists (
      select 1
      from public.chat_participants cp
      where cp.thread_id = ct.id
        and cp.left_at is null
        and (
          (
            cp.archived_at is null
            and cp.deleted_at is null
          )
          or cp.archived_at >= now() - archived_after
          or cp.deleted_at >= now() - archived_after
        )
    )
  ),
  deleted as (
    delete from public.chat_threads ct
    where ct.id in (
      select id from stale_threads
      union
      select id from fully_archived_or_deleted_threads
    )
    returning 1
  )
  select count(*) into deleted_count from deleted;

  return deleted_count;
end;
$$;

grant execute on function public.delete_chat_thread(uuid) to authenticated;
grant execute on function public.cleanup_old_chat_threads(interval, interval)
  to authenticated;

commit;
