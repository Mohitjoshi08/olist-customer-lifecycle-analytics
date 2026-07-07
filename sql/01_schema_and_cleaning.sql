-- ============================================================================
-- 01_schema_and_cleaning.sql
-- Olist Customer Lifecycle Analytics
-- Purpose: Create cleaned tables and views with data quality rules applied
-- Database: Compatible with PostgreSQL / MySQL / SQLite
-- ============================================================================

-- --------------------------------------------------------------------------
-- RAW TABLE IMPORTS (assumes CSV import into staging tables)
-- Tables: customers, orders, order_items, products, sellers,
--         payments, reviews, geolocation, category_translation
-- --------------------------------------------------------------------------

-- --------------------------------------------------------------------------
-- CLEANED CUSTOMERS VIEW
-- Rule: Use customer_unique_id as the true customer identifier
-- Rule: Standardize city names to lowercase
-- --------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_customers_clean AS
SELECT
    customer_id,
    customer_unique_id,
    CAST(customer_zip_code_prefix AS VARCHAR(5)) AS customer_zip_code_prefix,
    LOWER(TRIM(customer_city)) AS customer_city,
    UPPER(TRIM(customer_state)) AS customer_state
FROM customers;


-- --------------------------------------------------------------------------
-- CLEANED ORDERS VIEW
-- Rule: Parse timestamps; flag delivered orders for revenue analysis
-- Rule: Exclude structurally invalid date sequences
-- --------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_orders_clean AS
SELECT
    order_id,
    customer_id,
    order_status,
    CAST(order_purchase_timestamp AS TIMESTAMP)      AS order_purchase_timestamp,
    CAST(order_approved_at AS TIMESTAMP)             AS order_approved_at,
    CAST(order_delivered_carrier_date AS TIMESTAMP)  AS order_delivered_carrier_date,
    CAST(order_delivered_customer_date AS TIMESTAMP) AS order_delivered_customer_date,
    CAST(order_estimated_delivery_date AS TIMESTAMP) AS order_estimated_delivery_date,
    CASE WHEN order_status = 'delivered' THEN 1 ELSE 0 END AS is_delivered,
    DATE_TRUNC('month', CAST(order_purchase_timestamp AS TIMESTAMP)) AS purchase_month,
    EXTRACT(YEAR FROM CAST(order_purchase_timestamp AS TIMESTAMP))   AS purchase_year
FROM orders
WHERE CAST(order_purchase_timestamp AS TIMESTAMP) IS NOT NULL;


-- --------------------------------------------------------------------------
-- CLEANED ORDER ITEMS VIEW
-- Rule: Compute total_value = price + freight_value
-- --------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_order_items_clean AS
SELECT
    oi.order_id,
    oi.order_item_id,
    oi.product_id,
    oi.seller_id,
    CAST(oi.shipping_limit_date AS TIMESTAMP) AS shipping_limit_date,
    oi.price,
    oi.freight_value,
    ROUND(oi.price + oi.freight_value, 2) AS total_value
FROM order_items oi;


-- --------------------------------------------------------------------------
-- CLEANED PRODUCTS VIEW
-- Rule: COALESCE missing categories to 'unknown'
-- Rule: Join English category translation
-- --------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_products_clean AS
SELECT
    p.product_id,
    COALESCE(p.product_category_name, 'unknown') AS product_category_name,
    COALESCE(t.product_category_name_english, 'unknown') AS category_english,
    p.product_name_lenght,
    p.product_description_lenght,
    p.product_photos_qty,
    p.product_weight_g,
    p.product_length_cm,
    p.product_height_cm,
    p.product_width_cm
FROM products p
LEFT JOIN category_translation t
    ON p.product_category_name = t.product_category_name;


-- --------------------------------------------------------------------------
-- CLEANED REVIEWS VIEW
-- Rule: Validate review_score between 1 and 5
-- Rule: Flag detractors (score <= 2) and promoters (score >= 4)
-- --------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_reviews_clean AS
SELECT
    review_id,
    order_id,
    review_score,
    review_comment_title,
    review_comment_message,
    CAST(review_creation_date AS TIMESTAMP)    AS review_creation_date,
    CAST(review_answer_timestamp AS TIMESTAMP) AS review_answer_timestamp,
    CASE WHEN review_score <= 2 THEN 1 ELSE 0 END AS is_detractor,
    CASE WHEN review_score >= 4 THEN 1 ELSE 0 END AS is_promoter
FROM reviews
WHERE review_score BETWEEN 1 AND 5;


-- --------------------------------------------------------------------------
-- CLEANED GEOLOCATION VIEW
-- Rule: Aggregate to zip prefix level (handle duplicates)
-- Rule: Standardize city names
-- --------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_geolocation_clean AS
SELECT
    geolocation_zip_code_prefix,
    AVG(geolocation_lat) AS geolocation_lat,
    AVG(geolocation_lng) AS geolocation_lng,
    LOWER(TRIM(MODE() WITHIN GROUP (ORDER BY geolocation_city))) AS geolocation_city,
    UPPER(TRIM(geolocation_state)) AS geolocation_state
FROM geolocation
GROUP BY geolocation_zip_code_prefix, geolocation_state;


-- --------------------------------------------------------------------------
-- MASTER ORDER FACT TABLE
-- Combines orders + items + customer + product + seller + review
-- Grain: one row per order_item
-- --------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_order_fact AS
SELECT
    oi.order_id,
    oi.order_item_id,
    o.order_status,
    o.order_purchase_timestamp,
    o.purchase_month,
    o.purchase_year,
    o.is_delivered,
    c.customer_unique_id,
    c.customer_state,
    c.customer_city,
    p.product_id,
    p.product_category_name,
    p.category_english,
    s.seller_id,
    s.seller_state,
    oi.price,
    oi.freight_value,
    oi.total_value,
    r.review_score,
    r.is_detractor,
    r.is_promoter,
    CASE
        WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 1
        ELSE 0
    END AS is_late_delivery,
    EXTRACT(DAY FROM o.order_delivered_customer_date - o.order_purchase_timestamp) AS delivery_days
FROM v_order_items_clean oi
INNER JOIN v_orders_clean o          ON oi.order_id = o.order_id
INNER JOIN v_customers_clean c       ON o.customer_id = c.customer_id
INNER JOIN v_products_clean p        ON oi.product_id = p.product_id
INNER JOIN sellers s                 ON oi.seller_id = s.seller_id
LEFT JOIN v_reviews_clean r          ON oi.order_id = r.order_id
WHERE o.is_delivered = 1;


-- --------------------------------------------------------------------------
-- CUSTOMER-LEVEL SUMMARY VIEW
-- Grain: one row per customer_unique_id
-- --------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_customer_summary AS
SELECT
    c.customer_unique_id,
    c.customer_state,
    c.customer_city,
    COUNT(DISTINCT o.order_id) AS total_orders,
    MIN(o.order_purchase_timestamp) AS first_order_date,
    MAX(o.order_purchase_timestamp) AS last_order_date,
    SUM(f.total_value) AS lifetime_value,
    AVG(f.total_value) AS avg_order_value,
    AVG(r.review_score) AS avg_review_score
FROM v_customers_clean c
INNER JOIN v_orders_clean o ON c.customer_id = o.customer_id
INNER JOIN (
    SELECT order_id, SUM(total_value) AS total_value
    FROM v_order_items_clean
    GROUP BY order_id
) f ON o.order_id = f.order_id
LEFT JOIN v_reviews_clean r ON o.order_id = r.order_id
WHERE o.is_delivered = 1
GROUP BY c.customer_unique_id, c.customer_state, c.customer_city;
