WITH firsts AS (
  SELECT DISTINCT ON (user_id, step)
         user_id, step, event_timestamp
  FROM dataset_case202425_abtest_feature_metrics
  ORDER BY user_id, step, event_timestamp
),
pivot AS (
  SELECT
    user_id,
    MAX(CASE WHEN step='visible'           THEN event_timestamp END) AS t_visible,
    MAX(CASE WHEN step='open_wonder'       THEN event_timestamp END) AS t_open,
    MAX(CASE WHEN step='crafter_transform' THEN event_timestamp END) AS t_transform,
    MAX(CASE WHEN step='recipe_selected'   THEN event_timestamp END) AS t_select,
    MAX(CASE WHEN step='ingredient_added'  THEN event_timestamp END) AS t_ingredient,
    MAX(CASE WHEN step='crafting_start'    THEN event_timestamp END) AS t_start,
    MAX(CASE WHEN step='item_collected'    THEN event_timestamp END) AS t_collect
  FROM firsts
  GROUP BY user_id
)
SELECT
  s.variant,
  COUNT(*) AS users_in_state,
  SUM((p.t_visible  IS NOT NULL)::int) AS seen_beacon,
  SUM((p.t_open     IS NOT NULL)::int) AS opened,
  SUM((p.t_select   IS NOT NULL)::int) AS recipe_selected,
  SUM((p.t_start    IS NOT NULL)::int) AS crafting_started,
  SUM((p.t_collect  IS NOT NULL)::int) AS item_collected,
  ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY ((p.t_start - p.t_select)/3600.0))::numeric, 2) AS median_h_select_to_start,
  ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY ((p.t_collect - p.t_start)/3600.0))::numeric, 2) AS median_h_start_to_collect
FROM pivot p
JOIN abtest_state_one s USING (user_id)
GROUP BY s.variant
ORDER BY s.variant;
