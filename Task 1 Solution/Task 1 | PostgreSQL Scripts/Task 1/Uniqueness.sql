-- 1) Drop the previous version (no arguments)
DROP FUNCTION IF EXISTS public.check_uniqueness();

CREATE OR REPLACE FUNCTION check_uniqueness()
RETURNS TABLE(
    table_name              text,
    column_name             text,
    total_rows              bigint,
    null_count              bigint,
    non_null_count          bigint,
    distinct_non_null       bigint,
    duplicates_non_null     bigint,
    is_unique_ignoring_nulls boolean,  -- true if all non-null values are unique
    is_unique_including_nulls boolean  -- true if non-null unique AND at most one NULL
)
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
            sql_text := format($f$
                SELECT
                    %L::text  AS table_name,
                    %L::text  AS column_name,
                    COUNT(*)  AS total_rows,
                    SUM(CASE WHEN %I IS NULL THEN 1 ELSE 0 END) AS null_count,
                    COUNT(%I) AS non_null_count,
                    COUNT(DISTINCT %I) AS distinct_non_null,
                    (COUNT(%I) - COUNT(DISTINCT %I)) AS duplicates_non_null,
                    (COUNT(%I) = COUNT(DISTINCT %I)) AS is_unique_ignoring_nulls,
                    (
                      (COUNT(*) - (
                         COUNT(DISTINCT %I) +
                         CASE WHEN SUM(CASE WHEN %I IS NULL THEN 1 ELSE 0 END) > 0 THEN 1 ELSE 0 END
                      )) = 0
                    ) AS is_unique_including_nulls
                FROM %I
            $f$,
              tbl.table_name, col.column_name,
              col.column_name,           -- null_count
              col.column_name,           -- non_null_count
              col.column_name,           -- distinct_non_null
              col.column_name, col.column_name, -- duplicates_non_null
              col.column_name, col.column_name, -- is_unique_ignoring_nulls
              col.column_name,           -- is_unique_including: COUNT(DISTINCT col)
              col.column_name,           -- is_unique_including: SUM(CASE WHEN col IS NULL ...)
              tbl.table_name
            );

            RETURN QUERY EXECUTE sql_text;
        END LOOP;
    END LOOP;
END $$;


SELECT * FROM public.check_uniqueness()
ORDER BY table_name, column_name;


