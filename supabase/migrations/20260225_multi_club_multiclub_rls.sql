-- Enforce per-club data isolation for key tables
-- Assumes user_profiles has a "club" text column and "is_admin" boolean.

BEGIN;

---------------------------------------------------------------------
-- user_profiles: restrict SELECT to same club (or own profile)
---------------------------------------------------------------------

ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can view user profiles" ON public.user_profiles;

CREATE POLICY "Users can view profiles in their club"
  ON public.user_profiles
  FOR SELECT
  USING (
    -- Always allow users to see their own profile
    auth.uid() = id
    OR EXISTS (
      SELECT 1
      FROM public.user_profiles me
      WHERE me.id = auth.uid()
        AND coalesce(me.club, '') <> ''
        AND me.club = public.user_profiles.club
    )
  );

---------------------------------------------------------------------
-- Helper expressions (inlined) for per-club checks
---------------------------------------------------------------------
-- NOTE: We inline the checks in each policy rather than using
-- separate SQL functions, to keep this migration self-contained.

---------------------------------------------------------------------
-- club_posts: per-club access based on author_id -> user_profiles.club
---------------------------------------------------------------------

ALTER TABLE public.club_posts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "club_posts_select_same_club" ON public.club_posts;
DROP POLICY IF EXISTS "club_posts_insert_authors_only" ON public.club_posts;
DROP POLICY IF EXISTS "club_posts_update_same_club" ON public.club_posts;
DROP POLICY IF EXISTS "club_posts_delete_same_club" ON public.club_posts;

-- Members and admins can read posts authored by members of their club
CREATE POLICY "club_posts_select_same_club"
  ON public.club_posts
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.user_profiles me
      JOIN public.user_profiles author ON author.id = public.club_posts.author_id
      WHERE me.id = auth.uid()
        AND coalesce(me.club, '') <> ''
        AND me.club = author.club
    )
  );

-- Only allow users to insert posts for themselves
CREATE POLICY "club_posts_insert_authors_only"
  ON public.club_posts
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.user_profiles me
      WHERE me.id = auth.uid()
        AND me.id = public.club_posts.author_id
    )
  );

-- Updates allowed for:
--   * the post author, or
--   * admins in the same club as the author
CREATE POLICY "club_posts_update_same_club"
  ON public.club_posts
  FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.user_profiles me
      JOIN public.user_profiles author ON author.id = public.club_posts.author_id
      WHERE me.id = auth.uid()
        AND coalesce(me.club, '') <> ''
        AND me.club = author.club
        AND (me.id = author.id OR coalesce(me.is_admin, false) = true)
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.user_profiles me
      JOIN public.user_profiles author ON author.id = public.club_posts.author_id
      WHERE me.id = auth.uid()
        AND coalesce(me.club, '') <> ''
        AND me.club = author.club
        AND (me.id = author.id OR coalesce(me.is_admin, false) = true)
    )
  );

-- Deletes allowed for same set as updates
CREATE POLICY "club_posts_delete_same_club"
  ON public.club_posts
  FOR DELETE TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.user_profiles me
      JOIN public.user_profiles author ON author.id = public.club_posts.author_id
      WHERE me.id = auth.uid()
        AND coalesce(me.club, '') <> ''
        AND me.club = author.club
        AND (me.id = author.id OR coalesce(me.is_admin, false) = true)
    )
  );

---------------------------------------------------------------------
-- club_post_comments: per-club via parent post's author
---------------------------------------------------------------------

ALTER TABLE public.club_post_comments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "club_post_comments_same_club" ON public.club_post_comments;

CREATE POLICY "club_post_comments_same_club"
  ON public.club_post_comments
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.user_profiles me
      JOIN public.club_posts p ON p.id = public.club_post_comments.post_id
      JOIN public.user_profiles author ON author.id = p.author_id
      WHERE me.id = auth.uid()
        AND coalesce(me.club, '') <> ''
        AND me.club = author.club
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.user_profiles me
      JOIN public.club_posts p ON p.id = public.club_post_comments.post_id
      JOIN public.user_profiles author ON author.id = p.author_id
      WHERE me.id = auth.uid()
        AND coalesce(me.club, '') <> ''
        AND me.club = author.club
    )
  );

---------------------------------------------------------------------
-- club_post_reactions: per-club via parent post's author
---------------------------------------------------------------------

ALTER TABLE public.club_post_reactions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "club_post_reactions_same_club" ON public.club_post_reactions;

CREATE POLICY "club_post_reactions_same_club"
  ON public.club_post_reactions
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.user_profiles me
      JOIN public.club_posts p ON p.id = public.club_post_reactions.post_id
      JOIN public.user_profiles author ON author.id = p.author_id
      WHERE me.id = auth.uid()
        AND coalesce(me.club, '') <> ''
        AND me.club = author.club
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.user_profiles me
      JOIN public.club_posts p ON p.id = public.club_post_reactions.post_id
      JOIN public.user_profiles author ON author.id = p.author_id
      WHERE me.id = auth.uid()
        AND coalesce(me.club, '') <> ''
        AND me.club = author.club
    )
  );

---------------------------------------------------------------------
-- club_events: per-club via created_by -> user_profiles.club
---------------------------------------------------------------------

ALTER TABLE public.club_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "club_events_select_same_club" ON public.club_events;
DROP POLICY IF EXISTS "club_events_insert_members_only" ON public.club_events;
DROP POLICY IF EXISTS "club_events_update_same_club" ON public.club_events;
DROP POLICY IF EXISTS "club_events_delete_same_club" ON public.club_events;

-- Members and admins can read events created by members of their club
CREATE POLICY "club_events_select_same_club"
  ON public.club_events
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.user_profiles me
      JOIN public.user_profiles creator ON creator.id = public.club_events.created_by
      WHERE me.id = auth.uid()
        AND coalesce(me.club, '') <> ''
        AND me.club = creator.club
    )
  );

-- Only allow users to create events where created_by = themselves
CREATE POLICY "club_events_insert_members_only"
  ON public.club_events
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.user_profiles me
      WHERE me.id = auth.uid()
        AND me.id = public.club_events.created_by
    )
  );

-- Updates allowed for creator or admins in same club
CREATE POLICY "club_events_update_same_club"
  ON public.club_events
  FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.user_profiles me
      JOIN public.user_profiles creator ON creator.id = public.club_events.created_by
      WHERE me.id = auth.uid()
        AND coalesce(me.club, '') <> ''
        AND me.club = creator.club
        AND (me.id = creator.id OR coalesce(me.is_admin, false) = true)
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.user_profiles me
      JOIN public.user_profiles creator ON creator.id = public.club_events.created_by
      WHERE me.id = auth.uid()
        AND coalesce(me.club, '') <> ''
        AND me.club = creator.club
        AND (me.id = creator.id OR coalesce(me.is_admin, false) = true)
    )
  );

-- Deletes allowed for same set as updates
CREATE POLICY "club_events_delete_same_club"
  ON public.club_events
  FOR DELETE TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.user_profiles me
      JOIN public.user_profiles creator ON creator.id = public.club_events.created_by
      WHERE me.id = auth.uid()
        AND coalesce(me.club, '') <> ''
        AND me.club = creator.club
        AND (me.id = creator.id OR coalesce(me.is_admin, false) = true)
    )
  );

---------------------------------------------------------------------
-- club_event_responses: per-club via parent event's creator
---------------------------------------------------------------------

ALTER TABLE public.club_event_responses ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "club_event_responses_same_club" ON public.club_event_responses;

CREATE POLICY "club_event_responses_same_club"
  ON public.club_event_responses
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.user_profiles me
      JOIN public.club_events e ON e.id = public.club_event_responses.event_id
      JOIN public.user_profiles creator ON creator.id = e.created_by
      WHERE me.id = auth.uid()
        AND coalesce(me.club, '') <> ''
        AND me.club = creator.club
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.user_profiles me
      JOIN public.club_events e ON e.id = public.club_event_responses.event_id
      JOIN public.user_profiles creator ON creator.id = e.created_by
      WHERE me.id = auth.uid()
        AND coalesce(me.club, '') <> ''
        AND me.club = creator.club
    )
  );

COMMIT;
