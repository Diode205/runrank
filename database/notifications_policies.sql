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
-- Admin is determined solely by user_profiles.is_admin
create policy "Admins can insert notifications for any user"
  on public.notifications
  for insert
  with check (
    exists (
      select 1
      from public.user_profiles p
      where p.id = auth.uid()
        and coalesce(p.is_admin, false) = true
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
