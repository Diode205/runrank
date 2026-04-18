-- Normalize Norwich Road Runners committee roles to the current role list.
--
-- This migration is idempotent and only affects clubs already stored as
-- NRR / Norwich Road Runners in committee_roles.

WITH desired_roles AS (
  SELECT *
  FROM (
    VALUES
      (0, 'Chairperson'),
      (1, 'Vice Chairperson'),
      (2, 'Club Secretary'),
      (3, 'Treasurer'),
      (4, 'Membership Secretary'),
      (5, 'Welfare Officer'),
      (6, 'Health & Safety Officer'),
      (7, 'New Members Officer'),
      (8, 'Kit Secretary'),
      (9, 'Junior Section Head'),
      (10, 'Horford XC Race Director'),
      (11, 'Road Racing Director'),
      (12, 'Parkrun On Tour Lead'),
      (13, 'Committee Member'),
      (14, 'Committee Member'),
      (15, 'Committee Member')
  ) AS role_map(display_order, role)
),
nrr_clubs AS (
  SELECT DISTINCT club
  FROM committee_roles
  WHERE club IS NOT NULL
    AND (
      lower(trim(club)) = 'nrr'
      OR lower(club) LIKE '%norwich road runners%'
    )
),
club_indexing AS (
  SELECT
    club,
    bool_or(display_order = 0) AS uses_zero_based
  FROM committee_roles
  WHERE club IN (SELECT club FROM nrr_clubs)
  GROUP BY club
),
normalized_existing AS (
  SELECT
    cr.id,
    cr.club,
    CASE
      WHEN ci.uses_zero_based THEN cr.display_order
      ELSE cr.display_order - 1
    END AS normalized_order
  FROM committee_roles cr
  JOIN club_indexing ci ON ci.club = cr.club
),
updated_rows AS (
  UPDATE committee_roles cr
  SET
    role = dr.role,
    display_order = dr.display_order
  FROM normalized_existing ne
  JOIN desired_roles dr ON dr.display_order = ne.normalized_order
  WHERE cr.id = ne.id
    AND ne.normalized_order BETWEEN 0 AND 15
  RETURNING cr.club, cr.display_order
)
INSERT INTO committee_roles (club, role, display_order, name, email)
SELECT
  nc.club,
  dr.role,
  dr.display_order,
  '',
  ''
FROM nrr_clubs nc
CROSS JOIN desired_roles dr
LEFT JOIN committee_roles cr
  ON cr.club = nc.club
 AND cr.display_order = dr.display_order
WHERE cr.id IS NULL;