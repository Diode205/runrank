-- Create table for membership migration codes and tracking
create table if not exists public.membership_migrations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid,
  from_club text,
  to_club text not null,
  migration_code text not null unique,
  status text not null default 'approved', -- requested | approved | completed | rejected
  created_at timestamptz not null default now(),
  approved_at timestamptz,
  completed_at timestamptz,
  constraint membership_migrations_status_check
    check (status in ('requested','approved','completed','rejected'))
);

comment on table public.membership_migrations is 'Tracks club-to-club membership migration codes and approval status.';
