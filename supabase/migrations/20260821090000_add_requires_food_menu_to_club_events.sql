-- Adds an explicit opt-in flag so admins choose per-event whether a
-- Special Event (AGM / Club Nights / Awards Night) requires food menu
-- options, instead of the Runners Banquet link always appearing automatically.
alter table if exists club_events
  add column if not exists requires_food_menu boolean not null default false;
