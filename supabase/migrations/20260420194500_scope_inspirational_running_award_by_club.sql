begin;

create or replace function public.canonical_club_name(raw_club text)
returns text
language sql
immutable
as $$
  select case
    when raw_club is null then ''
    when lower(trim(raw_club)) in ('nrr', 'norwich-road-runners')
      or lower(trim(raw_club)) like '%norwich road runners%'
      then 'Norwich Road Runners'
    when lower(trim(raw_club)) in ('nnbr', 'north-norfolk-beach-runners')
      or lower(trim(raw_club)) like '%north norfolk beach runners%'
      then 'NNBR (North Norfolk Beach Runners)'
    else trim(raw_club)
  end
$$;

alter table public.award_nominees add column if not exists club_name text;
update public.award_nominees
set club_name = 'NNBR (North Norfolk Beach Runners)'
where club_name is null or trim(club_name) = '';
alter table public.award_nominees alter column club_name set not null;
drop index if exists public.award_nominees_name_lc_uidx;
create unique index if not exists award_nominees_club_name_name_lc_uidx
  on public.award_nominees(club_name, name_lc);
create index if not exists idx_award_nominees_club_name
  on public.award_nominees(club_name);

alter table public.award_nominations add column if not exists club_name text;
update public.award_nominations n
set club_name = coalesce(a.club_name, 'NNBR (North Norfolk Beach Runners)')
from public.award_nominees a
where a.id = n.nominee_id
  and (n.club_name is null or trim(n.club_name) = '');
update public.award_nominations
set club_name = 'NNBR (North Norfolk Beach Runners)'
where club_name is null or trim(club_name) = '';
alter table public.award_nominations alter column club_name set not null;
create index if not exists idx_award_nominations_club_name
  on public.award_nominations(club_name);

alter table public.award_votes add column if not exists club_name text;
update public.award_votes v
set club_name = coalesce(a.club_name, 'NNBR (North Norfolk Beach Runners)')
from public.award_nominees a
where a.id = v.nominee_id
  and (v.club_name is null or trim(v.club_name) = '');
update public.award_votes
set club_name = 'NNBR (North Norfolk Beach Runners)'
where club_name is null or trim(club_name) = '';
alter table public.award_votes alter column club_name set not null;
create index if not exists idx_award_votes_club_name
  on public.award_votes(club_name);

alter table public.award_emojis add column if not exists club_name text;
update public.award_emojis e
set club_name = coalesce(a.club_name, 'NNBR (North Norfolk Beach Runners)')
from public.award_nominees a
where a.id = e.nominee_id
  and (e.club_name is null or trim(e.club_name) = '');
update public.award_emojis
set club_name = 'NNBR (North Norfolk Beach Runners)'
where club_name is null or trim(club_name) = '';
alter table public.award_emojis alter column club_name set not null;
create index if not exists idx_award_emojis_club_name
  on public.award_emojis(club_name);

alter table public.award_comments add column if not exists club_name text;
update public.award_comments c
set club_name = coalesce(a.club_name, 'NNBR (North Norfolk Beach Runners)')
from public.award_nominees a
where a.id = c.nominee_id
  and (c.club_name is null or trim(c.club_name) = '');
update public.award_comments
set club_name = 'NNBR (North Norfolk Beach Runners)'
where club_name is null or trim(club_name) = '';
alter table public.award_comments alter column club_name set not null;
create index if not exists idx_award_comments_club_name
  on public.award_comments(club_name);

alter table public.award_winners add column if not exists club_name text;
update public.award_winners w
set club_name = coalesce(a.club_name, 'NNBR (North Norfolk Beach Runners)')
from public.award_nominees a
where a.id = w.nominee_id
  and (w.club_name is null or trim(w.club_name) = '');
update public.award_winners
set club_name = 'NNBR (North Norfolk Beach Runners)'
where club_name is null or trim(club_name) = '';
alter table public.award_winners alter column club_name set not null;
alter table public.award_winners drop constraint if exists award_winners_year_key;
create unique index if not exists award_winners_club_name_year_uidx
  on public.award_winners(club_name, year);
create index if not exists idx_award_winners_club_name
  on public.award_winners(club_name);

alter table public.award_chat_messages add column if not exists club_name text;
update public.award_chat_messages
set club_name = 'NNBR (North Norfolk Beach Runners)'
where club_name is null or trim(club_name) = '';
alter table public.award_chat_messages alter column club_name set not null;
create index if not exists idx_award_chat_messages_club_name
  on public.award_chat_messages(club_name);

alter table public.award_message_emojis add column if not exists club_name text;
update public.award_message_emojis me
set club_name = coalesce(m.club_name, 'NNBR (North Norfolk Beach Runners)')
from public.award_chat_messages m
where m.id = me.message_id
  and (me.club_name is null or trim(me.club_name) = '');
update public.award_message_emojis
set club_name = 'NNBR (North Norfolk Beach Runners)'
where club_name is null or trim(club_name) = '';
alter table public.award_message_emojis alter column club_name set not null;
create index if not exists idx_award_message_emojis_club_name
  on public.award_message_emojis(club_name);

alter table public.award_settings add column if not exists club_name text;
update public.award_settings
set club_name = 'NNBR (North Norfolk Beach Runners)'
where club_name is null or trim(club_name) = '';
alter table public.award_settings alter column club_name set not null;
alter table public.award_settings alter column singleton set not null;
alter table public.award_settings drop constraint if exists award_settings_pkey;
alter table public.award_settings add constraint award_settings_pkey primary key (club_name);

insert into public.award_settings (
  club_name,
  singleton,
  voting_ends_at,
  updated_by,
  updated_at
)
values (
  'Norwich Road Runners',
  true,
  null,
  null,
  now()
)
on conflict (club_name) do nothing;

drop policy if exists award_nominees_select_all on public.award_nominees;
drop policy if exists award_nominees_insert_auth on public.award_nominees;
drop policy if exists award_nominees_delete_admin on public.award_nominees;
drop policy if exists award_nominees_select_same_club on public.award_nominees;
drop policy if exists award_nominees_insert_same_club on public.award_nominees;
drop policy if exists award_nominees_delete_admin_same_club on public.award_nominees;

create policy award_nominees_select_same_club
  on public.award_nominees for select
  using (
    exists (
      select 1 from public.user_profiles up
      where up.id = auth.uid()
        and public.canonical_club_name(up.club) = public.canonical_club_name(public.award_nominees.club_name)
    )
  );

create policy award_nominees_insert_same_club
  on public.award_nominees for insert to authenticated
  with check (
    created_by = auth.uid()
    and exists (
      select 1 from public.user_profiles up
      where up.id = auth.uid()
        and public.canonical_club_name(up.club) = public.canonical_club_name(public.award_nominees.club_name)
    )
  );

create policy award_nominees_delete_admin_same_club
  on public.award_nominees for delete to authenticated
  using (
    exists (
      select 1 from public.user_profiles up
      where up.id = auth.uid()
        and coalesce(up.is_admin, false) = true
        and public.canonical_club_name(up.club) = public.canonical_club_name(public.award_nominees.club_name)
    )
  );

drop policy if exists award_nominations_select_all on public.award_nominations;
drop policy if exists award_nominations_insert_self on public.award_nominations;
drop policy if exists award_nominations_delete_admin on public.award_nominations;
drop policy if exists award_nominations_select_same_club on public.award_nominations;
drop policy if exists award_nominations_insert_same_club on public.award_nominations;
drop policy if exists award_nominations_delete_admin_same_club on public.award_nominations;

create policy award_nominations_select_same_club
  on public.award_nominations for select
  using (
    exists (
      select 1 from public.user_profiles up
      where up.id = auth.uid()
        and public.canonical_club_name(up.club) = public.canonical_club_name(public.award_nominations.club_name)
    )
  );

create policy award_nominations_insert_same_club
  on public.award_nominations for insert to authenticated
  with check (
    user_id = auth.uid()
    and exists (
      select 1 from public.user_profiles up
      where up.id = auth.uid()
        and public.canonical_club_name(up.club) = public.canonical_club_name(public.award_nominations.club_name)
    )
  );

create policy award_nominations_delete_admin_same_club
  on public.award_nominations for delete to authenticated
  using (
    exists (
      select 1 from public.user_profiles up
      where up.id = auth.uid()
        and coalesce(up.is_admin, false) = true
        and public.canonical_club_name(up.club) = public.canonical_club_name(public.award_nominations.club_name)
    )
  );

drop policy if exists award_votes_select_all on public.award_votes;
drop policy if exists award_votes_insert_self on public.award_votes;
drop policy if exists award_votes_delete_admin on public.award_votes;
drop policy if exists award_votes_select_same_club on public.award_votes;
drop policy if exists award_votes_insert_same_club on public.award_votes;
drop policy if exists award_votes_delete_admin_same_club on public.award_votes;

create policy award_votes_select_same_club
  on public.award_votes for select
  using (
    exists (
      select 1 from public.user_profiles up
      where up.id = auth.uid()
        and public.canonical_club_name(up.club) = public.canonical_club_name(public.award_votes.club_name)
    )
  );

create policy award_votes_insert_same_club
  on public.award_votes for insert to authenticated
  with check (
    user_id = auth.uid()
    and exists (
      select 1 from public.user_profiles up
      where up.id = auth.uid()
        and public.canonical_club_name(up.club) = public.canonical_club_name(public.award_votes.club_name)
    )
  );

create policy award_votes_delete_admin_same_club
  on public.award_votes for delete to authenticated
  using (
    exists (
      select 1 from public.user_profiles up
      where up.id = auth.uid()
        and coalesce(up.is_admin, false) = true
        and public.canonical_club_name(up.club) = public.canonical_club_name(public.award_votes.club_name)
    )
  );

drop policy if exists award_emojis_select_all on public.award_emojis;
drop policy if exists award_emojis_insert_self on public.award_emojis;
drop policy if exists award_emojis_delete_admin on public.award_emojis;
drop policy if exists award_emojis_select_same_club on public.award_emojis;
drop policy if exists award_emojis_insert_same_club on public.award_emojis;
drop policy if exists award_emojis_delete_admin_same_club on public.award_emojis;

create policy award_emojis_select_same_club
  on public.award_emojis for select
  using (
    exists (
      select 1 from public.user_profiles up
      where up.id = auth.uid()
        and public.canonical_club_name(up.club) = public.canonical_club_name(public.award_emojis.club_name)
    )
  );

create policy award_emojis_insert_same_club
  on public.award_emojis for insert to authenticated
  with check (
    user_id = auth.uid()
    and exists (
      select 1 from public.user_profiles up
      where up.id = auth.uid()
        and public.canonical_club_name(up.club) = public.canonical_club_name(public.award_emojis.club_name)
    )
  );

create policy award_emojis_delete_admin_same_club
  on public.award_emojis for delete to authenticated
  using (
    exists (
      select 1 from public.user_profiles up
      where up.id = auth.uid()
        and coalesce(up.is_admin, false) = true
        and public.canonical_club_name(up.club) = public.canonical_club_name(public.award_emojis.club_name)
    )
  );

drop policy if exists award_comments_select_all on public.award_comments;
drop policy if exists award_comments_insert_self on public.award_comments;
drop policy if exists award_comments_delete_admin on public.award_comments;
drop policy if exists award_comments_select_same_club on public.award_comments;
drop policy if exists award_comments_insert_same_club on public.award_comments;
drop policy if exists award_comments_delete_admin_same_club on public.award_comments;

create policy award_comments_select_same_club
  on public.award_comments for select
  using (
    exists (
      select 1 from public.user_profiles up
      where up.id = auth.uid()
        and public.canonical_club_name(up.club) = public.canonical_club_name(public.award_comments.club_name)
    )
  );

create policy award_comments_insert_same_club
  on public.award_comments for insert to authenticated
  with check (
    user_id = auth.uid()
    and exists (
      select 1 from public.user_profiles up
      where up.id = auth.uid()
        and public.canonical_club_name(up.club) = public.canonical_club_name(public.award_comments.club_name)
    )
  );

create policy award_comments_delete_admin_same_club
  on public.award_comments for delete to authenticated
  using (
    exists (
      select 1 from public.user_profiles up
      where up.id = auth.uid()
        and coalesce(up.is_admin, false) = true
        and public.canonical_club_name(up.club) = public.canonical_club_name(public.award_comments.club_name)
    )
  );

drop policy if exists award_winners_select_all on public.award_winners;
drop policy if exists award_winners_insert_admin on public.award_winners;
drop policy if exists award_winners_update_admin on public.award_winners;
drop policy if exists award_winners_delete_admin on public.award_winners;
drop policy if exists award_winners_select_same_club on public.award_winners;
drop policy if exists award_winners_insert_admin_same_club on public.award_winners;
drop policy if exists award_winners_update_admin_same_club on public.award_winners;
drop policy if exists award_winners_delete_admin_same_club on public.award_winners;

create policy award_winners_select_same_club
  on public.award_winners for select
  using (
    exists (
      select 1 from public.user_profiles up
      where up.id = auth.uid()
        and public.canonical_club_name(up.club) = public.canonical_club_name(public.award_winners.club_name)
    )
  );

create policy award_winners_insert_admin_same_club
  on public.award_winners for insert to authenticated
  with check (
    exists (
      select 1 from public.user_profiles up
      where up.id = auth.uid()
        and coalesce(up.is_admin, false) = true
        and public.canonical_club_name(up.club) = public.canonical_club_name(public.award_winners.club_name)
    )
  );

create policy award_winners_update_admin_same_club
  on public.award_winners for update to authenticated
  using (
    exists (
      select 1 from public.user_profiles up
      where up.id = auth.uid()
        and coalesce(up.is_admin, false) = true
        and public.canonical_club_name(up.club) = public.canonical_club_name(public.award_winners.club_name)
    )
  )
  with check (
    exists (
      select 1 from public.user_profiles up
      where up.id = auth.uid()
        and coalesce(up.is_admin, false) = true
        and public.canonical_club_name(up.club) = public.canonical_club_name(public.award_winners.club_name)
    )
  );

create policy award_winners_delete_admin_same_club
  on public.award_winners for delete to authenticated
  using (
    exists (
      select 1 from public.user_profiles up
      where up.id = auth.uid()
        and coalesce(up.is_admin, false) = true
        and public.canonical_club_name(up.club) = public.canonical_club_name(public.award_winners.club_name)
    )
  );

drop policy if exists read_chat_messages on public.award_chat_messages;
drop policy if exists insert_chat_message on public.award_chat_messages;
drop policy if exists update_own_chat_message on public.award_chat_messages;
drop policy if exists delete_own_chat_message on public.award_chat_messages;
drop policy if exists delete_chat_messages_admin on public.award_chat_messages;
drop policy if exists read_chat_messages_same_club on public.award_chat_messages;
drop policy if exists insert_chat_message_same_club on public.award_chat_messages;
drop policy if exists update_own_chat_message_same_club on public.award_chat_messages;
drop policy if exists delete_own_chat_message_same_club on public.award_chat_messages;
drop policy if exists delete_chat_messages_admin_same_club on public.award_chat_messages;

create policy read_chat_messages_same_club
  on public.award_chat_messages for select
  using (
    exists (
      select 1 from public.user_profiles up
      where up.id = auth.uid()
        and public.canonical_club_name(up.club) = public.canonical_club_name(public.award_chat_messages.club_name)
    )
  );

create policy insert_chat_message_same_club
  on public.award_chat_messages for insert to authenticated
  with check (
    auth.uid() = user_id
    and exists (
      select 1 from public.user_profiles up
      where up.id = auth.uid()
        and public.canonical_club_name(up.club) = public.canonical_club_name(public.award_chat_messages.club_name)
    )
  );

create policy update_own_chat_message_same_club
  on public.award_chat_messages for update to authenticated
  using (
    auth.uid() = user_id
    and exists (
      select 1 from public.user_profiles up
      where up.id = auth.uid()
        and public.canonical_club_name(up.club) = public.canonical_club_name(public.award_chat_messages.club_name)
    )
  )
  with check (
    auth.uid() = user_id
    and exists (
      select 1 from public.user_profiles up
      where up.id = auth.uid()
        and public.canonical_club_name(up.club) = public.canonical_club_name(public.award_chat_messages.club_name)
    )
  );

create policy delete_own_chat_message_same_club
  on public.award_chat_messages for delete to authenticated
  using (
    auth.uid() = user_id
    and exists (
      select 1 from public.user_profiles up
      where up.id = auth.uid()
        and public.canonical_club_name(up.club) = public.canonical_club_name(public.award_chat_messages.club_name)
    )
  );

create policy delete_chat_messages_admin_same_club
  on public.award_chat_messages for delete to authenticated
  using (
    exists (
      select 1 from public.user_profiles up
      where up.id = auth.uid()
        and coalesce(up.is_admin, false) = true
        and public.canonical_club_name(up.club) = public.canonical_club_name(public.award_chat_messages.club_name)
    )
  );

drop policy if exists read_message_emojis on public.award_message_emojis;
drop policy if exists insert_message_emoji on public.award_message_emojis;
drop policy if exists award_message_emojis_delete_admin on public.award_message_emojis;
drop policy if exists read_message_emojis_same_club on public.award_message_emojis;
drop policy if exists insert_message_emoji_same_club on public.award_message_emojis;
drop policy if exists award_message_emojis_delete_admin_same_club on public.award_message_emojis;

create policy read_message_emojis_same_club
  on public.award_message_emojis for select
  using (
    exists (
      select 1 from public.user_profiles up
      where up.id = auth.uid()
        and public.canonical_club_name(up.club) = public.canonical_club_name(public.award_message_emojis.club_name)
    )
  );

create policy insert_message_emoji_same_club
  on public.award_message_emojis for insert to authenticated
  with check (
    auth.uid() = user_id
    and exists (
      select 1 from public.user_profiles up
      where up.id = auth.uid()
        and public.canonical_club_name(up.club) = public.canonical_club_name(public.award_message_emojis.club_name)
    )
  );

create policy award_message_emojis_delete_admin_same_club
  on public.award_message_emojis for delete to authenticated
  using (
    exists (
      select 1 from public.user_profiles up
      where up.id = auth.uid()
        and coalesce(up.is_admin, false) = true
        and public.canonical_club_name(up.club) = public.canonical_club_name(public.award_message_emojis.club_name)
    )
  );

drop policy if exists award_settings_select_all on public.award_settings;
drop policy if exists award_settings_insert_admin on public.award_settings;
drop policy if exists award_settings_update_admin on public.award_settings;
drop policy if exists award_settings_delete_admin on public.award_settings;
drop policy if exists award_settings_select_same_club on public.award_settings;
drop policy if exists award_settings_insert_admin_same_club on public.award_settings;
drop policy if exists award_settings_update_admin_same_club on public.award_settings;
drop policy if exists award_settings_delete_admin_same_club on public.award_settings;

create policy award_settings_select_same_club
  on public.award_settings for select
  using (
    exists (
      select 1 from public.user_profiles up
      where up.id = auth.uid()
        and public.canonical_club_name(up.club) = public.canonical_club_name(public.award_settings.club_name)
    )
  );

create policy award_settings_insert_admin_same_club
  on public.award_settings for insert to authenticated
  with check (
    exists (
      select 1 from public.user_profiles up
      where up.id = auth.uid()
        and coalesce(up.is_admin, false) = true
        and public.canonical_club_name(up.club) = public.canonical_club_name(public.award_settings.club_name)
    )
  );

create policy award_settings_update_admin_same_club
  on public.award_settings for update to authenticated
  using (
    exists (
      select 1 from public.user_profiles up
      where up.id = auth.uid()
        and coalesce(up.is_admin, false) = true
        and public.canonical_club_name(up.club) = public.canonical_club_name(public.award_settings.club_name)
    )
  )
  with check (
    exists (
      select 1 from public.user_profiles up
      where up.id = auth.uid()
        and coalesce(up.is_admin, false) = true
        and public.canonical_club_name(up.club) = public.canonical_club_name(public.award_settings.club_name)
    )
  );

create policy award_settings_delete_admin_same_club
  on public.award_settings for delete to authenticated
  using (
    exists (
      select 1 from public.user_profiles up
      where up.id = auth.uid()
        and coalesce(up.is_admin, false) = true
        and public.canonical_club_name(up.club) = public.canonical_club_name(public.award_settings.club_name)
    )
  );

commit;