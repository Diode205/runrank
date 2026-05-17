begin;

alter table public.club_events
  add column if not exists signature_image_asset text;

commit;
