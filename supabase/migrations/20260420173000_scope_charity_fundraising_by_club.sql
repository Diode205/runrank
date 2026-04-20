begin;

update public.charity_fundraising
set club = case
  when lower(trim(club)) in ('nrr', 'norwich-road-runners')
    or lower(trim(club)) like '%norwich road runners%'
    then 'Norwich Road Runners'
  when lower(trim(club)) in ('nnbr', 'north-norfolk-beach-runners')
    or lower(trim(club)) like '%north norfolk beach runners%'
    then 'NNBR (North Norfolk Beach Runners)'
  else nullif(trim(club), '')
end;

update public.charity_fundraising
set club = 'Norwich Road Runners'
where club is null;

alter table public.charity_fundraising
  alter column club set not null;

drop index if exists charity_fundraising_club_unique_idx;
create unique index if not exists charity_fundraising_club_unique_idx
  on public.charity_fundraising (club);

alter table public.charity_fundraising enable row level security;

drop policy if exists charity_fundraising_select_same_club on public.charity_fundraising;
drop policy if exists charity_fundraising_insert_same_club_admin on public.charity_fundraising;
drop policy if exists charity_fundraising_update_same_club_admin on public.charity_fundraising;
drop policy if exists charity_fundraising_delete_same_club_admin on public.charity_fundraising;

create policy charity_fundraising_select_same_club
  on public.charity_fundraising
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
            and charity_fundraising.club = 'Norwich Road Runners'
          )
          or (
            (lower(trim(up.club)) = 'nnbr'
              or lower(trim(up.club)) = 'north-norfolk-beach-runners'
              or lower(trim(up.club)) like '%north norfolk beach runners%')
            and charity_fundraising.club = 'NNBR (North Norfolk Beach Runners)'
          )
          or charity_fundraising.club = trim(up.club)
        )
    )
  );

create policy charity_fundraising_insert_same_club_admin
  on public.charity_fundraising
  for insert to authenticated
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
            and charity_fundraising.club = 'Norwich Road Runners'
          )
          or (
            (lower(trim(up.club)) = 'nnbr'
              or lower(trim(up.club)) = 'north-norfolk-beach-runners'
              or lower(trim(up.club)) like '%north norfolk beach runners%')
            and charity_fundraising.club = 'NNBR (North Norfolk Beach Runners)'
          )
          or charity_fundraising.club = trim(up.club)
        )
    )
  );

create policy charity_fundraising_update_same_club_admin
  on public.charity_fundraising
  for update to authenticated
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
            and charity_fundraising.club = 'Norwich Road Runners'
          )
          or (
            (lower(trim(up.club)) = 'nnbr'
              or lower(trim(up.club)) = 'north-norfolk-beach-runners'
              or lower(trim(up.club)) like '%north norfolk beach runners%')
            and charity_fundraising.club = 'NNBR (North Norfolk Beach Runners)'
          )
          or charity_fundraising.club = trim(up.club)
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
            and charity_fundraising.club = 'Norwich Road Runners'
          )
          or (
            (lower(trim(up.club)) = 'nnbr'
              or lower(trim(up.club)) = 'north-norfolk-beach-runners'
              or lower(trim(up.club)) like '%north norfolk beach runners%')
            and charity_fundraising.club = 'NNBR (North Norfolk Beach Runners)'
          )
          or charity_fundraising.club = trim(up.club)
        )
    )
  );

create policy charity_fundraising_delete_same_club_admin
  on public.charity_fundraising
  for delete to authenticated
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
            and charity_fundraising.club = 'Norwich Road Runners'
          )
          or (
            (lower(trim(up.club)) = 'nnbr'
              or lower(trim(up.club)) = 'north-norfolk-beach-runners'
              or lower(trim(up.club)) like '%north norfolk beach runners%')
            and charity_fundraising.club = 'NNBR (North Norfolk Beach Runners)'
          )
          or charity_fundraising.club = trim(up.club)
        )
    )
  );

commit;