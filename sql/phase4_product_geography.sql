-- ============================================================================
-- Phase 4: Product & Geography Analysis
-- Olist Customer Lifecycle Analytics
-- Purpose: Answer product demand, category mix, and regional demand questions
-- Grain: Category-level and state-level delivered order facts
-- ============================================================================

-- Q1: Which product categories drive the strongest demand and revenue?
-- Business context: Assortment planning and category prioritization.
WITH category_revenue AS (
    SELECT
        COALESCE(p.category_english, 'unknown') AS category_english,
        COUNT(DISTINCT f.order_id) AS delivered_orders,
        COUNT(*) AS item_lines,
        ROUND(SUM(f.total_value), 2) AS revenue
    FROM v_order_fact f
    INNER JOIN v_products_clean p
        ON f.product_id = p.product_id
    WHERE f.is_delivered = 1
    GROUP BY 1
)
SELECT
    category_english,
    delivered_orders,
    item_lines,
    revenue,
    ROUND(revenue * 100.0 / SUM(revenue) OVER (), 2) AS revenue_share_pct,
    DENSE_RANK() OVER (ORDER BY revenue DESC) AS revenue_rank
FROM category_revenue
ORDER BY revenue DESC;


-- Q2: Where are the biggest gaps between customer demand and delivery performance?
-- Business context: Compare state-level demand, revenue, and late delivery burden.
WITH state_metrics AS (
    SELECT
        c.customer_state,
        COUNT(DISTINCT f.order_id) AS delivered_orders,
        ROUND(SUM(f.total_value), 2) AS revenue,
        ROUND(AVG(f.delivery_days), 2) AS avg_delivery_days,
        ROUND(AVG(f.is_late_delivery) * 100.0, 2) AS late_delivery_rate_pct
    FROM v_order_fact f
    INNER JOIN v_customers_clean c
        ON f.customer_id = c.customer_id
    WHERE f.is_delivered = 1
    GROUP BY 1
)
SELECT
    customer_state,
    delivered_orders,
    revenue,
    ROUND(revenue * 100.0 / SUM(revenue) OVER (), 2) AS revenue_share_pct,
    avg_delivery_days,
    late_delivery_rate_pct,
    ROW_NUMBER() OVER (ORDER BY revenue DESC) AS state_rank_by_revenue
FROM state_metrics
ORDER BY revenue DESC;