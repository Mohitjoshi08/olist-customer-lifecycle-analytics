# Power BI Dashboard Implementation Guide

This step-by-step guide explains how to connect your data, construct the star schema, write the DAX measures, and build the 4-page widescreen dashboard matching [dashboard_mockup.html](file:///C:/Users/mohit/OneDrive/Desktop/projects/olist-customer-lifecycle-analytic-main/powerbi/dashboard_mockup.html).

---

## Step 1: Data Connection & Power Query Preparation

### 1. Load the Cleaned Datasets
In Power BI Desktop, click **Get Data -> Text/CSV** and import these cleaned datasets from your local folders:

* **From `data/processed/cleaned/`:**
  1. `orders_clean.csv` (Rename to `Dim_Orders`)
  2. `order_items_clean.csv` (Rename to `Fact_Order_Items`)
  3. `customers_clean.csv` (Rename to `Dim_Customers`)
  4. `sellers_clean.csv` (Rename to `Dim_Sellers`)
  5. `products_clean.csv` (Rename to `Dim_Products`)
  6. `order_payments_clean.csv` (Rename to `Dim_Payments`)
  7. `order_reviews_clean.csv` (Rename to `Dim_Reviews`)

* **From `data/processed/phase5/`:**
  8. `customer_segments_phase5.csv` (Rename to `Dim_Customer_Segments`)
  9. `cohort_retention_phase5.csv` (Rename to `Fact_Cohort_Retention`)

### 2. Standardize Columns in Power Query
* **Dates:** In `Dim_Orders`, change these columns to **Date/Time** type:
  - `order_purchase_timestamp`
  - `order_delivered_customer_date`
  - `order_estimated_delivery_date`
* **Values:** In `Fact_Order_Items`, change `price` and `freight_value` to **Fixed Decimal Number (Currency)**.

### 3. Create a Calendar Dimension (Dim_Calendar)
In Power BI Desktop, go to **Modeling -> New Table** and write this DAX code to generate a date table:
```dax
Dim_Calendar = 
ADDCOLUMNS (
    CALENDAR (MIN(Dim_Orders[order_purchase_timestamp]), MAX(Dim_Orders[order_purchase_timestamp])),
    "Year", YEAR([Date]),
    "Month Num", MONTH([Date]),
    "Month Year", FORMAT([Date], "MMM YYYY"),
    "Month Year Sort", YEAR([Date]) * 100 + MONTH([Date]),
    "Quarter", "Q" & QUARTER([Date])
)
```
*Right-click `Dim_Calendar` -> select **Mark as date table** -> choose the `Date` column.*

---

## Step 2: Widescreen Layout & Styling Setup

### 1. Set Page Size (Widescreen 16:9)
* Select the canvas background (click outside any visual).
* In the **Format Pane**, set **Canvas settings -> Type** to `16:9` (Widescreen, 1280x720 or 1600x900).
* Disable page scrollbars by ensuring all visual boundaries stay within the canvas frame (`Height: 720px`).

### 2. Import the Visual Theme
* Go to the **View** tab in the top ribbon.
* Click the dropdown arrow in the **Themes** section.
* Click **Browse for themes** and select [portfolio_theme.json](file:///C:/Users/mohit/OneDrive/Desktop/projects/olist-customer-lifecycle-analytic-main/powerbi/portfolio_theme.json).
* *This locks in the fonts (Segoe UI), rounded visual borders (6px), and the color palette (Accent Blue, Orange, Plum, Green).*

---

## Step 3: Create the Relationships (Star Schema)

Go to the **Model View** tab (left sidebar) and drag connections to create the following relationships:

1. **Orders to Items (Fact table connection):**
   * `Dim_Orders[order_id]` $\rightarrow$ `Fact_Order_Items[order_id]` (1-to-many, Single direction)
2. **Customers to Orders:**
   * `Dim_Customers[customer_id]` $\rightarrow$ `Dim_Orders[customer_id]` (1-to-many, Single direction)
3. **Sellers to Items:**
   * `Dim_Sellers[seller_id]` $\rightarrow$ `Fact_Order_Items[seller_id]` (1-to-many, Single direction)
4. **Products to Items:**
   * `Dim_Products[product_id]` $\rightarrow$ `Fact_Order_Items[product_id]` (1-to-many, Single direction)
5. **Calendar to Orders:**
   * `Dim_Calendar[Date]` $\rightarrow$ `Dim_Orders[order_purchase_timestamp]` (1-to-many, Single direction)
6. **Customer Segments to Customers:**
   * `Dim_Customer_Segments[customer_unique_id]` $\rightarrow$ `Dim_Customers[customer_unique_id]` (1-to-many, Both directions)
7. **Reviews to Orders:**
   * `Dim_Reviews[order_id]` $\rightarrow$ `Dim_Orders[order_id]` (1-to-many, Single direction)

---

## Step 4: Write Explicit DAX Measures

Create a blank table named `_Measures` and write these DAX formulas:

```dax
// 1. Core financials
GMV = SUM(Fact_Order_Items[price]) + SUM(Fact_Order_Items[freight_value])

Orders = DISTINCTCOUNT(Dim_Orders[order_id])

Delivered Orders = 
CALCULATE(
    DISTINCTCOUNT(Dim_Orders[order_id]),
    Dim_Orders[order_status] = "delivered"
)

Order Success Rate = DIVIDE([Delivered Orders], [Orders], 0)

AOV = DIVIDE([GMV], [Delivered Orders], 0)


// 2. Retention KPIs
Unique Customers = 
VAR ActiveOrderIds = VALUES(Fact_Order_Items[order_id])
VAR ActiveCustomerIds = 
    CALCULATETABLE(
        VALUES(Dim_Orders[customer_id]),
        TREATAS(ActiveOrderIds, Dim_Orders[order_id])
    )
RETURN
    CALCULATE(
        DISTINCTCOUNT(Dim_Customers[customer_unique_id]),
        TREATAS(ActiveCustomerIds, Dim_Customers[customer_id])
    )

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


Median Spent (CLV) = MEDIAN(Dim_Customer_Segments[total_spent])

// 3. Logistics & Value KPIs
On-Time SLA Rate = 
VAR OnTime = CALCULATE(COUNT(Dim_Orders[order_id]), Dim_Orders[late_delivery_flag] = 0)
RETURN DIVIDE(OnTime, COUNT(Dim_Orders[order_id]), 0)

Late SLA Rate = 1 - [On-Time SLA Rate]

Avg Delivery Days = AVERAGE(Dim_Orders[delivery_days])

Median Spent (Order) = 
MEDIANX(
    VALUES(Fact_Order_Items[order_id]),
    CALCULATE(SUM(Fact_Order_Items[price]) + SUM(Fact_Order_Items[freight_value]))
)
```

---

## Step 5: Visual Construction (Page-by-Page)

### Page 1: Executive Overview
* **Theme Accent:** Green (`#55A868`)
* **KPI Row (Top - 6 Cards in a Single Row):**
  * Visual: **Card (New)**. Place `GMV`, `Orders`, `AOV`, `Repeat Purchase Rate`, `Late SLA Rate`, `Review Score`.
  * Style: Turn on **Card -> Reference labels** to display targets:
    * GMV target: *"Target: R$ 15.00M (Achieved)"*
    * Repeat Rate: *"Target: 10.0% (Below Target)"* (Color label red)
    * Late SLA Rate: *"Target: <5.0% (Risk Zone)"* (Color label red)
* **Left Graph:** **Line Chart**. 
  * X-Axis: `Dim_Calendar[Month Year]` (Sorted by `Month Year Sort`). Y-Axis: `[GMV]`.
  * Title: *“Monthly Revenue Growth | Peak Sales Concentrated in Q4”*
  * Annotation: Insert a Text Box over the November peak stating: *"▲ Nov 2017: Black Friday Peak (R$ 1.19M, +34% vs avg)"*.
* **Right Graph:** **Horizontal Bar Chart**.
  * Y-Axis: `Dim_Payments[payment_type]`. X-Axis: `[GMV]`.
  * Title: *“Payment Type Mix | Credit Cards Represent 73.92% of GMV Share”*
* **Bottom Panel:** **Text Box** styled as an executive AI insights panel.

---

### Page 2: Retention & Value
* **Theme Accent:** Purple/Plum (`#A23B72`)
* **KPI Row (Top - 5 Cards in a Single Row):**
  * Metrics: `Unique Customers`, `180d Churn Rate`, `Month 1 Retention (4.74%)`, `Average CLV`, `Median spent`.
* **Left Grid:** **Matrix Visual** (Cohort Retention Matrix).
  * Rows: `cohort_month`. Columns: `period_number` (Filter to 0–6). Values: `Cohort Retention %`.
  * Formatting: Turn on **Conditional formatting -> Background color** for Values. Set a color scale from White (`#FFFFFF`) to Plum (`#A23B72`) to create a cohort heatmap.
* **Right Visual:** **Clustered Column Chart** (Customer Segments).
  * X-Axis: `segment`. Y-Axis: `[Unique Customers]`. Color: Plum.
* **Bottom Table:** **Table Visual** (RFM Segments).
  * Columns: `RFM Segment`, `Customers`, `Share %`, `Revenue (BRL)`, `Revenue Share %`, `Order Freq`.
  * Formatting: Turn on **Conditional formatting -> Data bars** for the `Revenue Share %` column (colored Plum).

---

### Page 3: Marketplace Performance
* **Theme Accent:** Orange/Amber (`#F18F01`)
* **KPI Row (Top - 5 Cards in a Single Row):**
  * Metrics: `Active Sellers (3,095)`, `Top 1% Seller GMV % (25.08%)`, `Unique Products (32,951)`, `Multi-Item Orders (12.4%)`, `Avg Shipping Freight (R$ 22.80)`.
* **Left Graph:** **Clustered Bar Chart** (Product Categories).
  * X-Axis: `product_category_name_english` (Filter Top 10). Y-Axis: `[GMV]`. Color: Orange.
  * Title: *“Product Mix Dominance | Health & Beauty Leads Category Contribution (22.1% top GMV)”*
* **Right Graph:** **Horizontal Bar Chart** (Seller Leaderboard).
  * Y-Axis: `seller_id` (Filter Top 10 using Top N). X-Axis: `[GMV]`. Color: Blue.
* **Bottom Left Grid:** **Table Visual** (Market Basket Pairs).
  * Columns: `Category A`, `Category B`, `Co-Occurrences`.
* **Bottom Right Grid:** **Table Visual** (Freight-to-Price ratio).
  * Columns: `Category Name`, `Avg Price`, `Avg Freight`, `Freight-to-Price %`.
  * Formatting: Add **Red Data bars** on the `Freight-to-Price %` column.

---

### Page 4: Logistics & ML Diagnostics
* **Theme Accent:** Red/Crimson (`#DC2626`)
* **KPI Row (Top - 4 Cards in a Single Row):**
  * Metrics: `On-Time SLA Rate (91.89%)`, `Late SLA Rate (8.11%)`, `Avg Delivery Time (12.5 Days)`, `SLA Detractor Rate (59.8%)`.
* **Left Graph:** **100% Stacked Bar Chart** (Reviews vs Timeliness).
  * X-Axis: `is_late_delivery`. Y-Axis: `review_score` (Legend).
  * Title: *“SLA Impact | Late Deliveries Drive Detractors (59.8% 1-2 Star Reviews)”*
* **Middle Visual:** **Key Influencers Visual** (Native Power BI AI visual).
  * Analyze: `is_detractor` (Review score <= 2).
  * Explain by: `is_late_delivery`, `shipping_freight`, `customer_state`.
  * *Power BI will automatically render the relative increase nodes (e.g. "When is_late_delivery is 1, the likelihood of a detractor increases by 5.8x").*
* **Right Panel:** **Multi-row Card** (ML Diagnostics).
  * Display a vertical card structure representing:
    - Business Problem: *e.g. Predict Repeat Purchase*
    - Model Used: *Random Forest Classifier*
    - Performance: *AUC = 0.64*
    - Business Action: *Launch coupon campaigns in 30 days*
