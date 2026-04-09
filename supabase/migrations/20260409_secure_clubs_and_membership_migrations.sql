-- Harden client-accessible tables before App Store submission.
-- app_clubs should be public-read, but not openly writable.
-- membership_migrations should be restricted to the owning user and
-- admins of the source club that created the migration.

alter table if exists public.app_clubs enable row level security;

drop policy if exists "app_clubs_select_all" on public.app_clubs;
drop policy if exists "app_clubs_public_read" on public.app_clubs;

create policy "app_clubs_public_read"
on public.app_clubs
for select
to anon, authenticated
using (true);

alter table if exists public.membership_migrations enable row level security;

drop policy if exists "membership_migrations_owner_read" on public.membership_migrations;
drop policy if exists "membership_migrations_admin_read" on public.membership_migrations;
drop policy if exists "membership_migrations_admin_insert" on public.membership_migrations;

create policy "membership_migrations_owner_read"
on public.membership_migrations
for select
to authenticated
using (auth.uid() = user_id);

create policy "membership_migrations_admin_read"
on public.membership_migrations
for select
to authenticated
using (
  auth.uid() is not null
  and exists (
    select 1
    from public.user_profiles up
    where up.id = auth.uid()
      and up.is_admin = true
      and up.club = membership_migrations.from_club
  )
);

create policy "membership_migrations_admin_insert"
on public.membership_migrations
for insert
to authenticated
with check (
  auth.uid() is not null
  and exists (
    select 1
    from public.user_profiles up
    where up.id = auth.uid()
      and up.is_admin = true
      and up.club = membership_migrations.from_club
  )
);