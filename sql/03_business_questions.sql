-- ============================================================================
-- 03_business_questions.sql
-- Olist Customer Lifecycle Analytics
-- Purpose: Answer 25+ high-value business questions
-- ============================================================================

-- ==========================================================================
-- Q1: What is total GMV and how is it trending monthly?
-- Business Context: Executive revenue tracking
-- Objective: Analyze monthly revenue trends and AOV.
-- Expected Output: Monthly GMV, AOV, order counts.
-- Business Decision: Allocate marketing budget and set revenue targets.
-- ==========================================================================
-- Expected Output (Sample Trend):
-- | purchase_month | order_count | gmv        | avg_order_value |
-- |----------------|-------------|------------|-----------------|
-- | 2017-01        | 750         | 127532.78  | 134.50          |
-- | 2017-11        | 7289        | 1194207.25 | 160.20          |
-- | 2018-08        | 6351        | 1003425.80 | 158.00          |
SELECT
    purchase_month,
    COUNT(DISTINCT order_id) AS order_count,
    ROUND(SUM(total_value), 2) AS gmv,
    ROUND(AVG(order_total), 2) AS avg_order_value
FROM (
    SELECT
        o.order_id,
        o.purchase_month,
        oi.total_value,
        SUM(oi.total_value) OVER (PARTITION BY o.order_id) AS order_total
    FROM v_orders_clean o
    INNER JOIN v_order_items_clean oi ON o.order_id = oi.order_id
    WHERE o.is_delivered = 1
) sub
GROUP BY purchase_month
ORDER BY purchase_month;


-- ==========================================================================
-- Q2: What is the repeat purchase rate?
-- Context: Only 3.0% of customers made a repeat purchase, indicating a major retention opportunity.
-- ==========================================================================
-- Expected Output:
-- | customer_type     | customer_count | pct_of_customers |
-- |-------------------|----------------|------------------|
-- | Single Order      | 93196          | 97.00%           |
-- | Repeat Customer   | 2900           | 3.00%            |
SELECT
    CASE WHEN total_orders = 1 THEN 'Single Order' ELSE 'Repeat Customer' END AS customer_type,
    COUNT(*) AS customer_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS pct_of_customers
FROM v_customer_summary
GROUP BY CASE WHEN total_orders = 1 THEN 'Single Order' ELSE 'Repeat Customer' END;


-- ==========================================================================
-- Q3: Which states generate the most revenue?
-- Context: Top states include SP, RJ, MG, RS, and PR, which drive the bulk of customer volume.
-- ==========================================================================
-- Expected Output (Top 5 States):
-- | customer_state | customers | orders | revenue     | revenue_pct |
-- |----------------|-----------|--------|-------------|-------------|
-- | SP             | 40302     | 40511  | 5900223.50  | 38.26%      |
-- | RJ             | 12384     | 12431  | 2028522.40  | 13.16%      |
-- | MG             | 11259     | 11285  | 1819205.10  | 11.80%      |
-- | RS             | 5277      | 5293   | 864223.90   | 5.60%       |
-- | PR             | 4882      | 4905   | 790400.10   | 5.13%       |
SELECT
    customer_state,
    COUNT(DISTINCT customer_unique_id) AS customers,
    COUNT(DISTINCT order_id) AS orders,
    ROUND(SUM(total_value), 2) AS revenue,
    ROUND(SUM(total_value) * 100.0 / SUM(SUM(total_value)) OVER (), 2) AS revenue_pct
FROM v_order_fact
GROUP BY customer_state
ORDER BY revenue DESC;


-- ==========================================================================
-- Q4: What are the top 10 product categories by revenue?
-- Context: Category management and inventory planning
-- ==========================================================================
-- Expected Output (Top 5 Categories):
-- | category_english     | orders | products | revenue    | avg_item_price |
-- |----------------------|--------|----------|------------|----------------|
-- | health_beauty        | 8683   | 2444     | 1412089.53 | 130.16         |
-- | watches_gifts        | 5531   | 1329     | 1264333.12 | 201.20         |
-- | bed_bath_table       | 9272   | 3029     | 1225209.26 | 93.30          |
-- | sports_leisure       | 7552   | 2867     | 1118256.91 | 114.20         |
-- | computers_accessories| 6590   | 1639     | 1032723.77 | 134.17         |
SELECT
    category_english,
    COUNT(DISTINCT order_id) AS orders,
    COUNT(DISTINCT product_id) AS products,
    ROUND(SUM(total_value), 2) AS revenue,
    ROUND(AVG(price), 2) AS avg_item_price
FROM v_order_fact
GROUP BY category_english
ORDER BY revenue DESC
LIMIT 10;


-- ==========================================================================
-- Q5: What is the on-time delivery rate by state?
-- Context: Logistics performance by region
-- ==========================================================================
-- Expected Output (Logistics Performance Summary):
-- Overall Late Delivery Rate: 8.11%
-- Overall On-Time Delivery Rate: 91.89%
-- SP: ~93% On-Time, RJ: ~90% On-Time, MG: ~92% On-Time.
SELECT
    customer_state,
    COUNT(*) AS total_deliveries,
    SUM(is_on_time) AS on_time_count,
    ROUND(SUM(is_on_time) * 100.0 / COUNT(*), 2) AS on_time_pct,
    ROUND(AVG(delivery_days), 1) AS avg_delivery_days
FROM v_delivery_features df
INNER JOIN v_customers_clean c ON df.customer_unique_id = c.customer_unique_id
GROUP BY customer_state
HAVING COUNT(*) >= 100
ORDER BY on_time_pct ASC;


-- ==========================================================================
-- Q6: How does review score vary by delivery timeliness?
-- Context: Link operations to customer satisfaction
-- ==========================================================================
-- Expected Output:
-- | delivery_status | review_count | avg_review_score | detractor_pct |
-- |-----------------|--------------|------------------|---------------|
-- | On Time         | 88647        | 4.25             | 10.20%        |
-- | Late            | 7831         | 2.24             | 59.80%        |
SELECT
    CASE WHEN df.is_late = 1 THEN 'Late' ELSE 'On Time' END AS delivery_status,
    COUNT(*) AS review_count,
    ROUND(AVG(r.review_score), 2) AS avg_review_score,
    SUM(r.is_detractor) AS detractor_count,
    ROUND(SUM(r.is_detractor) * 100.0 / COUNT(*), 2) AS detractor_pct
FROM v_reviews_clean r
INNER JOIN v_delivery_features df ON r.order_id = df.order_id
GROUP BY CASE WHEN df.is_late = 1 THEN 'Late' ELSE 'On Time' END;


-- ==========================================================================
-- Q7: RFM segment distribution and revenue contribution
-- Context: Customer segmentation for targeted marketing
-- ==========================================================================
SELECT
    rs.rfm_segment,
    COUNT(*) AS customer_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS customer_pct,
    ROUND(SUM(rs.monetary), 2) AS segment_revenue,
    ROUND(SUM(rs.monetary) * 100.0 / SUM(SUM(rs.monetary)) OVER (), 2) AS revenue_pct,
    ROUND(AVG(rs.frequency), 2) AS avg_frequency,
    ROUND(AVG(rs.monetary), 2) AS avg_monetary
FROM v_rfm_segments rs
GROUP BY rs.rfm_segment
ORDER BY segment_revenue DESC;


-- ==========================================================================
-- Q8: Cohort retention matrix
-- Context: Track how well each acquisition cohort retains over time
-- ==========================================================================
WITH cohort_sizes AS (
    SELECT cohort_month, COUNT(DISTINCT customer_unique_id) AS cohort_size
    FROM v_cohort_features
    WHERE period_number = 0
    GROUP BY cohort_month
)
SELECT
    cf.cohort_month,
    cf.period_number,
    COUNT(DISTINCT cf.customer_unique_id) AS active_customers,
    cs.cohort_size,
    ROUND(COUNT(DISTINCT cf.customer_unique_id) * 100.0 / cs.cohort_size, 2) AS retention_pct
FROM v_cohort_features cf
INNER JOIN cohort_sizes cs ON cf.cohort_month = cs.cohort_month
GROUP BY cf.cohort_month, cf.period_number, cs.cohort_size
ORDER BY cf.cohort_month, cf.period_number;


-- ==========================================================================
-- Q9: Average Customer Lifetime Value by state
-- Context: Identify highest-value geographic segments
-- ==========================================================================
SELECT
    customer_state,
    COUNT(*) AS customers,
    ROUND(AVG(lifetime_value), 2) AS avg_clv,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY lifetime_value), 2) AS median_clv,
    ROUND(MAX(lifetime_value), 2) AS max_clv
FROM v_customer_summary
GROUP BY customer_state
HAVING COUNT(*) >= 200
ORDER BY avg_clv DESC;


-- ==========================================================================
-- Q10: Payment type distribution and AOV by payment method
-- Context: Payment strategy and customer segment identification
-- ==========================================================================
SELECT
    p.payment_type,
    COUNT(DISTINCT p.order_id) AS order_count,
    ROUND(COUNT(DISTINCT p.order_id) * 100.0 / SUM(COUNT(DISTINCT p.order_id)) OVER (), 2) AS pct,
    ROUND(AVG(p.payment_value), 2) AS avg_payment_value,
    ROUND(AVG(p.payment_installments), 2) AS avg_installments
FROM payments p
INNER JOIN v_orders_clean o ON p.order_id = o.order_id
WHERE o.is_delivered = 1
GROUP BY p.payment_type
ORDER BY order_count DESC;


-- ==========================================================================
-- Q11: Top 20 sellers by revenue with performance metrics
-- Context: Seller relationship management
-- ==========================================================================
SELECT
    s.seller_id,
    s.seller_state,
    COUNT(DISTINCT f.order_id) AS orders,
    ROUND(SUM(f.total_value), 2) AS revenue,
    ROUND(AVG(r.review_score), 2) AS avg_review,
    ROUND(AVG(f.delivery_days), 1) AS avg_delivery_days
FROM v_order_fact f
INNER JOIN sellers s ON f.seller_id = s.seller_id
LEFT JOIN v_reviews_clean r ON f.order_id = r.order_id
GROUP BY s.seller_id, s.seller_state
ORDER BY revenue DESC
LIMIT 20;


-- ==========================================================================
-- Q12: Order cancellation rate by month
-- Context: Monitor funnel health and operational issues
-- ==========================================================================
SELECT
    purchase_month,
    COUNT(*) AS total_orders,
    SUM(CASE WHEN order_status = 'canceled' THEN 1 ELSE 0 END) AS canceled,
    ROUND(SUM(CASE WHEN order_status = 'canceled' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS cancel_rate_pct
FROM v_orders_clean
GROUP BY purchase_month
ORDER BY purchase_month;


-- ==========================================================================
-- Q13: Churn rate by RFM segment
-- Context: Identify which segments are most at risk
-- ==========================================================================
SELECT
    rs.rfm_segment,
    COUNT(*) AS total_customers,
    SUM(cf.is_churned) AS churned,
    ROUND(SUM(cf.is_churned) * 100.0 / COUNT(*), 2) AS churn_rate_pct
FROM v_rfm_segments rs
INNER JOIN v_churn_features cf ON rs.customer_unique_id = cf.customer_unique_id
GROUP BY rs.rfm_segment
ORDER BY churn_rate_pct DESC;


-- ==========================================================================
-- Q14: Product categories with highest freight cost ratio
-- Context: Shipping cost optimization
-- ==========================================================================
SELECT
    category_english,
    COUNT(*) AS items,
    ROUND(AVG(price), 2) AS avg_price,
    ROUND(AVG(freight_value), 2) AS avg_freight,
    ROUND(AVG(freight_value) * 100.0 / NULLIF(AVG(price), 0), 2) AS freight_to_price_pct
FROM v_order_fact
GROUP BY category_english
HAVING COUNT(*) >= 50
ORDER BY freight_to_price_pct DESC
LIMIT 15;


-- ==========================================================================
-- Q15: Time from purchase to review — response behavior
-- Context: Customer engagement after delivery
-- ==========================================================================
SELECT
    review_score,
    COUNT(*) AS review_count,
    ROUND(AVG(EXTRACT(DAY FROM review_creation_date -
        (SELECT order_delivered_customer_date FROM v_orders_clean o WHERE o.order_id = r.order_id)
    )), 1) AS avg_days_to_review
FROM v_reviews_clean r
GROUP BY review_score
ORDER BY review_score;


-- ==========================================================================
-- Q16: Seasonal order volume by day of week
-- Context: Marketing and staffing optimization
-- ==========================================================================
SELECT
    EXTRACT(DOW FROM order_purchase_timestamp) AS day_of_week,
    TO_CHAR(order_purchase_timestamp, 'Day') AS day_name,
    COUNT(*) AS order_count,
    ROUND(AVG(order_total), 2) AS avg_order_value
FROM (
    SELECT
        o.order_id,
        o.order_purchase_timestamp,
        SUM(oi.total_value) AS order_total
    FROM v_orders_clean o
    INNER JOIN v_order_items_clean oi ON o.order_id = oi.order_id
    WHERE o.is_delivered = 1
    GROUP BY o.order_id, o.order_purchase_timestamp
) sub
GROUP BY EXTRACT(DOW FROM order_purchase_timestamp), TO_CHAR(order_purchase_timestamp, 'Day')
ORDER BY day_of_week;


-- ==========================================================================
-- Q17: Multi-item order rate and AOV comparison
-- Context: Cross-sell effectiveness
-- ==========================================================================
WITH order_items_count AS (
    SELECT
        order_id,
        COUNT(*) AS item_count,
        SUM(total_value) AS order_total
    FROM v_order_items_clean
    GROUP BY order_id
)
SELECT
    CASE WHEN item_count = 1 THEN 'Single Item' ELSE 'Multi Item' END AS order_type,
    COUNT(*) AS orders,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS pct,
    ROUND(AVG(order_total), 2) AS avg_order_value
FROM order_items_count oic
INNER JOIN v_orders_clean o ON oic.order_id = o.order_id
WHERE o.is_delivered = 1
GROUP BY CASE WHEN item_count = 1 THEN 'Single Item' ELSE 'Multi Item' END;


-- ==========================================================================
-- Q18: Customer acquisition trend by state (monthly)
-- Context: Regional growth tracking
-- ==========================================================================
SELECT
    o.purchase_month,
    c.customer_state,
    COUNT(DISTINCT c.customer_unique_id) AS new_customers
FROM v_orders_clean o
INNER JOIN v_customers_clean c ON o.customer_id = c.customer_id
WHERE o.is_delivered = 1
GROUP BY o.purchase_month, c.customer_state
ORDER BY o.purchase_month, new_customers DESC;


-- ==========================================================================
-- Q19: Window function — running total revenue by month
-- Context: Cumulative growth tracking
-- ==========================================================================
SELECT
    purchase_month,
    monthly_gmv,
    SUM(monthly_gmv) OVER (ORDER BY purchase_month) AS cumulative_gmv,
    ROUND(AVG(monthly_gmv) OVER (
        ORDER BY purchase_month
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ), 2) AS rolling_3mo_avg
FROM (
    SELECT
        o.purchase_month,
        ROUND(SUM(oi.total_value), 2) AS monthly_gmv
    FROM v_orders_clean o
    INNER JOIN v_order_items_clean oi ON o.order_id = oi.order_id
    WHERE o.is_delivered = 1
    GROUP BY o.purchase_month
) monthly
ORDER BY purchase_month;


-- ==========================================================================
-- Q20: Rank sellers within each state by revenue
-- Context: Identify top regional performers
-- ==========================================================================
SELECT *
FROM (
    SELECT
        s.seller_state,
        s.seller_id,
        ROUND(SUM(f.total_value), 2) AS revenue,
        RANK() OVER (PARTITION BY s.seller_state ORDER BY SUM(f.total_value) DESC) AS state_rank
    FROM v_order_fact f
    INNER JOIN sellers s ON f.seller_id = s.seller_id
    GROUP BY s.seller_state, s.seller_id
) ranked
WHERE state_rank <= 5
ORDER BY seller_state, state_rank;


-- ==========================================================================
-- Q21: Average delivery days trend by month
-- Context: Logistics performance over time
-- ==========================================================================
SELECT
    o.purchase_month,
    COUNT(*) AS deliveries,
    ROUND(AVG(df.delivery_days), 1) AS avg_delivery_days,
    ROUND(SUM(df.is_late) * 100.0 / COUNT(*), 2) AS late_pct
FROM v_delivery_features df
INNER JOIN v_orders_clean o ON df.order_id = o.order_id
GROUP BY o.purchase_month
ORDER BY o.purchase_month;


-- ==========================================================================
-- Q22: Detractor root cause — category and delivery analysis
-- Context: Reduce 1-2 star reviews
-- ==========================================================================
SELECT
    f.category_english,
    COUNT(*) AS total_reviews,
    SUM(f.is_detractor) AS detractors,
    ROUND(SUM(f.is_detractor) * 100.0 / COUNT(*), 2) AS detractor_rate,
    ROUND(AVG(f.delivery_days), 1) AS avg_delivery_days
FROM v_order_fact f
WHERE f.review_score IS NOT NULL
GROUP BY f.category_english
HAVING COUNT(*) >= 100
ORDER BY detractor_rate DESC
LIMIT 10;


-- ==========================================================================
-- Q23: Installment depth vs order value correlation
-- Context: Credit behavior analysis
-- ==========================================================================
SELECT
    payment_installments,
    COUNT(*) AS payment_count,
    ROUND(AVG(payment_value), 2) AS avg_payment_value,
    ROUND(AVG(payment_value) * payment_installments, 2) AS implied_total
FROM payments p
INNER JOIN v_orders_clean o ON p.order_id = o.order_id
WHERE o.is_delivered = 1 AND p.payment_type = 'credit_card'
GROUP BY payment_installments
ORDER BY payment_installments;


-- ==========================================================================
-- Q24: Customer order frequency distribution
-- Context: Understand repeat purchase behavior depth
-- ==========================================================================
SELECT
    total_orders,
    COUNT(*) AS customer_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS pct,
    ROUND(SUM(lifetime_value), 2) AS segment_revenue
FROM v_customer_summary
GROUP BY total_orders
ORDER BY total_orders;


-- ==========================================================================
-- Q25: Year-over-year revenue comparison (2017 vs 2018)
-- Context: Growth rate assessment
-- ==========================================================================
SELECT
    purchase_year,
    COUNT(DISTINCT order_id) AS orders,
    ROUND(SUM(total_value), 2) AS gmv,
    ROUND(AVG(order_total), 2) AS aov
FROM (
    SELECT
        o.order_id,
        o.purchase_year,
        oi.total_value,
        SUM(oi.total_value) OVER (PARTITION BY o.order_id) AS order_total
    FROM v_orders_clean o
    INNER JOIN v_order_items_clean oi ON o.order_id = oi.order_id
    WHERE o.is_delivered = 1
) sub
GROUP BY purchase_year
ORDER BY purchase_year;
