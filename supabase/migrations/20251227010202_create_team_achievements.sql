-- Create update function if it doesn't exist
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Team Achievements Table
CREATE TABLE IF NOT EXISTS team_achievements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  achievement_date DATE NOT NULL,
  event_name TEXT NOT NULL,
  award TEXT NOT NULL CHECK (award IN ('Gold', 'Silver', 'Bronze', 'Champion')),
  teams TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Index for faster date-based queries
CREATE INDEX IF NOT EXISTS idx_team_achievements_date ON team_achievements(achievement_date DESC);

-- Enable Row Level Security
ALTER TABLE team_achievements ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "team_achievements_select_all" ON team_achievements;
DROP POLICY IF EXISTS "team_achievements_insert_admin" ON team_achievements;
DROP POLICY IF EXISTS "team_achievements_update_admin" ON team_achievements;
DROP POLICY IF EXISTS "team_achievements_delete_admin" ON team_achievements;

-- Public can view all achievements
CREATE POLICY "team_achievements_select_all" ON team_achievements
  FOR SELECT
  USING (true);

-- Only admins can insert/update/delete
CREATE POLICY "team_achievements_insert_admin" ON team_achievements
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND user_profiles.is_admin = true
    )
  );

CREATE POLICY "team_achievements_update_admin" ON team_achievements
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND user_profiles.is_admin = true
    )
  );

CREATE POLICY "team_achievements_delete_admin" ON team_achievements
  FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND user_profiles.is_admin = true
    )
  );

-- Drop trigger if exists and recreate
DROP TRIGGER IF EXISTS team_achievements_updated_at ON team_achievements;
CREATE TRIGGER team_achievements_updated_at
  BEFORE UPDATE ON team_achievements
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();
