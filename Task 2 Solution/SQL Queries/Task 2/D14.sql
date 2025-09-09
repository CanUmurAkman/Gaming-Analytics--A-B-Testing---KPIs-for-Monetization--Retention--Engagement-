-- Build per-user D14 minutes & revenue (post-entry)
DROP TABLE IF EXISTS per_user_d14;

CREATE TEMP TABLE per_user_d14 AS
WITH minutes_raw AS (
  SELECT
    s.user_id,
    s.variant,
    (COALESCE(dc.camp_sec,0)+COALESCE(dc.level_sec,0)+COALESCE(dc.event_sec,0))/60.0 AS minutes,
    (dc.play_date - s.test_entry_date) AS d
  FROM abtest_state_one s
  JOIN duration_clean dc USING (user_id)
  WHERE dc.play_date >= s.test_entry_date
),
minutes_d14 AS (
  SELECT user_id, variant, SUM(minutes) AS minutes_d14
  FROM minutes_raw
  WHERE d BETWEEN 0 AND 14
  GROUP BY user_id, variant
),
revenue_raw AS (
  SELECT
    s.user_id,
    s.variant,
    r.purchase_usd_amount AS usd,
    (r.purchase_date - s.test_entry_date) AS d
  FROM abtest_state_one s
  JOIN dataset_case202425_abtest_revenue r USING (user_id)
  WHERE r.purchase_date >= s.test_entry_date
),
revenue_d14 AS (
  SELECT user_id, variant, SUM(usd) AS revenue_d14
  FROM revenue_raw
  WHERE d BETWEEN 0 AND 14
  GROUP BY user_id, variant
)
SELECT
  s.user_id,
  s.variant,
  COALESCE(m.minutes_d14, 0)::double precision  AS minutes_d14,
  COALESCE(rv.revenue_d14, 0)::double precision AS revenue_d14
FROM abtest_state_one s
LEFT JOIN minutes_d14  m  USING (user_id, variant)
LEFT JOIN revenue_d14 rv USING (user_id, variant);

SELECT user_id, variant, minutes_d14, revenue_d14
FROM per_user_d14
ORDER BY variant, user_id;


