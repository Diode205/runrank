begin;

create or replace function public.request_club_member_invite(
  p_club_name text,
  p_full_name text,
  p_uka_number text
)
returns table (
  invite_id uuid,
  full_name text,
  uka_number text,
  club_name text
)
language plpgsql
security definer
set search_path = public
as $$
declare
  existing_record public.club_member_invites%rowtype;
  inserted_record public.club_member_invites%rowtype;
begin
  if trim(coalesce(p_club_name, '')) = ''
    or trim(coalesce(p_full_name, '')) = ''
    or trim(coalesce(p_uka_number, '')) = '' then
    return;
  end if;

  select *
  into existing_record
  from public.club_member_invites cmi
  where lower(trim(cmi.club_name)) = lower(trim(p_club_name))
    and public.normalize_member_invite_value(cmi.uka_number)
      = public.normalize_member_invite_value(p_uka_number)
    and cmi.is_active = true
  limit 1;

  if found then
    if existing_record.claimed_by_user_id is not null
      or existing_record.claimed_at is not null then
      return;
    end if;

    if trim(existing_record.full_name) <> trim(p_full_name) then
      update public.club_member_invites
      set full_name = trim(p_full_name),
          updated_at = now()
      where id = existing_record.id
      returning * into existing_record;
    end if;

    invite_id := existing_record.id;
    full_name := existing_record.full_name;
    uka_number := existing_record.uka_number;
    club_name := existing_record.club_name;
    return next;
    return;
  end if;

  insert into public.club_member_invites (
    club_name,
    full_name,
    uka_number
  )
  values (
    trim(p_club_name),
    trim(p_full_name),
    trim(p_uka_number)
  )
  returning * into inserted_record;

  invite_id := inserted_record.id;
  full_name := inserted_record.full_name;
  uka_number := inserted_record.uka_number;
  club_name := inserted_record.club_name;
  return next;
end;
$$;

grant execute on function public.request_club_member_invite(text, text, text)
  to anon, authenticated;

commit;
