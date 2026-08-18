# Executive Summary

This executive summary outlines the key insights, operational challenges, and machine learning-driven recommendations for the Olist marketplace customer lifecycle.

---

## Dataset Summary
- **Total Orders:** 99,441
- **Delivered Orders:** 96,478
- **Unique Customers:** 96,096
- **Analysis Period:** Sept 2016 – Oct 2018
- **Total Gross Merchandise Value (GMV):** R$ 15.42M
- **Average Order Value (AOV):** R$ 159.83
- **Median Order Value:** R$ 105.28

---

## Core Problem
Although Olist has acquired **96,096 unique customers**, only **3.00%** placed a repeat purchase. The marketplace operates on a high-acquisition, low-retention model, resulting in a low Customer Lifetime Value (median CLV of **R$ 107.78**).

---

## 5 Key Findings
1. **Low Retention:** Repeat purchase rate is exactly 3.00% (2,900 repeat buyers out of 96k).
2. **Logistics Friction:** The overall late delivery rate is 8.11%.
3. **Satisfaction Impact:** Logistics delays drive customer dissatisfaction. On-time orders average a **4.25 review score** (10.2% detractors), whereas late orders drop to a **2.24 review score** (59.8% detractors).
4. **Geographic Concentration:** The top 5 customer states (SP, RJ, MG, RS, PR) drive **73.20%** of total revenue. São Paulo (SP) alone represents **38.26%** of GMV.
5. **High Seller Dependency:** The top 1.00% of sellers (29 accounts) generate **25.08%** of total revenue, creating significant marketplace operational risk.

---

## 4 Strategic Recommendations & Solutions

### 1. ML-Driven Post-Purchase CRM Flow (Retention)
* **Goal:** Increase the 3.00% repeat purchase rate.
* **Solution:** Deploy the repeat-purchase propensity classifier on first-order attributes. Automate targeted campaigns within 30 days for customers with high repeat propensity, offering high-margin product bundles from top categories (Health & Beauty, Watches). For at-risk customers, trigger automated win-back coupon flows.

### 2. Regional Fulfillment Hubs (Fulfillment by Olist)
* **Goal:** Reduce delivery days and late delivery rates.
* **Solution:** Establish Olist-operated fulfillment centers in the SP, RJ, and MG regions (which represent **63.22%** of total marketplace revenue). Storing top-selling inventory locally will drastically reduce shipping times and carrier handoff friction.

### 3. Predictive Late Delivery Alerts & Mitigation (Operations)
* **Goal:** Prevent 1-2 star reviews caused by late deliveries.
* **Solution:** Use the delivery delay classifier to monitor orders in real time. Flag high-risk shipments at checkout. If an order is delayed, proactively email the customer with a tracking update and a R$ 10 discount voucher before the SLA breach occurs, mitigating detractor sentiment.

### 4. Key Account Program & Seller Quality Controls (Marketplace)
* **Goal:** Mitigate seller concentration risk and improve product quality.
* **Solution:** Standardize seller performance tiers. Partner with the top 1.00% of sellers (generating 25.08% GMV) in a "Preferred Seller" program, offering them priority logistics routing and lower fees in exchange for keeping their late delivery rates below 3.00%.
