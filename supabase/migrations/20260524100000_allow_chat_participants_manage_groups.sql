begin;

drop policy if exists "Users can add participants to own chat threads" on public.chat_participants;
create policy "Chat members can add participants to group chats"
  on public.chat_participants
  for insert
  with check (
    user_id = auth.uid()
    or exists (
      select 1
      from public.chat_threads ct
      where ct.id = chat_participants.thread_id
        and (
          ct.created_by = auth.uid()
          or (ct.is_group = true and public.is_chat_participant(ct.id))
        )
    )
  );

commit;
