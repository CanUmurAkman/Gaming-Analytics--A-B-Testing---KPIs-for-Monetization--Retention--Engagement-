-- === COHORT-SAFE INSTALLS (one row per cohort) ===============================
WITH cohort_installs AS (
  SELECT
    dt::date                  AS install_date,
    country,
    platform,
    network,
    COUNT(DISTINCT uid)             AS installs
  FROM dataset_sl_install
  GROUP BY 1,2,3,4
),

-- === COHORT-SAFE COST (CPI numerator) ========================================
cohort_cost AS (
  SELECT
    date::date                    AS install_date,   -- align cost to install cohort date
    country,
    mapped_platform	              AS platform,
    network,
    SUM("cost")                      AS spend_usd
  FROM dataset_sl_cost
  GROUP BY 1,2,3,4
),

-- === CPI by cohort ============================================================
cpi_by_cohort AS (
  SELECT
    i.install_date,
    i.country,
    i.platform,
    i.network,
    i.installs,
    c.spend_usd,
    CASE WHEN i.installs > 0 THEN c.spend_usd::double precision / i.installs ELSE NULL END AS cpi
  FROM cohort_installs i
  LEFT JOIN cohort_cost c
    USING (install_date, country, platform, network)
),

-- === COHORT-ALIGNED REVENUE BY PLAYER AGE ====================================
-- We map each revenue event to the user’s install cohort (via install table),
-- compute player_age = (event_date - install_date) in days, then aggregate.
revenue_by_age AS (
  SELECT
    inst.dt::date            AS install_date,
    inst.country,
    inst.platform,
    inst.network,
    GREATEST(0, (rev.dt::date - inst.dt::date))::int AS player_age,
    SUM(rev.usd_revenue)               AS revenue_usd
  FROM dataset_sl_revenue rev
  JOIN dataset_sl_install  inst
    ON inst.uid = rev.uid
  WHERE rev.usd_revenue IS NOT NULL
    AND rev.usd_revenue <> 0
    AND rev.dt::date >= inst.dt::date   -- guard against negative ages
    AND rev.dt::date <= inst.dt::date + INTERVAL '30 days' -- cap to D30 for this pillar
  GROUP BY 1,2,3,4,5
),

-- === CUMULATIVE REVENUE BY AGE ===============================================
cumrev_by_age AS (
  SELECT
    install_date,
    country,
    platform,
    network,
    player_age,
    SUM(revenue_usd)                                                AS revenue_usd,
    SUM(SUM(revenue_usd)) OVER (
      PARTITION BY install_date, country, platform, network
      ORDER BY player_age
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )                                                               AS cum_revenue_usd
  FROM revenue_by_age
  GROUP BY 1,2,3,4,5
),

-- === LTV PER USER BY AGE (cum revenue / installs) ============================
ltv_by_age AS (
  SELECT
    a.install_date,
    a.country,
    a.platform,
    a.network,
    a.player_age,
    a.cum_revenue_usd,
    c.installs,
    CASE WHEN c.installs > 0 THEN a.cum_revenue_usd::double precision / c.installs ELSE NULL END AS ltv_per_user
  FROM cumrev_by_age a
  JOIN cpi_by_cohort c
    USING (install_date, country, platform, network)
),

-- === PICK DECISION CHECKPOINTS (D1, D7, D14, D30) ============================
checkpoints AS (
  SELECT * FROM ltv_by_age WHERE player_age IN (1,7,14,30)
),

-- === ROAS (cum revenue / spend) & LTV/CPI ratio ==============================
unit_econ AS (
  SELECT
    cp.install_date,
    cp.country,
    cp.platform,
    cp.network,
    cp.player_age,
    cp.installs,
    c.spend_usd,
    c.cpi,
    cp.cum_revenue_usd,
    cp.ltv_per_user,
    CASE WHEN c.spend_usd > 0 THEN cp.cum_revenue_usd::double precision / c.spend_usd ELSE NULL END AS roas,
    CASE WHEN c.cpi > 0       THEN cp.ltv_per_user::double precision / c.cpi       ELSE NULL END AS ltv_to_cpi
  FROM checkpoints cp
  JOIN cpi_by_cohort c
    USING (install_date, country, platform, network)
)

-- === FINAL SELECT ============================================================
SELECT
  install_date, country, platform, network,
  player_age AS day,
  installs, spend_usd, cpi,
  cum_revenue_usd, ltv_per_user,
  roas, ltv_to_cpi
FROM unit_econ
ORDER BY install_date, country, platform, network, day;
