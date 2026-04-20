begin;

alter table public.runners_banquet_config
  add column if not exists club_name text;

alter table public.runners_banquet_reservations
  add column if not exists club_name text;

update public.runners_banquet_config
set club_name = case
  when lower(trim(club_name)) in ('nrr', 'norwich-road-runners')
    or lower(trim(club_name)) like '%norwich road runners%'
    then 'Norwich Road Runners'
  when lower(trim(club_name)) in ('nnbr', 'north-norfolk-beach-runners')
    or lower(trim(club_name)) like '%north norfolk beach runners%'
    then 'NNBR (North Norfolk Beach Runners)'
  else nullif(trim(club_name), '')
end;

update public.runners_banquet_reservations
set club_name = case
  when lower(trim(club_name)) in ('nrr', 'norwich-road-runners')
    or lower(trim(club_name)) like '%norwich road runners%'
    then 'Norwich Road Runners'
  when lower(trim(club_name)) in ('nnbr', 'north-norfolk-beach-runners')
    or lower(trim(club_name)) like '%north norfolk beach runners%'
    then 'NNBR (North Norfolk Beach Runners)'
  else nullif(trim(club_name), '')
end;

update public.runners_banquet_config
set club_name = 'Norwich Road Runners'
where club_name is null;

update public.runners_banquet_reservations
set club_name = 'Norwich Road Runners'
where club_name is null;

alter table public.runners_banquet_config
  alter column club_name set not null;

alter table public.runners_banquet_reservations
  alter column club_name set not null;

create index if not exists idx_runners_banquet_config_club_event
  on public.runners_banquet_config (club_name, event_id);

create index if not exists idx_runners_banquet_reservations_club_event
  on public.runners_banquet_reservations (club_name, event_id);

drop policy if exists "runners_banquet_config_select_all" on public.runners_banquet_config;
drop policy if exists "runners_banquet_config_admin_write" on public.runners_banquet_config;

create policy "runners_banquet_config_select_same_club"
  on public.runners_banquet_config
  for select to authenticated
  using (
    exists (
      select 1
      from public.user_profiles up
      where up.id = auth.uid()
        and (
          (
            (lower(trim(up.club)) = 'nrr'
              or lower(trim(up.club)) = 'norwich-road-runners'
              or lower(trim(up.club)) like '%norwich road runners%')
            and runners_banquet_config.club_name = 'Norwich Road Runners'
          )
          or (
            (lower(trim(up.club)) = 'nnbr'
              or lower(trim(up.club)) = 'north-norfolk-beach-runners'
              or lower(trim(up.club)) like '%north norfolk beach runners%')
            and runners_banquet_config.club_name = 'NNBR (North Norfolk Beach Runners)'
          )
          or runners_banquet_config.club_name = trim(up.club)
        )
    )
  );

create policy "runners_banquet_config_admin_write_same_club"
  on public.runners_banquet_config
  for all to authenticated
  using (
    exists (
      select 1
      from public.user_profiles up
      where up.id = auth.uid()
        and coalesce(up.is_admin, false) = true
        and (
          (
            (lower(trim(up.club)) = 'nrr'
              or lower(trim(up.club)) = 'norwich-road-runners'
              or lower(trim(up.club)) like '%norwich road runners%')
            and runners_banquet_config.club_name = 'Norwich Road Runners'
          )
          or (
            (lower(trim(up.club)) = 'nnbr'
              or lower(trim(up.club)) = 'north-norfolk-beach-runners'
              or lower(trim(up.club)) like '%north norfolk beach runners%')
            and runners_banquet_config.club_name = 'NNBR (North Norfolk Beach Runners)'
          )
          or runners_banquet_config.club_name = trim(up.club)
        )
    )
  )
  with check (
    exists (
      select 1
      from public.user_profiles up
      where up.id = auth.uid()
        and coalesce(up.is_admin, false) = true
        and (
          (
            (lower(trim(up.club)) = 'nrr'
              or lower(trim(up.club)) = 'norwich-road-runners'
              or lower(trim(up.club)) like '%norwich road runners%')
            and runners_banquet_config.club_name = 'Norwich Road Runners'
          )
          or (
            (lower(trim(up.club)) = 'nnbr'
              or lower(trim(up.club)) = 'north-norfolk-beach-runners'
              or lower(trim(up.club)) like '%north norfolk beach runners%')
            and runners_banquet_config.club_name = 'NNBR (North Norfolk Beach Runners)'
          )
          or runners_banquet_config.club_name = trim(up.club)
        )
    )
  );

drop policy if exists "runners_banquet_reservations_select_own_or_admin" on public.runners_banquet_reservations;
drop policy if exists "runners_banquet_reservations_write_own_or_admin" on public.runners_banquet_reservations;

create policy "runners_banquet_reservations_select_own_or_same_club_admin"
  on public.runners_banquet_reservations
  for select to authenticated
  using (
    user_id = auth.uid()
    or exists (
      select 1
      from public.user_profiles up
      where up.id = auth.uid()
        and coalesce(up.is_admin, false) = true
        and (
          (
            (lower(trim(up.club)) = 'nrr'
              or lower(trim(up.club)) = 'norwich-road-runners'
              or lower(trim(up.club)) like '%norwich road runners%')
            and runners_banquet_reservations.club_name = 'Norwich Road Runners'
          )
          or (
            (lower(trim(up.club)) = 'nnbr'
              or lower(trim(up.club)) = 'north-norfolk-beach-runners'
              or lower(trim(up.club)) like '%north norfolk beach runners%')
            and runners_banquet_reservations.club_name = 'NNBR (North Norfolk Beach Runners)'
          )
          or runners_banquet_reservations.club_name = trim(up.club)
        )
    )
  );

create policy "runners_banquet_reservations_write_own_or_same_club_admin"
  on public.runners_banquet_reservations
  for all to authenticated
  using (
    (
      user_id = auth.uid()
      and exists (
        select 1
        from public.user_profiles up
        where up.id = auth.uid()
          and (
            (
              (lower(trim(up.club)) = 'nrr'
                or lower(trim(up.club)) = 'norwich-road-runners'
                or lower(trim(up.club)) like '%norwich road runners%')
              and runners_banquet_reservations.club_name = 'Norwich Road Runners'
            )
            or (
              (lower(trim(up.club)) = 'nnbr'
                or lower(trim(up.club)) = 'north-norfolk-beach-runners'
                or lower(trim(up.club)) like '%north norfolk beach runners%')
              and runners_banquet_reservations.club_name = 'NNBR (North Norfolk Beach Runners)'
            )
            or runners_banquet_reservations.club_name = trim(up.club)
          )
      )
    )
    or exists (
      select 1
      from public.user_profiles up
      where up.id = auth.uid()
        and coalesce(up.is_admin, false) = true
        and (
          (
            (lower(trim(up.club)) = 'nrr'
              or lower(trim(up.club)) = 'norwich-road-runners'
              or lower(trim(up.club)) like '%norwich road runners%')
            and runners_banquet_reservations.club_name = 'Norwich Road Runners'
          )
          or (
            (lower(trim(up.club)) = 'nnbr'
              or lower(trim(up.club)) = 'north-norfolk-beach-runners'
              or lower(trim(up.club)) like '%north norfolk beach runners%')
            and runners_banquet_reservations.club_name = 'NNBR (North Norfolk Beach Runners)'
          )
          or runners_banquet_reservations.club_name = trim(up.club)
        )
    )
  )
  with check (
    (
      user_id = auth.uid()
      and exists (
        select 1
        from public.user_profiles up
        where up.id = auth.uid()
          and (
            (
              (lower(trim(up.club)) = 'nrr'
                or lower(trim(up.club)) = 'norwich-road-runners'
                or lower(trim(up.club)) like '%norwich road runners%')
              and runners_banquet_reservations.club_name = 'Norwich Road Runners'
            )
            or (
              (lower(trim(up.club)) = 'nnbr'
                or lower(trim(up.club)) = 'north-norfolk-beach-runners'
                or lower(trim(up.club)) like '%north norfolk beach runners%')
              and runners_banquet_reservations.club_name = 'NNBR (North Norfolk Beach Runners)'
            )
            or runners_banquet_reservations.club_name = trim(up.club)
          )
      )
    )
    or exists (
      select 1
      from public.user_profiles up
      where up.id = auth.uid()
        and coalesce(up.is_admin, false) = true
        and (
          (
            (lower(trim(up.club)) = 'nrr'
              or lower(trim(up.club)) = 'norwich-road-runners'
              or lower(trim(up.club)) like '%norwich road runners%')
            and runners_banquet_reservations.club_name = 'Norwich Road Runners'
          )
          or (
            (lower(trim(up.club)) = 'nnbr'
              or lower(trim(up.club)) = 'north-norfolk-beach-runners'
              or lower(trim(up.club)) like '%north norfolk beach runners%')
            and runners_banquet_reservations.club_name = 'NNBR (North Norfolk Beach Runners)'
          )
          or runners_banquet_reservations.club_name = trim(up.club)
        )
    )
  );

commit;