CREATE OR REPLACE FUNCTION check_nulls()
RETURNS TABLE(table_name text, total_rows bigint, column_name text, null_count bigint)
LANGUAGE plpgsql AS $$
DECLARE
    tbl RECORD;
    col RECORD;
    sql_text TEXT;
BEGIN
    FOR tbl IN
        SELECT t.table_name
        FROM information_schema.tables t
        WHERE t.table_schema = 'public'
          AND t.table_name IN (
            'dataset_sl_cost',
            'dataset_sl_econ_spend_hc',
            'dataset_sl_endgame',
            'dataset_sl_install',
            'dataset_sl_login',
            'dataset_sl_revenue',
            'dataset_sl_startgame'
          )
    LOOP
        FOR col IN
            SELECT c.column_name
            FROM information_schema.columns c
            WHERE c.table_schema = 'public'
              AND c.table_name = tbl.table_name
        LOOP
            sql_text := format(
                'SELECT %L, COUNT(*) AS total_rows, %L, COUNT(*) - COUNT(%I) AS null_count FROM %I',
                tbl.table_name, col.column_name, col.column_name, tbl.table_name
            );

            RETURN QUERY EXECUTE sql_text;
        END LOOP;
    END LOOP;
END $$;


SELECT * FROM check_nulls();






