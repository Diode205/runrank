-- Set Norwich Road Runners colours in app_clubs
UPDATE app_clubs
SET primary_color = '#D32F2F',      -- strong red
    accent_color = '#FFFFFF',       -- white accents
    background_color = '#121212'    -- near-black background
WHERE slug = 'norwich-road-runners';
