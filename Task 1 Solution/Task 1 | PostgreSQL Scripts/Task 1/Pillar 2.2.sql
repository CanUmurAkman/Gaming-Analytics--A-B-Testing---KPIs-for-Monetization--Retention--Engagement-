/* =========================================================================================
PILLAR 2 — CUMULATIVE LTV BY INSTALL COHORT AND PLAYER AGE (D1 / D7 / D14 / D30)

Motivation:
- LTV(age) answers “how much revenue, on average, has each user in this install cohort generated
  by a given day of age?” This is the monetization curve we’ll compare to CPI in Pillar 3.

Key choices:
- Cohort anchor = first observed install per user (earliest dt).
- Age_day = (revenue_dt - install_date) in whole days; we keep non‑negative ages only.
- Average includes non‑payers by dividing total cohort cumulative revenue by installs_total.
- Eligibility: a cohort is eligible for day K if (install_date + K) ≤ global_max_dt. Ineligible cells → NULL.
========================================================================================= */

WITH
bounds AS (
  SELECT
    DATE '2019-07-31' AS sl_min_dt,
    DATE '2019-09-15' AS sl_max_dt
),

/* 1) Earliest install per user (dedupe) */
first_install AS (
  SELECT DISTINCT ON (i.uid)
         i.uid,
         i.dt::date   AS install_date,
         i.country,
         i.platform
  FROM dataset_sl_install i
  ORDER BY i.uid, i.dt ASC
),

/* 2) Installs per cohort grain (denominator includes non‑payers) */
cohort_installs AS (
  SELECT
    fi.install_date, fi.country, fi.platform,
    COUNT(DISTINCT fi.uid) AS installs_total
  FROM first_install fi
  GROUP BY 1,2,3
),

/* 3) Revenue mapped to cohort age (only non‑negative ages, cap at 30 for this report) */
cohort_rev AS (
  SELECT
    fi.install_date, fi.country, fi.platform, r.uid,
    (r.dt::date - fi.install_date) AS age_day,
    r.usd_revenue
  FROM first_install fi
  JOIN dataset_sl_revenue r
    ON r.uid = fi.uid
  WHERE (r.dt::date - fi.install_date) BETWEEN 0 AND 30
),

/* 4) Sum revenue per (uid, age_day); then cumulative revenue per uid over age */
user_age_rev AS (
  SELECT
    install_date, country, platform, uid, age_day,
    SUM(usd_revenue) AS usd_at_age
  FROM cohort_rev
  GROUP BY 1,2,3,4,5
),
user_cum_rev AS (
  SELECT
    install_date, country, platform, uid, age_day,
    SUM(usd_at_age) OVER (
      PARTITION BY install_date, country, platform, uid
      ORDER BY age_day
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cum_usd
  FROM user_age_rev
),

/* 5) Total cohort cumulative revenue at each age (sum over payers only),
      then average across ALL installs by dividing by installs_total */
cohort_cum_ltv AS (
  SELECT
    u.install_date, u.country, u.platform, u.age_day,
    SUM(u.cum_usd)                             AS cohort_cum_usd,   -- sum over users with any revenue
    ci.installs_total,
    (SUM(u.cum_usd) / NULLIF(ci.installs_total, 0))::numeric(12,4) AS ltv_usd
  FROM user_cum_rev u
  JOIN cohort_installs ci
    ON ci.install_date = u.install_date
   AND ci.country      = u.country
   AND ci.platform     = u.platform
  GROUP BY 1,2,3,4, ci.installs_total
),

/* 6) Eligibility for requested horizons vs global data max */
eligibility AS (
  SELECT
    ci.install_date, ci.country, ci.platform,
    (ci.install_date + INTERVAL '1 day'  <= (SELECT sl_max_dt FROM bounds)) AS eligible_d1,
    (ci.install_date + INTERVAL '7 day'  <= (SELECT sl_max_dt FROM bounds)) AS eligible_d7,
    (ci.install_date + INTERVAL '14 day' <= (SELECT sl_max_dt FROM bounds)) AS eligible_d14,
    (ci.install_date + INTERVAL '30 day' <= (SELECT sl_max_dt FROM bounds)) AS eligible_d30
  FROM cohort_installs ci
)

/* LONG FORM: full LTV curve by age_day (0..30). Useful for plotting.
SELECT
  c.install_date,
  c.country,
  c.platform,
  c.age_day,
  c.installs_total,
  c.ltv_usd
FROM cohort_cum_ltv c
ORDER BY c.install_date, c.country, c.platform, c.age_day;
*/


-- WIDE FORM: compact decision table for D1/D7/D14/D30 with eligibility.
-- Note: cells become NULL when cohort is ineligible at that horizon.

SELECT
 base.install_date,
 base.country,
 base.platform,
 base.installs_total,
 CASE WHEN e.eligible_d1  THEN MAX(CASE WHEN age_day = 1  THEN ltv_usd END) END AS ltv_d1_usd,
 CASE WHEN e.eligible_d7  THEN MAX(CASE WHEN age_day = 7  THEN ltv_usd END) END AS ltv_d7_usd,
 CASE WHEN e.eligible_d14 THEN MAX(CASE WHEN age_day = 14 THEN ltv_usd END) END AS ltv_d14_usd,
 CASE WHEN e.eligible_d30 THEN MAX(CASE WHEN age_day = 30 THEN ltv_usd END) END AS ltv_d30_usd,
 e.eligible_d1, e.eligible_d7, e.eligible_d14, e.eligible_d30
 FROM (
   SELECT install_date, country, platform, installs_total, age_day, ltv_usd
   FROM cohort_cum_ltv
   WHERE age_day IN (1,7,14,30)
 ) base
 JOIN eligibility e
   ON e.install_date = base.install_date
  AND e.country      = base.country
  AND e.platform     = base.platform
 GROUP BY base.install_date, base.country, base.platform, base.installs_total,
          e.eligible_d1, e.eligible_d7, e.eligible_d14, e.eligible_d30
 ORDER BY base.install_date, base.country, base.platform;
