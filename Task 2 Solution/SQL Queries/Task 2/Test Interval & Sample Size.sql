-- TEST WINDOW + BASIC COUNTS
WITH t AS (
  SELECT
    MIN(test_entry_date) AS test_start,
    MAX(test_entry_date) AS test_end,
    COUNT(*)              AS assigned_rows,
    COUNT(DISTINCT user_id) AS assigned_users
  FROM abtest_state_one
)
SELECT * FROM t;


-- DAILY ASSIGNMENTS (BALANCE OVER TIME)
SELECT
  test_entry_date::date AS dt,
  variant,
  platform,
  COUNT(DISTINCT user_id) AS users_assigned
FROM abtest_state_one
GROUP BY 1,2,3
ORDER BY 1,2,3;

--Date Bounds--
SELECT
  (SELECT MIN(test_entry_date) FROM abtest_state_one)      AS min_test_entry_date,
  (SELECT MAX(test_entry_date) FROM abtest_state_one)      AS max_test_entry_date,
  (SELECT MIN(install_date)    FROM abtest_state_one)      AS min_install_date,
  (SELECT MAX(install_date)    FROM abtest_state_one)      AS max_install_date,
  (SELECT MIN(login_date)      FROM dataset_case202425_abtest_login)      AS min_login_date,
  (SELECT MAX(login_date)      FROM dataset_case202425_abtest_login)      AS max_login_date,
  (SELECT MIN(purchase_date)   FROM dataset_case202425_abtest_revenue)    AS min_purchase_date,
  (SELECT MAX(purchase_date)   FROM dataset_case202425_abtest_revenue)    AS max_purchase_date
;

