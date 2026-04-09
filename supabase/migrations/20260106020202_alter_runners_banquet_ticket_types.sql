-- Add separate ticket prices for member, partner/spouse, and other guests

ALTER TABLE runners_banquet_config
  ADD COLUMN IF NOT EXISTS ticket_price_member_pence INTEGER,
  ADD COLUMN IF NOT EXISTS ticket_price_partner_pence INTEGER,
  ADD COLUMN IF NOT EXISTS ticket_price_other_pence INTEGER;

-- Backfill new member price from existing single ticket_price_pence
UPDATE runners_banquet_config
SET ticket_price_member_pence = COALESCE(ticket_price_member_pence, ticket_price_pence)
WHERE ticket_price_member_pence IS NULL;
