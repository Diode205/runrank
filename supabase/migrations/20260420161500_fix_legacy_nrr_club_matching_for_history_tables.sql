update public.team_achievements
set club_name = 'Norwich Road Runners'
where lower(trim(club_name)) in ('nrr', 'norwich-road-runners')
   or lower(trim(club_name)) like '%norwich road runners%';

update public.team_achievements
set club_name = 'NNBR (North Norfolk Beach Runners)'
where lower(trim(club_name)) in ('nnbr', 'north-norfolk-beach-runners')
   or lower(trim(club_name)) like '%north norfolk beach runners%';

update public.club_milestones
set club_name = 'Norwich Road Runners'
where lower(trim(club_name)) in ('nrr', 'norwich-road-runners')
   or lower(trim(club_name)) like '%norwich road runners%';

update public.club_milestones
set club_name = 'NNBR (North Norfolk Beach Runners)'
where lower(trim(club_name)) in ('nnbr', 'north-norfolk-beach-runners')
   or lower(trim(club_name)) like '%north norfolk beach runners%';

drop policy if exists "team_achievements_select_same_club" on public.team_achievements;
drop policy if exists "team_achievements_insert_same_club_admin" on public.team_achievements;
drop policy if exists "team_achievements_update_same_club_admin" on public.team_achievements;
drop policy if exists "team_achievements_delete_same_club_admin" on public.team_achievements;

create policy "team_achievements_select_same_club"
on public.team_achievements
for select
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
          and team_achievements.club_name = 'Norwich Road Runners'
        )
        or (
          (lower(trim(up.club)) = 'nnbr'
            or lower(trim(up.club)) = 'north-norfolk-beach-runners'
            or lower(trim(up.club)) like '%north norfolk beach runners%')
          and team_achievements.club_name = 'NNBR (North Norfolk Beach Runners)'
        )
      )
  )
);

create policy "team_achievements_insert_same_club_admin"
on public.team_achievements
for insert
with check (
  exists (
    select 1
    from public.user_profiles up
    where up.id = auth.uid()
      and up.is_admin = true
      and (
        (
          (lower(trim(up.club)) = 'nrr'
            or lower(trim(up.club)) = 'norwich-road-runners'
            or lower(trim(up.club)) like '%norwich road runners%')
          and team_achievements.club_name = 'Norwich Road Runners'
        )
        or (
          (lower(trim(up.club)) = 'nnbr'
            or lower(trim(up.club)) = 'north-norfolk-beach-runners'
            or lower(trim(up.club)) like '%north norfolk beach runners%')
          and team_achievements.club_name = 'NNBR (North Norfolk Beach Runners)'
        )
      )
  )
);

create policy "team_achievements_update_same_club_admin"
on public.team_achievements
for update
using (
  exists (
    select 1
    from public.user_profiles up
    where up.id = auth.uid()
      and up.is_admin = true
      and (
        (
          (lower(trim(up.club)) = 'nrr'
            or lower(trim(up.club)) = 'norwich-road-runners'
            or lower(trim(up.club)) like '%norwich road runners%')
          and team_achievements.club_name = 'Norwich Road Runners'
        )
        or (
          (lower(trim(up.club)) = 'nnbr'
            or lower(trim(up.club)) = 'north-norfolk-beach-runners'
            or lower(trim(up.club)) like '%north norfolk beach runners%')
          and team_achievements.club_name = 'NNBR (North Norfolk Beach Runners)'
        )
      )
  )
)
with check (
  exists (
    select 1
    from public.user_profiles up
    where up.id = auth.uid()
      and up.is_admin = true
      and (
        (
          (lower(trim(up.club)) = 'nrr'
            or lower(trim(up.club)) = 'norwich-road-runners'
            or lower(trim(up.club)) like '%norwich road runners%')
          and team_achievements.club_name = 'Norwich Road Runners'
        )
        or (
          (lower(trim(up.club)) = 'nnbr'
            or lower(trim(up.club)) = 'north-norfolk-beach-runners'
            or lower(trim(up.club)) like '%north norfolk beach runners%')
          and team_achievements.club_name = 'NNBR (North Norfolk Beach Runners)'
        )
      )
  )
);

create policy "team_achievements_delete_same_club_admin"
on public.team_achievements
for delete
using (
  exists (
    select 1
    from public.user_profiles up
    where up.id = auth.uid()
      and up.is_admin = true
      and (
        (
          (lower(trim(up.club)) = 'nrr'
            or lower(trim(up.club)) = 'norwich-road-runners'
            or lower(trim(up.club)) like '%norwich road runners%')
          and team_achievements.club_name = 'Norwich Road Runners'
        )
        or (
          (lower(trim(up.club)) = 'nnbr'
            or lower(trim(up.club)) = 'north-norfolk-beach-runners'
            or lower(trim(up.club)) like '%north norfolk beach runners%')
          and team_achievements.club_name = 'NNBR (North Norfolk Beach Runners)'
        )
      )
  )
);

drop policy if exists "club_milestones_select_same_club" on public.club_milestones;
drop policy if exists "club_milestones_insert_same_club_admin" on public.club_milestones;
drop policy if exists "club_milestones_update_same_club_admin" on public.club_milestones;
drop policy if exists "club_milestones_delete_same_club_admin" on public.club_milestones;

create policy "club_milestones_select_same_club"
on public.club_milestones
for select
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
          and club_milestones.club_name = 'Norwich Road Runners'
        )
        or (
          (lower(trim(up.club)) = 'nnbr'
            or lower(trim(up.club)) = 'north-norfolk-beach-runners'
            or lower(trim(up.club)) like '%north norfolk beach runners%')
          and club_milestones.club_name = 'NNBR (North Norfolk Beach Runners)'
        )
      )
  )
);

create policy "club_milestones_insert_same_club_admin"
on public.club_milestones
for insert
with check (
  exists (
    select 1
    from public.user_profiles up
    where up.id = auth.uid()
      and up.is_admin = true
      and (
        (
          (lower(trim(up.club)) = 'nrr'
            or lower(trim(up.club)) = 'norwich-road-runners'
            or lower(trim(up.club)) like '%norwich road runners%')
          and club_milestones.club_name = 'Norwich Road Runners'
        )
        or (
          (lower(trim(up.club)) = 'nnbr'
            or lower(trim(up.club)) = 'north-norfolk-beach-runners'
            or lower(trim(up.club)) like '%north norfolk beach runners%')
          and club_milestones.club_name = 'NNBR (North Norfolk Beach Runners)'
        )
      )
  )
);

create policy "club_milestones_update_same_club_admin"
on public.club_milestones
for update
using (
  exists (
    select 1
    from public.user_profiles up
    where up.id = auth.uid()
      and up.is_admin = true
      and (
        (
          (lower(trim(up.club)) = 'nrr'
            or lower(trim(up.club)) = 'norwich-road-runners'
            or lower(trim(up.club)) like '%norwich road runners%')
          and club_milestones.club_name = 'Norwich Road Runners'
        )
        or (
          (lower(trim(up.club)) = 'nnbr'
            or lower(trim(up.club)) = 'north-norfolk-beach-runners'
            or lower(trim(up.club)) like '%north norfolk beach runners%')
          and club_milestones.club_name = 'NNBR (North Norfolk Beach Runners)'
        )
      )
  )
)
with check (
  exists (
    select 1
    from public.user_profiles up
    where up.id = auth.uid()
      and up.is_admin = true
      and (
        (
          (lower(trim(up.club)) = 'nrr'
            or lower(trim(up.club)) = 'norwich-road-runners'
            or lower(trim(up.club)) like '%norwich road runners%')
          and club_milestones.club_name = 'Norwich Road Runners'
        )
        or (
          (lower(trim(up.club)) = 'nnbr'
            or lower(trim(up.club)) = 'north-norfolk-beach-runners'
            or lower(trim(up.club)) like '%north norfolk beach runners%')
          and club_milestones.club_name = 'NNBR (North Norfolk Beach Runners)'
        )
      )
  )
);

create policy "club_milestones_delete_same_club_admin"
on public.club_milestones
for delete
using (
  exists (
    select 1
    from public.user_profiles up
    where up.id = auth.uid()
      and up.is_admin = true
      and (
        (
          (lower(trim(up.club)) = 'nrr'
            or lower(trim(up.club)) = 'norwich-road-runners'
            or lower(trim(up.club)) like '%norwich road runners%')
          and club_milestones.club_name = 'Norwich Road Runners'
        )
        or (
          (lower(trim(up.club)) = 'nnbr'
            or lower(trim(up.club)) = 'north-norfolk-beach-runners'
            or lower(trim(up.club)) like '%north norfolk beach runners%')
          and club_milestones.club_name = 'NNBR (North Norfolk Beach Runners)'
        )
      )
  )
);