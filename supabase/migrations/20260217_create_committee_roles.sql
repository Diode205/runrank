-- Committee Roles Table
CREATE TABLE IF NOT EXISTS committee_roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  role TEXT NOT NULL,
  display_order INTEGER NOT NULL,
  name TEXT,
  email TEXT,
  user_id UUID REFERENCES user_profiles(id) ON DELETE SET NULL,
  avatar_url TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Index for ordering
CREATE INDEX IF NOT EXISTS idx_committee_roles_order
  ON committee_roles(display_order);

-- Enable Row Level Security
ALTER TABLE committee_roles ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "committee_roles_select_all" ON committee_roles;
DROP POLICY IF EXISTS "committee_roles_insert_admin" ON committee_roles;
DROP POLICY IF EXISTS "committee_roles_update_admin" ON committee_roles;
DROP POLICY IF EXISTS "committee_roles_delete_admin" ON committee_roles;

-- Everyone can view the committee
CREATE POLICY "committee_roles_select_all" ON committee_roles
  FOR SELECT
  USING (true);

-- Only admins can insert/update/delete committee roles
CREATE POLICY "committee_roles_insert_admin" ON committee_roles
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
        AND user_profiles.is_admin = true
    )
  );

CREATE POLICY "committee_roles_update_admin" ON committee_roles
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
        AND user_profiles.is_admin = true
    )
  );

CREATE POLICY "committee_roles_delete_admin" ON committee_roles
  FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
        AND user_profiles.is_admin = true
    )
  );

-- Updated_at trigger
DROP TRIGGER IF EXISTS committee_roles_updated_at ON committee_roles;
CREATE TRIGGER committee_roles_updated_at
  BEFORE UPDATE ON committee_roles
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Seed initial committee roles matching the current hard-coded list
INSERT INTO committee_roles (role, display_order, name, email) VALUES
  ('President', 1, 'Noel Spruce', ''),
  ('Chairperson', 2, 'Ness Dent', 'chairperson@nnbr.co.uk'),
  ('Vice-Chairperson', 3, 'Richard West', ''),
  ('Secretary', 4, 'Gav Dent', 'secretary@nnbr.co.uk'),
  ('Treasurer', 5, 'Peter Hill', 'treasurer@nnbr.co.uk'),
  ('Membership Secretary', 6, 'Libby Ashton', ''),
  ('Minutes Secretary', 7, 'Rachel Welch', 'minutes_secretary@nnbr.co.uk'),
  ('Clothing Manager', 8, 'Sarah Morter', ''),
  ('Club Head Coach', 9, 'Karen Balcombe', ''),
  ('Equipment Store Manager', 10, 'Phil King', ''),
  ('General Committee Member', 11, 'Neil Adams', ''),
  ('General Committee Member', 12, 'Tony Witmond', ''),
  ('Webmaster', 13, 'John Fagan', ''),
  ('Press Officer', 14, 'John Worrall', '')
ON CONFLICT DO NOTHING;
