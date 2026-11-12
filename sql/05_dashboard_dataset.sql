/* =====================================================================
   05 - DATASET FOR THE POWER BI DASHBOARD
   One row per delivered order (Jan 2017 - Aug 2018): 96,203 rows.
   Exported from MySQL Workbench as CSV and loaded into Power BI.
   ===================================================================== */

USE olist;

WITH review_per_order AS (       -- one review score per order
  SELECT order_id, AVG(review_score) AS review_score
  FROM order_reviews
  GROUP BY order_id
),
seller_per_order AS (            -- item totals and cross-state flag per order
  SELECT i.order_id,
         COUNT(*)             AS total_items,
         SUM(i.price)         AS items_value,
         SUM(i.freight_value) AS freight_value,
         MAX(CASE WHEN c.customer_state <> s.seller_state THEN 1 ELSE 0 END) AS cross_state
  FROM order_items i
  JOIN sellers s   ON i.seller_id   = s.seller_id
  JOIN orders o    ON i.order_id    = o.order_id
  JOIN customers c ON o.customer_id = c.customer_id
  GROUP BY i.order_id
)
SELECT
  o.order_id,
  DATE(o.order_purchase_timestamp)                 AS purchase_date,
  DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS purchase_month,
  c.customer_state,
  CASE
    WHEN c.customer_state IN ('AC','AP','AM','PA','RO','RR','TO')           THEN 'North'
    WHEN c.customer_state IN ('AL','BA','CE','MA','PB','PE','PI','RN','SE') THEN 'Northeast'
    WHEN c.customer_state IN ('DF','GO','MT','MS')                          THEN 'Central-West'
    WHEN c.customer_state IN ('ES','MG','RJ','SP')                          THEN 'Southeast'
    WHEN c.customer_state IN ('PR','RS','SC')                               THEN 'South'
  END AS region,
  sp.cross_state,
  sp.total_items,
  sp.items_value,
  sp.freight_value,
  DATEDIFF(o.order_estimated_delivery_date, o.order_purchase_timestamp)      AS estimated_days,
  DATEDIFF(o.order_delivered_customer_date, o.order_purchase_timestamp)      AS delivery_days,
  DATEDIFF(o.order_delivered_customer_date, o.order_estimated_delivery_date) AS days_vs_estimate,
  CASE WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date
       THEN 1 ELSE 0 END                           AS is_late,
  ROUND(r.review_score, 2)                         AS review_score
FROM orders o
JOIN customers c              ON o.customer_id = c.customer_id
LEFT JOIN seller_per_order sp ON o.order_id    = sp.order_id
LEFT JOIN review_per_order r  ON o.order_id    = r.order_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
  AND o.order_purchase_timestamp >= '2017-01-01'
  AND o.order_purchase_timestamp <  '2018-09-01';
