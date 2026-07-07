-- ============================================================================
-- Phase 4: Seller & Marketplace Quality Analysis
-- Olist Customer Lifecycle Analytics
-- Purpose: Answer seller concentration and seller performance questions
-- Grain: Seller-level revenue and quality metrics
-- ============================================================================

-- Q1: How concentrated is revenue among the top sellers?
-- Business context: Measure dependence on a small set of marketplace partners.
WITH seller_revenue AS (
    SELECT
        f.seller_id,
        COUNT(DISTINCT f.order_id) AS delivered_orders,
        ROUND(SUM(f.total_value), 2) AS revenue
    FROM v_order_fact f
    WHERE f.is_delivered = 1
    GROUP BY 1
)
SELECT
    seller_id,
    delivered_orders,
    revenue,
    ROUND(revenue * 100.0 / SUM(revenue) OVER (), 2) AS revenue_share_pct,
    ROUND(SUM(revenue) OVER (ORDER BY revenue DESC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) * 100.0 / SUM(revenue) OVER (), 2) AS cumulative_revenue_share_pct,
    DENSE_RANK() OVER (ORDER BY revenue DESC) AS revenue_rank
FROM seller_revenue
ORDER BY revenue DESC;


-- Q2: Which sellers consistently deliver strong revenue, review, and delivery quality?
-- Business context: Build a practical seller scorecard for account management.
WITH seller_scorecard AS (
    SELECT
        f.seller_id,
        COUNT(DISTINCT f.order_id) AS delivered_orders,
        ROUND(SUM(f.total_value), 2) AS revenue,
        ROUND(AVG(f.review_score), 2) AS avg_review_score,
        ROUND(AVG(f.delivery_days), 2) AS avg_delivery_days,
        ROUND(AVG(f.is_late_delivery) * 100.0, 2) AS late_delivery_rate_pct
    FROM v_order_fact f
    WHERE f.is_delivered = 1
    GROUP BY 1
)
SELECT
    seller_id,
    delivered_orders,
    revenue,
    avg_review_score,
    avg_delivery_days,
    late_delivery_rate_pct,
    ROW_NUMBER() OVER (ORDER BY revenue DESC) AS seller_rank_by_revenue
FROM seller_scorecard
ORDER BY revenue DESC
LIMIT 50;