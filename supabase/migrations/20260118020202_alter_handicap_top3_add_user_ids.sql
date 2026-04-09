-- Add user_id columns to store identity for medal winners
alter table public.handicap_top3
  add column if not exists gold_user_id uuid,
  add column if not exists silver_user_id uuid,
  add column if not exists bronze_user_id uuid;

-- Optional: update updated_at automatically
create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_handicap_top3_updated_at on public.handicap_top3;
create trigger trg_handicap_top3_updated_at
before update on public.handicap_top3
for each row execute function public.set_updated_at();
