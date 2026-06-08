begin;

create table if not exists public.app_owner_user_ids (
  user_id uuid primary key references auth.users(id) on delete cascade,
  label text,
  created_at timestamptz not null default now()
);

alter table public.app_owner_user_ids enable row level security;

drop policy if exists "app_owner_user_ids_select_self"
  on public.app_owner_user_ids;
create policy "app_owner_user_ids_select_self"
  on public.app_owner_user_ids
  for select
  to authenticated
  using (auth.uid() = user_id);

grant select on public.app_owner_user_ids to authenticated;
grant all on public.app_owner_user_ids to service_role;

drop policy if exists "secretary_vault_reports_admin_same_club_select"
  on public.secretary_vault_monthly_reports;
drop policy if exists "secretary_vault_reports_admin_same_club_write"
  on public.secretary_vault_monthly_reports;
drop policy if exists "secretary_vault_reports_secretary_or_owner_select"
  on public.secretary_vault_monthly_reports;
drop policy if exists "secretary_vault_reports_secretary_or_owner_write"
  on public.secretary_vault_monthly_reports;

create policy "secretary_vault_reports_secretary_or_owner_select"
  on public.secretary_vault_monthly_reports
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.app_owner_user_ids owner
      where owner.user_id = auth.uid()
    )
    or exists (
      select 1
      from public.user_profiles up
      join public.committee_roles cr
        on lower(trim(cr.club)) = lower(trim(up.club))
      where up.id = auth.uid()
        and lower(trim(up.club)) =
            lower(trim(secretary_vault_monthly_reports.club_name))
        and lower(trim(cr.role)) like '%secretary%'
        and lower(trim(cr.role)) not like '%membership%'
        and lower(trim(cr.role)) not like '%minutes%'
        and lower(trim(cr.role)) not like '%kit%'
        and (
          cr.user_id = auth.uid()
          or lower(trim(coalesce(cr.email, ''))) =
             lower(trim(coalesce(up.email, '')))
          or regexp_replace(lower(coalesce(cr.name, '')), '[^a-z0-9]', '', 'g') =
             regexp_replace(lower(coalesce(up.full_name, '')), '[^a-z0-9]', '', 'g')
        )
    )
  );

create policy "secretary_vault_reports_secretary_or_owner_write"
  on public.secretary_vault_monthly_reports
  for all
  to authenticated
  using (
    exists (
      select 1
      from public.app_owner_user_ids owner
      where owner.user_id = auth.uid()
    )
    or exists (
      select 1
      from public.user_profiles up
      join public.committee_roles cr
        on lower(trim(cr.club)) = lower(trim(up.club))
      where up.id = auth.uid()
        and lower(trim(up.club)) =
            lower(trim(secretary_vault_monthly_reports.club_name))
        and lower(trim(cr.role)) like '%secretary%'
        and lower(trim(cr.role)) not like '%membership%'
        and lower(trim(cr.role)) not like '%minutes%'
        and lower(trim(cr.role)) not like '%kit%'
        and (
          cr.user_id = auth.uid()
          or lower(trim(coalesce(cr.email, ''))) =
             lower(trim(coalesce(up.email, '')))
          or regexp_replace(lower(coalesce(cr.name, '')), '[^a-z0-9]', '', 'g') =
             regexp_replace(lower(coalesce(up.full_name, '')), '[^a-z0-9]', '', 'g')
        )
    )
  )
  with check (
    exists (
      select 1
      from public.app_owner_user_ids owner
      where owner.user_id = auth.uid()
    )
    or exists (
      select 1
      from public.user_profiles up
      join public.committee_roles cr
        on lower(trim(cr.club)) = lower(trim(up.club))
      where up.id = auth.uid()
        and lower(trim(up.club)) =
            lower(trim(secretary_vault_monthly_reports.club_name))
        and lower(trim(cr.role)) like '%secretary%'
        and lower(trim(cr.role)) not like '%membership%'
        and lower(trim(cr.role)) not like '%minutes%'
        and lower(trim(cr.role)) not like '%kit%'
        and (
          cr.user_id = auth.uid()
          or lower(trim(coalesce(cr.email, ''))) =
             lower(trim(coalesce(up.email, '')))
          or regexp_replace(lower(coalesce(cr.name, '')), '[^a-z0-9]', '', 'g') =
             regexp_replace(lower(coalesce(up.full_name, '')), '[^a-z0-9]', '', 'g')
        )
    )
  );

drop policy if exists membership_tier_configs_update_admin
  on public.membership_tier_configs;
drop policy if exists membership_tier_configs_insert_admin
  on public.membership_tier_configs;

create policy membership_tier_configs_update_admin
  on public.membership_tier_configs
  for update to authenticated
  using (
    exists (
      select 1
      from public.app_owner_user_ids owner
      where owner.user_id = auth.uid()
    )
    or exists (
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
    or exists (
      select 1
      from public.user_profiles up
      join public.committee_roles cr
        on lower(trim(cr.club)) = lower(trim(up.club))
      where up.id = auth.uid()
        and lower(trim(cr.role)) like '%membership%'
        and lower(trim(cr.role)) like '%secretary%'
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
        and (
          cr.user_id = auth.uid()
          or lower(trim(coalesce(cr.email, ''))) =
             lower(trim(coalesce(up.email, '')))
          or regexp_replace(lower(coalesce(cr.name, '')), '[^a-z0-9]', '', 'g') =
             regexp_replace(lower(coalesce(up.full_name, '')), '[^a-z0-9]', '', 'g')
        )
    )
  )
  with check (
    exists (
      select 1
      from public.app_owner_user_ids owner
      where owner.user_id = auth.uid()
    )
    or exists (
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
    or exists (
      select 1
      from public.user_profiles up
      join public.committee_roles cr
        on lower(trim(cr.club)) = lower(trim(up.club))
      where up.id = auth.uid()
        and lower(trim(cr.role)) like '%membership%'
        and lower(trim(cr.role)) like '%secretary%'
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
        and (
          cr.user_id = auth.uid()
          or lower(trim(coalesce(cr.email, ''))) =
             lower(trim(coalesce(up.email, '')))
          or regexp_replace(lower(coalesce(cr.name, '')), '[^a-z0-9]', '', 'g') =
             regexp_replace(lower(coalesce(up.full_name, '')), '[^a-z0-9]', '', 'g')
        )
    )
  );

create policy membership_tier_configs_insert_admin
  on public.membership_tier_configs
  for insert to authenticated
  with check (
    exists (
      select 1
      from public.app_owner_user_ids owner
      where owner.user_id = auth.uid()
    )
    or exists (
      select 1
      from public.user_profiles up
      where up.id = auth.uid()
        and coalesce(up.is_admin, false) = true
    )
    or exists (
      select 1
      from public.user_profiles up
      join public.committee_roles cr
        on lower(trim(cr.club)) = lower(trim(up.club))
      where up.id = auth.uid()
        and lower(trim(cr.role)) like '%membership%'
        and lower(trim(cr.role)) like '%secretary%'
        and (
          cr.user_id = auth.uid()
          or lower(trim(coalesce(cr.email, ''))) =
             lower(trim(coalesce(up.email, '')))
          or regexp_replace(lower(coalesce(cr.name, '')), '[^a-z0-9]', '', 'g') =
             regexp_replace(lower(coalesce(up.full_name, '')), '[^a-z0-9]', '', 'g')
        )
    )
  );

drop policy if exists "kit_products_insert_admin" on public.kit_products;
drop policy if exists "kit_products_update_admin" on public.kit_products;
drop policy if exists "kit_products_delete_admin" on public.kit_products;

create policy "kit_products_insert_admin" on public.kit_products
  for insert
  with check (
    exists (
      select 1
      from public.app_owner_user_ids owner
      where owner.user_id = auth.uid()
    )
    or exists (
      select 1
      from public.user_profiles up
      where up.id = auth.uid()
        and coalesce(up.is_admin, false) = true
    )
    or exists (
      select 1
      from public.user_profiles up
      join public.committee_roles cr
        on lower(trim(cr.club)) = lower(trim(up.club))
      where up.id = auth.uid()
        and lower(trim(cr.role)) like '%kit%'
        and (
          cr.user_id = auth.uid()
          or lower(trim(coalesce(cr.email, ''))) =
             lower(trim(coalesce(up.email, '')))
          or regexp_replace(lower(coalesce(cr.name, '')), '[^a-z0-9]', '', 'g') =
             regexp_replace(lower(coalesce(up.full_name, '')), '[^a-z0-9]', '', 'g')
        )
    )
  );

create policy "kit_products_update_admin" on public.kit_products
  for update
  using (
    exists (
      select 1
      from public.app_owner_user_ids owner
      where owner.user_id = auth.uid()
    )
    or exists (
      select 1
      from public.user_profiles up
      where up.id = auth.uid()
        and coalesce(up.is_admin, false) = true
    )
    or exists (
      select 1
      from public.user_profiles up
      join public.committee_roles cr
        on lower(trim(cr.club)) = lower(trim(up.club))
      where up.id = auth.uid()
        and lower(trim(cr.role)) like '%kit%'
        and (
          cr.user_id = auth.uid()
          or lower(trim(coalesce(cr.email, ''))) =
             lower(trim(coalesce(up.email, '')))
          or regexp_replace(lower(coalesce(cr.name, '')), '[^a-z0-9]', '', 'g') =
             regexp_replace(lower(coalesce(up.full_name, '')), '[^a-z0-9]', '', 'g')
        )
    )
  );

create policy "kit_products_delete_admin" on public.kit_products
  for delete
  using (
    exists (
      select 1
      from public.app_owner_user_ids owner
      where owner.user_id = auth.uid()
    )
    or exists (
      select 1
      from public.user_profiles up
      where up.id = auth.uid()
        and coalesce(up.is_admin, false) = true
    )
    or exists (
      select 1
      from public.user_profiles up
      join public.committee_roles cr
        on lower(trim(cr.club)) = lower(trim(up.club))
      where up.id = auth.uid()
        and lower(trim(cr.role)) like '%kit%'
        and (
          cr.user_id = auth.uid()
          or lower(trim(coalesce(cr.email, ''))) =
             lower(trim(coalesce(up.email, '')))
          or regexp_replace(lower(coalesce(cr.name, '')), '[^a-z0-9]', '', 'g') =
             regexp_replace(lower(coalesce(up.full_name, '')), '[^a-z0-9]', '', 'g')
        )
    )
  );

commit;
