"""Run EDA on the cleaned Olist datasets and save figures plus summary metrics.

Expected Execution Output:
--------------------------
{
  "analysis_period": {
    "start": "2016-09-04 21:15:19",
    "end": "2018-10-17 17:30:18"
  },
  "orders": 99441,
  "delivered_orders": 96478,
  "delivery_rate_pct": 97.02,
  "unique_customers": 96096,
  "gmv": 15419773.75,
  "aov": 159.83,
  "median_order_value": 105.28,
  "avg_review_score": 4.09,
  "late_delivery_rate_pct": 8.11,
  "single_order_customer_pct": 97.0,
  "repeat_customer_pct": 3.0,
  "top_states": {
    "SP": 41746,
    "RJ": 12852,
    "MG": 11635,
    "RS": 5466,
    "PR": 5045
  },
  "payment_mix": {
    "credit_card": 73.92,
    "boleto": 19.04,
    "voucher": 5.56,
    "debit_card": 1.47
  },
  "top_categories": {
    "health_beauty": 1412089.53,
    "watches_gifts": 1264333.12,
    "bed_bath_table": 1225209.26,
    "sports_leisure": 1118256.91,
    "computers_accessories": 1032723.77
  }
}

Generated Visualizations (saved to assets/screenshots/):
-------------------------------------------------------
- monthly_gmv_trend.png
- state_revenue.png
- review_score_distribution.png
- payment_mix.png
- seller_revenue.png
- category_revenue.png
- cohort_retention_heatmap.png
- customer_recency_segments.png

Generated JSON file:
--------------------
- data/processed/eda/eda_metrics.json
"""

from __future__ import annotations

import json
from itertools import combinations
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import seaborn as sns


BASE = Path(__file__).resolve().parent.parent
CLEAN = BASE / "data" / "processed" / "cleaned"
OUT = BASE / "data" / "processed" / "eda"
FIG = BASE / "assets" / "screenshots"
OUT.mkdir(parents=True, exist_ok=True)
FIG.mkdir(parents=True, exist_ok=True)

sns.set_theme(style="whitegrid", palette="muted")
plt.rcParams.update({"figure.figsize": (11, 6), "figure.dpi": 150, "savefig.bbox": "tight"})


def savefig(filename: str) -> None:
    plt.savefig(FIG / filename)
    plt.close()


customers = pd.read_csv(CLEAN / "customers_clean.csv")
orders = pd.read_csv(CLEAN / "orders_clean.csv", parse_dates=["order_purchase_timestamp", "order_approved_at", "order_delivered_carrier_date", "order_delivered_customer_date", "order_estimated_delivery_date"])
order_items = pd.read_csv(CLEAN / "order_items_clean.csv")
order_payments = pd.read_csv(CLEAN / "order_payments_clean.csv")
order_reviews = pd.read_csv(CLEAN / "order_reviews_clean.csv", parse_dates=["review_creation_date", "review_answer_timestamp"])
products = pd.read_csv(CLEAN / "products_clean.csv")
sellers = pd.read_csv(CLEAN / "sellers_clean.csv")
customer_features = pd.read_csv(CLEAN / "customer_lifecycle_features.csv", parse_dates=["first_order_date", "last_order_date"])

order_items["order_total_value"] = order_items["item_total_value"]
order_revenue = order_items.groupby("order_id", as_index=False).agg(order_total_value=("order_total_value", "sum"))
delivered = orders[orders["delivered_flag"] == 1].merge(order_revenue, on="order_id", how="left")
delivered["purchase_month"] = pd.to_datetime(delivered["order_purchase_timestamp"]).dt.to_period("M").astype(str)

metrics = {
    "analysis_period": {
        "start": str(pd.to_datetime(orders["order_purchase_timestamp"]).min()),
        "end": str(pd.to_datetime(orders["order_purchase_timestamp"]).max()),
    },
    "orders": int(len(orders)),
    "delivered_orders": int(delivered.shape[0]),
    "delivery_rate_pct": round(delivered.shape[0] / len(orders) * 100, 2),
    "unique_customers": int(customers["customer_unique_id"].nunique()),
    "gmv": round(float(delivered["order_total_value"].sum()), 2),
    "aov": round(float(delivered["order_total_value"].mean()), 2),
    "median_order_value": round(float(delivered["order_total_value"].median()), 2),
    "avg_review_score": round(float(order_reviews["review_score"].mean()), 2),
    "late_delivery_rate_pct": round(float(delivered["late_delivery_flag"].mean() * 100), 2),
    "single_order_customer_pct": round(float((customer_features["order_count"] == 1).mean() * 100), 2),
    "repeat_customer_pct": round(float((customer_features["order_count"] > 1).mean() * 100), 2),
    "top_states": customers["customer_state"].value_counts().head(5).to_dict(),
    "payment_mix": order_payments["payment_type"].value_counts(normalize=True).round(4).mul(100).to_dict(),
    "top_categories": {},
}

monthly = delivered.groupby("purchase_month", as_index=False)["order_total_value"].sum()
fig, ax = plt.subplots()
ax.plot(monthly["purchase_month"], monthly["order_total_value"] / 1_000_000, marker="o", color="#2E86AB")
ax.set_title("Monthly GMV Trend")
ax.set_xlabel("Month")
ax.set_ylabel("GMV (R$ millions)")
ax.tick_params(axis="x", rotation=45)
savefig("monthly_gmv_trend.png")

fig, ax = plt.subplots()
state_rev = delivered.merge(customers[["customer_id", "customer_state"]], on="customer_id", how="left").groupby("customer_state")["order_total_value"].sum().sort_values(ascending=True).tail(10)
state_rev.plot(kind="barh", ax=ax, color="#F18F01")
ax.set_title("Top 10 States by Revenue")
ax.set_xlabel("Revenue (BRL)")
savefig("state_revenue.png")

fig, ax = plt.subplots()
review_scores = order_reviews["review_score"].value_counts().sort_index()
review_scores.plot(kind="bar", ax=ax, color="#A23B72")
ax.set_title("Review Score Distribution")
ax.set_xlabel("Review Score")
ax.set_ylabel("Orders")
savefig("review_score_distribution.png")

fig, ax = plt.subplots()
payment_mix = order_payments["payment_type"].value_counts()
ax.pie(payment_mix.values, labels=payment_mix.index, autopct="%1.1f%%", colors=sns.color_palette("Pastel1"))
ax.set_title("Payment Type Distribution")
savefig("payment_mix.png")

fig, ax = plt.subplots()
seller_revenue = (
    delivered.merge(order_items[["order_id", "seller_id", "item_total_value"]], on="order_id", how="left")
    .groupby("seller_id")["item_total_value"]
    .sum()
    .sort_values(ascending=True)
    .tail(15)
)
seller_revenue.plot(kind="barh", ax=ax, color="#4C72B0")
ax.set_title("Top Sellers by Revenue")
ax.set_xlabel("Revenue (BRL)")
savefig("seller_revenue.png")

fig, ax = plt.subplots()
category_revenue = (
    delivered.merge(order_items[["order_id", "product_id", "item_total_value"]], on="order_id", how="left")
    .merge(products[["product_id", "product_category_name_english"]], on="product_id", how="left")
    .groupby("product_category_name_english")["item_total_value"].sum().sort_values(ascending=False).head(10)
)
category_revenue.plot(kind="bar", ax=ax, color="#55A868")
ax.set_title("Top Categories by Revenue")
ax.set_xlabel("Category")
ax.set_ylabel("Revenue (BRL)")
ax.tick_params(axis="x", rotation=45)
savefig("category_revenue.png")
metrics["top_categories"] = category_revenue.round(2).to_dict()

fig, ax = plt.subplots()
cohort_source = delivered.merge(customers[["customer_id", "customer_unique_id"]], on="customer_id", how="left")
cohort_source["cohort_month"] = cohort_source.groupby("customer_unique_id")["order_purchase_timestamp"].transform("min").dt.to_period("M")
cohort_source["order_month"] = cohort_source["order_purchase_timestamp"].dt.to_period("M")
cohort_source["period_number"] = (cohort_source["order_month"] - cohort_source["cohort_month"]).apply(lambda x: x.n)
cohort_sizes = cohort_source.groupby("cohort_month")["customer_unique_id"].nunique()
cohort_retention = cohort_source.groupby(["cohort_month", "period_number"])["customer_unique_id"].nunique().unstack(fill_value=0)
cohort_pct = cohort_retention.div(cohort_sizes, axis=0).round(4) * 100
sns.heatmap(cohort_pct.iloc[:12, :8], annot=True, fmt=".1f", cmap="YlOrRd", ax=ax, cbar_kws={"label": "Retention %"})
ax.set_title("Cohort Retention Heatmap")
ax.set_xlabel("Months Since First Purchase")
ax.set_ylabel("Cohort Month")
savefig("cohort_retention_heatmap.png")

fig, ax = plt.subplots()
rfm_source = customer_features.copy()
rfm_source["segment"] = pd.cut(rfm_source["recency_days"], bins=[-1, 90, 180, 365, np.inf], labels=["Recent", "Warm", "At Risk", "Lost"])
rfm_source["segment"].value_counts().sort_index().plot(kind="bar", ax=ax, color="#937860")
ax.set_title("Customer Recency Segments")
ax.set_xlabel("Segment")
ax.set_ylabel("Customers")
savefig("customer_recency_segments.png")

with open(OUT / "eda_metrics.json", "w", encoding="utf-8") as f:
    json.dump(metrics, f, indent=2, default=str)

print(json.dumps(metrics, indent=2, default=str))