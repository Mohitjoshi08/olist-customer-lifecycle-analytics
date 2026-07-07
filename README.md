# Olist Customer Lifecycle Analytics

A focused portfolio project analyzing customer retention, delivery performance, product mix, seller performance, and geography for the Olist Brazilian e-commerce marketplace.

## Why This Project?

Many e-commerce companies invest heavily in acquisition while overlooking retention. This project investigates whether customer behavior, logistics performance, and marketplace operations reveal opportunities to improve long-term growth.

## Executive Summary

The business has historical e-commerce transaction data but lacks a structured understanding of customer retention, purchasing behavior, and long-term customer value. This project analyzes the complete customer lifecycle to identify opportunities for improving customer retention, CLV, and overall business performance.

## Business Problem

Although the marketplace served 96,096 unique customers, only 3.0% placed another order. This project investigates the operational and behavioral drivers behind that low retention rate to unlock revenue potential.

## Core Insights

| Business Question | Finding | Evidence | Recommendation |
| :--- | :--- | :--- | :--- |
| Why is retention low? | Only 3.0% repeat customers | 2,900 repeat buyers | Loyalty campaigns |
| How do delays impact satisfaction? | Late deliveries hurt scores | 8.11% late rate | Optimize SLA management |
| Which regions drive revenue? | Top 5 states drive 73.2% revenue | SP alone drives 38.3% GMV | Targeted geographic expansion |
| What is the customer value? | Median CLV is R$ 107.78 | CLV distribution | High-value segment focus |

## Repository Structure

```text
python/       - Cleaning, EDA, and advanced analytics
sql/          - Business-focused SQL analysis
notebooks/    - Explorations and validations
processed/    - Summary outputs
models/       - Model metrics
assets/       - Charts and visual snapshots
powerbi/      - Dashboard specification
```

## Tech Stack

- **Languages:** Python, SQL
- **Libraries:** Pandas, NumPy, Matplotlib, Seaborn
- **Tools:** Power BI, MySQL

## Methodology
```text
Business Understanding
        ↓
Data Cleaning
        ↓
Exploratory Data Analysis
        ↓
Feature Engineering
        ↓
SQL Business Analytics
        ↓
Machine Learning
        ↓
Power BI Dashboard
        ↓
Business Recommendations
```
## Project Architecture
```text
Raw CSV Files
      │
      ▼
Python Data Cleaning
      │
      ▼
Feature Engineering
      │
      ├────────► SQL Business Analysis
      │
      ▼
Machine Learning
      │
      ▼
Power BI Dashboard
      │
      ▼
Executive Recommendations
```
## Dashboard Snapshots
*(Insert dashboard images in `assets/dashboard/`)*

## Business Impact

This analysis identified customer retention not acquisition as the primary growth opportunity. The findings support:
- Retention campaign design
- Logistics optimization
- High-value customer targeting
- Regional expansion planning
- Executive KPI monitoring

## Project Limitations

- Dataset covers historical transactions only.
- Customer churn is inferred from purchase inactivity.
- Marketing campaign data is unavailable.
- External economic factors are not included.
- Analysis is limited to observed customer behavior.

## Future Work

- Predict customer churn using ML.
- Forecast customer lifetime value.
- Build recommendation engine.
- Marketing attribution analysis.
- Time-series demand forecasting.
