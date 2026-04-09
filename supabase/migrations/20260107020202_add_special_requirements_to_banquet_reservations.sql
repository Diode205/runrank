-- Add special requirements text to banquet reservations so admins
-- can see dietary notes alongside each name.

ALTER TABLE runners_banquet_reservations
  ADD COLUMN IF NOT EXISTS special_requirements TEXT;
