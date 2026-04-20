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

alter table public.team_achievements
  add column if not exists club_name text;

alter table public.club_milestones
  add column if not exists club_name text;

update public.team_achievements
set club_name = 'NNBR (North Norfolk Beach Runners)'
where club_name is null;

update public.club_milestones
set club_name = 'NNBR (North Norfolk Beach Runners)'
where club_name is null;

alter table public.team_achievements
  alter column club_name set not null;

alter table public.club_milestones
  alter column club_name set not null;

create index if not exists idx_team_achievements_club_date
  on public.team_achievements (club_name, achievement_date desc);

create index if not exists idx_club_milestones_club_order
  on public.club_milestones (club_name, display_order asc);

drop policy if exists "team_achievements_select_all" on public.team_achievements;
drop policy if exists "team_achievements_insert_admin" on public.team_achievements;
drop policy if exists "team_achievements_update_admin" on public.team_achievements;
drop policy if exists "team_achievements_delete_admin" on public.team_achievements;

create policy "team_achievements_select_same_club"
on public.team_achievements
for select
using (
  exists (
    select 1
    from public.user_profiles
    where user_profiles.id = auth.uid()
      and public.canonical_club_name(user_profiles.club) = team_achievements.club_name
  )
);

create policy "team_achievements_insert_same_club_admin"
on public.team_achievements
for insert
with check (
  exists (
    select 1
    from public.user_profiles
    where user_profiles.id = auth.uid()
      and user_profiles.is_admin = true
      and public.canonical_club_name(user_profiles.club) = team_achievements.club_name
  )
);

create policy "team_achievements_update_same_club_admin"
on public.team_achievements
for update
using (
  exists (
    select 1
    from public.user_profiles
    where user_profiles.id = auth.uid()
      and user_profiles.is_admin = true
      and public.canonical_club_name(user_profiles.club) = team_achievements.club_name
  )
)
with check (
  exists (
    select 1
    from public.user_profiles
    where user_profiles.id = auth.uid()
      and user_profiles.is_admin = true
      and public.canonical_club_name(user_profiles.club) = team_achievements.club_name
  )
);

create policy "team_achievements_delete_same_club_admin"
on public.team_achievements
for delete
using (
  exists (
    select 1
    from public.user_profiles
    where user_profiles.id = auth.uid()
      and user_profiles.is_admin = true
      and public.canonical_club_name(user_profiles.club) = team_achievements.club_name
  )
);

drop policy if exists "club_milestones_select_all" on public.club_milestones;
drop policy if exists "club_milestones_insert_admin" on public.club_milestones;
drop policy if exists "club_milestones_update_admin" on public.club_milestones;
drop policy if exists "club_milestones_delete_admin" on public.club_milestones;

create policy "club_milestones_select_same_club"
on public.club_milestones
for select
using (
  exists (
    select 1
    from public.user_profiles
    where user_profiles.id = auth.uid()
      and public.canonical_club_name(user_profiles.club) = club_milestones.club_name
  )
);

create policy "club_milestones_insert_same_club_admin"
on public.club_milestones
for insert
with check (
  exists (
    select 1
    from public.user_profiles
    where user_profiles.id = auth.uid()
      and user_profiles.is_admin = true
      and public.canonical_club_name(user_profiles.club) = club_milestones.club_name
  )
);

create policy "club_milestones_update_same_club_admin"
on public.club_milestones
for update
using (
  exists (
    select 1
    from public.user_profiles
    where user_profiles.id = auth.uid()
      and user_profiles.is_admin = true
      and public.canonical_club_name(user_profiles.club) = club_milestones.club_name
  )
)
with check (
  exists (
    select 1
    from public.user_profiles
    where user_profiles.id = auth.uid()
      and user_profiles.is_admin = true
      and public.canonical_club_name(user_profiles.club) = club_milestones.club_name
  )
);

create policy "club_milestones_delete_same_club_admin"
on public.club_milestones
for delete
using (
  exists (
    select 1
    from public.user_profiles
    where user_profiles.id = auth.uid()
      and user_profiles.is_admin = true
      and public.canonical_club_name(user_profiles.club) = club_milestones.club_name
  )
);