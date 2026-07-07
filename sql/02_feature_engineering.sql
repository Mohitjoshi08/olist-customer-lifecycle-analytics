-- ============================================================================
-- 02_feature_engineering.sql
-- Olist Customer Lifecycle Analytics
-- Purpose: Create analytical features for segmentation, churn, and CLV models
-- ============================================================================

-- --------------------------------------------------------------------------
-- RFM FEATURES
-- Recency, Frequency, Monetary at customer_unique_id level
-- Reference date: day after last order in dataset
-- --------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_rfm_features AS
WITH reference_date AS (
    SELECT MAX(order_purchase_timestamp) + INTERVAL '1 day' AS ref_date
    FROM v_orders_clean
    WHERE is_delivered = 1
),
customer_rfm AS (
    SELECT
        c.customer_unique_id,
        EXTRACT(DAY FROM r.ref_date - MAX(o.order_purchase_timestamp)) AS recency_days,
        COUNT(DISTINCT o.order_id) AS frequency,
        SUM(oi.total_value) AS monetary
    FROM v_customers_clean c
    INNER JOIN v_orders_clean o ON c.customer_id = o.customer_id
    INNER JOIN v_order_items_clean oi ON o.order_id = oi.order_id
    CROSS JOIN reference_date r
    WHERE o.is_delivered = 1
    GROUP BY c.customer_unique_id, r.ref_date
)
SELECT
    customer_unique_id,
    recency_days,
    frequency,
    ROUND(monetary, 2) AS monetary,
    NTILE(5) OVER (ORDER BY recency_days ASC)  AS recency_quintile,
    NTILE(5) OVER (ORDER BY frequency DESC)     AS frequency_quintile,
    NTILE(5) OVER (ORDER BY monetary DESC)       AS monetary_quintile
FROM customer_rfm;


-- --------------------------------------------------------------------------
-- RFM SEGMENT ASSIGNMENT
-- Maps quintile scores to named business segments
-- --------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_rfm_segments AS
SELECT
    customer_unique_id,
    recency_days,
    frequency,
    monetary,
    recency_quintile,
    frequency_quintile,
    monetary_quintile,
    CASE
        WHEN recency_quintile >= 4 AND frequency_quintile >= 4 AND monetary_quintile >= 4
            THEN 'Champions'
        WHEN recency_quintile >= 3 AND frequency_quintile >= 3
            THEN 'Loyal Customers'
        WHEN recency_quintile >= 4 AND frequency_quintile <= 2
            THEN 'Recent Customers'
        WHEN recency_quintile <= 2 AND frequency_quintile >= 4
            THEN 'At Risk'
        WHEN recency_quintile <= 2 AND frequency_quintile <= 2
            THEN 'Lost'
        ELSE 'Potential Loyalists'
    END AS rfm_segment
FROM v_rfm_features;


-- --------------------------------------------------------------------------
-- COHORT FEATURES
-- Assign each customer to acquisition cohort (first purchase month)
-- Calculate period number for retention analysis
-- --------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_cohort_features AS
WITH customer_first_order AS (
    SELECT
        c.customer_unique_id,
        DATE_TRUNC('month', MIN(o.order_purchase_timestamp)) AS cohort_month
    FROM v_customers_clean c
    INNER JOIN v_orders_clean o ON c.customer_id = o.customer_id
    WHERE o.is_delivered = 1
    GROUP BY c.customer_unique_id
),
customer_orders AS (
    SELECT
        c.customer_unique_id,
        DATE_TRUNC('month', o.order_purchase_timestamp) AS order_month
    FROM v_customers_clean c
    INNER JOIN v_orders_clean o ON c.customer_id = o.customer_id
    WHERE o.is_delivered = 1
)
SELECT
    cfo.customer_unique_id,
    cfo.cohort_month,
    co.order_month,
    EXTRACT(YEAR FROM AGE(co.order_month, cfo.cohort_month)) * 12
        + EXTRACT(MONTH FROM AGE(co.order_month, cfo.cohort_month)) AS period_number
FROM customer_first_order cfo
INNER JOIN customer_orders co ON cfo.customer_unique_id = co.customer_unique_id;


-- --------------------------------------------------------------------------
-- DELIVERY FEATURES
-- Compute delivery performance metrics per order
-- --------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_delivery_features AS
SELECT
    o.order_id,
    c.customer_unique_id,
    EXTRACT(DAY FROM o.order_delivered_customer_date - o.order_purchase_timestamp) AS delivery_days,
    EXTRACT(DAY FROM o.order_delivered_carrier_date - o.order_approved_at) AS carrier_handoff_days,
    EXTRACT(DAY FROM o.order_delivered_customer_date - o.order_delivered_carrier_date) AS transit_days,
    EXTRACT(DAY FROM o.order_estimated_delivery_date - o.order_purchase_timestamp) AS promised_days,
    CASE
        WHEN o.order_delivered_customer_date <= o.order_estimated_delivery_date THEN 1
        ELSE 0
    END AS is_on_time,
    CASE
        WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 1
        ELSE 0
    END AS is_late
FROM v_orders_clean o
INNER JOIN v_customers_clean c ON o.customer_id = c.customer_id
WHERE o.is_delivered = 1
  AND o.order_delivered_customer_date IS NOT NULL;


-- --------------------------------------------------------------------------
-- CHURN LABEL FEATURES
-- Binary churn flag: no purchase within 180 days of last order
-- --------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_churn_features AS
WITH last_purchase AS (
    SELECT
        c.customer_unique_id,
        MAX(o.order_purchase_timestamp) AS last_order_date,
        COUNT(DISTINCT o.order_id) AS total_orders,
        SUM(oi.total_value) AS total_spent,
        AVG(r.review_score) AS avg_review_score
    FROM v_customers_clean c
    INNER JOIN v_orders_clean o ON c.customer_id = o.customer_id
    INNER JOIN v_order_items_clean oi ON o.order_id = oi.order_id
    LEFT JOIN v_reviews_clean r ON o.order_id = r.order_id
    WHERE o.is_delivered = 1
    GROUP BY c.customer_unique_id
),
reference AS (
    SELECT MAX(order_purchase_timestamp) + INTERVAL '1 day' AS ref_date
    FROM v_orders_clean
)
SELECT
    lp.customer_unique_id,
    lp.last_order_date,
    lp.total_orders,
    lp.total_spent,
    lp.avg_review_score,
    EXTRACT(DAY FROM r.ref_date - lp.last_order_date) AS days_since_last_order,
    CASE
        WHEN EXTRACT(DAY FROM r.ref_date - lp.last_order_date) > 180 THEN 1
        ELSE 0
    END AS is_churned
FROM last_purchase lp
CROSS JOIN reference r;


-- --------------------------------------------------------------------------
-- PAYMENT FEATURES
-- Aggregate payment behavior per order
-- --------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_payment_features AS
SELECT
    order_id,
    MAX(CASE WHEN payment_type = 'credit_card' THEN 1 ELSE 0 END) AS used_credit_card,
    MAX(CASE WHEN payment_type = 'boleto' THEN 1 ELSE 0 END)       AS used_boleto,
    MAX(payment_installments) AS max_installments,
    SUM(payment_value) AS total_payment_value
FROM payments
GROUP BY order_id;
