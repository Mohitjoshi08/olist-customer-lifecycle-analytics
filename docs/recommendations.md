# Strategic Recommendations

Actionable, data-backed initiatives to improve retention, logistics, and seller management across the Olist marketplace.

| Priority | Initiative | Owner | Timeline | Expected Impact | Primary KPI Target |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Critical** | ML-Driven Post-Purchase CRM Flow | CRM & Marketing | Q3 (30 Days) | High | Repeat Purchase Rate |
| **High** | Regional Fulfillment Hubs (Fulfillment by Olist) | Logistics & Ops | Q4 (90 Days) | High | Late Delivery Rate / Avg Delivery Days |
| **High** | Real-time SLA Risk Alerts & Proactive Mitigation | Product & Customer Care | Q4 (60 Days) | Medium | Average Review Score / Detractor Rate |
| **Medium** | Key Account Seller Support Program | Partner Relations | Q4 (90 Days) | High | Seller Retention / GMV Stability |

---

### Initiative Details & Implementation Solutions

#### 1. ML-Driven CRM Flows (CRM & Marketing)
* **Problem:** Only 3.00% repeat purchase rate, leading to a low median CLV (R$ 107.78).
* **Solution:** Deploy the RandomForest repeat-purchase propensity model. Automatically trigger targeted cross-sell emails within 14–30 days of the first delivery. Focus on high-frequency, high-co-occurrence category bundles (such as Bed, Bath & Table + Furniture Decor, which had 70 co-occurrences).
* **Action:** Target customers with high propensity scores with exclusive discounts, and send automated win-back emails to customers entering the "At Risk" recency band (90–180 days inactive).

#### 2. Regional Fulfillment Hubs (Logistics & Ops)
* **Problem:** 8.11% late delivery rate, heavily impacting customer review scores.
* **Solution:** Establish Olist-operated regional fulfillment centers in São Paulo (SP), Rio de Janeiro (RJ), and Minas Gerais (MG), which collectively represent **63.22%** of all GMV.
* **Action:** Allow top sellers in these regions to store inventory in Olist hubs. This guarantees carrier handoff in <24 hours, reducing total delivery days and late delivery rates in key regional corridors.

#### 3. Real-time SLA Risk Alerts (Product & Support)
* **Problem:** Delayed orders average a low 2.24 review score and suffer from a 59.8% detractor rate.
* **Solution:** Embed the delivery delay classifier into the order tracking system. 
* **Action:** If the model flags a shipment as "at risk of delay" during transit, proactively notify the customer, apologize, and offer a R$ 10 coupon *before* the estimated delivery date passes. This transforms a negative logistics event into a positive customer service touchpoint, preventing 1-star reviews.

#### 4. Key Account Seller Program (Partner Relations)
* **Problem:** Top 1% of sellers represent **25.08%** of total GMV, creating high concentration and operational dependency.
* **Solution:** Launch a tier-based "Preferred Seller" program.
* **Action:** Provide the top 29 sellers with direct account support, cheaper logistics rates, and premium catalog placement in exchange for strict service standards (e.g., late handoff rate < 2.0% and average review score > 4.2). This stabilizes our primary revenue generators.
