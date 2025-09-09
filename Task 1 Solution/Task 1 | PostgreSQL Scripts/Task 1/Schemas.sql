-- Columns & types for all seven tables
SELECT 
  c.table_name,
  c.ordinal_position,
  c.column_name,
  c.data_type,
  c.udt_name,
  c.is_nullable,
  c.character_maximum_length,
  c.numeric_precision,
  c.numeric_scale
FROM information_schema.columns c
WHERE c.table_schema = 'public'
  AND c.table_name IN (
    'dataset_sl_cost',
    'dataset_sl_econ_spend_hc',
    'dataset_sl_endgame',
    'dataset_sl_install',
    'dataset_sl_login',
    'dataset_sl_revenue',
    'dataset_sl_startgame'
  )
ORDER BY c.table_name, c.ordinal_position;