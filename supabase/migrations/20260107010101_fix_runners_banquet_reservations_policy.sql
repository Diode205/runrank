-- Fix runners_banquet_reservations write policy so inserts succeed

ALTER TABLE runners_banquet_reservations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "runners_banquet_reservations_write_own_or_admin" ON runners_banquet_reservations;

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
