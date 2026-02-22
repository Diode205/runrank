-- Clubs table to support multi-club configuration (app-specific)
-- Use app_clubs to avoid clashing with any existing system tables
CREATE TABLE IF NOT EXISTS app_clubs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  primary_color TEXT,
  accent_color TEXT,
  background_color TEXT,
  logo_url TEXT,
  hero_image_url TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Ensure slug column exists even if clubs table was created earlier
ALTER TABLE app_clubs
  ADD COLUMN IF NOT EXISTS slug TEXT;

-- Ensure slug is unique (multiple NULLs are allowed)
CREATE UNIQUE INDEX IF NOT EXISTS idx_app_clubs_slug ON app_clubs(slug);

ALTER TABLE app_clubs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "app_clubs_select_all" ON app_clubs;
CREATE POLICY "app_clubs_select_all" ON app_clubs
  FOR SELECT
  USING (true);

-- Basic seed data for initial clubs
INSERT INTO app_clubs (slug, name) VALUES
  ('nnbr', 'NNBR (North Norfolk Beach Runners)'),
  ('generic', 'Generic Running Club'),
  ('aylsham-runners', 'Aylsham Runners'),
  ('norfolk-gazelles', 'Norfolk Gazelles'),
  ('norwich-road-runners', 'Norwich Road Runners'),
  ('runners-next-the-sea', 'Runners-next-the-Sea'),
  ('wymondham-ac', 'Wymondham Athletic Club')
ON CONFLICT (slug) DO NOTHING;
