-- ============================================================================
-- Phase 4: Operations & Delivery Analysis
-- Olist Customer Lifecycle Analytics
-- Purpose: Answer on-time delivery, review impact, and delay concentration questions
-- Grain: Delivered order and order-item facts aggregated by month and geography
-- ============================================================================

-- Q1: What is the on-time delivery rate over time?
-- Business context: Track logistics reliability by month.
WITH delivery_monthly AS (
    SELECT
        DATE_TRUNC('month', order_purchase_timestamp)::date AS purchase_month,
        COUNT(*) AS delivered_orders,
        SUM(CASE WHEN order_delivered_customer_date <= order_estimated_delivery_date THEN 1 ELSE 0 END) AS on_time_orders,
        SUM(CASE WHEN order_delivered_customer_date > order_estimated_delivery_date THEN 1 ELSE 0 END) AS late_orders,
        ROUND(AVG(EXTRACT(EPOCH FROM (order_delivered_customer_date - order_purchase_timestamp)) / 86400.0), 2) AS avg_delivery_days
    FROM v_orders_clean
    WHERE is_delivered = 1
    GROUP BY 1
)
SELECT
    purchase_month,
    delivered_orders,
    on_time_orders,
    late_orders,
    ROUND(on_time_orders * 100.0 / NULLIF(delivered_orders, 0), 2) AS on_time_rate_pct,
    avg_delivery_days
FROM delivery_monthly
ORDER BY purchase_month;


-- Q2: How much does late delivery reduce review scores?
-- Business context: Quantify the operational cost of missed SLAs.
WITH review_delivery AS (
    SELECT
        r.order_id,
        r.review_score,
        CASE WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 'Late' ELSE 'On Time' END AS delivery_status
    FROM v_reviews_clean r
    INNER JOIN v_orders_clean o
        ON r.order_id = o.order_id
    WHERE o.is_delivered = 1
      AND o.order_delivered_customer_date IS NOT NULL
      AND o.order_estimated_delivery_date IS NOT NULL
)
SELECT
    delivery_status,
    COUNT(*) AS reviews,
    ROUND(AVG(review_score), 2) AS avg_review_score,
    SUM(CASE WHEN review_score <= 2 THEN 1 ELSE 0 END) AS detractor_reviews,
    ROUND(SUM(CASE WHEN review_score <= 2 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS detractor_rate_pct
FROM review_delivery
GROUP BY 1
ORDER BY avg_review_score ASC;


-- Q3: Which states and shipping lanes have the highest late delivery rates?
-- Business context: Find the regional pockets where service problems are concentrated.
WITH state_delivery AS (
    SELECT
        c.customer_state,
        COUNT(*) AS delivered_orders,
        SUM(CASE WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 1 ELSE 0 END) AS late_orders,
        ROUND(AVG(EXTRACT(EPOCH FROM (o.order_delivered_customer_date - o.order_purchase_timestamp)) / 86400.0), 2) AS avg_delivery_days
    FROM v_orders_clean o
    INNER JOIN v_customers_clean c
        ON o.customer_id = c.customer_id
    WHERE o.is_delivered = 1
      AND o.order_delivered_customer_date IS NOT NULL
      AND o.order_estimated_delivery_date IS NOT NULL
    GROUP BY 1
)
SELECT
    customer_state,
    delivered_orders,
    late_orders,
    ROUND(late_orders * 100.0 / NULLIF(delivered_orders, 0), 2) AS late_delivery_rate_pct,
    avg_delivery_days
FROM state_delivery
ORDER BY late_delivery_rate_pct DESC, delivered_orders DESC;