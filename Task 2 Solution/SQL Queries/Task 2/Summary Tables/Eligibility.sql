WITH max_dp AS (
  SELECT user_id, MAX(d_power) AS max_d_power
  FROM dataset_case202425_abtest_login
  GROUP BY user_id
),
first_dp700 AS (
  SELECT l.user_id, MIN(l.login_date) AS first_date_700
  FROM dataset_case202425_abtest_login l
  WHERE l.d_power >= 700
  GROUP BY l.user_id
)
SELECT
  s.variant,
  s.platform,
  COUNT(*)                                         AS users,
  SUM(CASE WHEN md.max_d_power >= 700 THEN 1 ELSE 0 END) AS eligible_700p,
  ROUND(100.0 * SUM(CASE WHEN md.max_d_power >= 700 THEN 1 ELSE 0 END) / COUNT(*), 2) AS pct_eligible,
  SUM(CASE WHEN fd.first_date_700 IS NOT NULL AND fd.first_date_700 >= s.test_entry_date THEN 1 ELSE 0 END) AS reached_700_after_entry
FROM abtest_state_one s
LEFT JOIN max_dp md ON md.user_id = s.user_id
LEFT JOIN first_dp700 fd ON fd.user_id = s.user_id
GROUP BY s.variant, s.platform
ORDER BY s.variant, s.platform;
