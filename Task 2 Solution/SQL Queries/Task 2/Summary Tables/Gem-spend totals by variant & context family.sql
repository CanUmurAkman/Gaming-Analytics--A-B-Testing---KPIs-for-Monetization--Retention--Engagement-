SELECT
  s.variant,
  SUM(CASE WHEN es.currency ILIKE 'gem' THEN es.amount ELSE 0 END)                                                     AS gem_spent_total,
  SUM(CASE WHEN es.currency ILIKE 'gem' AND es.spend_context ILIKE '%craft%' THEN es.amount ELSE 0 END)                AS gem_craft_like,
  SUM(CASE WHEN es.currency ILIKE 'gem' AND es.spend_context ILIKE '%slot%'  THEN es.amount ELSE 0 END)                AS gem_slots_like,
  SUM(CASE WHEN es.currency ILIKE 'gem' AND es.spend_context ILIKE '%skip%'  THEN es.amount ELSE 0 END)                AS gem_skips_like
FROM dataset_case202425_abtest_economy_spend es
JOIN abtest_state_one s USING (user_id)
GROUP BY s.variant
ORDER BY s.variant;