create table if not exists public.club_post_comment_reactions (
  id uuid primary key default gen_random_uuid(),
  comment_id uuid not null references public.club_post_comments(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  emoji text not null,
  created_at timestamptz not null default now(),
  unique (comment_id, user_id, emoji)
);

alter table public.club_post_comment_reactions enable row level security;

drop policy if exists "club_post_comment_reactions_same_club"
  on public.club_post_comment_reactions;

create policy "club_post_comment_reactions_same_club"
  on public.club_post_comment_reactions
  for all to authenticated
  using (
    exists (
      select 1
      from public.user_profiles me
      join public.club_post_comments c
        on c.id = public.club_post_comment_reactions.comment_id
      join public.club_posts p on p.id = c.post_id
      join public.user_profiles author on author.id = p.author_id
      where me.id = auth.uid()
        and coalesce(me.club, '') <> ''
        and me.club = author.club
    )
  )
  with check (
    exists (
      select 1
      from public.user_profiles me
      join public.club_post_comments c
        on c.id = public.club_post_comment_reactions.comment_id
      join public.club_posts p on p.id = c.post_id
      join public.user_profiles author on author.id = p.author_id
      where me.id = auth.uid()
        and coalesce(me.club, '') <> ''
        and me.club = author.club
    )
  );
