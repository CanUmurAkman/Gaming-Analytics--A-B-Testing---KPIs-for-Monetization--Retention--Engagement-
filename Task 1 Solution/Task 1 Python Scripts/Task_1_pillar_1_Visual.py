#!/usr/bin/env python3
from pathlib import Path
import pandas as pd
import matplotlib.pyplot as plt

# ======= CONFIG =======
INPUT_CSV = Path("/Users/macbookpro/Desktop/Task 1/Task 1 | Pillar 1/Pillar 1 Analysis/Cohort Stability over Time.csv")
OUTPUT_DIR = Path("/Users/macbookpro/Desktop/Task 1/Plots & Summary CSVs/Pillar 1 Summary Tables & Plots/Pillar1_Plots")

# Create output directory if it doesn't exist
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

# ======= LOAD DATA =======
# Expected columns:
#   install_week, country, platform, avg_d1, avg_d7, avg_d14
# install_week is a week-start date (YYYY-MM-DD)
df = pd.read_csv(INPUT_CSV)

# Basic sanity checks / normalization
df.columns = [c.lower() for c in df.columns]
required = ["install_week","country","platform","avg_d1","avg_d7","avg_d14"]
for col in required:
    if col not in df.columns:
        raise ValueError(f"Required column '{col}' not found in CSV. Found columns: {list(df.columns)}")

# Parse dates and sort
df["install_week"] = pd.to_datetime(df["install_week"], errors="coerce")
df = df.dropna(subset=["install_week"])
df = df.sort_values(["country","platform","install_week"])

# ======= PLOTTING =======
def _sanitize(s: str) -> str:
    return "".join(ch if ch.isalnum() or ch in ("-","_") else "_" for ch in str(s))

plot_index_rows = []

for (country, platform), g in df.groupby(["country","platform"], dropna=False):
    g = g.sort_values("install_week")
    if g.empty:
        continue

    fig = plt.figure()  # one chart per figure, no style/colors specified
    ax = fig.gca()

    ax.plot(g["install_week"], g["avg_d1"], label="D1 retention (%)")
    ax.plot(g["install_week"], g["avg_d7"], label="D7 retention (%)")
    ax.plot(g["install_week"], g["avg_d14"], label="D14 retention (%)")

    ax.set_title(f"{country} — {platform} | D1/D7/D14 Retention by Install Week")
    ax.set_xlabel("Install Week")
    ax.set_ylabel("Retention (%)")
    ax.legend()
    fig.autofmt_xdate()
    plt.tight_layout()

    fname = f"{_sanitize(country)}__{_sanitize(platform)}__retention_timeseries.png"
    outpath = OUTPUT_DIR / fname
    fig.savefig(outpath, dpi=150)
    plt.close(fig)

    plot_index_rows.append({
        "country": country,
        "platform": platform,
        "plot_file": str(outpath)
    })

print(f"Done. Generated {len(plot_index_rows)} plots in: {OUTPUT_DIR}")
