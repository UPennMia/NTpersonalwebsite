-- Mother ID is a family-origin key, not a current household ID.
-- A child can move out and still be linked to the same biological mother.
SELECT c.child_id, c.mother_id, c.birth_year AS child_birth_year,
       c.sex AS child_sex, m.birth_year AS mother_birth_year
FROM children AS c
JOIN mothers AS m ON c.mother_id = m.mother_id
ORDER BY c.child_id;
