# Machine Learning Modeling and Business Interpretation

This document details the predictive models built to transition the Olist Customer Lifecycle project from descriptive analytics to proactive business decision-making. 

---

## 1. Churn and Repeat Purchase Propensity Model

### Model Objective
To predict whether a first-time customer will make a repeat purchase based on their first order experience. This serves as our predictive churn model (where a low propensity score indicates a high risk of churn).

* **Algorithm**: RandomForestClassifier
* **Target Variable**: `repeat_customer_flag` (1 for repeat buyer, 0 for one-time buyer)
* **Model Evaluation (AUC-ROC)**: 0.6025

### Feature Importance and Business Interpretation
The relative contribution of first-order features in predicting repeat purchases is detailed below:

| Feature Name | Importance Share (%) | Business Interpretation |
| :--- | :--- | :--- |
| `first_avg_freight` | 14.03% | Shipping fees are the single largest driver of customer churn. High freight relative to item price discourages repeat buying. |
| `first_order_value` | 12.09% | First-order basket size indicates initial customer budget and commitment level. |
| `first_avg_item_price` | 11.93% | Purchase price points correlate with customer demographic tiers and retention profiles. |
| `first_delivery_days` | 11.45% | Logistics delay. Slow delivery speeds act as a direct customer experience detractor. |
| `payment_installments` | 8.66% | Payment options. Customers utilizing credit installments show different retention rates compared to single-payment users. |
| `review_score` | 4.16% | Product satisfaction. Low review scores on the first order correlate with immediate churn. |

### Business Action
* **Logistics & Fee Optimization**: Since shipping fees (`first_avg_freight`) and delivery times (`first_delivery_days`) represent a combined **25.5%** of churn predictability, Olist should prioritize optimizing shipping SLAs and subsidizing freight in high-volume regions.
* **Targeted Retargeting**: Customers flagged with a repeat propensity below 15% should be automatically enrolled in an email recovery flow offering localized shipping discounts or coupons.

---

## 2. Customer Lifetime Value (CLV) Prediction Model

### Model Objective
To predict a customer's total lifetime spending value based on their initial transaction attributes, enabling acquisition teams to optimize Customer Acquisition Cost (CAC) thresholds.

* **Algorithm**: RandomForestRegressor
* **Target Variable**: `total_spent` (cumulative historical customer spend)
* **Performance Metrics**:
  * **R² Score**: 0.9209 (92.1% of CLV variance explained)
  * **Mean Absolute Error (MAE)**: R$ 9.70

### Feature Importance and Business Interpretation
* **First Order Value (98.18%)**: The value of a customer's first purchase is the absolute strongest predictor of their lifetime value. 
* **Other Features (Price, Delivery Speed, Freight, Reviews) (< 2.0% combined)**: Post-purchase experience features show low statistical predictive weight on absolute spend compared to the initial ticket size.

### Business Action
* **High-Value Acquisition Staging**: Since the first order value dominates CLV prediction, marketing teams should focus budgets on high-ticket product categories (e.g. electronics, small appliances, and furniture) rather than low-value accessories. Acquiring a customer on a high-value category anchors long-term customer value.

---

## 3. Retention Campaign & ROI Simulation

To validate the business utility of our propensity model, we developed a simulation script (`python/retention_simulation.py`) that models an A/B test comparing a baseline churn environment against a targeted coupon campaign.

### Campaign Design
* **Control Group (50% sample)**: Receives no promotional outreach. Natural repeat rate is observed.
* **Treatment Group (50% sample)**: Customers with a repeat purchase propensity score of `≤ 0.15` (high churn risk) are offered a **R$ 15.00 discount coupon** for their next order.
* **Incentive Lift Assumption**: The coupon increases a targeted user's propensity score by a factor of 2.5x.

### Simulation Output
Running the simulation on our historical customer base generates the following projected financial returns:

* **Baseline / Control Repeat Rate**: 16.37%
* **Campaign-Targeted / Treatment Repeat Rate**: 23.18% (+6.81% conversion lift)
* **Incremental Orders Generated**: 3,180 orders
* **Total Campaign Cost (Redeemed Coupons)**: R$ 76,110.00
* **Incremental Revenue Generated**: R$ 525,234.91
* **Net Campaign Profit**: R$ 449,124.91
* **Campaign Return on Investment (ROI)**: **590.10%**

This simulation demonstrates that using the machine learning classifier to target *only* high-risk accounts yields a highly profitable retention campaign compared to blanketing the entire database with promotions.
