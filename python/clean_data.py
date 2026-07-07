"""Clean and standardize the Olist source datasets for analysis.

Expected Execution Output:
--------------------------
{
  "customers_rows": 99441,
  "orders_rows": 99441,
  "order_items_rows": 112650,
  "payments_rows": 103886,
  "reviews_rows": 99224,
  "products_rows": 32951,
  "sellers_rows": 3095,
  "geolocation_rows": 19023,
  "customer_features_rows": 93358,
  "delivered_orders": 96478,
  "late_delivery_rate": 8.11
}

Generated Files (saved to data/processed/cleaned/):
---------------------------------------------
- customers_clean.csv
- orders_clean.csv
- order_items_clean.csv
- order_payments_clean.csv
- order_reviews_clean.csv
- products_clean.csv
- sellers_clean.csv
- geolocation_clean.csv
- product_category_name_translation_clean.csv
- customer_lifecycle_features.csv
- data/processed/cleaning_audit.json
"""

from __future__ import annotations

import json
import unicodedata
from pathlib import Path

import numpy as np
import pandas as pd


BASE = Path(__file__).resolve().parent.parent
RAW = BASE / "data" / "raw"
PROCESSED = BASE / "data" / "processed"
CLEAN = PROCESSED / "cleaned"
CLEAN.mkdir(parents=True, exist_ok=True)


def standardize_text(value: object) -> object:
    if pd.isna(value):
        return np.nan
    text = str(value).strip().lower()
    text = unicodedata.normalize("NFKD", text).encode("ascii", "ignore").decode("ascii")
    text = " ".join(text.split())
    return text


def read_csv(name: str, **kwargs) -> pd.DataFrame:
    return pd.read_csv(RAW / name, **kwargs)


def save(df: pd.DataFrame, name: str) -> None:
    df.to_csv(CLEAN / name, index=False)


customers = read_csv("olist_customers_dataset.csv")
orders = read_csv(
    "olist_orders_dataset.csv",
    parse_dates=[
        "order_purchase_timestamp",
        "order_approved_at",
        "order_delivered_carrier_date",
        "order_delivered_customer_date",
        "order_estimated_delivery_date",
    ],
)
order_items = read_csv("olist_order_items_dataset.csv")
order_payments = read_csv("olist_order_payments_dataset.csv")
order_reviews = read_csv(
    "olist_order_reviews_dataset.csv",
    parse_dates=["review_creation_date", "review_answer_timestamp"],
)
products = read_csv("olist_products_dataset.csv")
sellers = read_csv("olist_sellers_dataset.csv")
geolocation = read_csv("olist_geolocation_dataset.csv")
translation = read_csv("product_category_name_translation.csv")


customers_clean = customers.copy()
customers_clean["customer_city_clean"] = customers_clean["customer_city"].map(standardize_text)
customers_clean["customer_zip_code_prefix"] = customers_clean["customer_zip_code_prefix"].astype(str).str.zfill(5)
customers_clean["customer_state"] = customers_clean["customer_state"].str.upper()

orders_clean = orders.copy()
orders_clean["order_purchase_month"] = orders_clean["order_purchase_timestamp"].dt.to_period("M").astype(str)
orders_clean["order_purchase_year"] = orders_clean["order_purchase_timestamp"].dt.year
orders_clean["order_purchase_weekday"] = orders_clean["order_purchase_timestamp"].dt.day_name()
orders_clean["delivered_flag"] = orders_clean["order_status"].eq("delivered").astype(int)
orders_clean["late_delivery_flag"] = (
    orders_clean["order_delivered_customer_date"] > orders_clean["order_estimated_delivery_date"]
).astype("Int64")
orders_clean["delivery_days"] = (
    orders_clean["order_delivered_customer_date"] - orders_clean["order_purchase_timestamp"]
).dt.days
orders_clean["approval_days"] = (
    orders_clean["order_approved_at"] - orders_clean["order_purchase_timestamp"]
).dt.total_seconds() / 86400
orders_clean["carrier_days"] = (
    orders_clean["order_delivered_carrier_date"] - orders_clean["order_approved_at"]
).dt.total_seconds() / 86400

order_items_clean = order_items.copy()
order_items_clean["item_total_value"] = order_items_clean["price"] + order_items_clean["freight_value"]
order_items_clean["price_per_freight_ratio"] = order_items_clean["price"] / order_items_clean["freight_value"].replace(0, np.nan)

order_payments_clean = order_payments.copy()
order_payments_clean["payment_type"] = order_payments_clean["payment_type"].str.lower()

order_reviews_clean = order_reviews.copy()
order_reviews_clean["has_review_text"] = (
    order_reviews_clean[["review_comment_title", "review_comment_message"]].notna().any(axis=1).astype(int)
)

translation_clean = translation.copy()
translation_clean["product_category_name"] = translation_clean["product_category_name"].str.lower()
translation_clean["product_category_name_english"] = translation_clean["product_category_name_english"].str.lower()

products_clean = products.merge(translation_clean, on="product_category_name", how="left")
products_clean["product_category_name"] = products_clean["product_category_name"].str.lower()
products_clean["product_category_name_english"] = products_clean["product_category_name_english"].fillna("unknown")
products_clean["has_category"] = products_clean["product_category_name"].notna().astype(int)
products_clean["product_weight_kg"] = products_clean["product_weight_g"] / 1000

sellers_clean = sellers.copy()
sellers_clean["seller_city_clean"] = sellers_clean["seller_city"].map(standardize_text)
sellers_clean["seller_state"] = sellers_clean["seller_state"].str.upper()
sellers_clean["seller_zip_code_prefix"] = sellers_clean["seller_zip_code_prefix"].astype(str).str.zfill(5)

geolocation_clean = (
    geolocation.assign(
        geolocation_city_clean=geolocation["geolocation_city"].map(standardize_text),
        geolocation_state=geolocation["geolocation_state"].str.upper(),
        geolocation_zip_code_prefix=geolocation["geolocation_zip_code_prefix"].astype(str).str.zfill(5),
    )
    .groupby(["geolocation_zip_code_prefix", "geolocation_state"], as_index=False)
    .agg(
        geolocation_lat=("geolocation_lat", "mean"),
        geolocation_lng=("geolocation_lng", "mean"),
        geolocation_city_clean=("geolocation_city_clean", lambda s: s.mode().iat[0] if not s.mode().empty else s.iloc[0]),
    )
)

delivered_orders = orders_clean.loc[orders_clean["delivered_flag"] == 1, [
    "order_id",
    "customer_id",
    "order_purchase_timestamp",
    "order_purchase_month",
    "order_status",
    "order_delivered_customer_date",
    "order_estimated_delivery_date",
    "delivery_days",
    "late_delivery_flag",
]]

order_item_revenue = order_items_clean.assign(order_total_value=lambda df: df["item_total_value"]).groupby("order_id", as_index=False).agg(
    order_item_count=("order_item_id", "count"),
    order_price=("price", "sum"),
    order_freight=("freight_value", "sum"),
    order_total_value=("item_total_value", "sum"),
)

customer_lifecycle_features = (
    delivered_orders.merge(customers_clean[["customer_id", "customer_unique_id", "customer_state", "customer_city_clean"]], on="customer_id", how="left")
    .merge(order_item_revenue, on="order_id", how="left")
)
customer_lifecycle_features["customer_purchase_rank"] = customer_lifecycle_features.groupby("customer_unique_id")["order_purchase_timestamp"].rank(method="first")

customer_lifecycle_summary = (
    customer_lifecycle_features.groupby("customer_unique_id", as_index=False)
    .agg(
        first_order_date=("order_purchase_timestamp", "min"),
        last_order_date=("order_purchase_timestamp", "max"),
        order_count=("order_id", "nunique"),
        total_spent=("order_total_value", "sum"),
        avg_order_value=("order_total_value", "mean"),
        avg_delivery_days=("delivery_days", "mean"),
        late_delivery_rate=("late_delivery_flag", "mean"),
        state=("customer_state", "first"),
        city=("customer_city_clean", "first"),
    )
)
reference_date = orders_clean["order_purchase_timestamp"].max() + pd.Timedelta(days=1)
customer_lifecycle_summary["recency_days"] = (reference_date - customer_lifecycle_summary["last_order_date"]).dt.days
customer_lifecycle_summary["tenure_days"] = (
    customer_lifecycle_summary["last_order_date"] - customer_lifecycle_summary["first_order_date"]
).dt.days
customer_lifecycle_summary["repeat_customer_flag"] = (customer_lifecycle_summary["order_count"] > 1).astype(int)
customer_lifecycle_summary["churn_flag_180d"] = (customer_lifecycle_summary["recency_days"] > 180).astype(int)

save(customers_clean, "customers_clean.csv")
save(orders_clean, "orders_clean.csv")
save(order_items_clean, "order_items_clean.csv")
save(order_payments_clean, "order_payments_clean.csv")
save(order_reviews_clean, "order_reviews_clean.csv")
save(products_clean, "products_clean.csv")
save(sellers_clean, "sellers_clean.csv")
save(geolocation_clean, "geolocation_clean.csv")
save(translation_clean, "product_category_name_translation_clean.csv")
save(customer_lifecycle_summary, "customer_lifecycle_features.csv")

audit_summary = {
    "customers_rows": len(customers_clean),
    "orders_rows": len(orders_clean),
    "order_items_rows": len(order_items_clean),
    "payments_rows": len(order_payments_clean),
    "reviews_rows": len(order_reviews_clean),
    "products_rows": len(products_clean),
    "sellers_rows": len(sellers_clean),
    "geolocation_rows": len(geolocation_clean),
    "customer_features_rows": len(customer_lifecycle_summary),
    "delivered_orders": int(orders_clean["delivered_flag"].sum()),
    "late_delivery_rate": round(float(orders_clean.loc[orders_clean["delivered_flag"] == 1, "late_delivery_flag"].mean() * 100), 2),
}

with open(PROCESSED / "cleaning_audit.json", "w", encoding="utf-8") as f:
    json.dump(audit_summary, f, indent=2, default=str)

print(json.dumps(audit_summary, indent=2))