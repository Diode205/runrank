begin;

update public.club_records
set club = 'Norwich Road Runners'
where lower(trim(coalesce(club, ''))) in ('nrr', 'norwich-road-runners')
   or lower(trim(coalesce(club, ''))) like '%norwich road runners%';

update public.club_records
set club = 'NNBR (North Norfolk Beach Runners)'
where lower(trim(coalesce(club, ''))) in (
        'nnbr',
        'north-norfolk-beach-runners'
      )
   or lower(trim(coalesce(club, ''))) like '%north norfolk beach runners%';

commit;
