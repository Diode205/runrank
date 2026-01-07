-- Runners Banquet configuration and reservations

-- Reuse generic updated_at trigger
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Configuration per special event (or global when event_id IS NULL)
CREATE TABLE IF NOT EXISTS runners_banquet_config (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id UUID REFERENCES club_events(id) ON DELETE CASCADE,
  menu_text TEXT,
  option1_label TEXT,
  option2_label TEXT,
  option3_label TEXT,
  ticket_price_pence INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE runners_banquet_config ENABLE ROW LEVEL SECURITY;

-- Everyone can read config
DROP POLICY IF EXISTS "runners_banquet_config_select_all" ON runners_banquet_config;
DROP POLICY IF EXISTS "runners_banquet_config_admin_write" ON runners_banquet_config;

CREATE POLICY "runners_banquet_config_select_all" ON runners_banquet_config
  FOR SELECT
  USING (true);

-- Only admins can insert/update/delete config
CREATE POLICY "runners_banquet_config_admin_write" ON runners_banquet_config
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND user_profiles.is_admin = true
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND user_profiles.is_admin = true
    )
  );

DROP TRIGGER IF EXISTS runners_banquet_config_updated_at ON runners_banquet_config;
CREATE TRIGGER runners_banquet_config_updated_at
  BEFORE UPDATE ON runners_banquet_config
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Reservations: one row per purchase/booking
CREATE TABLE IF NOT EXISTS runners_banquet_reservations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id UUID,
  user_id UUID NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
  option_label TEXT NOT NULL,
  quantity INTEGER NOT NULL DEFAULT 1 CHECK (quantity > 0),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE runners_banquet_reservations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "runners_banquet_reservations_select_own_or_admin" ON runners_banquet_reservations;
DROP POLICY IF EXISTS "runners_banquet_reservations_write_own_or_admin" ON runners_banquet_reservations;

-- Users can see their own reservations; admins see all
CREATE POLICY "runners_banquet_reservations_select_own_or_admin" ON runners_banquet_reservations
  FOR SELECT
  USING (
    user_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND user_profiles.is_admin = true
    )
  );

-- Users can insert/update/delete their own reservations; admins can manage all
CREATE POLICY "runners_banquet_reservations_write_own_or_admin" ON runners_banquet_reservations
  FOR ALL
  USING (
    user_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND user_profiles.is_admin = true
    )
  )
  WITH CHECK (
    user_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND user_profiles.is_admin = true
    )
  );

DROP TRIGGER IF EXISTS runners_banquet_reservations_updated_at ON runners_banquet_reservations;
CREATE TRIGGER runners_banquet_reservations_updated_at
  BEFORE UPDATE ON runners_banquet_reservations
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();
