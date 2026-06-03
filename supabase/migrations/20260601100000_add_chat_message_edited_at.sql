begin;

alter table public.chat_messages
  add column if not exists edited_at timestamptz;

grant select, insert, update on table public.chat_messages to authenticated;

commit;
