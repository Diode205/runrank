begin;

create or replace function public.normalize_member_invite_value(value text)
returns text
language sql
immutable
as $$
  select regexp_replace(upper(trim(coalesce(value, ''))), '[^A-Z0-9]', '', 'g');
$$;

create or replace function public.generate_member_invite_code()
returns text
language plpgsql
volatile
as $$
declare
  alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  code text := '';
  i integer;
begin
  for i in 1..6 loop
    code := code || substr(alphabet, floor(random() * length(alphabet) + 1)::int, 1);
  end loop;
  return code;
end;
$$;

create table if not exists public.club_member_invites (
  id uuid primary key default gen_random_uuid(),
  club_name text not null,
  full_name text not null,
  uka_number text not null,
  invite_code text not null default public.generate_member_invite_code(),
  is_active boolean not null default true,
  claimed_by_user_id uuid references auth.users(id) on delete set null,
  claimed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists club_member_invites_club_uka_active_uidx
  on public.club_member_invites (
    lower(trim(club_name)),
    public.normalize_member_invite_value(uka_number)
  )
  where is_active;

create unique index if not exists club_member_invites_club_code_active_uidx
  on public.club_member_invites (
    lower(trim(club_name)),
    public.normalize_member_invite_value(invite_code)
  )
  where is_active;

create index if not exists club_member_invites_claimed_by_idx
  on public.club_member_invites (claimed_by_user_id);

create or replace function public.set_club_member_invite_defaults()
returns trigger
language plpgsql
as $$
begin
  new.club_name := trim(new.club_name);
  new.full_name := trim(new.full_name);
  new.uka_number := trim(new.uka_number);
  new.invite_code := public.normalize_member_invite_value(new.invite_code);

  if new.invite_code = '' then
    new.invite_code := public.generate_member_invite_code();
  end if;

  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists set_club_member_invite_defaults
  on public.club_member_invites;

create trigger set_club_member_invite_defaults
  before insert or update on public.club_member_invites
  for each row
  execute function public.set_club_member_invite_defaults();

alter table public.club_member_invites enable row level security;

drop policy if exists "club_member_invites_admin_same_club_select"
  on public.club_member_invites;
drop policy if exists "club_member_invites_admin_same_club_write"
  on public.club_member_invites;

create policy "club_member_invites_admin_same_club_select"
  on public.club_member_invites
  for select to authenticated
  using (
    exists (
      select 1
      from public.user_profiles up
      where up.id = auth.uid()
        and coalesce(up.is_admin, false) = true
        and lower(trim(up.club)) = lower(trim(club_member_invites.club_name))
    )
  );

create policy "club_member_invites_admin_same_club_write"
  on public.club_member_invites
  for all to authenticated
  using (
    exists (
      select 1
      from public.user_profiles up
      where up.id = auth.uid()
        and coalesce(up.is_admin, false) = true
        and lower(trim(up.club)) = lower(trim(club_member_invites.club_name))
    )
  )
  with check (
    exists (
      select 1
      from public.user_profiles up
      where up.id = auth.uid()
        and coalesce(up.is_admin, false) = true
        and lower(trim(up.club)) = lower(trim(club_member_invites.club_name))
    )
  );

create or replace function public.validate_club_member_invite(
  p_club_name text,
  p_uka_number text,
  p_invite_code text
)
returns table (
  invite_id uuid,
  full_name text,
  uka_number text,
  club_name text
)
language sql
security definer
set search_path = public
as $$
  select cmi.id, cmi.full_name, cmi.uka_number, cmi.club_name
  from public.club_member_invites cmi
  where lower(trim(cmi.club_name)) = lower(trim(p_club_name))
    and public.normalize_member_invite_value(cmi.uka_number)
      = public.normalize_member_invite_value(p_uka_number)
    and public.normalize_member_invite_value(cmi.invite_code)
      = public.normalize_member_invite_value(p_invite_code)
    and cmi.is_active = true
    and cmi.claimed_by_user_id is null
    and cmi.claimed_at is null
  limit 1;
$$;

create or replace function public.claim_club_member_invite(p_invite_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  updated_count integer := 0;
begin
  if auth.uid() is null then
    return false;
  end if;

  update public.club_member_invites cmi
  set claimed_by_user_id = auth.uid(),
      claimed_at = now(),
      updated_at = now()
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

  get diagnostics updated_count = row_count;
  return updated_count = 1;
end;
$$;

grant select, insert, update, delete
  on public.club_member_invites
  to authenticated;

grant execute on function public.validate_club_member_invite(text, text, text)
  to anon, authenticated;

grant execute on function public.claim_club_member_invite(uuid)
  to authenticated;

commit;
