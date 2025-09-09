-- 1) Deduplicate assignment (state only)
CREATE TEMP VIEW abtest_state_one AS
SELECT DISTINCT ON (user_id)
  user_id, platform, variant, test_entry_date, install_date
FROM dataset_case202425_abtest_state
ORDER BY user_id, test_entry_date;  -- earliest assignment

-- 2) Sanitize durations (clamp negatives; recompute total from parts)
CREATE TEMP VIEW duration_clean AS
SELECT
  d.user_id,
  d.play_date,
  GREATEST(0, COALESCE(d.camp_duration, 0))  ::double precision AS camp_sec,
  GREATEST(0, COALESCE(d.level_duration, 0)) ::double precision AS level_sec,
  GREATEST(0, COALESCE(d.event_duration, 0)) ::double precision AS event_sec,
  ( GREATEST(0, COALESCE(d.camp_duration, 0))
  + GREATEST(0, COALESCE(d.level_duration, 0))
  + GREATEST(0, COALESCE(d.event_duration, 0)) )::double precision AS total_sec
FROM dataset_case202425_abtest_duration d;

