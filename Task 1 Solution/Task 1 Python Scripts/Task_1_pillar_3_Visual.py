# Pillar 3 — Cohort-based unit economics: load, summarize, visualize
# Run this as a single script. It creates PNG plots + summary CSVs.

import os
from pathlib import Path
import math
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt

# ------------------------- CONFIG ---------------------------------------------
CSV_PATH = Path('/Users/macbookpro/Desktop/Task 1/Task_1_Pillar_3/LTV & CPI & Revenue.csv')

# Output folder next to your CSV
OUT_DIR = CSV_PATH.parent / "Pillar 3 Summary Tables & Plots"
OUT_DIR.mkdir(parents=True, exist_ok=True)

# Benchmarks
BENCHMARKS = {7: 0.33, 14: 0.60, 30: 1.00}

# Plot options
TOP_N_MARKETS = 10   # for top/bottom charts
MAX_POINTS_SCATTER = 250  # cap to keep scatter readable
plt.rcParams["figure.dpi"] = 140

# ------------------------- LOAD -----------------------------------------------
df = pd.read_csv(CSV_PATH)

# Basic cleanup
# Ensure expected columns exist
expected_cols = {
    "install_date","country","platform","network","day","installs",
    "spend_usd","cpi","cum_revenue_usd","ltv_per_user","roas","ltv_to_cpi"
}
missing = expected_cols - set(df.columns)
if missing:
    raise ValueError(f"Missing expected columns in CSV: {missing}")

# Types
df["install_date"] = pd.to_datetime(df["install_date"], errors="coerce")
df["day"] = pd.to_numeric(df["day"], errors="coerce").astype("Int64")
for col in ["installs","spend_usd","cpi","cum_revenue_usd","ltv_per_user","roas","ltv_to_cpi"]:
    df[col] = pd.to_numeric(df[col], errors="coerce")

# Payback flags vs benchmarks
def flag(row):
    b = BENCHMARKS.get(int(row["day"])) if not pd.isna(row["day"]) else None
    if b is None or pd.isna(row["ltv_to_cpi"]):
        return None
    return "PASS" if row["ltv_to_cpi"] >= b else "FAIL"

df["benchmark_target"] = df["day"].map(BENCHMARKS)
df["payback_flag"] = df.apply(flag, axis=1)

# Helper: spend-weighted means (avoid tiny cohorts dominating)
def weighted_mean(x, value_col, weight_col):
    w = x[weight_col].fillna(0).clip(lower=0)
    v = x[value_col]
    if w.sum() == 0 or v.isna().all():
        return np.nan
    return (v * w).sum() / w.sum()

# ------------------------- SUMMARIES TO CSV -----------------------------------
# Pass-rate (share of cohorts meeting benchmark) by platform/network at D7 and D30
def pass_rate(df_in, day_val):
    sub = df_in[df_in["day"] == day_val].dropna(subset=["payback_flag"])
    if sub.empty:
        return pd.DataFrame(columns=["platform","network","pass_rate","n"])
    g = sub.groupby(["platform","network"], as_index=False).agg(
        n=("payback_flag","size"),
        passes=("payback_flag", lambda s: (s=="PASS").sum())
    )
    g["pass_rate"] = g["passes"]/g["n"]
    g["day"] = day_val
    return g[["day","platform","network","n","passes","pass_rate"]]

pr7  = pass_rate(df, 7)
pr30 = pass_rate(df, 30)
pr_all = pd.concat([pr7, pr30], ignore_index=True)
pr_all.to_csv(OUT_DIR / "pass_rates_by_platform_network.csv", index=False)

# Country x platform D7 LTV/CPI (spend-weighted)
d7 = df[df["day"] == 7].copy()
agg_d7 = (
    d7.groupby(["country","platform"], as_index=False)
      .apply(lambda x: pd.Series({
          "ltv_to_cpi_w": weighted_mean(x, "ltv_to_cpi", "spend_usd"),
          "cpi_w":         weighted_mean(x, "cpi", "spend_usd"),
          "installs_sum":  x["installs"].sum(),
          "spend_sum":     x["spend_usd"].sum()
      }))
)
agg_d7.to_csv(OUT_DIR / "d7_country_platform_weighted.csv", index=False)

# ------------------------- PLOTS ----------------------------------------------
def savefig(name):
    path = OUT_DIR / f"{name}.png"
    plt.tight_layout()
    plt.savefig(path, bbox_inches="tight")
    plt.show()
    print(f"Saved: {path}")

# 1) ROAS trajectories by platform (spend-weighted, across all markets)
roas_w = (
    df.groupby(["platform","day"], as_index=False)
      .apply(lambda x: pd.Series({"roas_w": weighted_mean(x, "roas", "spend_usd")}))
      .sort_values(["platform","day"])
)

for platform, g in roas_w.groupby("platform"):
    plt.figure()
    plt.plot(g["day"], g["roas_w"], marker="o")
    plt.title(f"ROAS by Day — {platform} (spend-weighted)")
    plt.xlabel("Day (D1, D7, D14, D30)")
    plt.ylabel("ROAS (cum revenue / spend)")
    plt.grid(True, alpha=0.3)
    savefig(f"01_roas_by_day_{platform}")

# 2) LTV/CPI trajectories by platform with horizontal benchmark lines
ltvcpi_w = (
    df.groupby(["platform","day"], as_index=False)
      .apply(lambda x: pd.Series({"ratio_w": weighted_mean(x, "ltv_to_cpi", "spend_usd")}))
      .sort_values(["platform","day"])
)

for platform, g in ltvcpi_w.groupby("platform"):
    plt.figure()
    plt.plot(g["day"], g["ratio_w"], marker="o")
    # Benchmarks as horizontal lines
    if 7 in BENCHMARKS:  plt.axhline(BENCHMARKS[7], linestyle="--", linewidth=1)
    if 14 in BENCHMARKS: plt.axhline(BENCHMARKS[14], linestyle="--", linewidth=1)
    if 30 in BENCHMARKS: plt.axhline(BENCHMARKS[30], linestyle="--", linewidth=1)
    plt.title(f"LTV/CPI by Day — {platform} (spend-weighted)")
    plt.xlabel("Day (D1, D7, D14, D30)")
    plt.ylabel("LTV per user / CPI")
    plt.grid(True, alpha=0.3)
    savefig(f"02_ltv_to_cpi_by_day_{platform}")

# 3) Top/Bottom countries by D7 LTV/CPI for each platform (spend-weighted)
for platform in agg_d7["platform"].dropna().unique():
    sub = agg_d7[agg_d7["platform"] == platform].dropna(subset=["ltv_to_cpi_w"])
    if sub.empty:
        continue
    top = sub.nlargest(TOP_N_MARKETS, "ltv_to_cpi_w")
    bot = sub.nsmallest(TOP_N_MARKETS, "ltv_to_cpi_w")

    # Top
    plt.figure(figsize=(8, max(3, 0.35*len(top))))
    order = top.sort_values("ltv_to_cpi_w", ascending=True)
    plt.barh(order["country"], order["ltv_to_cpi_w"])
    if 7 in BENCHMARKS: plt.axvline(BENCHMARKS[7], linestyle="--", linewidth=1)
    plt.title(f"Top {len(top)} Countries by D7 LTV/CPI — {platform}")
    plt.xlabel("D7 LTV per user / CPI (spend-weighted)")
    savefig(f"03_top_countries_d7_ltv_to_cpi_{platform}")

    # Bottom
    plt.figure(figsize=(8, max(3, 0.35*len(bot))))
    order = bot.sort_values("ltv_to_cpi_w", ascending=True)
    plt.barh(order["country"], order["ltv_to_cpi_w"])
    if 7 in BENCHMARKS: plt.axvline(BENCHMARKS[7], linestyle="--", linewidth=1)
    plt.title(f"Bottom {len(bot)} Countries by D7 LTV/CPI — {platform}")
    plt.xlabel("D7 LTV per user / CPI (spend-weighted)")
    savefig(f"04_bottom_countries_d7_ltv_to_cpi_{platform}")

# 4) CPI vs LTV per user (D7) — bubble scatter with benchmark diagonals (ratio lines)
#    Show up to MAX_POINTS_SCATTER biggest cohorts by installs for readability.
d7_scatter = d7.copy()
d7_scatter["size"] = (d7_scatter["installs"].fillna(0).clip(lower=0)) ** 0.5 * 4 + 10  # gentle scaling
d7_scatter = d7_scatter.sort_values("installs", ascending=False).head(MAX_POINTS_SCATTER)

plt.figure()
plt.scatter(d7_scatter["cpi"], d7_scatter["ltv_per_user"], s=d7_scatter["size"], alpha=0.6)
# Ratio guide lines: y = r * x
xmax = np.nanpercentile(d7_scatter["cpi"], 98) if not d7_scatter["cpi"].dropna().empty else 1.0
xs = np.linspace(0, xmax, 100)
plt.plot(xs, xs * 1.0, linestyle="--", linewidth=1)   # full payback
plt.plot(xs, xs * 0.33, linestyle="--", linewidth=1)  # 33% by D7
plt.title("D7 CPI vs LTV per User (bubble size ~ installs)")
plt.xlabel("CPI (USD)")
plt.ylabel("D7 LTV per user (USD)")
plt.grid(True, alpha=0.3)
savefig("05_scatter_cpi_vs_ltv_d7")

# 5) Pass rate by network (D7 and D30) — bars
def bar_pass_rate(day_val):
    sub = pr_all[pr_all["day"] == day_val].copy()
    if sub.empty:
        return
    sub = sub.sort_values("pass_rate", ascending=True)
    plt.figure(figsize=(8, max(3, 0.35*len(sub))))
    labels = sub["platform"] + " | " + sub["network"]
    plt.barh(labels, sub["pass_rate"])
    plt.title(f"Payback PASS rate by platform|network — D{day_val}")
    plt.xlabel("Share of cohorts meeting benchmark")
    savefig(f"06_pass_rate_network_D{day_val}")

bar_pass_rate(7)
bar_pass_rate(30)

# 6) Optional: platform-level CPI and LTV per user distributions at D7
for metric in ["cpi","ltv_per_user"]:
    plt.figure()
    for platform in d7["platform"].dropna().unique():
        vals = d7.loc[d7["platform"]==platform, metric].dropna()
        vals = vals[~np.isinf(vals)]
        if len(vals) == 0: 
            continue
        # Simple KDE-ish (Kernel Density Estimation) histogram using matplotlib (no seaborn)
        plt.hist(vals, bins=30, alpha=0.5, label=platform)  # default colors
    plt.title(f"D7 distribution — {metric}")
    plt.xlabel(metric)
    plt.ylabel("Count of cohorts")
    plt.legend()
    savefig(f"07_dist_D7_{metric}")

print(f"\nAll outputs in: {OUT_DIR}\n")
