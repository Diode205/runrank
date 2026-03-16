-- Add club column to committee_roles so committees can be per-club

ALTER TABLE committee_roles
  ADD COLUMN IF NOT EXISTS club TEXT;

-- Index to support querying by club + display_order
CREATE INDEX IF NOT EXISTS idx_committee_roles_club_order
  ON committee_roles(club, display_order);

-- For existing data, assume the original seeded committee belongs
-- to NNBR (North Norfolk Beach Runners).
UPDATE committee_roles
SET club = 'NNBR (North Norfolk Beach Runners)'
WHERE club IS NULL;