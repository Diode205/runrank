begin;

alter table public.chat_threads
  add column if not exists context_title text,
  add column if not exists context_date date;

create index if not exists chat_threads_context_idx
  on public.chat_threads (club, context_title, context_date);

commit;
