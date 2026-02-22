-- Clear any seeded committee role holder names/emails so clubs can configure their own
UPDATE committee_roles
SET name = NULL,
    email = NULL;
