WITH mins AS (
  SELECT s.variant,
         d.play_date AS dt,
         SUM(d.total_sec) / 60.0 AS total_minutes,
         SUM(d.camp_sec)  / 60.0 AS camp_minutes,
         SUM(d.level_sec) / 60.0 AS level_minutes,
         SUM(d.event_sec) / 60.0 AS event_minutes
  FROM duration_clean d
  JOIN abtest_state_one s USING (user_id)
  GROUP BY s.variant, dt
),
dau AS (
  SELECT s.variant, l.login_date AS dt, COUNT(DISTINCT l.user_id) AS dau
  FROM dataset_case202425_abtest_login l
  JOIN abtest_state_one s USING (user_id)
  GROUP BY s.variant, dt
)
SELECT
  COALESCE(m.variant, a.variant) AS variant,
  COALESCE(m.dt, a.dt)           AS dt,
  COALESCE(a.dau, 0)             AS dau,
  -- averages per DAU
  ROUND( (COALESCE(m.total_minutes,0)::numeric) / NULLIF(COALESCE(a.dau,0)::numeric,0), 2)  AS minutes_per_DAU,
  ROUND( (COALESCE(m.camp_minutes,0)::numeric)  / NULLIF(COALESCE(a.dau,0)::numeric,0), 2)  AS camp_min_per_DAU,
  ROUND( (COALESCE(m.level_minutes,0)::numeric) / NULLIF(COALESCE(a.dau,0)::numeric,0), 2)  AS level_min_per_DAU,
  ROUND( (COALESCE(m.event_minutes,0)::numeric) / NULLIF(COALESCE(a.dau,0)::numeric,0), 2)  AS event_min_per_DAU,
  -- mix of minutes (shares)
  ROUND( (COALESCE(m.camp_minutes,0)::numeric)  / NULLIF(COALESCE(m.total_minutes,0)::numeric,0), 3) AS camp_share,
  ROUND( (COALESCE(m.level_minutes,0)::numeric) / NULLIF(COALESCE(m.total_minutes,0)::numeric,0), 3) AS level_share,
  ROUND( (COALESCE(m.event_minutes,0)::numeric) / NULLIF(COALESCE(m.total_minutes,0)::numeric,0), 3) AS event_share
FROM mins m
FULL OUTER JOIN dau a ON a.variant = m.variant AND a.dt = m.dt
ORDER BY variant, dt;

