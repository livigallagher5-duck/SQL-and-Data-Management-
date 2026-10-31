-- Assignment 1 asked for the top 3 best-selling item categories in our stores during August 2001.
-- From comments: best-selling = total quantity sold


--import beginning from class examples
use role STUDENT_CRICKET;  /* Use your own role STUDENT_{ANIMAL}, e.g. STUDENT_TIGER */
use warehouse mqe_wh_xs; 

--solution below
SELECT
    i.i_category AS category,
    SUM(s.ss_quantity) AS total_quantity
FROM SNOWFLAKE_SAMPLE_DATA.TPCDS_SF10TCL.store_sales AS s
LEFT JOIN SNOWFLAKE_SAMPLE_DATA.TPCDS_SF10TCL.date_dim AS d ON s.ss_sold_date_sk = d.d_date_sk
LEFT JOIN SNOWFLAKE_SAMPLE_DATA.TPCDS_SF10TCL.item AS i ON s.ss_item_sk = i.i_item_sk
WHERE
    YEAR(d.d_date) = 2001 AND MONTH(d.d_date) = 8
GROUP BY category
ORDER BY total_quantity DESC
LIMIT 3;

--answer: the top 3 categories are music (2941256133), shoes (2936055907), sports (2931201056).
