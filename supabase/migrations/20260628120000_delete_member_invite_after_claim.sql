begin;

-- Member invite codes should remain valid until used. If an earlier/manual
-- version of the table has a time limit column, remove it.
alter table public.club_member_invites
  drop column if exists expires_at;

-- Existing already-claimed rows no longer need to keep their invite codes.
delete from public.club_member_invites
where claimed_by_user_id is not null
   or claimed_at is not null;

create or replace function public.claim_club_member_invite(p_invite_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  deleted_count integer := 0;
begin
  if auth.uid() is null then
    return false;
  end if;

  delete from public.club_member_invites cmi
  where cmi.id = p_invite_id
    and cmi.is_active = true
    and cmi.claimed_by_user_id is null
    and cmi.claimed_at is null
    and exists (
      select 1
      from public.user_profiles up
      where up.id = auth.uid()
        and lower(trim(up.club)) = lower(trim(cmi.club_name))
        and public.normalize_member_invite_value(up.uka_number)
          = public.normalize_member_invite_value(cmi.uka_number)
    );

  get diagnostics deleted_count = row_count;
  return deleted_count = 1;
end;
$$;

grant execute on function public.claim_club_member_invite(uuid)
  to authenticated;

commit;
