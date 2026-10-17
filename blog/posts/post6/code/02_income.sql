-- Collapse person-years BEFORE joining generations. Otherwise n maternal
-- waves times k child waves would produce n*k rows for each child.
WITH eligible AS (
    SELECT i.*, w.window, w.center_age,
           ROW_NUMBER() OVER (
               PARTITION BY i.generation, i.person_id, w.window
               ORDER BY ABS(i.age - w.center_age), i.income_year, i.survey_year
           ) AS rank_in_window
    FROM incomes AS i
    JOIN windows AS w ON i.generation = w.generation
                     AND i.age BETWEEN w.min_age AND w.max_age
    WHERE i.earnings_real IS NOT NULL AND i.earnings_real >= 0
)
SELECT generation, person_id, window,
       COUNT(*) AS n_years,
       AVG(earnings_real) AS mean_income,
       AVG(age) AS mean_age,
       MIN(income_year) AS first_year, MAX(income_year) AS last_year,
       MAX(CASE WHEN rank_in_window = 1 THEN earnings_real END) AS single_income,
       MAX(CASE WHEN rank_in_window = 1 THEN age END) AS single_age
FROM eligible
GROUP BY generation, person_id, window
ORDER BY generation, person_id, window;
