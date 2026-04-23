-- Notifications RLS policies
-- Fixes: "only WITH CHECK expression allowed for INSERT"
-- Run this in Supabase SQL editor as postgres (or with service role)

begin;

-- 1) Ensure RLS is enabled
alter table public.notifications enable row level security;

-- 2) Drop any old/conflicting policies
drop policy if exists "Users can view own notifications" on public.notifications;
drop policy if exists "Users can update own notifications" on public.notifications;
drop policy if exists "Users can delete own notifications" on public.notifications;
drop policy if exists "Admins can insert notifications for any user" on public.notifications;

-- 3) Read: users can read their own notifications
create policy "Users can view own notifications"
  on public.notifications
  for select
  using (user_id = auth.uid());

-- 4) Insert: admins can insert notifications for any user
-- IMPORTANT: INSERT policies must use WITH CHECK (not USING)
-- Any authenticated member can notify recipients in the same club.
create or replace function public.canonical_club_name(raw_club text)
returns text
language sql
immutable
as $$
  select case
    when raw_club is null or btrim(raw_club) = '' then ''
    when lower(btrim(raw_club)) = 'nrr'
      or lower(btrim(raw_club)) like '%norwich road runners%'
      then 'Norwich Road Runners'
    when lower(btrim(raw_club)) = 'nnbr'
      or lower(btrim(raw_club)) like '%north norfolk beach runners%'
      then 'NNBR (North Norfolk Beach Runners)'
    else btrim(raw_club)
  end
$$;

drop policy if exists "Authenticated users can insert same-club notifications"
  on public.notifications;

create policy "Authenticated users can insert same-club notifications"
  on public.notifications
  for insert
  with check (
    exists (
      select 1
      from public.user_profiles actor
      left join public.user_profiles recipient
        on recipient.id = public.notifications.user_id
      where actor.id = auth.uid()
        and (
          coalesce(actor.is_admin, false) = true
          or (
            recipient.id is not null
            and public.canonical_club_name(actor.club) <> ''
            and public.canonical_club_name(actor.club) =
                public.canonical_club_name(recipient.club)
          )
        )
    )
  );

-- 5) Update: users can update their own notifications (eg. mark read)
create policy "Users can update own notifications"
  on public.notifications
  for update
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- 6) Delete: users can delete their own notifications (optional)
create policy "Users can delete own notifications"
  on public.notifications
  for delete
  using (user_id = auth.uid());

-- 7) Helpful indexes for unread counts
create index if not exists idx_notifications_user_id on public.notifications(user_id);
create index if not exists idx_notifications_user_unread on public.notifications(user_id, is_read);

commit;
