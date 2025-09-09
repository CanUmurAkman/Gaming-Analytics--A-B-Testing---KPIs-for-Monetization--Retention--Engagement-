WITH dau AS (
  SELECT s.variant, l.login_date AS dt, COUNT(DISTINCT l.user_id) AS dau
  FROM dataset_case202425_abtest_login l
  JOIN abtest_state_one s USING (user_id)
  GROUP BY s.variant, dt
),
rev AS (
  SELECT s.variant, r.purchase_date AS dt, SUM(r.purchase_usd_amount) AS usd
  FROM dataset_case202425_abtest_revenue r
  JOIN abtest_state_one s USING (user_id)
  GROUP BY s.variant, dt
)
SELECT
  COALESCE(d.variant, r.variant) AS variant,
  COALESCE(d.dt, r.dt)           AS dt,
  COALESCE(d.dau, 0)             AS dau,
  COALESCE(r.usd, 0)             AS usd,
  ROUND((COALESCE(r.usd, 0)::numeric) / NULLIF(COALESCE(d.dau, 0)::numeric, 0), 4) AS arpDAU
FROM dau d
FULL OUTER JOIN rev r ON r.variant = d.variant AND r.dt = d.dt
ORDER BY variant, dt;
