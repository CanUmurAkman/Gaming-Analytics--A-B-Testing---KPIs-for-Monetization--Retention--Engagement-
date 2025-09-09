#!/usr/bin/env python3
from pathlib import Path
import pandas as pd
import matplotlib.pyplot as plt

# ===== CONFIG =====
INPUT_CSV = Path("/Users/macbookpro/Desktop/Task 1/Task 1 | Pillar 2/Pillar 2.1 |Monetization KPIs.csv")
OUTPUT_DIR = Path("/Users/macbookpro/Desktop/Task 1/Plots & Summary CSVs/Pillar 2 Summary Tables & Plots/Pillar2_Plots")
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

# ===== LOAD DATA =====
df = pd.read_csv(INPUT_CSV)
df.columns = [c.lower() for c in df.columns]

required = ["activity_date","dau","usd_revenue","payers","arpdau","arppu","payer_rate_pct"]
for col in required:
    if col not in df.columns:
        raise ValueError(f"Required column '{col}' not found. Columns present: {list(df.columns)}")

df["activity_date"] = pd.to_datetime(df["activity_date"], errors="coerce")
df = df.dropna(subset=["activity_date"]).sort_values("activity_date")

# ===== PLOTTING HELPERS =====
def make_timeseries(x, y, title, ylabel, fname):
    fig = plt.figure()  # one figure per chart
    ax = fig.gca()
    ax.plot(x, y, label=title)
    ax.set_title(title)
    ax.set_xlabel("Date")
    ax.set_ylabel(ylabel)
    ax.legend()
    fig.autofmt_xdate()
    plt.tight_layout()
    out = OUTPUT_DIR / fname
    fig.savefig(out, dpi=150)
    plt.close(fig)
    return out

# ===== GENERATE SIX SEPARATE PLOTS =====
outputs = []
outputs.append(make_timeseries(df["activity_date"], df["dau"],
                               "DAU Over Time", "DAU", "dau_timeseries.png"))
outputs.append(make_timeseries(df["activity_date"], df["usd_revenue"],
                               "Revenue (USD) Over Time", "USD Revenue", "usd_revenue_timeseries.png"))
outputs.append(make_timeseries(df["activity_date"], df["payers"],
                               "Payers Over Time", "Payers", "payers_timeseries.png"))
outputs.append(make_timeseries(df["activity_date"], df["arpdau"],
                               "ARPDAU Over Time", "ARPDAU ($)", "arpdau_timeseries.png"))
outputs.append(make_timeseries(df["activity_date"], df["arppu"],
                               "ARPPU Over Time", "ARPPU ($)", "arppu_timeseries.png"))
outputs.append(make_timeseries(df["activity_date"], df["payer_rate_pct"],
                               "Payer Rate (%) Over Time", "Payer Rate (%)", "payer_rate_pct_timeseries.png"))

print(f"Generated {len(outputs)} plots in: {OUTPUT_DIR}")
