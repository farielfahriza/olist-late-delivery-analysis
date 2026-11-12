/* =====================================================================
   04 - DISTANCE, REGIONS, DELAY SEVERITY AND TRENDS
   Uses CTEs and window functions (MySQL 8+).
   ===================================================================== */

USE olist;

-- 4.1 Same state vs cross-state shipping ---------------------------------
-- After joining order_items, one order can appear in several rows (one per
-- item), so the CTE first reduces the data to one row per order.
-- cross_state = 1 if any item was shipped from another state.
-- Result: cross-state 61,895 orders, 9.25% late, 15.1 days (estimate 27.8)
--         same state  34,575 orders, 6.08% late,  7.9 days (estimate 18.2)
WITH order_level AS (
  SELECT o.order_id,
         MAX(CASE WHEN c.customer_state <> s.seller_state THEN 1 ELSE 0 END) AS cross_state,
         MAX(CASE WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date
                  THEN 1 ELSE 0 END) AS is_late,
         MAX(DATEDIFF(o.order_delivered_customer_date, o.order_purchase_timestamp)) AS delivery_days,
         MAX(DATEDIFF(o.order_estimated_delivery_date, o.order_purchase_timestamp)) AS estimated_days
  FROM orders o
  JOIN customers c   ON o.customer_id = c.customer_id
  JOIN order_items i ON o.order_id    = i.order_id
  JOIN sellers s     ON i.seller_id   = s.seller_id
  WHERE o.order_status = 'delivered'
    AND o.order_delivered_customer_date IS NOT NULL
  GROUP BY o.order_id
)
SELECT
  CASE WHEN cross_state = 1 THEN 'Different state' ELSE 'Same state' END AS shipping_type,
  COUNT(*)                                AS total_orders,
  SUM(is_late)                            AS total_late,
  ROUND(SUM(is_late) / COUNT(*) * 100, 2) AS late_pct,
  ROUND(AVG(delivery_days), 1)            AS avg_delivery_days,
  ROUND(AVG(estimated_days), 1)           AS avg_estimated_days
FROM order_level
GROUP BY shipping_type;

-- 4.2 Late rate per Brazilian region -------------------------------------
-- Result: Northeast 14.33% | North 9.80% | Central-West 7.97% |
--         Southeast 7.45% | South 7.05%
SELECT
  CASE
    WHEN c.customer_state IN ('AC','AP','AM','PA','RO','RR','TO')           THEN 'North'
    WHEN c.customer_state IN ('AL','BA','CE','MA','PB','PE','PI','RN','SE') THEN 'Northeast'
    WHEN c.customer_state IN ('DF','GO','MT','MS')                          THEN 'Central-West'
    WHEN c.customer_state IN ('ES','MG','RJ','SP')                          THEN 'Southeast'
    WHEN c.customer_state IN ('PR','RS','SC')                               THEN 'South'
  END AS region,
  COUNT(*) AS total_delivered,
  SUM(CASE WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date
           THEN 1 ELSE 0 END) AS total_late,
  ROUND(SUM(CASE WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date
                 THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS late_pct,
  ROUND(AVG(DATEDIFF(o.order_delivered_customer_date, o.order_purchase_timestamp)), 1) AS avg_delivery_days
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
GROUP BY region
ORDER BY late_pct DESC;

-- 4.3 Review score by delay severity -------------------------------------
-- "Up to 3 days late" also includes orders that arrived on the estimated
-- date but after its time (DATEDIFF = 0).
SELECT
  CASE
    WHEN o.order_delivered_customer_date <= o.order_estimated_delivery_date THEN '1. On time'
    WHEN DATEDIFF(o.order_delivered_customer_date, o.order_estimated_delivery_date) <= 3  THEN '2. Up to 3 days late'
    WHEN DATEDIFF(o.order_delivered_customer_date, o.order_estimated_delivery_date) <= 7  THEN '3. 4-7 days late'
    WHEN DATEDIFF(o.order_delivered_customer_date, o.order_estimated_delivery_date) <= 14 THEN '4. 8-14 days late'
    ELSE '5. 15+ days late'
  END AS delay_group,
  COUNT(*)                      AS total_reviews,
  ROUND(AVG(r.review_score), 2) AS avg_review,
  ROUND(SUM(CASE WHEN r.review_score = 1 THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS pct_1_star
FROM orders o
JOIN order_reviews r ON o.order_id = r.order_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
GROUP BY delay_group
ORDER BY delay_group;

-- 4.4 Monthly trend with month-over-month change (LAG) -------------------
WITH monthly AS (
  SELECT DATE_FORMAT(order_purchase_timestamp, '%Y-%m') AS purchase_month,
         COUNT(*) AS total_delivered,
         SUM(CASE WHEN order_delivered_customer_date > order_estimated_delivery_date
                  THEN 1 ELSE 0 END) AS total_late
  FROM orders
  WHERE order_status = 'delivered'
    AND order_purchase_timestamp >= '2017-01-01'
    AND order_purchase_timestamp <  '2018-09-01'
  GROUP BY purchase_month
)
SELECT purchase_month,
       total_delivered,
       ROUND(total_late / total_delivered * 100, 2) AS late_pct,
       ROUND(total_late / total_delivered * 100
             - LAG(total_late / total_delivered * 100) OVER (ORDER BY purchase_month), 2)
         AS late_pct_change,
       ROUND((total_delivered - LAG(total_delivered) OVER (ORDER BY purchase_month))
             / LAG(total_delivered) OVER (ORDER BY purchase_month) * 100, 1)
         AS order_growth_pct
FROM monthly
ORDER BY purchase_month;

-- 4.5 State ranking: national and within region (RANK, PARTITION BY) ----
WITH state_stats AS (
  SELECT
    c.customer_state,
    CASE
      WHEN c.customer_state IN ('AC','AP','AM','PA','RO','RR','TO')           THEN 'North'
      WHEN c.customer_state IN ('AL','BA','CE','MA','PB','PE','PI','RN','SE') THEN 'Northeast'
      WHEN c.customer_state IN ('DF','GO','MT','MS')                          THEN 'Central-West'
      WHEN c.customer_state IN ('ES','MG','RJ','SP')                          THEN 'Southeast'
      WHEN c.customer_state IN ('PR','RS','SC')                               THEN 'South'
    END AS region,
    COUNT(*) AS total_delivered,
    ROUND(SUM(CASE WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date
                   THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS late_pct
  FROM orders o
  JOIN customers c ON o.customer_id = c.customer_id
  WHERE o.order_status = 'delivered'
  GROUP BY c.customer_state
  HAVING COUNT(*) > 100
)
SELECT customer_state,
       region,
       total_delivered,
       late_pct,
       RANK() OVER (ORDER BY late_pct DESC)                     AS rank_national,
       RANK() OVER (PARTITION BY region ORDER BY late_pct DESC) AS rank_in_region
FROM state_stats
ORDER BY rank_national;
