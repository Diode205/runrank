-- Demo club accounts should have full admin access so prospective clubs can
-- explore the complete app without manual role setup.

update public.user_profiles
set
  is_admin = true,
  admin_since = coalesce(admin_since, now())
where lower(trim(coalesce(club, ''))) = 'ycrr'
   or lower(coalesce(club, '')) like '%your club road runners%';

create or replace function public.set_ycrr_profile_admin()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if lower(trim(coalesce(new.club, ''))) = 'ycrr'
     or lower(coalesce(new.club, '')) like '%your club road runners%' then
    new.is_admin := true;
    new.admin_since := coalesce(new.admin_since, now());
  end if;

  return new;
end;
$$;

drop trigger if exists set_ycrr_profile_admin_trigger on public.user_profiles;

create trigger set_ycrr_profile_admin_trigger
before insert or update of club on public.user_profiles
for each row
execute function public.set_ycrr_profile_admin();
