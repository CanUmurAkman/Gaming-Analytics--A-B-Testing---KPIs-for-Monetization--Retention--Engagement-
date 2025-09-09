SELECT 
  platform,
  ROUND(AVG(d1_retention_pct),2) AS avg_d1,
  ROUND(AVG(d3_retention_pct),2) AS avg_d3,
  ROUND(AVG(d7_retention_pct),2) AS avg_d7,
  ROUND(AVG(d14_retention_pct),2) AS avg_d14
FROM retention_results   -- using the temporary table
GROUP BY platform;

SELECT country, platform,
       ROUND(AVG(d7_retention_pct),2) AS avg_d7,
       COUNT(*) AS cohorts
FROM retention_results
GROUP BY country, platform
HAVING COUNT(*) > 3   -- filter out tiny sample sizes
ORDER BY avg_d7 DESC
LIMIT 5;

-- And then flip ORDER BY avg_d7 ASC LIMIT 5 for the worst.
SELECT country, platform,
       ROUND(AVG(d7_retention_pct),2) AS avg_d7,
       COUNT(*) AS cohorts
FROM retention_results
GROUP BY country, platform
HAVING COUNT(*) > 3   -- filter out tiny sample sizes
ORDER BY avg_d7 ASC
LIMIT 5;

SELECT install_date, country, platform,
       d1_retention_pct,
       d7_retention_pct,
       ROUND(d7_retention_pct / NULLIF(d1_retention_pct,0), 2) AS d7_to_d1_ratio
FROM retention_results
ORDER BY install_date, country, platform;

SELECT DATE_TRUNC('week', install_date)::date AS install_week,
       country, platform,
       ROUND(AVG(d1_retention_pct),2) AS avg_d1,
       ROUND(AVG(d7_retention_pct),2) AS avg_d7,
       ROUND(AVG(d14_retention_pct),2) AS avg_d14
FROM retention_results
GROUP BY 1,2,3
ORDER BY 1,2,3;




