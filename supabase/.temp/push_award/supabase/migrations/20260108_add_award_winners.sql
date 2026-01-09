-- Hall Of Fame: yearly winners for Malcolm Ball Award

create table if not exists public.award_winners (
  id uuid primary key default gen_random_uuid(),
  year integer not null,
  name text not null, -- freeform historic entry
  nominee_id uuid references public.award_nominees(id) on delete set null,
  added_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  unique(year)
);

alter table public.award_winners enable row level security;

create policy award_winners_select_all
  on public.award_winners for select using (true);

-- Admin-only inserts based on user_profiles.is_admin
create policy award_winners_insert_admin
  on public.award_winners for insert to authenticated
  with check (
    exists(
      select 1 from public.user_profiles up
      where up.id = auth.uid() and coalesce(up.is_admin, false) = true
    )
  );

-- Optional: allow admins to delete/update
create policy award_winners_update_admin
  on public.award_winners for update to authenticated
  using (
    exists(
      select 1 from public.user_profiles up
      where up.id = auth.uid() and coalesce(up.is_admin, false) = true
    )
  )
  with check (
    exists(
      select 1 from public.user_profiles up
      where up.id = auth.uid() and coalesce(up.is_admin, false) = true
    )
  );

create policy award_winners_delete_admin
  on public.award_winners for delete to authenticated
  using (
    exists(
      select 1 from public.user_profiles up
      where up.id = auth.uid() and coalesce(up.is_admin, false) = true
    )
  );
