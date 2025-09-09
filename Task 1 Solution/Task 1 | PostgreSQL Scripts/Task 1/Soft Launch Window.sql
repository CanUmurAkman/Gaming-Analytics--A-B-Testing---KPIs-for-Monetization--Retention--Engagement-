/* ===========================================================================================
Find the soft-launch window across all tables.
Steps:
1) For each table, select the minimum and maximum of its date column.
   - All tables use "dt" except dataset_sl_cost, which uses "date".
   - We alias them consistently as "dt" for homogeneity.
2) UNION ALL the results together into one combined set.
3) From that set, compute:
   - The minimum among the minima (global_min)
   - The maximum among the maxima (global_max)
=========================================================================================== */

WITH per_table AS (
    SELECT 'dataset_sl_install'      AS table_name, MIN(dt) AS min_dt, MAX(dt) AS max_dt FROM dataset_sl_install
    UNION ALL
    SELECT 'dataset_sl_login',       MIN(dt), MAX(dt) FROM dataset_sl_login
    UNION ALL
    SELECT 'dataset_sl_revenue',     MIN(dt), MAX(dt) FROM dataset_sl_revenue
    UNION ALL
    SELECT 'dataset_sl_endgame',     MIN(dt), MAX(dt) FROM dataset_sl_endgame
    UNION ALL
    SELECT 'dataset_sl_startgame',   MIN(dt), MAX(dt) FROM dataset_sl_startgame
    UNION ALL
    SELECT 'dataset_sl_econ_spend_hc', MIN(dt), MAX(dt) FROM dataset_sl_econ_spend_hc
    UNION ALL
    -- dataset_sl_cost uses "date" instead of "dt"; alias it as dt for consistency
    SELECT 'dataset_sl_cost',        MIN("date") AS min_dt, MAX("date") AS max_dt FROM dataset_sl_cost
),
global_range AS (
    SELECT MIN(min_dt) AS global_min_dt, MAX(max_dt) AS global_max_dt
    FROM per_table
)
SELECT *
FROM per_table
UNION ALL
SELECT 'GLOBAL_RANGE' AS table_name, global_min_dt AS min_dt, global_max_dt AS max_dt
FROM global_range;