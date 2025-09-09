# ================================
# Cumulative LTV: Plotting Script
# ================================
# This script:
# 1) Loads the LONG FORM cumulative LTV CSV (one row per install_date × country × platform × age_day).
# 2) Builds practical aggregations for interpretation.
# 3) Creates a small set of clear matplotlib plots (no seaborn, one chart per figure, no forced colors).
#
# You can tweak the PARAMETERS section to change which plots to generate.

import os
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
from pathlib import Path

# -----------------
# PARAMETERS
# -----------------
CSV_PATH = Path('/Users/macbookpro/Desktop/Task 1/Task 1 | Pillar 2/Pillar 2.2 | LONG FORM Cumulative LTV.csv')  # Update if the file path differs
SAVE_PLOTS = True                         # If True, figures are saved as PNGs in ./ltv_plots
OUTPUT_DIR = CSV_PATH.parent / "Pillar2_Plots"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

# Number of countries to plot for "top/bottom LTV" comparisons (by Day-7 average)
TOP_N = 5
BOTTOM_N = 5

# Decision horizons to extract (typical horizons)
DECISION_DAYS = [1, 7, 14, 30]

# -----------------
# LOAD DATA
# -----------------
df = pd.read_csv(CSV_PATH)

# Safe conversions
df['install_date'] = pd.to_datetime(df['install_date'], errors='coerce')  # coerce invalids to NaT
df['age_day'] = pd.to_numeric(df['age_day'], errors='coerce')
df['ltv_usd'] = pd.to_numeric(df['ltv_usd'], errors='coerce')

# Drop any unexpected nulls on critical fields
df = df.dropna(subset=['platform', 'country', 'age_day', 'ltv_usd']).copy()

# -----------------
# HELPER FUNCTIONS
# -----------------
def save_or_show(fig, name):
    """Save figure to disk (if enabled) and also show."""
    if SAVE_PLOTS:
        path = os.path.join(OUTPUT_DIR, f"{name}.png")
        fig.savefig(path, bbox_inches="tight", dpi=150)
    plt.show()


# -----------------
# PLOT 1: Average LTV curve by PLATFORM
# -----------------
# Motivation: Compare monetization shape between iOS and Android without day-to-day noise.
df_plat = (df.groupby(['platform', 'age_day'], as_index=False)['ltv_usd']
             .mean()
             .sort_values(['platform', 'age_day']))

fig = plt.figure(figsize=(9, 5))
for plat in df_plat['platform'].unique():
    sub = df_plat[df_plat['platform'] == plat]
    plt.plot(sub['age_day'], sub['ltv_usd'], label=str(plat))

plt.title("Average Cumulative LTV by Platform")
plt.xlabel("Player Age (days)")
plt.ylabel("LTV (USD per user)")
plt.legend()
plt.grid(True, linestyle='--', linewidth=0.5, alpha=0.5)
save_or_show(fig, "ltv_curve_by_platform")


# -----------------
# PLOT 2: Average LTV curve by INSTALL WEEK (global)
# -----------------
# Motivation: Check cohort stability across time (week-to-week smoothing).
df['install_week'] = df['install_date'].dt.to_period('W').apply(lambda r: r.start_time)

df_week = (df.groupby(['install_week', 'age_day'], as_index=False)['ltv_usd']
             .mean()
             .sort_values(['install_week', 'age_day']))

# Since installs_total is noisy, we can include all weeks -> here we include all.
fig = plt.figure(figsize=(10, 6))
for week in df_week['install_week'].unique():
    sub = df_week[df_week['install_week'] == week]
    plt.plot(sub['age_day'], sub['ltv_usd'], label=str(week.date()))

plt.title("Average Cumulative LTV by Install Week (Global)")
plt.xlabel("Player Age (days)")
plt.ylabel("LTV (USD per user)")
plt.legend(ncol=2, fontsize=8)
plt.grid(True, linestyle='--', linewidth=0.5, alpha=0.5)
save_or_show(fig, "ltv_curve_by_install_week_global")


# -----------------
# PLOT 3: Average LTV curve by PLATFORM & INSTALL WEEK (faceted by platform)
# -----------------
# Motivation: See if week-to-week behavior differs by platform (e.g., a new Android build changes shape).
df_plat_week = (df.groupby(['platform', 'install_week', 'age_day'], as_index=False)['ltv_usd']
                  .mean()
                  .sort_values(['platform', 'install_week', 'age_day']))

for plat in df_plat_week['platform'].unique():
    subp = df_plat_week[df_plat_week['platform'] == plat]
    fig = plt.figure(figsize=(10, 6))
    for week in subp['install_week'].unique():
        subw = subp[subp['install_week'] == week]
        plt.plot(subw['age_day'], subw['ltv_usd'], label=str(week.date()))
    plt.title(f"Average Cumulative LTV by Install Week — {plat}")
    plt.xlabel("Player Age (days)")
    plt.ylabel("LTV (USD per user)")
    plt.legend(ncol=2, fontsize=8)
    plt.grid(True, linestyle='--', linewidth=0.5, alpha=0.5)
    save_or_show(fig, f"ltv_curve_by_install_week_{plat}")


# -----------------
# PLOT 4: Top vs Bottom COUNTRIES by Day-7 LTV (global averages)
# -----------------
# Motivation: Identify best/worst markets for monetization checkpoint (Day-7).
d7 = df[df['age_day'] == 7]
country_d7 = (d7.groupby(['country', 'platform'], as_index=False)['ltv_usd']
                .mean()
                .rename(columns={'ltv_usd': 'ltv_d7'}))

# Rank per platform (avoid mixing platform effects)
for plat in country_d7['platform'].unique():
    sub = country_d7[country_d7['platform'] == plat].copy()
    sub = sub.sort_values('ltv_d7', ascending=False)

    top = sub.head(TOP_N)
    bot = sub.tail(BOTTOM_N)

    # Bar plot: TOP N
    fig = plt.figure(figsize=(9, 5))
    plt.bar(top['country'].astype(str), top['ltv_d7'])
    plt.title(f"Top {TOP_N} Countries by Day-7 LTV — {plat}")
    plt.xlabel("Country")
    plt.ylabel("LTV at Day-7 (USD)")
    plt.xticks(rotation=30, ha='right')
    plt.grid(axis='y', linestyle='--', linewidth=0.5, alpha=0.5)
    save_or_show(fig, f"top{TOP_N}_countries_d7_{plat}")

    # Bar plot: BOTTOM N
    fig = plt.figure(figsize=(9, 5))
    plt.bar(bot['country'].astype(str), bot['ltv_d7'])
    plt.title(f"Bottom {BOTTOM_N} Countries by Day-7 LTV — {plat}")
    plt.xlabel("Country")
    plt.ylabel("LTV at Day-7 (USD)")
    plt.xticks(rotation=30, ha='right')
    plt.grid(axis='y', linestyle='--', linewidth=0.5, alpha=0.5)
    save_or_show(fig, f"bottom{BOTTOM_N}_countries_d7_{plat}")


# -----------------
# PLOT 5: Decision checkpoints (D1, D7, D14, D30) by PLATFORM
# -----------------
# Motivation: Compact view for comparisons to CPI later (Pillar 3).
check = df[df['age_day'].isin(DECISION_DAYS)]
plat_check = (check.groupby(['platform', 'age_day'], as_index=False)['ltv_usd']
                 .mean()
                 .sort_values(['platform', 'age_day']))

# One line per platform with markers at decision days
fig = plt.figure(figsize=(9, 5))
for plat in plat_check['platform'].unique():
    sub = plat_check[plat_check['platform'] == plat]
    plt.plot(sub['age_day'], sub['ltv_usd'], marker='o', label=str(plat))
plt.title("Decision Checkpoints LTV (D1, D7, D14, D30) by Platform")
plt.xlabel("Player Age (days)")
plt.ylabel("LTV (USD per user)")
plt.xticks(DECISION_DAYS)
plt.legend()
plt.grid(True, linestyle='--', linewidth=0.5, alpha=0.5)
save_or_show(fig, "ltv_decision_checkpoints_by_platform")
