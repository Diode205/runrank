create table if not exists public.password_reset_codes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  club text,
  reset_code text not null unique,
  status text not null default 'issued',
  created_by uuid,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '7 days'),
  used_at timestamptz,
  constraint password_reset_codes_status_check
    check (status in ('issued', 'used', 'revoked'))
);

comment on table public.password_reset_codes is
  'Tracks one-off admin-issued password reset codes for members.';

alter table if exists public.password_reset_codes enable row level security;

drop policy if exists "password_reset_codes_admin_read" on public.password_reset_codes;
drop policy if exists "password_reset_codes_admin_insert" on public.password_reset_codes;

create policy "password_reset_codes_admin_read"
on public.password_reset_codes
for select
to authenticated
using (
  auth.uid() is not null
  and exists (
    select 1
    from public.user_profiles up
    where up.id = auth.uid()
      and up.is_admin = true
      and up.club = password_reset_codes.club
  )
);

create policy "password_reset_codes_admin_insert"
on public.password_reset_codes
for insert
to authenticated
with check (
  auth.uid() is not null
  and exists (
    select 1
    from public.user_profiles up
    where up.id = auth.uid()
      and up.is_admin = true
      and up.club = password_reset_codes.club
  )
);
