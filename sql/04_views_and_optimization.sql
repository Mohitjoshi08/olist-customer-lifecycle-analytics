-- ============================================================================
-- 04_views_and_optimization.sql
-- Olist Customer Lifecycle Analytics
-- Purpose: Production-ready views and performance optimization
-- ============================================================================

-- --------------------------------------------------------------------------
-- EXECUTIVE KPI VIEW
-- Single-row snapshot of key business metrics
-- --------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_kpi_snapshot AS
SELECT
    (SELECT COUNT(*) FROM v_orders_clean WHERE is_delivered = 1) AS delivered_orders,
    (SELECT COUNT(DISTINCT customer_unique_id) FROM v_customer_summary) AS unique_customers,
    (SELECT ROUND(SUM(total_value), 2) FROM v_order_items_clean oi
     INNER JOIN v_orders_clean o ON oi.order_id = o.order_id WHERE o.is_delivered = 1) AS total_gmv,
    (SELECT ROUND(AVG(order_total), 2) FROM (
        SELECT SUM(oi.total_value) AS order_total
        FROM v_order_items_clean oi
        INNER JOIN v_orders_clean o ON oi.order_id = o.order_id
        WHERE o.is_delivered = 1 GROUP BY oi.order_id
    ) t) AS avg_order_value,
    (SELECT ROUND(AVG(review_score), 2) FROM v_reviews_clean) AS avg_review_score,
    (SELECT ROUND(SUM(is_late) * 100.0 / COUNT(*), 2) FROM v_delivery_features) AS late_delivery_pct,
    (SELECT ROUND(SUM(is_churned) * 100.0 / COUNT(*), 2) FROM v_churn_features) AS churn_rate_pct;


-- --------------------------------------------------------------------------
-- MONTHLY REVENUE VIEW (for Power BI / dashboards)
-- --------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_monthly_revenue AS
SELECT
    o.purchase_month,
    o.purchase_year,
    COUNT(DISTINCT o.order_id) AS order_count,
    COUNT(DISTINCT c.customer_unique_id) AS unique_customers,
    ROUND(SUM(oi.price), 2) AS product_revenue,
    ROUND(SUM(oi.freight_value), 2) AS freight_revenue,
    ROUND(SUM(oi.total_value), 2) AS gmv
FROM v_orders_clean o
INNER JOIN v_order_items_clean oi ON o.order_id = oi.order_id
INNER JOIN v_customers_clean c ON o.customer_id = c.customer_id
WHERE o.is_delivered = 1
GROUP BY o.purchase_month, o.purchase_year
ORDER BY o.purchase_month;


-- --------------------------------------------------------------------------
-- COHORT RETENTION VIEW (for heatmap visualization)
-- --------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_cohort_retention AS
WITH cohort_size AS (
    SELECT cohort_month, COUNT(DISTINCT customer_unique_id) AS n
    FROM v_cohort_features WHERE period_number = 0
    GROUP BY cohort_month
)
SELECT
    cf.cohort_month,
    cf.period_number,
    COUNT(DISTINCT cf.customer_unique_id) AS active_customers,
    cs.n AS cohort_size,
    ROUND(COUNT(DISTINCT cf.customer_unique_id) * 100.0 / cs.n, 2) AS retention_rate
FROM v_cohort_features cf
JOIN cohort_size cs ON cf.cohort_month = cs.cohort_month
GROUP BY cf.cohort_month, cf.period_number, cs.n;


-- --------------------------------------------------------------------------
-- INDEX RECOMMENDATIONS
-- Apply these indexes for query performance on large datasets
-- --------------------------------------------------------------------------

-- Primary lookup indexes
-- CREATE INDEX idx_orders_customer_id ON orders(customer_id);
-- CREATE INDEX idx_orders_status ON orders(order_status);
-- CREATE INDEX idx_orders_purchase_ts ON orders(order_purchase_timestamp);
-- CREATE INDEX idx_order_items_order_id ON order_items(order_id);
-- CREATE INDEX idx_order_items_product_id ON order_items(product_id);
-- CREATE INDEX idx_order_items_seller_id ON order_items(seller_id);
-- CREATE INDEX idx_payments_order_id ON payments(order_id);
-- CREATE INDEX idx_reviews_order_id ON reviews(order_id);
-- CREATE INDEX idx_customers_unique_id ON customers(customer_unique_id);
-- CREATE INDEX idx_products_category ON products(product_category_name);

-- Composite indexes for common join patterns
-- CREATE INDEX idx_orders_status_purchase ON orders(order_status, order_purchase_timestamp);
-- CREATE INDEX idx_items_order_product ON order_items(order_id, product_id);

-- --------------------------------------------------------------------------
-- MATERIALIZED VIEW RECOMMENDATION (PostgreSQL)
-- For production, materialize the order fact table for dashboard performance
-- --------------------------------------------------------------------------
-- CREATE MATERIALIZED VIEW mv_order_fact AS
-- SELECT * FROM v_order_fact;
-- CREATE INDEX idx_mv_order_fact_month ON mv_order_fact(purchase_month);
-- CREATE INDEX idx_mv_order_fact_state ON mv_order_fact(customer_state);
-- REFRESH MATERIALIZED VIEW mv_order_fact;  -- Schedule daily refresh
