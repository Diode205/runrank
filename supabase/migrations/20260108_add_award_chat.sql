-- Award general chat and message reactions
-- Creates tables: award_chat_messages, award_message_emojis, with RLS

begin;

create table if not exists public.award_chat_messages (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  content text not null,
  created_at timestamptz not null default now()
);

alter table public.award_chat_messages enable row level security;

-- Select: anyone logged in can read chat
create policy if not exists "read chat messages"
  on public.award_chat_messages
  for select
  using (true);

-- Insert: any authenticated user can post
create policy if not exists "insert own chat message"
  on public.award_chat_messages
  for insert
  with check (auth.uid() = user_id);

-- Delete/Update: only author can modify (optional)
create policy if not exists "update own chat message"
  on public.award_chat_messages
  for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy if not exists "delete own chat message"
  on public.award_chat_messages
  for delete
  using (auth.uid() = user_id);

-- Reactions to chat messages
create table if not exists public.award_message_emojis (
  id uuid primary key default gen_random_uuid(),
  message_id uuid not null references public.award_chat_messages(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  emoji text not null,
  created_at timestamptz not null default now()
);

alter table public.award_message_emojis enable row level security;

create policy if not exists "read message emojis"
  on public.award_message_emojis
  for select
  using (true);

create policy if not exists "insert own message emoji"
  on public.award_message_emojis
  for insert
  with check (auth.uid() = user_id);

create index if not exists idx_award_message_emojis_message on public.award_message_emojis(message_id);

commit;
