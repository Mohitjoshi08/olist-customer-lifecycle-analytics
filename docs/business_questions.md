# Business Questions & Analytical Answers

This document lists the primary business questions investigated in this analysis, along with their analytical answers, SQL/Python evidence, and strategic recommendations, designed for easy review by recruiters and hiring managers.

---

### Q1: How has revenue (GMV) changed over time?
* **Analytical Answer:** Gross Merchandise Value (GMV) shows steady monthly expansion, starting from ~R$ 130k in Jan 2017 and peaking at **R$ 1.19M** in November 2017, representing a **34% spike** over the annual monthly average.
* **Evidence:** Delivered GMV totaled **R$ 15.42M** across the entire period (2016–2018).
* **Business Takeaway:** The November spike indicates high seasonal demand (Black Friday). Prepare inventory and marketing campaigns in Q3 to capture this seasonal demand.

---

### Q2: What is Olist's customer retention (repeat purchase rate)?
* **Analytical Answer:** Olist has a major retention gap: **only 3.00%** of unique customers made a repeat purchase (2,900 repeat buyers out of 96,096 total unique customers). **97.00%** placed only one order.
* **Evidence:** Calculated from the customer lifecycle features table.
* **Business Takeaway:** Acquisition volume is strong, but customer lifetime value is low because of the poor repeat purchase rate. Post-purchase loyalty and remarketing campaigns are the highest-priority growth opportunities.

---

### Q3: Which states generate the highest revenue?
* **Analytical Answer:** Revenue is heavily concentrated geographically. The top 5 states drive **73.20%** of total revenue. São Paulo (SP) alone represents **38.26%** of GMV.
* **Evidence:**
  - **SP (São Paulo):** 38.26% GMV (R$ 5.90M)
  - **RJ (Rio de Janeiro):** 13.16% GMV (R$ 2.03M)
  - **MG (Minas Gerais):** 11.80% GMV (R$ 1.82M)
  - **RS (Rio Grande do Sul):** 5.60% GMV (R$ 0.86M)
  - **PR (Paraná):** 5.13% GMV (R$ 0.79M)
* **Business Takeaway:** Olist is highly dependent on SP/RJ. Targeted geographic expansion and logistics hardening in other states will reduce regional logistics risk.

---

### Q4: Which product categories perform best?
* **Analytical Answer:** The top 5 categories generate **37.25%** of all revenue.
* **Evidence:**
  - **Health & Beauty:** R$ 1.41M (9.16%)
  - **Watches & Gifts:** R$ 1.26M (8.20%)
  - **Bed, Bath & Table:** R$ 1.23M (7.95%)
  - **Sports & Leisure:** R$ 1.12M (7.25%)
  - **Computers & Accessories:** R$ 1.03M (6.69%)
* **Business Takeaway:** Focus product cross-sell and bundle strategies on these high-velocity categories.

---

### Q5: What is the on-time delivery rate?
* **Analytical Answer:** The late delivery rate is **8.11%** (overall on-time rate is **91.89%**). Average delivery days vary significantly by state (e.g. SP averages ~8 days, while AL/AP averages 20+ days).
* **Evidence:** Derived from orders table (`order_delivered_customer_date > order_estimated_delivery_date`).
* **Business Takeaway:** Optimize SLAs and shipping lanes in high-delay regions to protect customer experience.

---

### Q6: How does review score vary by timeliness?
* **Analytical Answer:** Timely deliveries average a **4.25 review score** (with only 10.2% detractor rate), whereas late deliveries average a **2.24 review score** (with a **59.8% detractor rate**).
* **Evidence:** Grouping review scores by the late delivery flag.
* **Business Takeaway:** Logistics delays are the single largest driver of negative customer reviews (detractor status). Improving logistics will directly boost customer satisfaction and organic growth.

---

### Q7: What is the average and median Customer Lifetime Value (CLV)?
* **Analytical Answer:** The median CLV is **R$ 107.78**, while the mean is **R$ 165.17** (skewed by high-value outliers).
* **Evidence:** Derived from total customer spent distribution.
* **Business Takeaway:** Most customers spend relatively little. Focus acquisition budget on demographics that mirror the top 10% highest-spending customer segment.
