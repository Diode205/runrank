-- Malcolm Ball Award schema

create table if not exists public.award_nominees (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  name_lc text generated always as (lower(name)) stored,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

create unique index if not exists award_nominees_name_lc_uidx
  on public.award_nominees(name_lc);

alter table public.award_nominees enable row level security;

create policy award_nominees_select_all
  on public.award_nominees for select
  using (true);

create policy award_nominees_insert_auth
  on public.award_nominees for insert
  to authenticated
  with check (created_by = auth.uid());

-- Nominations (reason why)
create table if not exists public.award_nominations (
  id uuid primary key default gen_random_uuid(),
  nominee_id uuid not null references public.award_nominees(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  reason text not null,
  created_at timestamptz not null default now()
);

alter table public.award_nominations enable row level security;

create policy award_nominations_select_all
  on public.award_nominations for select using (true);

create policy award_nominations_insert_self
  on public.award_nominations for insert to authenticated
  with check (user_id = auth.uid());

-- Votes (one per user per nominee)
create table if not exists public.award_votes (
  id uuid primary key default gen_random_uuid(),
  nominee_id uuid not null references public.award_nominees(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (nominee_id, user_id)
);

alter table public.award_votes enable row level security;

create policy award_votes_select_all
  on public.award_votes for select using (true);

create policy award_votes_insert_self
  on public.award_votes for insert to authenticated
  with check (user_id = auth.uid());

-- Emoji reactions (many allowed)
create table if not exists public.award_emojis (
  id uuid primary key default gen_random_uuid(),
  nominee_id uuid not null references public.award_nominees(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  emoji text not null,
  created_at timestamptz not null default now()
);

alter table public.award_emojis enable row level security;

create policy award_emojis_select_all
  on public.award_emojis for select using (true);

create policy award_emojis_insert_self
  on public.award_emojis for insert to authenticated
  with check (user_id = auth.uid());

-- Comments
create table if not exists public.award_comments (
  id uuid primary key default gen_random_uuid(),
  nominee_id uuid not null references public.award_nominees(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  content text not null,
  created_at timestamptz not null default now()
);

alter table public.award_comments enable row level security;

create policy award_comments_select_all
  on public.award_comments for select using (true);

create policy award_comments_insert_self
  on public.award_comments for insert to authenticated
  with check (user_id = auth.uid());
