begin;

create table if not exists public.secretary_vault_monthly_reports (
  id uuid primary key default gen_random_uuid(),
  club_name text not null,
  report_type text not null check (
    report_type in ('club_standard_awardees', 'age_grade_tops')
  ),
  month_start date not null,
  month_end date not null,
  title text not null,
  content text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint secretary_vault_monthly_reports_unique unique (
    club_name,
    report_type,
    month_start
  )
);

create index if not exists secretary_vault_monthly_reports_club_month_idx
  on public.secretary_vault_monthly_reports (
    lower(trim(club_name)),
    month_start desc
  );

create or replace function public.touch_secretary_vault_monthly_reports()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists secretary_vault_monthly_reports_touch_updated_at
  on public.secretary_vault_monthly_reports;
create trigger secretary_vault_monthly_reports_touch_updated_at
  before update on public.secretary_vault_monthly_reports
  for each row
  execute function public.touch_secretary_vault_monthly_reports();

alter table public.secretary_vault_monthly_reports enable row level security;

drop policy if exists "secretary_vault_reports_admin_same_club_select"
  on public.secretary_vault_monthly_reports;
create policy "secretary_vault_reports_admin_same_club_select"
  on public.secretary_vault_monthly_reports
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.user_profiles up
      where up.id = auth.uid()
        and coalesce(up.is_admin, false) = true
        and lower(trim(up.club)) =
            lower(trim(secretary_vault_monthly_reports.club_name))
    )
  );

drop policy if exists "secretary_vault_reports_admin_same_club_write"
  on public.secretary_vault_monthly_reports;
create policy "secretary_vault_reports_admin_same_club_write"
  on public.secretary_vault_monthly_reports
  for all
  to authenticated
  using (
    exists (
      select 1
      from public.user_profiles up
      where up.id = auth.uid()
        and coalesce(up.is_admin, false) = true
        and lower(trim(up.club)) =
            lower(trim(secretary_vault_monthly_reports.club_name))
    )
  )
  with check (
    exists (
      select 1
      from public.user_profiles up
      where up.id = auth.uid()
        and coalesce(up.is_admin, false) = true
        and lower(trim(up.club)) =
            lower(trim(secretary_vault_monthly_reports.club_name))
    )
  );

grant select, insert, update on public.secretary_vault_monthly_reports
  to authenticated;

commit;
