WITH exposure AS (
  SELECT DISTINCT user_id
  FROM dataset_case202425_abtest_feature_metrics
),
eligible AS (
  SELECT user_id
  FROM dataset_case202425_abtest_login
  GROUP BY user_id
  HAVING MAX(d_power) >= 700
)
SELECT
  s.variant,
  COUNT(*) AS users,
  SUM(CASE WHEN e.user_id IS NOT NULL THEN 1 ELSE 0 END) AS exposed_any,
  SUM(CASE WHEN el.user_id IS NOT NULL THEN 1 ELSE 0 END) AS eligible_700p,
  SUM(CASE WHEN el.user_id IS NOT NULL AND e.user_id IS NOT NULL THEN 1 ELSE 0 END) AS exposed_among_eligible
FROM abtest_state_one s
LEFT JOIN exposure e ON e.user_id = s.user_id
LEFT JOIN eligible el ON el.user_id = s.user_id
GROUP BY s.variant
ORDER BY s.variant;
