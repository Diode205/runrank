-- Backfill missing author_name values from user_profiles
-- This will try to get full_name, otherwise use email, otherwise use 'Member'

UPDATE club_posts
SET author_name = COALESCE(
  (SELECT full_name FROM user_profiles WHERE user_profiles.id = club_posts.author_id AND full_name IS NOT NULL AND full_name != ''),
  (SELECT email FROM user_profiles WHERE user_profiles.id = club_posts.author_id),
  'Member'
)
WHERE author_name IS NULL OR author_name = '' OR author_name = 'Unknown';
