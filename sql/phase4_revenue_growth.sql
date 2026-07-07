-- ============================================================================
-- Phase 4: Revenue & Growth Analysis
-- Olist Customer Lifecycle Analytics
-- Purpose: Answer revenue, AOV, category concentration, and repeat-share questions
-- Grain: Delivered order-item facts aggregated to month, category, and customer level
-- ============================================================================

-- Q1: How are monthly GMV and AOV trending?
-- Business context: Executive revenue tracking and seasonality detection.
WITH monthly_revenue AS (
    SELECT
        DATE_TRUNC('month', o.order_purchase_timestamp)::date AS purchase_month,
        COUNT(DISTINCT o.order_id) AS delivered_orders,
        ROUND(SUM(f.total_value), 2) AS gmv,
        ROUND(SUM(f.total_value) / NULLIF(COUNT(DISTINCT o.order_id), 0), 2) AS aov
    FROM v_orders_clean o
    INNER JOIN v_order_items_clean f
        ON o.order_id = f.order_id
    WHERE o.is_delivered = 1
    GROUP BY 1
)
SELECT
    purchase_month,
    delivered_orders,
    gmv,
    aov,
    ROUND((gmv - LAG(gmv) OVER (ORDER BY purchase_month)) * 100.0 / NULLIF(LAG(gmv) OVER (ORDER BY purchase_month), 0), 2) AS mom_gmv_growth_pct
FROM monthly_revenue
ORDER BY purchase_month;


-- Q2: How does AOV vary by month and product category?
-- Business context: Identify monetization levers by time and category mix.
WITH category_monthly_aov AS (
    SELECT
        DATE_TRUNC('month', o.order_purchase_timestamp)::date AS purchase_month,
        COALESCE(p.category_english, 'unknown') AS category_english,
        COUNT(DISTINCT o.order_id) AS delivered_orders,
        ROUND(SUM(f.total_value), 2) AS gmv,
        ROUND(SUM(f.total_value) / NULLIF(COUNT(DISTINCT o.order_id), 0), 2) AS aov
    FROM v_orders_clean o
    INNER JOIN v_order_items_clean f
        ON o.order_id = f.order_id
    INNER JOIN v_products_clean p
        ON f.product_id = p.product_id
    WHERE o.is_delivered = 1
    GROUP BY 1, 2
)
SELECT
    purchase_month,
    category_english,
    delivered_orders,
    gmv,
    aov,
    ROW_NUMBER() OVER (PARTITION BY purchase_month ORDER BY gmv DESC) AS category_rank_in_month
FROM category_monthly_aov
WHERE delivered_orders >= 25
ORDER BY purchase_month, gmv DESC;


-- Q3: Which categories drive revenue and how concentrated is the mix?
-- Business context: Category portfolio management and assortment strategy.
WITH category_revenue AS (
    SELECT
        COALESCE(p.category_english, 'unknown') AS category_english,
        COUNT(DISTINCT o.order_id) AS delivered_orders,
        ROUND(SUM(f.total_value), 2) AS revenue
    FROM v_orders_clean o
    INNER JOIN v_order_items_clean f
        ON o.order_id = f.order_id
    INNER JOIN v_products_clean p
        ON f.product_id = p.product_id
    WHERE o.is_delivered = 1
    GROUP BY 1
)
SELECT
    category_english,
    delivered_orders,
    revenue,
    ROUND(revenue * 100.0 / SUM(revenue) OVER (), 2) AS revenue_share_pct,
    ROUND(SUM(revenue) OVER (ORDER BY revenue DESC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) * 100.0 / SUM(revenue) OVER (), 2) AS cumulative_share_pct,
    DENSE_RANK() OVER (ORDER BY revenue DESC) AS revenue_rank
FROM category_revenue
ORDER BY revenue DESC;


-- Q4: What share of revenue comes from repeat customers versus first-time customers?
-- Business context: Measure how much of GMV is still first-order driven.
WITH customer_order_counts AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS total_orders
    FROM v_customers_clean c
    INNER JOIN v_orders_clean o
        ON c.customer_id = o.customer_id
    GROUP BY 1
),
customer_revenue AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS order_count,
        ROUND(SUM(f.total_value), 2) AS lifetime_revenue
    FROM v_customers_clean c
    INNER JOIN v_orders_clean o
        ON c.customer_id = o.customer_id
    INNER JOIN v_order_items_clean f
        ON o.order_id = f.order_id
    WHERE o.is_delivered = 1
    GROUP BY 1
)
SELECT
    CASE WHEN cro.total_orders = 1 THEN 'First-time customers' ELSE 'Repeat customers' END AS customer_type,
    COUNT(*) AS customers,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS customer_share_pct,
    ROUND(SUM(cr.lifetime_revenue), 2) AS revenue,
    ROUND(SUM(cr.lifetime_revenue) * 100.0 / SUM(SUM(cr.lifetime_revenue)) OVER (), 2) AS revenue_share_pct,
    ROUND(AVG(cr.lifetime_revenue), 2) AS avg_customer_revenue
FROM customer_order_counts cro
INNER JOIN customer_revenue cr
    ON cro.customer_unique_id = cr.customer_unique_id
GROUP BY 1
ORDER BY revenue DESC;