# Power BI Dashboard Specification — Olist Customer Lifecycle Analytics

## Purpose

This dashboard is designed for executive review. It should tell one coherent story: Olist has strong acquisition scale, but long-term growth depends on retention, service quality, seller quality, and geographic focus.

## Design Principles

- Use a clean, editorial layout with clear hierarchy and minimal clutter.
- Keep the narrative sequential: market overview, retention, operations, sellers, products, geography, and actions.
- Use the same KPI definitions as the documentation and SQL layer.
- Keep the dashboard interactive, but do not bury the main story behind too many slicers.

## Suggested Page Structure

### Page 1: Executive Overview

**Goal:** Give leadership a one-page snapshot of marketplace health.

**KPIs:**
- Total Revenue: R$ 15.4M
- Delivered Orders: 96,478
- Average Order Value: R$ 159.83
- Active Customers: 96,096
- Repeat Purchase Rate: 3.0%
- Late Delivery Rate: 8.11%
- Average Review Score: 4.09

**Visuals:** KPI cards, monthly GMV line chart, top state revenue bar chart, customer lifecycle donut, callout summary box.

**Message:** Growth is real, but retention is the strategic gap.

### Page 2: Revenue & Growth

**Goal:** Show revenue trend, seasonality, and category concentration.

**KPIs:** Monthly GMV, monthly orders, AOV, top category revenue share, repeat-revenue share.

**Visuals:** Line chart, stacked bar by category, Pareto chart for revenue concentration, month-over-month change table.

**Message:** Category mix and repeat purchase matter more than raw acquisition.

### Page 3: Retention & Customer Value

**Goal:** Show customer lifecycle health and value concentration.

**KPIs:** Month-1 retention, Month-3 retention, churn rate, average CLV, median CLV, Champions share of revenue.

**Visuals:** Cohort heatmap, RFM segment bar chart, CLV distribution, churn band funnel, repeat purchase funnel.

**Message:** The customer base decays quickly after first purchase.

### Page 4: Operations & Delivery

**Goal:** Show how service quality drives customer experience.

**KPIs:** On-time delivery rate, late delivery rate, average delivery days, detractor rate, review score gap between late and on-time orders.

**Visuals:** Delivery trend line, late-delivery by state heatmap, review score distribution, late vs. on-time comparison cards.

**Message:** Delivery is a retention lever, not just an operations metric.

### Page 5: Sellers & Marketplace Quality

**Goal:** Show concentration risk and seller performance.

**KPIs:** Top 1% seller revenue share, seller count, average seller review, late rate by seller, seller concentration ratio.

**Visuals:** Seller Pareto chart, top seller leaderboard, seller scorecard table, seller geography map.

**Message:** A small set of sellers drives a large share of revenue and risk.

### Page 6: Products & Basket Behavior

**Goal:** Show category demand and cross-sell opportunities.

**KPIs:** Top category revenue, category concentration, multi-item order rate, top basket pair count.

**Visuals:** Category revenue bar chart, basket pair matrix, price band chart, category share treemap.

**Message:** Home and lifestyle categories create the clearest bundling opportunity.

### Page 7: Geography

**Goal:** Show where demand, revenue, and delivery issues are concentrated.

**KPIs:** Revenue by state, customer share by state, late delivery rate by state, average delivery days by state.

**Visuals:** Filled map, state bar chart, side-by-side demand vs. service chart, top underpenetrated state table.

**Message:** Growth and logistics need to be planned together by geography.

### Page 8: Recommendations

**Goal:** Turn the analysis into an action plan.

**Visuals:** Prioritized initiative table, impact vs. effort matrix, KPI tracker, 30/90/180-day action roadmap.

**Message:** The next best actions are retention, win-back, delivery improvement, loyalty, and cross-sell.

## Core Filters

- Date range
- State
- Category
- Seller state
- Customer segment
- Order status

## Required Measures

- GMV
- AOV
- Repeat purchase rate
- Retention rate by cohort
- CLV
- On-time delivery rate
- Late delivery rate
- Average review score
- Seller revenue share
- Category revenue share

## Layout Guidance

- Use a wide desktop canvas.
- Keep the executive summary page above the fold.
- Put the recommendation page last so it feels like the conclusion of the narrative.
- Use a restrained palette: dark neutral base, one accent color for growth, one for risk, one for emphasis.

## Storytelling Flow

1. What happened?
2. Why did it happen?
3. What is the business risk?
4. What should leadership do next?

## Build Notes

- All KPIs must match the SQL and documentation definitions.
- Use cleaned and derived tables only.
- Avoid using raw geolocation rows directly; aggregate first.
- Keep review score and delivery metrics filtered to delivered orders unless the visual is explicitly about funnel drop-off.