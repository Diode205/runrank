begin;

create table if not exists public.membership_tier_configs (
  id uuid primary key default gen_random_uuid(),
  club_name text not null,
  tier_name text not null,
  amount_pence integer not null check (amount_pence >= 0),
  stripe_enabled boolean not null default true,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id) on delete set null,
  constraint membership_tier_configs_club_tier_unique unique (club_name, tier_name)
);

insert into public.membership_tier_configs (club_name, tier_name, amount_pence, stripe_enabled)
values
  ('NNBR (North Norfolk Beach Runners)', '1st Claim', 3000, true),
  ('NNBR (North Norfolk Beach Runners)', '2nd Claim', 1500, true),
  ('NNBR (North Norfolk Beach Runners)', 'Social', 500, true),
  ('NNBR (North Norfolk Beach Runners)', 'Full-Time Education', 1500, true),
  ('Norwich Road Runners', '1st Claim', 4200, true),
  ('Norwich Road Runners', '2nd Claim', 2300, true)
on conflict (club_name, tier_name) do update
set amount_pence = excluded.amount_pence,
    stripe_enabled = excluded.stripe_enabled,
    updated_at = now();

alter table public.membership_tier_configs enable row level security;

drop policy if exists membership_tier_configs_select_by_club on public.membership_tier_configs;
create policy membership_tier_configs_select_by_club
  on public.membership_tier_configs
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

drop policy if exists membership_tier_configs_update_admin on public.membership_tier_configs;
create policy membership_tier_configs_update_admin
  on public.membership_tier_configs
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

drop policy if exists membership_tier_configs_insert_admin on public.membership_tier_configs;
create policy membership_tier_configs_insert_admin
  on public.membership_tier_configs
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

commit;
