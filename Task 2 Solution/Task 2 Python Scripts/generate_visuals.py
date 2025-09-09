# Requirements: pandas, numpy, matplotlib

import os
from pathlib import Path
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt

# ------------------------
# CONFIG
# ------------------------
INPUT_ENG = Path('/Users/macbookpro/Desktop/Task 2/Outputs/SQL Query Outputs/Engagement (Query Output).csv')
INPUT_ARP = Path('/Users/macbookpro/Desktop/Task 2/Outputs/SQL Query Outputs/Daily ARPDAU (Query Output).csv')
OUTDIR = Path('/Users/macbookpro/Desktop/Task 2/Outputs/Plots & Summary Tables')
# ------------------------
# Helpers
# ------------------------
def load_csv_standardized(path: Path) -> pd.DataFrame:
    df = pd.read_csv(path)
    df.columns = [c.strip().lower() for c in df.columns]
    if "dt" in df.columns:
        df["dt"] = pd.to_datetime(df["dt"])
    return df

def ensure_outdir(p: Path):
    p.mkdir(parents=True, exist_ok=True)

# ------------------------
# Main
# ------------------------
def main():
    ensure_outdir(OUTDIR)

    # Load inputs
    df_eng = load_csv_standardized(INPUT_ENG)
    df_arp = load_csv_standardized(INPUT_ARP)

    # ============== E1: Minutes/DAU (daily mean across dates) with 95% CI
    eng_group = df_eng.groupby("variant", as_index=False).agg(
        mean_min_per_dau=("minutes_per_dau", "mean"),
        std_min_per_dau=("minutes_per_dau", "std"),
        n_days=("minutes_per_dau", "count"),
    )
    eng_group["se"] = eng_group["std_min_per_dau"] / np.sqrt(eng_group["n_days"].clip(lower=1))
    eng_group["ci95"] = 1.96 * eng_group["se"]

    plt.figure(figsize=(8, 5))
    x = np.arange(len(eng_group))
    plt.bar(x, eng_group["mean_min_per_dau"])
    plt.errorbar(x, eng_group["mean_min_per_dau"], yerr=eng_group["ci95"], fmt="none", capsize=4)
    plt.xticks(x, eng_group["variant"], rotation=0)
    plt.ylabel("Minutes per DAU (daily mean)")
    plt.title("E1: Minutes/DAU by Variant (±95% CI)")
    plt.tight_layout()
    plt.savefig(OUTDIR / "E1_minutes_per_DAU_with_CI.png")
    plt.close()

    # Save summary table for E1
    eng_group.to_csv(OUTDIR / "E1_summary_minutes_per_DAU.csv", index=False)

    # ============== E2: Minutes mix (camp/level/event) — 100% stacked (sum over the test interval)
    # Convert per-DAU mins to raw minutes per day, then sum
    df_eng["total_minutes"] = df_eng["minutes_per_dau"] * df_eng["dau"]
    df_eng["camp_minutes"]  = df_eng["camp_min_per_dau"]  * df_eng["dau"]
    df_eng["level_minutes"] = df_eng["level_min_per_dau"] * df_eng["dau"]
    df_eng["event_minutes"] = df_eng["event_min_per_dau"] * df_eng["dau"]

    mix = df_eng.groupby("variant", as_index=False).agg(
        camp=("camp_minutes", "sum"),
        level=("level_minutes", "sum"),
        event=("event_minutes", "sum"),
    )
    mix["total"] = mix[["camp", "level", "event"]].sum(axis=1).replace(0, np.nan)
    mix["camp_share"]  = mix["camp"]  / mix["total"]
    mix["level_share"] = mix["level"] / mix["total"]
    mix["event_share"] = mix["event"] / mix["total"]

    plt.figure(figsize=(8, 5))
    x = np.arange(len(mix))
    bottom = np.zeros(len(mix))
    for col in ["camp_share", "level_share", "event_share"]:
        plt.bar(x, mix[col], bottom=bottom, label=col.replace("_share", "").title())
        bottom += mix[col].to_numpy()
    plt.xticks(x, mix["variant"], rotation=0)
    plt.ylim(0, 1)
    plt.ylabel("Share of Minutes")
    plt.title("E2: Minutes Mix (Camp/Level/Event) — 100% Stacked")
    plt.legend()
    plt.tight_layout()
    plt.savefig(OUTDIR / "E2_minutes_mix_stacked.png")
    plt.close()

    # Save shares table
    mix[["variant", "camp_share", "level_share", "event_share"]].to_csv(
        OUTDIR / "E2_minutes_mix_shares.csv", index=False
    )

    # ============== E3: Minutes/DAU by date with 7-day moving average
    df_eng_sorted = df_eng.sort_values(["variant", "dt"]).copy()
    df_eng_sorted["min_per_dau_ma7"] = df_eng_sorted.groupby("variant")["minutes_per_dau"].transform(
        lambda s: s.rolling(7, min_periods=1).mean()
    )

    plt.figure(figsize=(10, 5))
    for v, sub in df_eng_sorted.groupby("variant"):
        plt.plot(sub["dt"], sub["minutes_per_dau"], label=f"{v} (daily)")
        plt.plot(sub["dt"], sub["min_per_dau_ma7"], linestyle="--", label=f"{v} (7d MA)")
    plt.xlabel("Date")
    plt.ylabel("Minutes per DAU")
    plt.title("E3: Minutes/DAU by Date (with 7-day MA)")
    plt.legend(ncol=2)
    plt.tight_layout()
    plt.savefig(OUTDIR / "E3_minutes_per_DAU_timeseries.png")
    plt.close()

    # ============== A1: ARPDAU by date with 7-day MA
    df_arp_sorted = df_arp.sort_values(["variant", "dt"]).copy()
    df_arp_sorted["arpdau_ma7"] = df_arp_sorted.groupby("variant")["arpdau"].transform(
        lambda s: s.rolling(7, min_periods=1).mean()
    )

    plt.figure(figsize=(10, 5))
    for v, sub in df_arp_sorted.groupby("variant"):
        plt.plot(sub["dt"], sub["arpdau"], label=f"{v} (daily)")
        plt.plot(sub["dt"], sub["arpdau_ma7"], linestyle="--", label=f"{v} (7d MA)")
    plt.xlabel("Date")
    plt.ylabel("ARPDAU (USD)")
    plt.title("A1: Calendar ARPDAU by Variant (with 7-day MA)")
    plt.legend(ncol=2)
    plt.tight_layout()
    plt.savefig(OUTDIR / "A1_ARPDAU_timeseries.png")
    plt.close()

    # ============== A3: DAU vs ARPDAU scatter (one point per day per variant)
    plt.figure(figsize=(8, 5))
    for v, sub in df_arp_sorted.groupby("variant"):
        plt.scatter(sub["dau"], sub["arpdau"], label=v, alpha=0.7)
    plt.xlabel("DAU")
    plt.ylabel("ARPDAU (USD)")
    plt.title("A3: DAU vs ARPDAU")
    plt.legend()
    plt.tight_layout()
    plt.savefig(OUTDIR / "A3_DAU_vs_ARPDAU_scatter.png")
    plt.close()

    print(f"Done. Plots + CSVs saved in: {OUTDIR.resolve()}")

if __name__ == "__main__":
    main()
