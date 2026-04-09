begin;

alter table public.club_records
  add column if not exists club text,
  add column if not exists gender text;

update public.club_records cr
set club = up.club,
    gender = case
      when upper(coalesce(up.gender, '')) in ('M', 'F') then upper(up.gender)
      else cr.gender
    end
from public.user_profiles up
where cr.user_id = up.id
  and (cr.club is null or cr.gender is null);

alter table public.club_records
  drop constraint if exists club_records_gender_check;

alter table public.club_records
  add constraint club_records_gender_check
  check (gender is null or gender in ('M', 'F'));

create index if not exists idx_club_records_club on public.club_records(club);
create index if not exists idx_club_records_gender on public.club_records(gender);
create index if not exists idx_club_records_club_gender_distance_time
  on public.club_records(club, gender, distance, time_seconds);

commit;