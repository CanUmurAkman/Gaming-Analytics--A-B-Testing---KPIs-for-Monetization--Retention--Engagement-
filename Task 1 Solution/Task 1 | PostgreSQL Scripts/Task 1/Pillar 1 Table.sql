/* ===========================================================================================
PILLAR 1 — STEP 1: COHORT RETENTION (D1 / D3 / D7 / D14) FOR THE SOFT‑LAUNCH WINDOW
Soft‑launch window (from your discovery):
  min_dt = '2019-07-31'  |  max_dt = '2019-09-15'

Motivation:
- Measure whether new users (by their first observed install date) return exactly on day 1, 3, 7, and 14.
- Segment by country and platform to reveal market and device differences.
- Use “eligible denominators” so late installs are not unfairly penalized for days that fall outside the data window.

Data‑health safeguards:
- No globally unique columns ⇒ deduplicate explicitly:
  * Earliest install per user via DISTINCT ON (uid ORDER BY dt ASC).
  * Distinct user‑day activity from login (uid, dt::date).
- Null‑only currency columns in startgame are irrelevant here, so no special handling.
- I do NOT (because I can't as I don't have ALTER permission) rename columns physically.

Output columns:
- install_date, country, platform
- installs_total: all users whose earliest install is in the Soft Launch (SL) window
- eligible_installs_d1/d3/d7/d14: installs where install_date+k <= global_max_dt
- d{K}_returners and d{K}_retention_pct: returners / eligible_installs_{K}
=========================================================================================== */
-- Rebuild retention view with explicit eligibility rules:
-- Exclude cohorts whose install_date falls in the LAST 7/14 days of the soft‑launch
-- window from D7/D14 computations (set those metrics to NULL).
DROP VIEW IF EXISTS retention_results;

CREATE OR REPLACE VIEW retention_results AS
WITH
-- 0) Soft-launch bounds (confirmed dates)
bounds AS (
  SELECT
    DATE '2019-07-31' AS sl_min_dt,
    DATE '2019-09-15' AS sl_max_dt
),

-- 1) Earliest install per user (dedupe; anchor cohort)
first_install AS (
  SELECT DISTINCT ON (i.uid)
         i.uid,
         i.dt::date   AS install_date,
         i.country,
         i.platform,
         i.network
  FROM dataset_sl_install i
  ORDER BY i.uid, i.dt ASC
),

-- 2) Cohorts = all first installs (no filtering to soft-launch window here)
cohorts AS (
  SELECT fi.*
  FROM first_install fi
  WHERE fi.platform IN ('ios','android')  -- no other platforms exist
),

-- 3) Distinct user-day activity from login
activity AS (
  SELECT DISTINCT l.uid, l.dt::date AS activity_date
  FROM dataset_sl_login l
),

-- 4) Map activity to cohort age (limit to ages we care about)
age_hits AS (
  SELECT
    c.install_date,
    c.country,
    c.platform,
    c.uid,
    (a.activity_date - c.install_date) AS age_day
  FROM cohorts c
  LEFT JOIN activity a
    ON a.uid = c.uid
   AND a.activity_date BETWEEN c.install_date + INTERVAL '1 day'
                           AND c.install_date + INTERVAL '14 day'
),

-- 5) Installs per cohort (include zero-activity users)
cohort_installs AS (
  SELECT
    c.install_date,
    c.country,
    c.platform,
    COUNT(DISTINCT c.uid) AS installs_total
  FROM cohorts c
  GROUP BY 1,2,3
),

-- 6) Distinct returners by exact age
returners AS (
  SELECT
    ah.install_date,
    ah.country,
    ah.platform,
    COUNT(DISTINCT CASE WHEN ah.age_day = 1  THEN ah.uid END) AS d1_returners,
    COUNT(DISTINCT CASE WHEN ah.age_day = 3  THEN ah.uid END) AS d3_returners,
    COUNT(DISTINCT CASE WHEN ah.age_day = 7  THEN ah.uid END) AS d7_returners,
    COUNT(DISTINCT CASE WHEN ah.age_day = 14 THEN ah.uid END) AS d14_returners
  FROM age_hits ah
  GROUP BY 1,2,3
),

-- 7) Eligibility flags using global bounds (exclude late cohorts from D7/D14 percentages)
eligibility AS (
  SELECT
    ci.install_date,
    ci.country,
    ci.platform,
    (ci.install_date + INTERVAL '1 day'  <= (SELECT sl_max_dt FROM bounds)) AS eligible_d1,
    (ci.install_date + INTERVAL '3 day'  <= (SELECT sl_max_dt FROM bounds)) AS eligible_d3,
    (ci.install_date + INTERVAL '7 day'  <= (SELECT sl_max_dt FROM bounds)) AS eligible_d7,
    (ci.install_date + INTERVAL '14 day' <= (SELECT sl_max_dt FROM bounds)) AS eligible_d14
  FROM cohort_installs ci
)

-- 8) Final assembly (percentages are NULL where ineligible)
SELECT
  ci.install_date,
  ci.country,
  ci.platform,

  ci.installs_total,

  r.d1_returners,
  r.d3_returners,
  r.d7_returners,
  r.d14_returners,

  CASE WHEN e.eligible_d1
       THEN ROUND(r.d1_returners  * 100.0 / NULLIF(ci.installs_total,0), 2)
       ELSE NULL END AS d1_retention_pct,

  CASE WHEN e.eligible_d3
       THEN ROUND(r.d3_returners  * 100.0 / NULLIF(ci.installs_total,0), 2)
       ELSE NULL END AS d3_retention_pct,

  CASE WHEN e.eligible_d7
       THEN ROUND(r.d7_returners  * 100.0 / NULLIF(ci.installs_total,0), 2)
       ELSE NULL END AS d7_retention_pct,

  CASE WHEN e.eligible_d14
       THEN ROUND(r.d14_returners * 100.0 / NULLIF(ci.installs_total,0), 2)
       ELSE NULL END AS d14_retention_pct,

  e.eligible_d1,
  e.eligible_d3,
  e.eligible_d7,
  e.eligible_d14

FROM cohort_installs ci
LEFT JOIN returners r
  ON r.install_date = ci.install_date
 AND r.country      = ci.country
 And r.platform     = ci.platform
JOIN eligibility e
  ON e.install_date = ci.install_date
 AND e.country      = ci.country
 And e.platform     = ci.platform
ORDER BY ci.install_date, ci.country, ci.platform;

select * from retention_results;