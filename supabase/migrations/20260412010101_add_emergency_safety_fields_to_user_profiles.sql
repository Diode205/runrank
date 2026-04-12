begin;

alter table public.user_profiles
  add column if not exists emergency_contact_name text,
  add column if not exists emergency_contact_number text,
  add column if not exists emergency_contact_relation text,
  add column if not exists emergency_details_consent boolean not null default false,
  add column if not exists medical_notes text;

update public.user_profiles
set emergency_details_consent = false
where emergency_details_consent is null;

commit;