begin;

alter table public.chat_threads
  add column if not exists event_id uuid references public.club_events(id) on delete cascade;

create index if not exists chat_threads_event_id_idx
  on public.chat_threads (event_id);

commit;
