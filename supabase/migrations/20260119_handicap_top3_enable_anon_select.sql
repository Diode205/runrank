-- Ensure read access for non-authenticated (anon) users and add missing columns
begin;

alter table if exists public.handicap_top3
  add column if not exists date_label text,
  add column if not exists venue text;

-- Grant read to anon in addition to authenticated
drop policy if exists "handicap_top3_read_anon" on public.handicap_top3;
create policy "handicap_top3_read_anon" on public.handicap_top3
  for select
  to anon
  using (true);

commit;