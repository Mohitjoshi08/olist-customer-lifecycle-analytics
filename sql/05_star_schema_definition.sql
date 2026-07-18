-- Star Schema and Data Warehouse Layer Definition for Olist E-commerce

-- Create Staging view for deduplicated orders and items
CREATE OR REPLACE VIEW olist.stg_order_items AS
SELECT
  oi.order_id,
  oi.order_item_id,
  oi.product_id,
  oi.seller_id,
  oi.price,
  oi.freight_value,
  (oi.price + oi.freight_value) AS item_total_value
FROM olist.olist_order_items_dataset oi;


-- Dimension: Customers
CREATE OR REPLACE TABLE olist.DimCustomer AS
SELECT
  FARM_FINGERPRINT(customer_unique_id) AS customer_key,
  customer_unique_id AS customer_id,
  customer_city AS city,
  customer_state AS state
FROM olist.olist_customers_dataset
GROUP BY customer_unique_id, customer_city, customer_state;


-- Dimension: Products
CREATE OR REPLACE TABLE olist.DimProduct AS
SELECT
  FARM_FINGERPRINT(p.product_id) AS product_key,
  p.product_id,
  COALESCE(t.product_category_name_english, p.product_category_name, 'unknown') AS category_name,
  p.product_weight_g / 1000.0 AS weight_kg
FROM olist.olist_products_dataset p
LEFT JOIN olist.product_category_name_translation t
  ON p.product_category_name = t.product_category_name;


-- Dimension: Sellers
CREATE OR REPLACE TABLE olist.DimSeller AS
SELECT
  FARM_FINGERPRINT(seller_id) AS seller_key,
  seller_id,
  seller_city AS city,
  seller_state AS state
FROM olist.olist_sellers_dataset;


-- Dimension: Date Calendar
CREATE OR REPLACE TABLE olist.DimDate AS
SELECT
  CAST(FORMAT_DATE('%Y%m%d', d) AS INT64) AS date_key,
  d AS date,
  EXTRACT(YEAR FROM d) AS year,
  EXTRACT(MONTH FROM d) AS month,
  FORMAT_DATE('%B', d) AS month_name,
  EXTRACT(DAY FROM d) AS day,
  EXTRACT(DAYOFWEEK FROM d) AS day_of_week
FROM UNNEST(GENERATE_DATE_ARRAY('2016-09-01', '2018-10-31', INTERVAL 1 DAY)) AS d;


-- Fact Table: Sales Transactions
CREATE OR REPLACE TABLE olist.FactSales AS
SELECT
  -- Dimension Surrogate Keys
  FARM_FINGERPRINT(c.customer_unique_id) AS customer_key,
  FARM_FINGERPRINT(oi.product_id) AS product_key,
  FARM_FINGERPRINT(oi.seller_id) AS seller_key,
  CAST(FORMAT_TIMESTAMP('%Y%m%d', o.order_purchase_timestamp) AS INT64) AS date_key,
  
  -- Business Keys
  o.order_id,
  oi.order_item_id,
  
  -- Metrics/Measures
  oi.price AS item_price,
  oi.freight_value AS freight_cost,
  (oi.price + oi.freight_value) AS total_item_value,
  
  -- Logistics and Review Metrics
  DATE_DIFF(DATE(o.order_delivered_customer_date), DATE(o.order_purchase_timestamp), DAY) AS delivery_days,
  IF(o.order_delivered_customer_date > o.order_estimated_delivery_date, 1, 0) AS is_late,
  r.review_score
FROM olist.olist_orders_dataset o
JOIN olist.olist_customers_dataset c
  ON o.customer_id = c.customer_id
JOIN olist.stg_order_items oi
  ON o.order_id = oi.order_id
LEFT JOIN (
  -- Aggregate review score to handle order level reviews
  SELECT order_id, AVG(review_score) AS review_score
  FROM olist.olist_order_reviews_dataset
  GROUP BY order_id
) r ON o.order_id = r.order_id
WHERE o.order_status = 'delivered';
