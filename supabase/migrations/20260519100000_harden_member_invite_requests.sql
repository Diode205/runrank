begin;

-- If duplicate active invite rows already exist for the same club + UKA,
-- keep the earliest claimed row where present, otherwise the earliest pending
-- row. Older pending codes are therefore preserved for admins/members.
with ranked as (
  select
    id,
    row_number() over (
      partition by
        lower(trim(club_name)),
        public.normalize_member_invite_value(uka_number)
      order by
        case
          when claimed_by_user_id is not null or claimed_at is not null then 0
          else 1
        end,
        created_at,
        id
    ) as rn
  from public.club_member_invites
  where is_active = true
)
update public.club_member_invites cmi
set is_active = false,
    updated_at = now()
from ranked r
where cmi.id = r.id
  and r.rn > 1;

create unique index if not exists club_member_invites_club_uka_active_uidx
  on public.club_member_invites (
    lower(trim(club_name)),
    public.normalize_member_invite_value(uka_number)
  )
  where is_active;

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
  normalized_club text := lower(trim(coalesce(p_club_name, '')));
  normalized_uka text := public.normalize_member_invite_value(p_uka_number);
begin
  if normalized_club = ''
    or trim(coalesce(p_full_name, '')) = ''
    or normalized_uka = '' then
    return;
  end if;

  -- Serialise requests for the same club + UKA so repeated taps, back/forward
  -- navigation, or two devices cannot create two active invite codes.
  perform pg_advisory_xact_lock(hashtext(normalized_club), hashtext(normalized_uka));

  select *
  into existing_record
  from public.club_member_invites cmi
  where lower(trim(cmi.club_name)) = normalized_club
    and public.normalize_member_invite_value(cmi.uka_number) = normalized_uka
    and cmi.is_active = true
  order by cmi.created_at, cmi.id
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
