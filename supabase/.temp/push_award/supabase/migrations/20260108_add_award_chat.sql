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

-- RLS policies (idempotent): use DO blocks to avoid duplicates
-- Read: authenticated users can read chat
do $$
begin
  if not exists (
    select 1
    from pg_policies p
    join pg_class c on c.oid = p.polrelid
    join pg_namespace n on n.oid = c.relnamespace
    where p.polname = 'read_chat_messages'
      and n.nspname = 'public'
      and c.relname = 'award_chat_messages'
  ) then
    create policy read_chat_messages
      on public.award_chat_messages
      for select
      using (auth.uid() is not null);
  end if;
end$$;

-- Insert: only authenticated users; row must match author
do $$
begin
  if not exists (
    select 1
    from pg_policies p
    join pg_class c on c.oid = p.polrelid
    join pg_namespace n on n.oid = c.relnamespace
    where p.polname = 'insert_chat_message'
      and n.nspname = 'public'
      and c.relname = 'award_chat_messages'
  ) then
    create policy insert_chat_message
      on public.award_chat_messages
      for insert
      with check (auth.uid() = user_id);
  end if;
end$$;

-- Update: only the author can modify
do $$
begin
  if not exists (
    select 1
    from pg_policies p
    join pg_class c on c.oid = p.polrelid
    join pg_namespace n on n.oid = c.relnamespace
    where p.polname = 'update_own_chat_message'
      and n.nspname = 'public'
      and c.relname = 'award_chat_messages'
  ) then
    create policy update_own_chat_message
      on public.award_chat_messages
      for update
      using (auth.uid() = user_id)
      with check (auth.uid() = user_id);
  end if;
end$$;

-- Delete: only the author can delete
do $$
begin
  if not exists (
    select 1
    from pg_policies p
    join pg_class c on c.oid = p.polrelid
    join pg_namespace n on n.oid = c.relnamespace
    where p.polname = 'delete_own_chat_message'
      and n.nspname = 'public'
      and c.relname = 'award_chat_messages'
  ) then
    create policy delete_own_chat_message
      on public.award_chat_messages
      for delete
      using (auth.uid() = user_id);
  end if;
end$$;

-- Reactions to chat messages
create table if not exists public.award_message_emojis (
  id uuid primary key default gen_random_uuid(),
  message_id uuid not null references public.award_chat_messages(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  emoji text not null,
  created_at timestamptz not null default now()
);

alter table public.award_message_emojis enable row level security;

-- Unique to prevent duplicate reactions per user/emoji/message
-- Use a unique index (portable across PG versions)
create unique index if not exists ux_award_message_emojis_unique
  on public.award_message_emojis(message_id, user_id, emoji);

-- Read: authenticated users can read emojis
do $$
begin
  if not exists (
    select 1
    from pg_policies p
    join pg_class c on c.oid = p.polrelid
    join pg_namespace n on n.oid = c.relnamespace
    where p.polname = 'read_message_emojis'
      and n.nspname = 'public'
      and c.relname = 'award_message_emojis'
  ) then
    create policy read_message_emojis
      on public.award_message_emojis
      for select
      using (auth.uid() is not null);
  end if;
end$$;

-- Insert: only authenticated user for self
do $$
begin
  if not exists (
    select 1
    from pg_policies p
    join pg_class c on c.oid = p.polrelid
    join pg_namespace n on n.oid = c.relnamespace
    where p.polname = 'insert_message_emoji'
      and n.nspname = 'public'
      and c.relname = 'award_message_emojis'
  ) then
    create policy insert_message_emoji
      on public.award_message_emojis
      for insert
      with check (auth.uid() = user_id);
  end if;
end$$;

create index if not exists idx_award_message_emojis_message on public.award_message_emojis(message_id);

commit;
