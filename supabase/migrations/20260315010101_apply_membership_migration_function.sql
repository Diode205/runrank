-- Creates or replaces a function to apply a membership migration
-- given a migration code and destination club.

create or replace function public.apply_membership_migration(
  p_migration_code text,
  p_new_club text
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_migration record;
begin
  -- Find an approved migration matching this code and destination club
  select *
  into v_migration
  from public.membership_migrations
  where migration_code = p_migration_code
    and to_club = p_new_club
    and status = 'approved'
  order by created_at asc
  limit 1;

  if not found then
    raise exception 'Invalid or expired migration code for this club.'
      using errcode = '22023';
  end if;

  if v_migration.user_id is null then
    raise exception 'Migration has no user associated.'
      using errcode = '22023';
  end if;

  -- Optional safety check: if there is an authenticated user, ensure
  -- this code belongs to them.
  if auth.uid() is not null and v_migration.user_id <> auth.uid() then
    raise exception 'This migration code does not belong to the current user.'
      using errcode = '22023';
  end if;

  -- Update the user profile to the new club.
  update public.user_profiles
  set club = v_migration.to_club
  where id = v_migration.user_id;

  -- Mark the migration as completed so it cannot be reused.
  update public.membership_migrations
  set status = 'completed'
  where id = v_migration.id;

  return jsonb_build_object(
    'user_id', v_migration.user_id,
    'from_club', v_migration.from_club,
    'to_club', v_migration.to_club
  );
end;
$$;
