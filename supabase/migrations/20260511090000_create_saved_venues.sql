create table if not exists public.saved_venues (
  id uuid primary key default gen_random_uuid(),
  club text not null,
  venue text not null,
  address text not null default '',
  latitude double precision not null,
  longitude double precision not null,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint saved_venues_latitude_range check (latitude between -90 and 90),
  constraint saved_venues_longitude_range check (longitude between -180 and 180),
  constraint saved_venues_unique unique (club, venue, address)
);

alter table public.saved_venues enable row level security;

drop policy if exists "Saved venues are readable by authenticated users"
  on public.saved_venues;
create policy "Saved venues are readable by authenticated users"
  on public.saved_venues
  for select
  to authenticated
  using (true);

drop policy if exists "Authenticated users can insert saved venues"
  on public.saved_venues;
create policy "Authenticated users can insert saved venues"
  on public.saved_venues
  for insert
  to authenticated
  with check (auth.uid() = created_by);

drop policy if exists "Authenticated users can update saved venues"
  on public.saved_venues;
create policy "Authenticated users can update saved venues"
  on public.saved_venues
  for update
  to authenticated
  using (true)
  with check (true);

drop policy if exists "Authenticated users can delete saved venues"
  on public.saved_venues;
create policy "Authenticated users can delete saved venues"
  on public.saved_venues
  for delete
  to authenticated
  using (true);
