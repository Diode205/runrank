-- Migration: Add relay_stages_json for multi-stage relay responses
-- Run this in the Supabase SQL editor (or via migration tooling).

-- 1) Add a JSONB column to store multiple relay stages per response.
ALTER TABLE club_event_responses
ADD COLUMN IF NOT EXISTS relay_stages_json JSONB;

-- 2) Backfill from the existing single integer relay_stage column so
-- existing data is preserved. Each non-null relay_stage becomes a
-- single-element array in relay_stages_json.
UPDATE club_event_responses
SET relay_stages_json = to_jsonb(ARRAY[relay_stage])
WHERE relay_stage IS NOT NULL
  AND relay_stages_json IS NULL;

-- 3) (Optional) You may later choose to deprecate relay_stage and rely
-- solely on relay_stages_json from the app code. For now we leave the
-- integer column in place for backwards compatibility.
--
-- In Dart, you would then:
--   - Read relay_stages_json as List<int> for stage lists.
--   - Write relay_stages_json with all selected stages instead of
--     only the first, while optionally still setting relay_stage
--     to the first stage for legacy views/queries.
