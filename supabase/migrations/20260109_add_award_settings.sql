-- Award settings: singleton row for voting end date

begin;

create table if not exists public.award_settings (
  singleton boolean primary key default true,
  voting_ends_at timestamptz null,
  updated_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default now()
);

alter table public.award_settings enable row level security;

-- Select: anyone can read settings
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE policyname = 'award_settings_select_all'
      AND schemaname = 'public'
      AND tablename = 'award_settings'
  ) THEN
    CREATE POLICY award_settings_select_all
      ON public.award_settings
      FOR SELECT
      USING (true);
  END IF;
END $$;

-- Admin-only insert/update/delete
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE policyname = 'award_settings_insert_admin'
      AND schemaname = 'public'
      AND tablename = 'award_settings'
  ) THEN
    CREATE POLICY award_settings_insert_admin
      ON public.award_settings
      FOR INSERT TO authenticated
      WITH CHECK (
        EXISTS (
          SELECT 1 FROM public.user_profiles up
          WHERE up.id = auth.uid() AND coalesce(up.is_admin,false) = true
        )
      );
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE policyname = 'award_settings_update_admin'
      AND schemaname = 'public'
      AND tablename = 'award_settings'
  ) THEN
    CREATE POLICY award_settings_update_admin
      ON public.award_settings
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

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE policyname = 'award_settings_delete_admin'
      AND schemaname = 'public'
      AND tablename = 'award_settings'
  ) THEN
    CREATE POLICY award_settings_delete_admin
      ON public.award_settings
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
