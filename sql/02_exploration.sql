/* =====================================================================
   02 - EXPLORATION (orders table only)
   Definition used throughout the project:
     Late = order_delivered_customer_date > order_estimated_delivery_date
   ===================================================================== */

USE olist;

-- 2.1 Orders by status --------------------------------------------------
SELECT order_status, COUNT(*) AS total_orders
FROM orders
GROUP BY order_status
ORDER BY total_orders DESC;

-- 2.2 Orders per month ----------------------------------------------------
-- Sep-Dec 2016 and Sep-Oct 2018 are incomplete and excluded from trend analysis.
SELECT DATE_FORMAT(order_purchase_timestamp, '%Y-%m') AS purchase_month,
       COUNT(*) AS total_orders
FROM orders
GROUP BY purchase_month
ORDER BY purchase_month;

-- 2.3 Daily orders in November 2017 (checking the Black Friday spike) -----
SELECT DATE(order_purchase_timestamp) AS order_date,
       COUNT(*) AS total_orders
FROM orders
WHERE order_purchase_timestamp >= '2017-11-01'
  AND order_purchase_timestamp <  '2017-12-01'
GROUP BY order_date
ORDER BY order_date;

-- 2.4 Overall late rate (delivered orders) -------------------------------
-- Result: 96,478 delivered, 7,826 late, 8.11%
SELECT
  COUNT(*) AS total_delivered,
  SUM(CASE WHEN order_delivered_customer_date > order_estimated_delivery_date
           THEN 1 ELSE 0 END) AS total_late,
  ROUND(SUM(CASE WHEN order_delivered_customer_date > order_estimated_delivery_date
                 THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS late_pct
FROM orders
WHERE order_status = 'delivered';

-- 2.5 Late rate per month (Jan 2017 - Aug 2018) --------------------------
-- Late rate is used instead of late count, because busier months
-- naturally have more late orders.
SELECT
  DATE_FORMAT(order_purchase_timestamp, '%Y-%m') AS purchase_month,
  COUNT(*) AS total_delivered,
  SUM(CASE WHEN order_delivered_customer_date > order_estimated_delivery_date
           THEN 1 ELSE 0 END) AS total_late,
  ROUND(SUM(CASE WHEN order_delivered_customer_date > order_estimated_delivery_date
                 THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS late_pct
FROM orders
WHERE order_status = 'delivered'
  AND order_purchase_timestamp >= '2017-01-01'
  AND order_purchase_timestamp <  '2018-09-01'
GROUP BY purchase_month
ORDER BY late_pct DESC;

-- 2.6 Estimated vs actual delivery time per month ------------------------
-- buffer_days = how much earlier than promised an order arrives on average.
SELECT
  DATE_FORMAT(order_purchase_timestamp, '%Y-%m') AS purchase_month,
  ROUND(AVG(DATEDIFF(order_estimated_delivery_date, order_purchase_timestamp)), 1) AS avg_estimated_days,
  ROUND(AVG(DATEDIFF(order_delivered_customer_date, order_purchase_timestamp)), 1) AS avg_actual_days,
  ROUND(AVG(DATEDIFF(order_estimated_delivery_date, order_delivered_customer_date)), 1) AS avg_buffer_days
FROM orders
WHERE order_status = 'delivered'
  AND order_purchase_timestamp >= '2017-01-01'
  AND order_purchase_timestamp <  '2018-09-01'
GROUP BY purchase_month
ORDER BY purchase_month;
