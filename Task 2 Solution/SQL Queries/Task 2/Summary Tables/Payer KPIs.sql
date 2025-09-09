-- Variant-level payer KPIs over full test window
SELECT
  s.variant,
  COUNT(DISTINCT s.user_id)                                                        AS users,
  COUNT(DISTINCT r.user_id) FILTER (WHERE r.purchase_usd_amount > 0)               AS payers,
  ROUND(100.0 * COUNT(DISTINCT r.user_id) FILTER (WHERE r.purchase_usd_amount > 0)
       / NULLIF(COUNT(DISTINCT s.user_id),0), 2)                                   AS payer_rate_pct,
  COALESCE(SUM(r.purchase_usd_amount),0)                                           AS total_usd,
  ROUND((COALESCE(SUM(r.purchase_usd_amount),0)::numeric) 
       / NULLIF(COUNT(DISTINCT s.user_id)::numeric,0), 4)                          AS arpu
FROM abtest_state_one s
LEFT JOIN dataset_case202425_abtest_revenue r USING (user_id)
GROUP BY s.variant
ORDER BY s.variant;