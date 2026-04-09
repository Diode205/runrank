-- Create update function if it doesn't exist (may already exist from team_achievements)
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Club Milestones Table
CREATE TABLE IF NOT EXISTS club_milestones (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  milestone_date TEXT NOT NULL,  -- Can be "1980s", "Early 2000s", or specific "2024-12-25"
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  icon TEXT NOT NULL DEFAULT 'emoji_events',  -- Material icon name
  display_order INTEGER NOT NULL DEFAULT 0,  -- For manual ordering
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Index for faster ordering queries
CREATE INDEX IF NOT EXISTS idx_club_milestones_order ON club_milestones(display_order ASC);

-- Enable Row Level Security
ALTER TABLE club_milestones ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "club_milestones_select_all" ON club_milestones;
DROP POLICY IF EXISTS "club_milestones_insert_admin" ON club_milestones;
DROP POLICY IF EXISTS "club_milestones_update_admin" ON club_milestones;
DROP POLICY IF EXISTS "club_milestones_delete_admin" ON club_milestones;

-- Public can view all milestones
CREATE POLICY "club_milestones_select_all" ON club_milestones
  FOR SELECT
  USING (true);

-- Only admins can insert/update/delete
CREATE POLICY "club_milestones_insert_admin" ON club_milestones
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND user_profiles.is_admin = true
    )
  );

CREATE POLICY "club_milestones_update_admin" ON club_milestones
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND user_profiles.is_admin = true
    )
  );

CREATE POLICY "club_milestones_delete_admin" ON club_milestones
  FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND user_profiles.is_admin = true
    )
  );

-- Drop trigger if exists and recreate
DROP TRIGGER IF EXISTS club_milestones_updated_at ON club_milestones;
CREATE TRIGGER club_milestones_updated_at
  BEFORE UPDATE ON club_milestones
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Insert default milestones from existing page
INSERT INTO club_milestones (milestone_date, title, description, icon, display_order) VALUES
  ('Mid 1980s', 'Club Founded', 'Informal group begins running out of Cromer and East Runton', 'flag', 1),
  ('Early Days', 'First Female Members', 'The club welcomes its first two lady members, marking the beginning of a more inclusive community', 'people', 2),
  ('Evolution', 'Boxing Day Dip Tradition', 'Annual Boxing Day sea dip becomes a massive fundraising event for local charities', 'waves', 3),
  ('2020s', 'Modern Era', 'Established as one of Norfolk''s premier running clubs, welcoming runners of all abilities', 'emoji_events', 4)
ON CONFLICT DO NOTHING;
