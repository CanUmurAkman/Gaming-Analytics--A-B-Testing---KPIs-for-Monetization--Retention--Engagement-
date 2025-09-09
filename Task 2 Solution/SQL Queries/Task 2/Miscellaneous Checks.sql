-- Check for duplicates in user_id -> Timestamps are in seconds (10-digit; converting as ms absurdly gives 1970 dates).
SELECT 
    COUNT(*) AS total_rows,
    COUNT(DISTINCT user_id) AS distinct_user_ids
FROM dataset_case202425_abtest_login;

-- Revenue timestamps: seconds vs milliseconds?
SELECT
  MIN(purchase_timestamp) AS min_ts,
  MAX(purchase_timestamp) AS max_ts,
  AVG(LENGTH(purchase_timestamp::text)) AS avg_len
FROM dataset_case202425_abtest_revenue;

-- Sanity: interpret as seconds vs milliseconds
SELECT
  to_timestamp(MIN(purchase_timestamp))          AS min_as_sec,
  to_timestamp(MAX(purchase_timestamp))          AS max_as_sec,
  to_timestamp(MIN(purchase_timestamp)/1000.0)   AS min_as_ms,
  to_timestamp(MAX(purchase_timestamp)/1000.0)   AS max_as_ms
FROM dataset_case202425_abtest_revenue;

-- Feature metrics timestamps
SELECT
  to_timestamp(MIN(event_timestamp))        AS fm_min_as_sec,
  to_timestamp(MAX(event_timestamp))        AS fm_max_as_sec,
  to_timestamp(MIN(event_timestamp)/1000.0) AS fm_min_as_ms,
  to_timestamp(MAX(event_timestamp)/1000.0) AS fm_max_as_ms
FROM dataset_case202425_abtest_feature_metrics;

--Activity windows line up with test-entry interval.--

-- Duration sanity (expect plausible ranges if in seconds) -> Negative total_duration appears (min ≈ −57.64). Max totals look like hours-scale, so units are plausible; the negatives are data noise.
SELECT
  MIN(total_duration)  AS min_total,
  MAX(total_duration)  AS max_total,
  MIN(camp_duration)   AS min_camp,
  MAX(camp_duration)   AS max_camp,
  MIN(level_duration)  AS min_level,
  MAX(level_duration)  AS max_level,
  MIN(event_duration)  AS min_event,
  MAX(event_duration)  AS max_event
FROM dataset_case202425_abtest_duration;
