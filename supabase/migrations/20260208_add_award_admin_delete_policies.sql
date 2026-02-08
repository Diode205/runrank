-- Allow admins to clear Malcolm Ball Award tables
-- so that the in-app "Reset nominees & votes" action works.

begin;

-- Helper predicate: admin = user_profiles.is_admin = true
-- We repeat the EXISTS(...) expression in each policy to avoid
-- creating a separate SQL function.

-- award_votes: admin can delete any row
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE policyname = 'award_votes_delete_admin'
      AND schemaname = 'public'
      AND tablename = 'award_votes'
  ) THEN
    CREATE POLICY award_votes_delete_admin
      ON public.award_votes
      FOR DELETE TO authenticated
      USING (
        EXISTS (
          SELECT 1 FROM public.user_profiles up
          WHERE up.id = auth.uid() AND coalesce(up.is_admin,false) = true
        )
      );
  END IF;
END $$;

-- award_emojis: admin can delete any row
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE policyname = 'award_emojis_delete_admin'
      AND schemaname = 'public'
      AND tablename = 'award_emojis'
  ) THEN
    CREATE POLICY award_emojis_delete_admin
      ON public.award_emojis
      FOR DELETE TO authenticated
      USING (
        EXISTS (
          SELECT 1 FROM public.user_profiles up
          WHERE up.id = auth.uid() AND coalesce(up.is_admin,false) = true
        )
      );
  END IF;
END $$;

-- award_comments: admin can delete any row
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE policyname = 'award_comments_delete_admin'
      AND schemaname = 'public'
      AND tablename = 'award_comments'
  ) THEN
    CREATE POLICY award_comments_delete_admin
      ON public.award_comments
      FOR DELETE TO authenticated
      USING (
        EXISTS (
          SELECT 1 FROM public.user_profiles up
          WHERE up.id = auth.uid() AND coalesce(up.is_admin,false) = true
        )
      );
  END IF;
END $$;

-- award_nominations: admin can delete any row
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE policyname = 'award_nominations_delete_admin'
      AND schemaname = 'public'
      AND tablename = 'award_nominations'
  ) THEN
    CREATE POLICY award_nominations_delete_admin
      ON public.award_nominations
      FOR DELETE TO authenticated
      USING (
        EXISTS (
          SELECT 1 FROM public.user_profiles up
          WHERE up.id = auth.uid() AND coalesce(up.is_admin,false) = true
        )
      );
  END IF;
END $$;

-- award_nominees: admin can delete any row
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE policyname = 'award_nominees_delete_admin'
      AND schemaname = 'public'
      AND tablename = 'award_nominees'
  ) THEN
    CREATE POLICY award_nominees_delete_admin
      ON public.award_nominees
      FOR DELETE TO authenticated
      USING (
        EXISTS (
          SELECT 1 FROM public.user_profiles up
          WHERE up.id = auth.uid() AND coalesce(up.is_admin,false) = true
        )
      );
  END IF;
END $$;

-- award_chat_messages: keep existing per-user delete, add admin override
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE policyname = 'delete_chat_messages_admin'
      AND schemaname = 'public'
      AND tablename = 'award_chat_messages'
  ) THEN
    CREATE POLICY delete_chat_messages_admin
      ON public.award_chat_messages
      FOR DELETE TO authenticated
      USING (
        EXISTS (
          SELECT 1 FROM public.user_profiles up
          WHERE up.id = auth.uid() AND coalesce(up.is_admin,false) = true
        )
      );
  END IF;
END $$;

-- award_message_emojis: admin can delete any row
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE policyname = 'award_message_emojis_delete_admin'
      AND schemaname = 'public'
      AND tablename = 'award_message_emojis'
  ) THEN
    CREATE POLICY award_message_emojis_delete_admin
      ON public.award_message_emojis
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
