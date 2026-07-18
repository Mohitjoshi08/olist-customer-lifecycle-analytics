# Power BI DAX Measure Catalog

This document provides copy-pasteable DAX formulas for the critical marketplace KPIs and customer lifecycle metrics specified in [dashboard_specification.md](file:///C:/Users/mohit/OneDrive/Desktop/projects/olist-customer-lifecycle-analytic-main/powerbi/dashboard_specification.md).

---

## 1. Core Financials & Order Metrics

### Total Revenue (GMV)
* **Description:** Sum of all order item prices and shipping freight costs.
* **DAX Formula:**
```dax
GMV = SUM(v_order_fact[total_value])
```

### Delivered Orders
* **Description:** Total volume of orders successfully completed and delivered.
* **DAX Formula:**
```dax
Delivered Orders = DISTINCTCOUNT(v_order_fact[order_id])
```

### Average Order Value (AOV)
* **Description:** The average amount spent per order.
* **DAX Formula:**
```dax
AOV = DIVIDE([GMV], [Delivered Orders], 0)
```

### Median Spent (per Order)
* **Description:** The median order value (total spent on price + freight per order) for delivered orders (equals R$ 105.28).
* **DAX Formula:**
```dax
Median Order Value = 
MEDIANX(
    VALUES(Fact_Order_Items[order_id]),
    CALCULATE(SUM(Fact_Order_Items[price]) + SUM(Fact_Order_Items[freight_value]))
)
```
*(Or, if your table has a pre-calculated `item_total_value` column)*:
```dax
Median Order Value = 
MEDIANX(
    VALUES(Fact_Order_Items[order_id]),
    CALCULATE(SUM(Fact_Order_Items[item_total_value]))
)
```


### Total Orders
* **Description:** The total count of all orders placed, regardless of order status.
* **DAX Formula (for Star Schema):**
```dax
Total Orders = DISTINCTCOUNT(Dim_Orders[order_id])
```

### Order Success Rate
* **Description:** The percentage of placed orders that were successfully delivered to the customer. Excellent for adding as a KPI card sub-label or status indicator.
* **DAX Formula (Star Schema):**
```dax
Order Success Rate = 
VAR TotalOrders = DISTINCTCOUNT(Dim_Orders[order_id])
VAR DeliveredOrders = 
    CALCULATE(
        DISTINCTCOUNT(Dim_Orders[order_id]),
        Dim_Orders[order_status] = "delivered"
    )
RETURN
    DIVIDE(DeliveredOrders, TotalOrders, 0)
```
*(Or, if you already have explicit `[Delivered Orders]` and `[Orders]` measures in your model)*:
```dax
Order Success Rate = DIVIDE([Delivered Orders], [Orders], 0)
```


---

## 2. Customer Retention & Lifecycle KPIs

### Active Unique Customers
* **Description:** Distinct count of unique customer IDs in the dataset.
* **DAX Formula:**
```dax
Active Customers = DISTINCTCOUNT(Dim_Customers[customer_unique_id])
```

### Repeat Purchase Rate
* **Description:** Percentage of customers who purchased more than once.
* **DAX Formula:**
```dax
Repeat Purchase Rate = 
VAR ActiveOrderIds = VALUES(Fact_Order_Items[order_id])
VAR ActiveCustomerIds = 
    CALCULATETABLE(
        VALUES(Dim_Orders[customer_id]),
        TREATAS(ActiveOrderIds, Dim_Orders[order_id])
    )
VAR ActiveUniqueCustomers = 
    CALCULATETABLE(
        VALUES(Dim_Customers[customer_unique_id]),
        TREATAS(ActiveCustomerIds, Dim_Customers[customer_id])
    )
VAR RepeatBuyersCount = 
    CALCULATE(
        COUNTROWS(Dim_Customer_Segments),
        TREATAS(ActiveUniqueCustomers, Dim_Customer_Segments[customer_unique_id]),
        Dim_Customer_Segments[order_count] > 1
    )
RETURN
    DIVIDE(RepeatBuyersCount, [Unique Customers], 0)

```

### Customer Lifetime Value (CLV)
* **Description:** The average lifetime value spent per customer.
* **DAX Formula:**
```dax
Average CLV = AVERAGE(Dim_Customer_Segments[total_spent])
```

### Median CLV (Median Spent per Customer)
* **Description:** The median lifetime spent per customer (equals R$ 107.78).
* **DAX Formula:**
```dax
Median CLV = MEDIAN(Dim_Customer_Segments[total_spent])
```


---

## 3. Operations & Delivery Metrics

### On-Time Delivery Rate
* **Description:** Percentage of orders delivered on or before the estimated delivery date.
* **DAX Formula:**
```dax
On-Time Delivery Rate = 
VAR OnTimeOrders = 
    CALCULATE(
        DISTINCTCOUNT(v_order_fact[order_id]),
        v_order_fact[is_late_delivery] = 0
    )
VAR TotalOrders = DISTINCTCOUNT(v_order_fact[order_id])
RETURN
    DIVIDE(OnTimeOrders, TotalOrders, 0)
```

### Late Delivery Rate
* **Description:** Percentage of orders that missed their SLA estimated delivery date.
* **DAX Formula:**
```dax
Late Delivery Rate = 1 - [On-Time Delivery Rate]
```

### Average Delivery Days
* **Description:** Average days elapsed from purchase timestamp to customer delivery timestamp.
* **DAX Formula:**
```dax
Average Delivery Days = AVERAGE(v_order_fact[delivery_days])
```

### Average Review Score
* **Description:** The average rating score left by customer reviews.
* **DAX Formula:**
```dax
Average Review Score = AVERAGE(v_order_fact[review_score])
```

---

## 4. Concentration & Marketplace Risk

### Top 1% Seller Revenue Share
* **Description:** The percentage of GMV captured by the top 1.00% sellers. Highlights supplier concentration risk.
* **DAX Formula:**
```dax
Top 1% Seller Revenue Share = 
VAR TotalGMV = [GMV]
VAR SellerRevenueTable = 
    ADDCOLUMNS(
        VALUES(v_order_fact[seller_id]),
        "@SellerGMV", [GMV]
    )
VAR SellerCount = COUNTROWS(VALUES(v_order_fact[seller_id]))
VAR Top1PercentCount = MAX(1, ROUND(SellerCount * 0.01, 0))
VAR TopSellersGMV = 
    SUMX(
        TOPN(
            Top1PercentCount,
            SellerRevenueTable,
            [@SellerGMV],
            DESC
        ),
        [@SellerGMV]
    )
RETURN
    DIVIDE(TopSellersGMV, TotalGMV, 0)
```

### Category Revenue Share %
* **Description:** Category GMV contribution relative to total GMV.
* **DAX Formula:**
```dax
Category Revenue Share % = 
VAR CategoryGMV = [GMV]
VAR TotalGMV = CALCULATE([GMV], ALL(Dim_Products[product_category_name_english]))
RETURN
    DIVIDE(CategoryGMV, TotalGMV, 0)
```

---

## 5. Cohort Retention Matrix DAX

*To build the cohort matrix in a Power BI Matrix Visual, use the `v_cohort_features` table. Place `cohort_month` in Rows, `period_number` in Columns, and compile the following measure in Values:*

### Cohort Retention % (Matrix Measure)
* **DAX Formula:**
```dax
Cohort Retention % = 
VAR CohortSize = 
    CALCULATE(
        DISTINCTCOUNT(v_cohort_features[customer_unique_id]),
        v_cohort_features[period_number] = 0,
        REMOVEFILTERS(v_cohort_features[period_number])
    )
VAR ActiveInPeriod = DISTINCTCOUNT(v_cohort_features[customer_unique_id])
RETURN
    DIVIDE(ActiveInPeriod, CohortSize, 0)
```
