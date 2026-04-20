create extension if not exists pgcrypto;

create table if not exists public.charity_fundraising (
  id uuid primary key default gen_random_uuid(),
  club text,
  charity_name text not null default 'Charity of the Year',
  intro_text text,
  website_url text,
  donate_url text,
  qr_image_url text,
  total_raised numeric not null default 0,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

alter table if exists public.charity_fundraising
  add column if not exists club text,
  add column if not exists intro_text text,
  add column if not exists website_url text,
  add column if not exists qr_image_url text,
  add column if not exists created_at timestamptz not null default timezone('utc', now()),
  add column if not exists updated_at timestamptz not null default timezone('utc', now());

alter table if exists public.charity_fundraising
  alter column charity_name set default 'Charity of the Year',
  alter column total_raised set default 0,
  alter column created_at set default timezone('utc', now()),
  alter column updated_at set default timezone('utc', now());

update public.charity_fundraising
set website_url = donate_url
where website_url is null
  and donate_url is not null;

update public.charity_fundraising
set updated_at = timezone('utc', now())
where updated_at is null;
