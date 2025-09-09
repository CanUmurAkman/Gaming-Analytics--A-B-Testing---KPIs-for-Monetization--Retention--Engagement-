SELECT
  s.variant,
  s.platform,
  COUNT(*)                                  AS users,
  ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_total,
  MIN(s.install_date) AS min_install_date,
  MAX(s.install_date) AS max_install_date,
  MIN(s.test_entry_date) AS min_test_entry_date,
  MAX(s.test_entry_date) AS max_test_entry_date
FROM abtest_state_one s
GROUP BY s.variant, s.platform
ORDER BY s.variant, s.platform;

