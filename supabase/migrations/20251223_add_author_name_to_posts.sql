-- Add author_name column to club_posts table
ALTER TABLE club_posts 
ADD COLUMN IF NOT EXISTS author_name TEXT;

-- Backfill author_name from user_profiles for existing posts
UPDATE club_posts
SET author_name = (
  SELECT full_name 
  FROM user_profiles 
  WHERE user_profiles.id = club_posts.author_id
)
WHERE author_name IS NULL;

-- Set default to 'Member' for any that still don't have a name
UPDATE club_posts
SET author_name = 'Member'
WHERE author_name IS NULL OR author_name = '';
