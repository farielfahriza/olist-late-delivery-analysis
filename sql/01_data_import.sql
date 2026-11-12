/* =====================================================================
   01 - DATA IMPORT
   Creates the five tables used in this project and loads the CSV files
   from the Olist dataset (Kaggle) into MySQL 8.

   Replace 'path/to/' with the folder where the CSV files are saved.
   Validate the row count after each import (expected counts below).
   ===================================================================== */

SET GLOBAL local_infile = 1;   -- needed for LOAD DATA LOCAL INFILE

CREATE DATABASE IF NOT EXISTS olist;
USE olist;

-- ---------------------------------------------------------------------
-- orders  (expected: 99,441 rows, one row per order)
-- ---------------------------------------------------------------------
CREATE TABLE orders (
  order_id VARCHAR(50) PRIMARY KEY,
  customer_id VARCHAR(50),
  order_status VARCHAR(20),
  order_purchase_timestamp DATETIME,
  order_approved_at DATETIME,
  order_delivered_carrier_date DATETIME,
  order_delivered_customer_date DATETIME,
  order_estimated_delivery_date DATETIME
);

LOAD DATA LOCAL INFILE 'path/to/olist_orders_dataset.csv'
INTO TABLE orders
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(order_id, customer_id, order_status, @purchase, @approved, @carrier, @delivered, @estimated)
SET
  order_purchase_timestamp      = NULLIF(@purchase, ''),
  order_approved_at             = NULLIF(@approved, ''),
  order_delivered_carrier_date  = NULLIF(@carrier, ''),
  order_delivered_customer_date = NULLIF(@delivered, ''),
  order_estimated_delivery_date = NULLIF(TRIM(TRAILING '\r' FROM @estimated), '');

-- ---------------------------------------------------------------------
-- order_reviews  (expected: 99,224 rows)
-- No primary key: review_id is not unique in this dataset.
-- ESCAPED BY '' is required: some comments contain a backslash before
-- a quote, which otherwise merges two reviews into one row.
-- ---------------------------------------------------------------------
CREATE TABLE order_reviews (
  review_id VARCHAR(50),
  order_id VARCHAR(50),
  review_score INT,
  review_comment_title VARCHAR(255),
  review_comment_message TEXT,
  review_creation_date DATETIME,
  review_answer_timestamp DATETIME
);

LOAD DATA LOCAL INFILE 'path/to/olist_order_reviews_dataset.csv'
INTO TABLE order_reviews
FIELDS TERMINATED BY ',' ENCLOSED BY '"' ESCAPED BY ''
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(review_id, order_id, review_score, @title, @msg, @created, @answered)
SET
  review_comment_title    = NULLIF(@title, ''),
  review_comment_message  = NULLIF(@msg, ''),
  review_creation_date    = NULLIF(@created, ''),
  review_answer_timestamp = NULLIF(TRIM(TRAILING '\r' FROM @answered), '');

-- ---------------------------------------------------------------------
-- customers  (expected: 99,441 rows)
-- customer_id is created per order; customer_unique_id identifies the person.
-- Zip code stored as text to keep leading zeros.
-- ---------------------------------------------------------------------
CREATE TABLE customers (
  customer_id VARCHAR(50) PRIMARY KEY,
  customer_unique_id VARCHAR(50),
  customer_zip_code_prefix VARCHAR(10),
  customer_city VARCHAR(100),
  customer_state CHAR(2)
);

LOAD DATA LOCAL INFILE 'path/to/olist_customers_dataset.csv'
INTO TABLE customers
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(customer_id, customer_unique_id, customer_zip_code_prefix, customer_city, @state)
SET customer_state = TRIM(TRAILING '\r' FROM @state);

-- ---------------------------------------------------------------------
-- order_items  (expected: 112,650 rows, one row per item)
-- ---------------------------------------------------------------------
CREATE TABLE order_items (
  order_id VARCHAR(50),
  order_item_id INT,
  product_id VARCHAR(50),
  seller_id VARCHAR(50),
  shipping_limit_date DATETIME,
  price DECIMAL(10,2),
  freight_value DECIMAL(10,2)
);

LOAD DATA LOCAL INFILE 'path/to/olist_order_items_dataset.csv'
INTO TABLE order_items
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(order_id, order_item_id, product_id, seller_id, shipping_limit_date, price, @freight)
SET freight_value = TRIM(TRAILING '\r' FROM @freight);

-- ---------------------------------------------------------------------
-- sellers  (expected: 3,095 rows)
-- ---------------------------------------------------------------------
CREATE TABLE sellers (
  seller_id VARCHAR(50) PRIMARY KEY,
  seller_zip_code_prefix VARCHAR(10),
  seller_city VARCHAR(100),
  seller_state CHAR(2)
);

LOAD DATA LOCAL INFILE 'path/to/olist_sellers_dataset.csv'
INTO TABLE sellers
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(seller_id, seller_zip_code_prefix, seller_city, @state)
SET seller_state = TRIM(TRAILING '\r' FROM @state);

-- ---------------------------------------------------------------------
-- Row count validation
-- ---------------------------------------------------------------------
SELECT 'orders' AS table_name, COUNT(*) AS row_count FROM orders
UNION ALL SELECT 'order_reviews', COUNT(*) FROM order_reviews
UNION ALL SELECT 'customers',     COUNT(*) FROM customers
UNION ALL SELECT 'order_items',   COUNT(*) FROM order_items
UNION ALL SELECT 'sellers',       COUNT(*) FROM sellers;
