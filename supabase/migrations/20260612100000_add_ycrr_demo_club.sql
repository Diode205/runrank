insert into public.app_clubs (
  slug,
  name,
  primary_color,
  accent_color,
  background_color,
  logo_url,
  hero_image_url
)
values (
  'your-club-road-runners',
  'Your Club Road Runners',
  '#FFD300',
  '#16803A',
  '#000000',
  null,
  null
)
on conflict (slug) do update
set
  name = excluded.name,
  primary_color = excluded.primary_color,
  accent_color = excluded.accent_color,
  background_color = excluded.background_color,
  logo_url = excluded.logo_url,
  hero_image_url = excluded.hero_image_url;
