-- ============================================================================
-- Phase 4: Retention & Customer Lifecycle Analysis
-- Olist Customer Lifecycle Analytics
-- Purpose: Answer reorder, cohort, CLV, and churn-risk questions
-- Grain: Customer-level lifecycle facts derived from delivered orders
-- ============================================================================

-- Q1: What is the first-to-second purchase conversion rate and time to reorder?
-- Business context: Identify the biggest retention bottleneck after the first order.
WITH customer_orders AS (
    SELECT
        c.customer_unique_id,
        o.order_id,
        o.order_purchase_timestamp,
        ROW_NUMBER() OVER (
            PARTITION BY c.customer_unique_id
            ORDER BY o.order_purchase_timestamp, o.order_id
        ) AS order_rank
    FROM v_customers_clean c
    INNER JOIN v_orders_clean o
        ON c.customer_id = o.customer_id
    WHERE o.is_delivered = 1
),
first_second AS (
    SELECT
        customer_unique_id,
        MAX(CASE WHEN order_rank = 1 THEN order_purchase_timestamp END) AS first_order_date,
        MAX(CASE WHEN order_rank = 2 THEN order_purchase_timestamp END) AS second_order_date,
        COUNT(*) AS delivered_orders
    FROM customer_orders
    GROUP BY 1
)
SELECT
    COUNT(*) AS customers,
    SUM(CASE WHEN delivered_orders > 1 THEN 1 ELSE 0 END) AS repeat_customers,
    ROUND(SUM(CASE WHEN delivered_orders > 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS repeat_customer_rate_pct,
    ROUND(AVG(EXTRACT(EPOCH FROM (second_order_date - first_order_date)) / 86400.0), 1) AS avg_days_to_second_order,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (
        ORDER BY EXTRACT(EPOCH FROM (second_order_date - first_order_date)) / 86400.0
    ), 1) AS median_days_to_second_order
FROM first_second;


-- Q2: How do cohort retention curves behave by acquisition month?
-- Business context: Show how quickly cohorts decay after acquisition.
WITH first_purchase AS (
    SELECT
        c.customer_unique_id,
        DATE_TRUNC('month', MIN(o.order_purchase_timestamp)) AS cohort_month
    FROM v_customers_clean c
    INNER JOIN v_orders_clean o
        ON c.customer_id = o.customer_id
    WHERE o.is_delivered = 1
    GROUP BY 1
),
cohort_periods AS (
    SELECT
        fp.customer_unique_id,
        fp.cohort_month,
        DATE_TRUNC('month', o.order_purchase_timestamp) AS order_month,
        (EXTRACT(YEAR FROM age(DATE_TRUNC('month', o.order_purchase_timestamp), fp.cohort_month)) * 12
        + EXTRACT(MONTH FROM age(DATE_TRUNC('month', o.order_purchase_timestamp), fp.cohort_month)))::int AS period_number
    FROM first_purchase fp
    INNER JOIN v_customers_clean c
        ON fp.customer_unique_id = c.customer_unique_id
    INNER JOIN v_orders_clean o
        ON c.customer_id = o.customer_id
    WHERE o.is_delivered = 1
),
cohort_sizes AS (
    SELECT cohort_month, COUNT(DISTINCT customer_unique_id) AS cohort_size
    FROM cohort_periods
    WHERE period_number = 0
    GROUP BY 1
)
SELECT
    cp.cohort_month::date,
    cp.period_number,
    COUNT(DISTINCT cp.customer_unique_id) AS active_customers,
    cs.cohort_size,
    ROUND(COUNT(DISTINCT cp.customer_unique_id) * 100.0 / cs.cohort_size, 2) AS retention_pct
FROM cohort_periods cp
INNER JOIN cohort_sizes cs
    ON cp.cohort_month = cs.cohort_month
GROUP BY 1, 2, 4
ORDER BY 1, 2;


-- Q3: Which customer segments generate the highest historical CLV?
-- Business context: Build an RFM-style view of customer value.
WITH customer_lifecycle AS (
    SELECT
        c.customer_unique_id,
        c.customer_state,
        COUNT(DISTINCT o.order_id) AS order_count,
        ROUND(SUM(f.total_value), 2) AS lifetime_value,
        MAX(o.order_purchase_timestamp) AS last_order_date,
        MIN(o.order_purchase_timestamp) AS first_order_date
    FROM v_customers_clean c
    INNER JOIN v_orders_clean o
        ON c.customer_id = o.customer_id
    INNER JOIN v_order_items_clean f
        ON o.order_id = f.order_id
    WHERE o.is_delivered = 1
    GROUP BY 1, 2
),
rfm_scored AS (
    SELECT
        customer_unique_id,
        customer_state,
        order_count,
        lifetime_value,
        EXTRACT(EPOCH FROM ((SELECT MAX(order_purchase_timestamp) FROM v_orders_clean) + INTERVAL '1 day' - last_order_date)) / 86400.0 AS recency_days,
        NTILE(5) OVER (ORDER BY EXTRACT(EPOCH FROM ((SELECT MAX(order_purchase_timestamp) FROM v_orders_clean) + INTERVAL '1 day' - last_order_date)) / 86400.0 ASC) AS recency_score,
        NTILE(5) OVER (ORDER BY order_count ASC) AS frequency_score,
        NTILE(5) OVER (ORDER BY lifetime_value ASC) AS monetary_score
    FROM customer_lifecycle
)
SELECT
    CASE
        WHEN recency_score >= 4 AND frequency_score >= 4 AND monetary_score >= 4 THEN 'Champions'
        WHEN recency_score >= 3 AND frequency_score >= 3 THEN 'Loyal Customers'
        WHEN recency_score >= 4 AND frequency_score <= 2 THEN 'Recent Customers'
        WHEN recency_score <= 2 AND frequency_score >= 4 THEN 'At Risk'
        WHEN recency_score <= 2 AND frequency_score <= 2 THEN 'Lost'
        ELSE 'Potential Loyalists'
    END AS rfm_segment,
    COUNT(*) AS customers,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS customer_share_pct,
    ROUND(SUM(lifetime_value), 2) AS segment_revenue,
    ROUND(SUM(lifetime_value) * 100.0 / SUM(SUM(lifetime_value)) OVER (), 2) AS revenue_share_pct,
    ROUND(AVG(lifetime_value), 2) AS avg_clv,
    ROUND(AVG(order_count), 2) AS avg_orders_per_customer
FROM rfm_scored
GROUP BY 1
ORDER BY segment_revenue DESC;


-- Q4: Which customers are at risk of churn based on recency, frequency, and monetary value?
-- Business context: Define a practical churn-risk funnel for marketing and CRM.
WITH customer_lifecycle AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS order_count,
        ROUND(SUM(f.total_value), 2) AS lifetime_value,
        MAX(o.order_purchase_timestamp) AS last_order_date
    FROM v_customers_clean c
    INNER JOIN v_orders_clean o
        ON c.customer_id = o.customer_id
    INNER JOIN v_order_items_clean f
        ON o.order_id = f.order_id
    WHERE o.is_delivered = 1
    GROUP BY 1
),
churn_band AS (
    SELECT
        customer_unique_id,
        order_count,
        lifetime_value,
        EXTRACT(EPOCH FROM ((SELECT MAX(order_purchase_timestamp) FROM v_orders_clean) + INTERVAL '1 day' - last_order_date)) / 86400.0 AS recency_days,
        CASE
            WHEN EXTRACT(EPOCH FROM ((SELECT MAX(order_purchase_timestamp) FROM v_orders_clean) + INTERVAL '1 day' - last_order_date)) / 86400.0 > 180 THEN 'Churned'
            WHEN EXTRACT(EPOCH FROM ((SELECT MAX(order_purchase_timestamp) FROM v_orders_clean) + INTERVAL '1 day' - last_order_date)) / 86400.0 BETWEEN 91 AND 180 THEN 'At Risk'
            WHEN EXTRACT(EPOCH FROM ((SELECT MAX(order_purchase_timestamp) FROM v_orders_clean) + INTERVAL '1 day' - last_order_date)) / 86400.0 BETWEEN 31 AND 90 THEN 'Warm'
            ELSE 'Active'
        END AS churn_status
    FROM customer_lifecycle
)
SELECT
    churn_status,
    COUNT(*) AS customers,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS customer_share_pct,
    ROUND(SUM(lifetime_value), 2) AS revenue_at_status,
    ROUND(AVG(recency_days), 1) AS avg_recency_days,
    ROUND(AVG(order_count), 2) AS avg_orders_per_customer
FROM churn_band
GROUP BY 1
ORDER BY customers DESC;