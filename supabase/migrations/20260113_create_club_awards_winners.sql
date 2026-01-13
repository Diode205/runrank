-- Club Awards: winners for multiple award categories

begin;

create table if not exists public.club_awards_winners (
  id uuid primary key default gen_random_uuid(),
  award_key text not null, -- e.g. short_performance, newcomer, etc
  year integer not null,
  female_name text null,
  male_name text null,
  added_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  constraint club_awards_winners_unique_per_year unique (award_key, year)
);

-- Helpful index for fetches
create index if not exists club_awards_winners_award_year_idx
  on public.club_awards_winners (award_key, year);

alter table public.club_awards_winners enable row level security;

-- Read: allow anyone to select winners
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE policyname = 'club_awards_winners_select_all'
      AND schemaname = 'public'
      AND tablename = 'club_awards_winners'
  ) THEN
    CREATE POLICY club_awards_winners_select_all
      ON public.club_awards_winners
      FOR SELECT
      USING (true);
  END IF;
END $$;

-- Insert: admins only (based on public.user_profiles.is_admin)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE policyname = 'club_awards_winners_insert_admin'
      AND schemaname = 'public'
      AND tablename = 'club_awards_winners'
  ) THEN
    CREATE POLICY club_awards_winners_insert_admin
      ON public.club_awards_winners
      FOR INSERT TO authenticated
      WITH CHECK (
        EXISTS (
          SELECT 1 FROM public.user_profiles up
          WHERE up.id = auth.uid() AND coalesce(up.is_admin,false) = true
        )
      );
  END IF;
END $$;

-- Update: admins only
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE policyname = 'club_awards_winners_update_admin'
      AND schemaname = 'public'
      AND tablename = 'club_awards_winners'
  ) THEN
    CREATE POLICY club_awards_winners_update_admin
      ON public.club_awards_winners
      FOR UPDATE TO authenticated
      USING (
        EXISTS (
          SELECT 1 FROM public.user_profiles up
          WHERE up.id = auth.uid() AND coalesce(up.is_admin,false) = true
        )
      )
      WITH CHECK (
        EXISTS (
          SELECT 1 FROM public.user_profiles up
          WHERE up.id = auth.uid() AND coalesce(up.is_admin,false) = true
        )
      );
  END IF;
END $$;

-- Delete: admins only
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE policyname = 'club_awards_winners_delete_admin'
      AND schemaname = 'public'
      AND tablename = 'club_awards_winners'
  ) THEN
    CREATE POLICY club_awards_winners_delete_admin
      ON public.club_awards_winners
      FOR DELETE TO authenticated
      USING (
        EXISTS (
          SELECT 1 FROM public.user_profiles up
          WHERE up.id = auth.uid() AND coalesce(up.is_admin,false) = true
        )
      );
  END IF;
END $$;

commit;
