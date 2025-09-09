/* ==========================================================================
PILLAR 2 — MONETIZATION (ARPDAU, Payer Rate, ARPPU)

Motivation:
- ARPDAU (average revenue per daily user) shows monetization efficiency per active player.
- Payer rate reveals how many actives actually spend.
- ARPPU (average revenue per paying user) shows spending depth among those who pay.

Method:
- DAU from login table (distinct users per day).
- Revenue and payers from revenue table (sum revenue_usd, distinct users).
- Join on date, compute KPIs.

========================================================================== */

WITH dau AS (
    SELECT dt::date AS activity_date,
           COUNT(DISTINCT uid) AS dau
    FROM dataset_sl_login
    GROUP BY dt::date
),
rev AS (
    SELECT dt::date AS activity_date,
           SUM(usd_revenue) AS usd_revenue,
           COUNT(DISTINCT uid) AS payers
    FROM dataset_sl_revenue
    GROUP BY dt::date
)
SELECT d.activity_date,
       d.dau,
       COALESCE(r.usd_revenue, 0) AS usd_revenue,
       COALESCE(r.payers, 0) AS payers,       
       ROUND((COALESCE(r.usd_revenue,0) / NULLIF(d.dau,0))::numeric, 4) AS arpdau,
	   ROUND((COALESCE(r.usd_revenue,0) / NULLIF(r.payers,0))::numeric, 2) AS arppu,
	   ROUND((COALESCE(r.payers,0) * 100.0 / NULLIF(d.dau,0))::numeric, 2) AS payer_rate_pct
FROM dau d
LEFT JOIN rev r
       ON d.activity_date = r.activity_date
ORDER BY d.activity_date;
