-- Add block flags to user_profiles
-- Run with: supabase db push (or apply via Supabase SQL editor)

begin;

-- Columns (idempotent)
alter table public.user_profiles
  add column if not exists is_blocked boolean default false,
  add column if not exists block_reason text;

-- Backfill NULLs to false so checks behave consistently
update public.user_profiles
set is_blocked = false
where is_blocked is null;

-- Helpful index for admin queries
create index if not exists idx_user_profiles_is_blocked
  on public.user_profiles(is_blocked);

commit;
