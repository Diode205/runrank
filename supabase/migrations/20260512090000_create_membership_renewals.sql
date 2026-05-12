create table if not exists public.membership_renewals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  club text not null,
  membership_year_start date not null,
  renewed_at timestamptz not null default now(),
  renewed_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  constraint membership_renewals_unique unique (
    user_id,
    club,
    membership_year_start
  )
);

alter table public.membership_renewals enable row level security;

drop policy if exists "Membership renewals readable by authenticated users"
  on public.membership_renewals;
create policy "Membership renewals readable by authenticated users"
  on public.membership_renewals
  for select
  to authenticated
  using (true);

drop policy if exists "Authenticated users can insert membership renewals"
  on public.membership_renewals;
create policy "Authenticated users can insert membership renewals"
  on public.membership_renewals
  for insert
  to authenticated
  with check (auth.uid() = renewed_by);

drop policy if exists "Authenticated users can update membership renewals"
  on public.membership_renewals;
create policy "Authenticated users can update membership renewals"
  on public.membership_renewals
  for update
  to authenticated
  using (true)
  with check (true);
