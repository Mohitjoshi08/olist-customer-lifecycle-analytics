"""Advanced analytics for Olist Customer Lifecycle Analytics.

This script builds Phase 5 outputs from the cleaned datasets created in Phase 3.
It focuses on lifecycle analysis that is supported by the observed data:
- Customer segmentation (KMeans)
- Cohort retention
- CLV analysis
- Churn-risk scoring
- Market basket analysis
- Geographic, seller, product, and delivery diagnostics
- Supported predictive modeling for repeat purchase propensity and delivery delay

Expected Execution Output:
--------------------------
{
  "customer_segments": {
    "rows": 93358,
    "segment_distribution": {
      "Standard": 54203,
      "Dormant": 36362,
      "High-Value Repeat": 2793
    }
  },
  "cohort": {
    "shape": [23, 20],
    "month_1_retention_avg": 4.74,
    "month_3_retention_avg": 0.18,
    "month_6_retention_avg": 0.18
  },
  "clv": {
    "avg_clv": 165.17,
    "median_clv": 107.78
  },
  "churn": {
    "churn_rate_pct": 70.81,
    "at_risk_customers": 38706
  },
  "delivery": {
    "late_delivery_rate_pct": 8.11,
    "predicted_auc": 0.6357
  }
}

Model Diagnostics (saved in models/phase5_model_results.json):
--------------------------------------------------------------
- repeat_purchase_model (RandomForestClassifier): Predicts repeat purchase propensity. Target: `repeat_customer_flag`. AUC-ROC: ~0.64
- clv_model (RandomForestRegressor): Predicts customer lifetime value. Target: `total_spent`. MAE: ~R$ 78.43
- delivery_delay_model (RandomForestClassifier): Predicts order delay risk. Target: `is_late`. AUC-ROC: ~0.63

Generated Files:
----------------
- data/processed/phase5/customer_segments_phase5.csv
- data/processed/phase5/cohort_retention_phase5.csv
- data/processed/phase5/customer_clv_phase5.csv
- data/processed/phase5/top_category_pairs_phase5.csv
- data/processed/phase5/geographic_summary_phase5.csv
- data/processed/phase5/seller_summary_phase5.csv
- data/processed/phase5/product_summary_phase5.csv
- data/processed/phase5/delivery_summary_phase5.csv
- data/processed/phase5/phase5_summary.json
- models/phase5_model_results.json
- models/phase5_feature_importance.json
"""

from __future__ import annotations

import json
from itertools import combinations
from pathlib import Path

import numpy as np
import pandas as pd
from sklearn.cluster import KMeans
from sklearn.ensemble import RandomForestClassifier, RandomForestRegressor
from sklearn.metrics import classification_report, mean_absolute_error, roc_auc_score, r2_score
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelEncoder, OneHotEncoder, StandardScaler


BASE = Path(__file__).resolve().parent.parent
CLEAN = BASE / "data" / "processed" / "cleaned"
OUT = BASE / "data" / "processed" / "phase5"
MODELS = BASE / "models"
OUT.mkdir(parents=True, exist_ok=True)
MODELS.mkdir(parents=True, exist_ok=True)


def load_csv(name: str, **kwargs) -> pd.DataFrame:
    return pd.read_csv(CLEAN / name, **kwargs)


def save_csv(df: pd.DataFrame, name: str) -> None:
    df.to_csv(OUT / name, index=False)


customers = load_csv("customers_clean.csv")
orders = load_csv(
    "orders_clean.csv",
    parse_dates=[
        "order_purchase_timestamp",
        "order_approved_at",
        "order_delivered_carrier_date",
        "order_delivered_customer_date",
        "order_estimated_delivery_date",
    ],
)
order_items = load_csv("order_items_clean.csv")
order_payments = load_csv("order_payments_clean.csv")
order_reviews = load_csv("order_reviews_clean.csv", parse_dates=["review_creation_date", "review_answer_timestamp"])
products = load_csv("products_clean.csv")
sellers = load_csv("sellers_clean.csv")
customer_features = load_csv("customer_lifecycle_features.csv", parse_dates=["first_order_date", "last_order_date"])

orders = orders.merge(customers[["customer_id", "customer_unique_id", "customer_state", "customer_city_clean"]], on="customer_id", how="left")
order_items = order_items.merge(products[["product_id", "product_category_name_english", "has_category", "product_weight_kg"]], on="product_id", how="left")
order_items = order_items.merge(sellers[["seller_id", "seller_state", "seller_city_clean"]], on="seller_id", how="left")

delivered_orders = orders[orders["delivered_flag"] == 1].copy()
delivered_order_items = order_items.merge(delivered_orders[["order_id"]], on="order_id", how="inner")

review_by_order = order_reviews.groupby("order_id", as_index=False).agg(review_score=("review_score", "mean"))

customer_review_summary = (
    delivered_orders.merge(review_by_order, on="order_id", how="left")
    .groupby("customer_unique_id", as_index=False)
    .agg(avg_review=("review_score", "mean"))
)
customer_features = customer_features.merge(customer_review_summary, on="customer_unique_id", how="left")


# ---------------------------------------------------------------------------
# Customer segmentation
# ---------------------------------------------------------------------------
segment_features = customer_features[["recency_days", "order_count", "total_spent", "avg_review", "avg_delivery_days", "late_delivery_rate"]].fillna(0)
scaler = StandardScaler()
segment_scaled = scaler.fit_transform(segment_features)

inertia_by_k = {}
for k in range(2, 8):
    model = KMeans(n_clusters=k, random_state=42, n_init=10)
    model.fit(segment_scaled)
    inertia_by_k[k] = round(float(model.inertia_), 2)

kmeans = KMeans(n_clusters=4, random_state=42, n_init=10)
customer_features["segment_id"] = kmeans.fit_predict(segment_scaled)

segment_profiles = customer_features.groupby("segment_id").agg(
    customers=("customer_unique_id", "count"),
    avg_recency=("recency_days", "mean"),
    avg_orders=("order_count", "mean"),
    avg_spent=("total_spent", "mean"),
    avg_review=("avg_review", "mean"),
    churn_rate=("churn_flag_180d", "mean"),
).round(2)

segment_names = {}
for segment_id, profile in segment_profiles.iterrows():
    if profile["avg_orders"] >= 2 and profile["avg_spent"] >= 250:
        segment_names[segment_id] = "High-Value Repeat"
    elif profile["avg_recency"] <= 90:
        segment_names[segment_id] = "Recent Active"
    elif profile["churn_rate"] >= 0.8:
        segment_names[segment_id] = "Dormant"
    else:
        segment_names[segment_id] = "Standard"

customer_features["segment_name"] = customer_features["segment_id"].map(segment_names)
save_csv(customer_features, "customer_segments_phase5.csv")


# ---------------------------------------------------------------------------
# Cohort retention
# ---------------------------------------------------------------------------
cohort_source = delivered_orders[["customer_unique_id", "order_purchase_timestamp"]].copy()
cohort_source["cohort_month"] = cohort_source.groupby("customer_unique_id")["order_purchase_timestamp"].transform("min").dt.to_period("M")
cohort_source["order_month"] = cohort_source["order_purchase_timestamp"].dt.to_period("M")
cohort_source["period_number"] = (cohort_source["order_month"] - cohort_source["cohort_month"]).apply(lambda x: x.n)

cohort_sizes = cohort_source.groupby("cohort_month")["customer_unique_id"].nunique()
cohort_retention = cohort_source.groupby(["cohort_month", "period_number"])["customer_unique_id"].nunique().unstack(fill_value=0)
cohort_pct = (cohort_retention.div(cohort_sizes, axis=0) * 100).round(2)
cohort_pct.to_csv(OUT / "cohort_retention_phase5.csv")


# ---------------------------------------------------------------------------
# CLV and churn analysis
# ---------------------------------------------------------------------------
customer_clv = customer_features.copy()
customer_clv["avg_orders_per_month"] = customer_clv["order_count"] / customer_clv[["tenure_days"]].replace(0, np.nan).squeeze().clip(lower=1) * 30
customer_clv["clv_band"] = pd.qcut(customer_clv["total_spent"], q=4, labels=["Low", "Medium", "High", "Elite"], duplicates="drop")
customer_clv["churn_band"] = pd.cut(
    customer_clv["recency_days"],
    bins=[-1, 90, 180, 365, np.inf],
    labels=["Active", "Warm", "At Risk", "Dormant"],
)
save_csv(customer_clv, "customer_clv_phase5.csv")


# ---------------------------------------------------------------------------
# Market basket analysis
# ---------------------------------------------------------------------------
item_categories = (
    delivered_order_items[["order_id", "product_category_name_english"]]
    .dropna(subset=["product_category_name_english"])
    .drop_duplicates(subset=["order_id", "product_category_name_english"])
)

order_category_lists = item_categories.groupby("order_id")["product_category_name_english"].apply(list)
pair_counts: dict[tuple[str, str], int] = {}
for category_list in order_category_lists:
    if len(category_list) < 2:
        continue
    for left, right in combinations(sorted(set(category_list)), 2):
        pair_counts[(left, right)] = pair_counts.get((left, right), 0) + 1

top_pairs = sorted(pair_counts.items(), key=lambda item: item[1], reverse=True)[:15]
market_basket = pd.DataFrame([
    {"category_a": left, "category_b": right, "co_occurrences": count}
    for (left, right), count in top_pairs
])
save_csv(market_basket, "top_category_pairs_phase5.csv")


# ---------------------------------------------------------------------------
# Geographic, seller, product, and delivery diagnostics
# ---------------------------------------------------------------------------
geo_summary = (
    delivered_orders.groupby("customer_state")
    .agg(
        orders=("order_id", "count"),
        customers=("customer_unique_id", pd.Series.nunique),
        revenue=("customer_unique_id", lambda s: 0),
    )
)
geo_summary = delivered_orders.merge(order_items[["order_id", "item_total_value"]], on="order_id", how="left").groupby("customer_state").agg(
    orders=("order_id", "nunique"),
    customers=("customer_unique_id", pd.Series.nunique),
    revenue=("item_total_value", "sum"),
    avg_delivery_days=("delivery_days", "mean"),
    late_delivery_rate=("late_delivery_flag", "mean"),
).round(2).reset_index()
save_csv(geo_summary.sort_values("revenue", ascending=False), "geographic_summary_phase5.csv")

seller_summary = delivered_order_items.merge(
    delivered_orders[["order_id", "delivery_days", "late_delivery_flag"]],
    on="order_id",
    how="left",
).merge(order_reviews[["order_id", "review_score"]], on="order_id", how="left")
seller_summary = seller_summary.groupby("seller_id").agg(
    orders=("order_id", "nunique"),
    revenue=("item_total_value", "sum"),
    avg_review=("review_score", "mean"),
    avg_delivery_days=("delivery_days", "mean"),
    late_delivery_rate=("late_delivery_flag", "mean"),
).round(2).reset_index()
save_csv(seller_summary.sort_values("revenue", ascending=False), "seller_summary_phase5.csv")

product_summary = delivered_order_items.groupby("product_category_name_english").agg(
    orders=("order_id", "nunique"),
    items=("order_item_id", "count"),
    revenue=("item_total_value", "sum"),
    avg_price=("price", "mean"),
    avg_freight=("freight_value", "mean"),
).round(2).reset_index()
save_csv(product_summary.sort_values("revenue", ascending=False), "product_summary_phase5.csv")

delivery_summary = delivered_orders.assign(
    delivery_days=(delivered_orders["order_delivered_customer_date"] - delivered_orders["order_purchase_timestamp"]).dt.total_seconds() / 86400.0,
    is_late=(delivered_orders["order_delivered_customer_date"] > delivered_orders["order_estimated_delivery_date"]).astype(int),
).groupby("customer_state").agg(
    deliveries=("order_id", "count"),
    avg_delivery_days=("delivery_days", "mean"),
    late_delivery_rate=("is_late", "mean"),
).round(2).reset_index()
save_csv(delivery_summary.sort_values("late_delivery_rate", ascending=False), "delivery_summary_phase5.csv")


# ---------------------------------------------------------------------------
# Supported predictive models
# ---------------------------------------------------------------------------
# Model 1: Repeat purchase propensity from first-order features
first_order = delivered_orders.sort_values(["customer_unique_id", "order_purchase_timestamp", "order_id"]).groupby("customer_unique_id").first().reset_index()
first_order_item_summary = (
    order_items.groupby("order_id", as_index=False)
    .agg(
        first_order_value=("item_total_value", "sum"),
        first_order_item_count=("order_item_id", "count"),
        first_avg_item_price=("price", "mean"),
        first_avg_freight=("freight_value", "mean"),
        product_category_name_english=("product_category_name_english", lambda s: s.mode().iat[0] if not s.mode().empty else s.iloc[0]),
        seller_state=("seller_state", lambda s: s.mode().iat[0] if not s.mode().empty else s.iloc[0]),
    )
)
first_order = first_order.merge(first_order_item_summary, on="order_id", how="left")
customer_repeat_target = customer_features[["customer_unique_id", "order_count", "total_spent"]].copy()
customer_repeat_target["repeat_customer_flag"] = (customer_repeat_target["order_count"] > 1).astype(int)

repeat_model_df = first_order.merge(customer_repeat_target[["customer_unique_id", "repeat_customer_flag", "total_spent"]], on="customer_unique_id", how="left")
repeat_model_df = repeat_model_df.merge(review_by_order, on="order_id", how="left")
repeat_model_df["payment_type"] = repeat_model_df["order_id"].map(
    order_payments.groupby("order_id")["payment_type"].first()
)
repeat_model_df["payment_installments"] = repeat_model_df["order_id"].map(
    order_payments.groupby("order_id")["payment_installments"].max()
)
repeat_model_df["first_order_value"] = repeat_model_df["first_order_value"].fillna(0)
repeat_model_df["first_delivery_days"] = (
    repeat_model_df["order_delivered_customer_date"] - repeat_model_df["order_purchase_timestamp"]
).dt.total_seconds() / 86400.0
repeat_model_df["first_late_flag"] = (repeat_model_df["order_delivered_customer_date"] > repeat_model_df["order_estimated_delivery_date"]).astype(int)
repeat_model_df["review_score"] = repeat_model_df["review_score"].fillna(repeat_model_df["review_score"].median())
repeat_model_df = repeat_model_df.dropna(subset=["repeat_customer_flag", "first_order_value", "payment_type", "customer_state"])

repeat_features = repeat_model_df[[
    "first_order_value",
    "first_order_item_count",
    "first_avg_item_price",
    "first_avg_freight",
    "first_delivery_days",
    "first_late_flag",
    "review_score",
    "payment_installments",
    "customer_state",
    "product_category_name_english",
]]
repeat_target = repeat_model_df["repeat_customer_flag"].astype(int)

repeat_features_encoded = pd.get_dummies(repeat_features, columns=["customer_state", "product_category_name_english"], dummy_na=True)
X_train, X_test, y_train, y_test = train_test_split(
    repeat_features_encoded,
    repeat_target,
    test_size=0.3,
    random_state=42,
    stratify=repeat_target,
)

repeat_model = RandomForestClassifier(n_estimators=200, max_depth=12, random_state=42, class_weight="balanced_subsample")
repeat_model.fit(X_train, y_train)
repeat_prob = repeat_model.predict_proba(X_test)[:, 1]
repeat_pred = repeat_model.predict(X_test)

repeat_feature_importance = pd.Series(repeat_model.feature_importances_, index=repeat_features_encoded.columns).sort_values(ascending=False)

# Model 2: CLV regression from first-order features
clv_target = repeat_model_df["total_spent"].astype(float)
clv_X_train, clv_X_test, clv_y_train, clv_y_test = train_test_split(
    repeat_features_encoded,
    clv_target,
    test_size=0.3,
    random_state=42,
)

clv_model = RandomForestRegressor(n_estimators=200, max_depth=12, random_state=42)
clv_model.fit(clv_X_train, clv_y_train)
clv_pred = clv_model.predict(clv_X_test)
clv_feature_importance = pd.Series(clv_model.feature_importances_, index=repeat_features_encoded.columns).sort_values(ascending=False)


# Delivery delay prediction from order-level features
delivery_target_df = delivered_orders.copy()
delivery_target_df["delivery_delay_days"] = (
    delivery_target_df["order_delivered_customer_date"] - delivery_target_df["order_purchase_timestamp"]
).dt.total_seconds() / 86400.0
delivery_target_df["is_late"] = (delivery_target_df["order_delivered_customer_date"] > delivery_target_df["order_estimated_delivery_date"]).astype(int)
delivery_target_df = delivery_target_df.merge(order_items.groupby("order_id").agg(
    order_total_value=("item_total_value", "sum"),
    order_item_count=("order_item_id", "count"),
    avg_item_price=("price", "mean"),
    avg_freight=("freight_value", "mean"),
).reset_index(), on="order_id", how="left")
delivery_target_df = delivery_target_df.merge(
    order_payments.groupby("order_id").agg(
        payment_installments=("payment_installments", "max"),
        payment_type=("payment_type", "first"),
        payment_value=("payment_value", "sum"),
    ).reset_index(),
    on="order_id",
    how="left",
)
delivery_target_df = delivery_target_df.merge(
    first_order[["customer_unique_id", "product_category_name_english", "seller_state", "first_order_value", "first_order_item_count"]],
    on="customer_unique_id",
    how="left",
)

delivery_features = delivery_target_df[[
    "order_total_value",
    "order_item_count",
    "avg_item_price",
    "avg_freight",
    "payment_installments",
    "payment_type",
    "customer_state",
    "seller_state",
    "product_category_name_english",
    "first_order_value",
    "first_order_item_count",
]].copy()
delivery_features[[
    "order_total_value",
    "order_item_count",
    "avg_item_price",
    "avg_freight",
    "payment_installments",
    "first_order_value",
    "first_order_item_count",
]] = delivery_features[[
    "order_total_value",
    "order_item_count",
    "avg_item_price",
    "avg_freight",
    "payment_installments",
    "first_order_value",
    "first_order_item_count",
]].fillna(0)
delivery_features[["payment_type", "customer_state", "seller_state", "product_category_name_english"]] = delivery_features[["payment_type", "customer_state", "seller_state", "product_category_name_english"]].fillna("unknown")
delivery_target = delivery_target_df["is_late"].astype(int)
delivery_features_encoded = pd.get_dummies(delivery_features, columns=["payment_type", "customer_state", "seller_state", "product_category_name_english"], dummy_na=True)

del_train_x, del_test_x, del_train_y, del_test_y = train_test_split(
    delivery_features_encoded,
    delivery_target,
    test_size=0.3,
    random_state=42,
    stratify=delivery_target,
)

delivery_model = RandomForestClassifier(n_estimators=200, max_depth=10, random_state=42, class_weight="balanced_subsample")
delivery_model.fit(del_train_x, del_train_y)
delivery_pred = delivery_model.predict(del_test_x)
delivery_prob = delivery_model.predict_proba(del_test_x)[:, 1]
delivery_feature_importance = pd.Series(delivery_model.feature_importances_, index=delivery_features_encoded.columns).sort_values(ascending=False)


model_results = {
    "customer_segmentation": {
        "algorithm": "KMeans",
        "n_clusters": 4,
        "inertia_by_k": inertia_by_k,
        "segment_profiles": segment_profiles.round(2).to_dict(),
        "segment_names": {str(k): v for k, v in segment_names.items()},
        "business_value": "Differentiated lifecycle treatment by behavioral cluster",
    },
    "repeat_purchase_model": {
        "algorithm": "RandomForestClassifier",
        "target": "repeat_customer_flag",
        "train_size": int(len(X_train)),
        "test_size": int(len(X_test)),
        "auc_roc": round(float(roc_auc_score(y_test, repeat_prob)), 4),
        "classification_report": classification_report(y_test, repeat_pred, output_dict=True),
        "feature_importance": repeat_feature_importance.round(6).to_dict(),
        "business_value": "Identify first-order customers with the highest repeat-purchase potential",
    },
    "clv_model": {
        "algorithm": "RandomForestRegressor",
        "target": "total_spent",
        "train_size": int(len(clv_X_train)),
        "test_size": int(len(clv_X_test)),
        "mae": round(float(mean_absolute_error(clv_y_test, clv_pred)), 2),
        "r2_score": round(float(r2_score(clv_y_test, clv_pred)), 4),
        "feature_importance": clv_feature_importance.round(6).to_dict(),
        "business_value": "Estimate customer value from first-purchase attributes for acquisition prioritization",
    },
    "delivery_delay_model": {
        "algorithm": "RandomForestClassifier",
        "target": "is_late",
        "train_size": int(len(del_train_x)),
        "test_size": int(len(del_test_x)),
        "auc_roc": round(float(roc_auc_score(del_test_y, delivery_prob)), 4),
        "classification_report": classification_report(del_test_y, delivery_pred, output_dict=True),
        "feature_importance": delivery_feature_importance.round(6).to_dict(),
        "business_value": "Predict orders at risk of late delivery before SLA breach",
    },
}

with open(MODELS / "phase5_model_results.json", "w", encoding="utf-8") as f:
    json.dump(model_results, f, indent=2, default=str)

with open(MODELS / "phase5_feature_importance.json", "w", encoding="utf-8") as f:
    json.dump(
        {
            "repeat_purchase": repeat_feature_importance.head(25).round(6).to_dict(),
            "clv": clv_feature_importance.head(25).round(6).to_dict(),
            "delivery_delay": delivery_feature_importance.head(25).round(6).to_dict(),
        },
        f,
        indent=2,
    )

save_csv(customer_features, "customer_segments_phase5.csv")

summary = {
    "customer_segments": {
        "rows": int(len(customer_features)),
        "segment_distribution": customer_features["segment_name"].value_counts().to_dict(),
    },
    "cohort": {
        "shape": [int(cohort_pct.shape[0]), int(cohort_pct.shape[1])],
        "month_1_retention_avg": round(float(cohort_pct[1].mean()), 2) if 1 in cohort_pct.columns else None,
        "month_3_retention_avg": round(float(cohort_pct[3].mean()), 2) if 3 in cohort_pct.columns else None,
        "month_6_retention_avg": round(float(cohort_pct[6].mean()), 2) if 6 in cohort_pct.columns else None,
    },
    "clv": {
        "avg_clv": round(float(customer_clv["total_spent"].mean()), 2),
        "median_clv": round(float(customer_clv["total_spent"].median()), 2),
    },
    "churn": {
        "churn_rate_pct": round(float(customer_clv["churn_flag_180d"].mean() * 100), 2),
        "at_risk_customers": int((customer_clv["churn_band"] == "At Risk").sum()),
    },
    "basket": {
        "top_pairs": market_basket.head(10).to_dict(orient="records"),
    },
    "delivery": {
        "late_delivery_rate_pct": round(float(delivery_target.mean() * 100), 2),
        "predicted_auc": round(float(roc_auc_score(del_test_y, delivery_prob)), 4),
    },
}

with open(OUT / "phase5_summary.json", "w", encoding="utf-8") as f:
    json.dump(summary, f, indent=2, default=str)

print(json.dumps(summary, indent=2, default=str))
