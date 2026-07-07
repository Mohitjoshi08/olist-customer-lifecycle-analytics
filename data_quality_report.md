# Data Quality Report

## Duplicate Records
- **Geolocation:** Identified and removed 261,831 duplicates.

## Missing Values
- **Products:** 610 products (1.85%) missing category names. 
  *Decision:* Retained to preserve transactional integrity; treated as 'Unknown' when required.
- **Orders:** `order_delivered_customer_date` has 2,965 missing values. 
  *Decision:* Most are expected business outcomes for non-delivered statuses. 8 delivered orders have missing timestamps; treated as isolated anomalies and excluded only from delivery-date calculations.
- **Order Carrier Date:** `order_delivered_carrier_date` has 1,783 missing values. 
  *Decision:* Most represent orders that did not reach the carrier stage. 2 delivered orders have missing timestamps; treated as isolated anomalies.
- **Reviews:** `review_comment_title` (87,656) and `review_comment_message` (58,247) have missing values.
  *Decision:* Retained; absence of comment text is a valid customer behavior (no review text provided).

## Invalid Dates
Detected structural invalidity in date sequences (e.g., delivered date before purchase date).
*Decision:* Excluded invalid rows to ensure analysis integrity.

## Outliers
Minor outliers in `order_total_value` detected.
*Decision:* Kept, as they represent genuine high-value orders and not data entry errors.
