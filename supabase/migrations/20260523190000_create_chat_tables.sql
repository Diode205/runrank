begin;

create table if not exists public.chat_threads (
  id uuid primary key default gen_random_uuid(),
  club text not null,
  title text,
  is_group boolean not null default false,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.chat_participants (
  thread_id uuid not null references public.chat_threads(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  joined_at timestamptz not null default now(),
  last_read_at timestamptz,
  archived_at timestamptz,
  left_at timestamptz,
  primary key (thread_id, user_id)
);

create table if not exists public.chat_messages (
  id uuid primary key default gen_random_uuid(),
  thread_id uuid not null references public.chat_threads(id) on delete cascade,
  sender_id uuid references auth.users(id) on delete set null,
  body text not null,
  created_at timestamptz not null default now(),
  deleted_at timestamptz
);

create index if not exists chat_threads_club_updated_idx
  on public.chat_threads (club, updated_at desc);

create index if not exists chat_participants_user_idx
  on public.chat_participants (user_id, archived_at, left_at);

create index if not exists chat_messages_thread_created_idx
  on public.chat_messages (thread_id, created_at desc);

alter table public.chat_threads enable row level security;
alter table public.chat_participants enable row level security;
alter table public.chat_messages enable row level security;

create or replace function public.is_chat_participant(target_thread_id uuid)
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.chat_participants cp
    where cp.thread_id = target_thread_id
      and cp.user_id = auth.uid()
      and cp.left_at is null
  );
$$;

drop policy if exists "Chat participants can view their threads" on public.chat_threads;
create policy "Chat participants can view their threads"
  on public.chat_threads
  for select
  using (created_by = auth.uid() or public.is_chat_participant(id));

drop policy if exists "Authenticated users can create chat threads" on public.chat_threads;
create policy "Authenticated users can create chat threads"
  on public.chat_threads
  for insert
  with check (created_by = auth.uid());

drop policy if exists "Thread creators can update chat threads" on public.chat_threads;
create policy "Thread creators can update chat threads"
  on public.chat_threads
  for update
  using (created_by = auth.uid())
  with check (created_by = auth.uid());

drop policy if exists "Thread creators can delete chat threads" on public.chat_threads;
create policy "Thread creators can delete chat threads"
  on public.chat_threads
  for delete
  using (created_by = auth.uid());

drop policy if exists "Chat participants can view participant rows" on public.chat_participants;
create policy "Chat participants can view participant rows"
  on public.chat_participants
  for select
  using (public.is_chat_participant(thread_id));

drop policy if exists "Users can add participants to own chat threads" on public.chat_participants;
create policy "Users can add participants to own chat threads"
  on public.chat_participants
  for insert
  with check (
    user_id = auth.uid()
    or exists (
      select 1
      from public.chat_threads ct
      where ct.id = chat_participants.thread_id
        and ct.created_by = auth.uid()
    )
  );

drop policy if exists "Users can update own chat participant row" on public.chat_participants;
create policy "Users can update own chat participant row"
  on public.chat_participants
  for update
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists "Chat participants can view messages" on public.chat_messages;
create policy "Chat participants can view messages"
  on public.chat_messages
  for select
  using (public.is_chat_participant(thread_id));

drop policy if exists "Chat participants can send messages" on public.chat_messages;
create policy "Chat participants can send messages"
  on public.chat_messages
  for insert
  with check (
    sender_id = auth.uid()
    and exists (
      select 1
      from public.chat_participants cp
      where cp.thread_id = chat_messages.thread_id
        and cp.user_id = auth.uid()
        and cp.left_at is null
    )
  );

drop policy if exists "Senders can soft delete own messages" on public.chat_messages;
create policy "Senders can soft delete own messages"
  on public.chat_messages
  for update
  using (sender_id = auth.uid())
  with check (sender_id = auth.uid());

grant select, insert, update, delete on table public.chat_threads to authenticated;
grant select, insert, update on table public.chat_participants to authenticated;
grant select, insert, update on table public.chat_messages to authenticated;
grant execute on function public.is_chat_participant(uuid) to authenticated;

commit;
