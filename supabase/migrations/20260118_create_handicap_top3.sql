-- Create Top 3 finishers table for Handicap races
create table if not exists public.handicap_top3 (
  race_id text primary key,
  gold text,
  silver text,
  bronze text,
  updated_at timestamptz not null default now(),
  updated_by uuid
);

-- Enable Row Level Security
alter table public.handicap_top3 enable row level security;

-- Read access for all authenticated users
drop policy if exists "handicap_top3_read_auth" on public.handicap_top3;
create policy "handicap_top3_read_auth" on public.handicap_top3
  for select
  to authenticated
  using (true);

-- Insert restricted to admins
drop policy if exists "handicap_top3_insert_admin" on public.handicap_top3;
create policy "handicap_top3_insert_admin" on public.handicap_top3
  for insert
  to authenticated
  with check (
    exists (
      select 1 from public.user_profiles up
      where up.id = auth.uid() and up.is_admin = true
    )
  );

-- Update restricted to admins
drop policy if exists "handicap_top3_update_admin" on public.handicap_top3;
create policy "handicap_top3_update_admin" on public.handicap_top3
  for update
  to authenticated
  using (
    exists (
      select 1 from public.user_profiles up
      where up.id = auth.uid() and up.is_admin = true
    )
  )
  with check (
    exists (
      select 1 from public.user_profiles up
      where up.id = auth.uid() and up.is_admin = true
    )
  );
