-- Add a timestamp for when a club event is cancelled
ALTER TABLE public.club_events
ADD COLUMN IF NOT EXISTS cancelled_at timestamptz;

-- Backfill for existing cancelled events that have no timestamp yet
UPDATE public.club_events
SET cancelled_at = COALESCE(cancelled_at, created_at)
WHERE is_cancelled = true AND cancelled_at IS NULL;
