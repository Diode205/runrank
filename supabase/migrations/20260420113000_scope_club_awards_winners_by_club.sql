begin;

alter table public.club_awards_winners
  add column if not exists club_name text;

with inferred_clubs as (
  select
    caw.id,
    coalesce(
      nullif(trim(added_by_profile.club), ''),
      nullif(trim(female_profile.club), ''),
      nullif(trim(male_profile.club), '')
    ) as inferred_club
  from public.club_awards_winners caw
  left join public.user_profiles added_by_profile
    on added_by_profile.id = caw.added_by
  left join public.user_profiles female_profile
    on female_profile.full_name = caw.female_name
  left join public.user_profiles male_profile
    on male_profile.full_name = caw.male_name
)
update public.club_awards_winners caw
set club_name = case
  when lower(trim(inferred_clubs.inferred_club)) = 'nrr'
    or lower(trim(inferred_clubs.inferred_club)) like '%norwich road runners%'
    then 'Norwich Road Runners'
  when lower(trim(inferred_clubs.inferred_club)) = 'nnbr'
    or lower(trim(inferred_clubs.inferred_club)) like '%north norfolk beach runners%'
    then 'NNBR (North Norfolk Beach Runners)'
  else nullif(trim(inferred_clubs.inferred_club), '')
end
from inferred_clubs
where caw.id = inferred_clubs.id
  and (caw.club_name is null or trim(caw.club_name) = '')
  and inferred_clubs.inferred_club is not null
  and trim(inferred_clubs.inferred_club) <> '';

update public.club_awards_winners
set club_name = case
  when lower(trim(club_name)) = 'nrr'
    or lower(trim(club_name)) like '%norwich road runners%'
    then 'Norwich Road Runners'
  when lower(trim(club_name)) = 'nnbr'
    or lower(trim(club_name)) like '%north norfolk beach runners%'
    then 'NNBR (North Norfolk Beach Runners)'
  else nullif(trim(club_name), '')
end
where club_name is not null;

alter table public.club_awards_winners
  drop constraint if exists club_awards_winners_unique_per_year;

drop index if exists public.club_awards_winners_award_year_idx;
drop index if exists public.club_awards_winners_award_club_year_idx;

create unique index if not exists club_awards_winners_award_club_year_unique_idx
  on public.club_awards_winners (award_key, club_name, year)
  where club_name is not null;

create index if not exists club_awards_winners_award_club_year_idx
  on public.club_awards_winners (award_key, club_name, year);

drop policy if exists club_awards_winners_insert_admin on public.club_awards_winners;
create policy club_awards_winners_insert_admin
  on public.club_awards_winners
  for insert to authenticated
  with check (
    exists (
      select 1
      from public.user_profiles up
      where up.id = auth.uid()
        and coalesce(up.is_admin, false) = true
        and (
          (
            lower(trim(up.club)) = 'nrr'
            or lower(trim(up.club)) like '%norwich road runners%'
          )
          and club_name = 'Norwich Road Runners'
          or (
            lower(trim(up.club)) = 'nnbr'
            or lower(trim(up.club)) like '%north norfolk beach runners%'
          )
          and club_name = 'NNBR (North Norfolk Beach Runners)'
          or club_name = trim(up.club)
        )
    )
  );

drop policy if exists club_awards_winners_update_admin on public.club_awards_winners;
create policy club_awards_winners_update_admin
  on public.club_awards_winners
  for update to authenticated
  using (
    exists (
      select 1
      from public.user_profiles up
      where up.id = auth.uid()
        and coalesce(up.is_admin, false) = true
        and (
          (
            lower(trim(up.club)) = 'nrr'
            or lower(trim(up.club)) like '%norwich road runners%'
          )
          and club_name = 'Norwich Road Runners'
          or (
            lower(trim(up.club)) = 'nnbr'
            or lower(trim(up.club)) like '%north norfolk beach runners%'
          )
          and club_name = 'NNBR (North Norfolk Beach Runners)'
          or club_name = trim(up.club)
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
            lower(trim(up.club)) = 'nrr'
            or lower(trim(up.club)) like '%norwich road runners%'
          )
          and club_name = 'Norwich Road Runners'
          or (
            lower(trim(up.club)) = 'nnbr'
            or lower(trim(up.club)) like '%north norfolk beach runners%'
          )
          and club_name = 'NNBR (North Norfolk Beach Runners)'
          or club_name = trim(up.club)
        )
    )
  );

drop policy if exists club_awards_winners_delete_admin on public.club_awards_winners;
create policy club_awards_winners_delete_admin
  on public.club_awards_winners
  for delete to authenticated
  using (
    exists (
      select 1
      from public.user_profiles up
      where up.id = auth.uid()
        and coalesce(up.is_admin, false) = true
        and (
          (
            lower(trim(up.club)) = 'nrr'
            or lower(trim(up.club)) like '%norwich road runners%'
          )
          and club_name = 'Norwich Road Runners'
          or (
            lower(trim(up.club)) = 'nnbr'
            or lower(trim(up.club)) like '%north norfolk beach runners%'
          )
          and club_name = 'NNBR (North Norfolk Beach Runners)'
          or club_name = trim(up.club)
        )
    )
  );

commit;