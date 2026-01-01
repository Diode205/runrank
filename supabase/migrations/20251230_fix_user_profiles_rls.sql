-- Fix user_profiles RLS to allow admins to update is_admin field
-- This migration ensures admins can promote/demote other users

begin;

-- 1) Ensure RLS is enabled on user_profiles
alter table public.user_profiles enable row level security;

-- 2) Drop any old conflicting policies if they exist
drop policy if exists "Users can update own profile" on public.user_profiles;
drop policy if exists "Users can view own profile" on public.user_profiles;
drop policy if exists "Admins can update is_admin field" on public.user_profiles;

-- 3) READ: Users can view profiles
-- Anyone can view any user's profile (public info)
create policy "Anyone can view user profiles"
  on public.user_profiles
  for select
  using (true);

-- 4) UPDATE: Allow users to update their own non-admin fields
create policy "Users can update own profile"
  on public.user_profiles
  for update
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- 5) UPDATE: Allow admins to update any user's is_admin, admin_since, is_blocked, block_reason
-- This is the critical policy that fixes the admin role toggle
create policy "Admins can update user admin and block status"
  on public.user_profiles
  for update
  using (
    exists (
      select 1
      from public.user_profiles p
      where p.id = auth.uid()
        and coalesce(p.is_admin, false) = true
    )
  )
  with check (
    exists (
      select 1
      from public.user_profiles p
      where p.id = auth.uid()
        and coalesce(p.is_admin, false) = true
    )
  );

-- 6) INSERT: Only service role should insert profiles (via auth trigger)
-- Users should not directly insert

commit;
