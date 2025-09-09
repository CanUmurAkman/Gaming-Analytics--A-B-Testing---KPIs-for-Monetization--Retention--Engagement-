# Requires: pandas, numpy, matplotlib
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt

df = pd.read_csv('/Users/macbookpro/Desktop/Task 2/Outputs/SQL Query Outputs/D14.csv')  # columns: user_id, variant, minutes_d14, revenue_d14

def bootstrap_ci_mean(x, n_boot=2000, alpha=0.05, rng_seed=42):
    rng = np.random.default_rng(rng_seed)
    x = np.asarray(x)
    boots = rng.choice(x, size=(n_boot, x.size), replace=True).mean(axis=1)
    lo, hi = np.quantile(boots, [alpha/2, 1-alpha/2])
    return lo, hi

def bar_with_ci(ax, means, cis, labels, title, ylabel):
    x = np.arange(len(labels))
    heights = means
    yerr = np.array([means - cis[:,0], cis[:,1] - means])
    ax.bar(x, heights)
    ax.errorbar(x, heights, yerr=yerr, fmt='none', capsize=4)
    ax.set_xticks(x)
    ax.set_xticklabels(labels, rotation=0)
    ax.set_ylabel(ylabel)
    ax.set_title(title)

# Order variants for consistent plots
order = sorted(df['variant'].unique())

# --- ARPU D14 (per user) ---
means = []
cis = []
for v in order:
    x = df.loc[df.variant == v, 'revenue_d14'].to_numpy()
    means.append(x.mean())
    lo, hi = bootstrap_ci_mean(x)
    cis.append((lo, hi))
means = np.array(means)
cis = np.array(cis)

fig, ax = plt.subplots(figsize=(8,5))
bar_with_ci(ax, means, cis, order, "D14 ARPU (per user, assignment groups)", "USD")
plt.tight_layout()
plt.savefig('/Users/macbookpro/Desktop/Task 2/Outputs/Plots & Summary Tables/D14_ARPU_bar_CI.png')
plt.close()

# --- Minutes D14 (per user) ---
means = []
cis = []
for v in order:
    x = df.loc[df.variant == v, 'minutes_d14'].to_numpy()
    means.append(x.mean())
    lo, hi = bootstrap_ci_mean(x)
    cis.append((lo, hi))
means = np.array(means)
cis = np.array(cis)

fig, ax = plt.subplots(figsize=(8,5))
bar_with_ci(ax, means, cis, order, "D14 Minutes per User (assignment groups)", "Minutes")
plt.tight_layout()
plt.savefig('/Users/macbookpro/Desktop/Task 2/Outputs/Plots & Summary Tables/D14_Minutes_bar_CI.png')
plt.close()

print("Saved: D14_ARPU_bar_CI.png, D14_Minutes_bar_CI.png")