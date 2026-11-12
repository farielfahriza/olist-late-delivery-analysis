/* =====================================================================
   03 - REVIEWS AND CUSTOMER STATES (JOINs)
   ===================================================================== */

USE olist;

-- 3.1 Data check: how many orders have more than one review? -------------
-- Result: 99,224 reviews for 98,673 orders -> 551 extra reviews (0.56%).
-- Example: a customer re-reviewed after items arrived in separate shipments.
-- Impact is small, so all reviews are kept.
SELECT COUNT(*)                            AS total_reviews,
       COUNT(DISTINCT order_id)            AS total_orders,
       COUNT(*) - COUNT(DISTINCT order_id) AS extra_reviews,
       ROUND((COUNT(*) - COUNT(DISTINCT order_id)) / COUNT(*) * 100, 2) AS extra_reviews_pct
FROM order_reviews;

-- 3.2 Average review score of delivered orders ---------------------------
-- Result: 4.16
SELECT ROUND(AVG(r.review_score), 2) AS avg_review
FROM orders o
JOIN order_reviews r ON o.order_id = r.order_id
WHERE o.order_status = 'delivered';

-- 3.3 Review score: late vs on time --------------------------------------
-- Result: on time 4.29 (6.60% 1-star) | late 2.57 (46.16% 1-star)
SELECT
  CASE WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date
       THEN 'Late' ELSE 'On time' END AS delivery_status,
  COUNT(*)                      AS total_reviews,
  ROUND(AVG(r.review_score), 2) AS avg_review,
  SUM(CASE WHEN r.review_score = 1 THEN 1 ELSE 0 END) AS total_1_star,
  ROUND(SUM(CASE WHEN r.review_score = 1 THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS pct_1_star
FROM orders o
JOIN order_reviews r ON o.order_id = r.order_id
WHERE o.order_status = 'delivered'
GROUP BY delivery_status;

-- 3.4 Data check: customer_id vs customer_unique_id ----------------------
-- customer_id is unique per order; customer_unique_id is the actual person.
-- JOIN to orders uses customer_id.
SELECT COUNT(*)                           AS total_rows,
       COUNT(DISTINCT customer_id)        AS distinct_customer_id,
       COUNT(DISTINCT customer_unique_id) AS distinct_customers
FROM customers;

-- 3.5 Late rate per customer state (states with more than 100 orders) ----
-- States with very few orders are excluded: in a state with 41 orders,
-- a single late order moves the late rate by about 2.4 points.
SELECT
  c.customer_state,
  COUNT(*) AS total_delivered,
  SUM(CASE WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date
           THEN 1 ELSE 0 END) AS total_late,
  ROUND(SUM(CASE WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date
                 THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS late_pct
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_state
HAVING total_delivered > 100
ORDER BY late_pct DESC;

-- 3.6 Sellers per state ---------------------------------------------------
-- Result: SP has 1,849 of 3,095 sellers (about 60%).
SELECT seller_state, COUNT(*) AS total_sellers
FROM sellers
GROUP BY seller_state
ORDER BY total_sellers DESC;
