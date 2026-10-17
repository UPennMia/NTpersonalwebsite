-- The same children must qualify for EVERY specification in the article.
-- Zero years count in the arithmetic mean. A zero single-year value cannot
-- enter a log regression, so those pairs are excluded here, not silently
-- replaced by another positive year.
SELECT p.*, m.mean_income AS mother_mean, m.single_income AS mother_single,
       m.n_years AS mother_years, m.mean_age AS mother_mean_age,
       e.mean_income AS early_mean, e.single_income AS early_single,
       e.n_years AS early_years, e.mean_age AS early_mean_age,
       l.mean_income AS late_mean, l.single_income AS late_single,
       l.n_years AS late_years, l.mean_age AS late_mean_age
FROM pairs AS p
JOIN summaries AS m ON m.generation = 'mother' AND m.person_id = p.mother_id
                   AND m.window = 'mother_35_39'
JOIN summaries AS e ON e.generation = 'child' AND e.person_id = p.child_id
                   AND e.window = 'child_20_29'
JOIN summaries AS l ON l.generation = 'child' AND l.person_id = p.child_id
                   AND l.window = 'child_30_39'
WHERE m.n_years >= 2 AND e.n_years >= 2 AND l.n_years >= 2
  AND m.mean_income > 0 AND e.mean_income > 0 AND l.mean_income > 0
  AND m.single_income > 0 AND e.single_income > 0 AND l.single_income > 0
ORDER BY p.child_id;
