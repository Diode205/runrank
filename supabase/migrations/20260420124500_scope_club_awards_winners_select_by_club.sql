begin;

drop policy if exists club_awards_winners_select_all on public.club_awards_winners;
drop policy if exists club_awards_winners_select_by_club on public.club_awards_winners;

create policy club_awards_winners_select_by_club
  on public.club_awards_winners
  for select to authenticated
  using (
    exists (
      select 1
      from public.user_profiles up
      where up.id = auth.uid()
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