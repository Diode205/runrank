begin;

create or replace function public.canonical_club_name(raw_club text)
returns text
language sql
immutable
as $$
  select case
    when raw_club is null or btrim(raw_club) = '' then ''
    when lower(btrim(raw_club)) = 'nrr'
      or lower(btrim(raw_club)) like '%norwich road runners%'
      then 'Norwich Road Runners'
    when lower(btrim(raw_club)) = 'nnbr'
      or lower(btrim(raw_club)) like '%north norfolk beach runners%'
      then 'NNBR (North Norfolk Beach Runners)'
    else btrim(raw_club)
  end
$$;

alter table public.notifications enable row level security;

drop policy if exists "Admins can insert notifications for any user"
on public.notifications;

drop policy if exists "Authenticated users can insert same-club notifications"
on public.notifications;

create policy "Authenticated users can insert same-club notifications"
  on public.notifications
  for insert
  to authenticated
  with check (
    exists (
      select 1
      from public.user_profiles actor
      left join public.user_profiles recipient
        on recipient.id = public.notifications.user_id
      where actor.id = auth.uid()
        and (
          coalesce(actor.is_admin, false) = true
          or (
            recipient.id is not null
            and public.canonical_club_name(actor.club) <> ''
            and public.canonical_club_name(actor.club) =
                public.canonical_club_name(recipient.club)
          )
        )
    )
  );

commit;
