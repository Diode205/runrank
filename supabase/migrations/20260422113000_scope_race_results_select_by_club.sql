begin;

create or replace function public.canonical_club_name(raw_club text)
returns text
language sql
immutable
as $$
  select case
    when raw_club is null or btrim(raw_club) = '' then ''
    when lower(btrim(raw_club)) = 'nrr'
      or lower(btrim(raw_club)) like '%norwich road runners%'
      then 'Norwich Road Runners'
    when lower(btrim(raw_club)) = 'nnbr'
      or lower(btrim(raw_club)) like '%north norfolk beach runners%'
      then 'NNBR (North Norfolk Beach Runners)'
    else btrim(raw_club)
  end
$$;

alter table public.race_results enable row level security;

drop policy if exists "race_results_select_own_or_same_club"
on public.race_results;

create policy "race_results_select_own_or_same_club"
on public.race_results
for select
using (
  auth.uid() = user_id
  or exists (
    select 1
    from public.user_profiles me
    join public.user_profiles owner
      on owner.id = public.race_results.user_id
    where me.id = auth.uid()
      and public.canonical_club_name(me.club) <> ''
      and public.canonical_club_name(me.club) =
          public.canonical_club_name(owner.club)
  )
);

commit;
