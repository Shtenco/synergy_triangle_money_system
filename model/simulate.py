from math import sqrt

RESERVE_FLOOR = 0.20
DEPLOY = 0.80
RECURSIVE_TIER = 0.25
MIN_HF = 1.25

def model(cf, reuse):
    q = cf * reuse * RECURSIVE_TIER
    first_credit = DEPLOY * cf * reuse
    recursive_credit = first_credit / (1 - q)
    productive_liquidity = 2 * (DEPLOY + recursive_credit)
    return recursive_credit, productive_liquidity

def hardnav_retention(shock_price):
    return RESERVE_FLOOR + DEPLOY * sqrt(shock_price)

def health_factor(shock_price, reuse):
    return sqrt(shock_price) / reuse

for name, cf, reuse in [
    ("BASE", 0.65, 0.50),
    ("AGGRESSIVE_STRESS_SAFE", 0.80, 0.65),
]:
    credit, mult = model(cf, reuse)
    print(name)
    print("recursive_credit_per_1_hardnav", credit)
    print("productive_liquidity_multiplier", mult)
    print("marginal_productive_liquidity_for_50", 50 * mult)
    print("total_productive_liquidity_for_100_hardnav", 100 * mult)
    print("HF_20pct_shock", health_factor(0.80, reuse))
    print("HF_30pct_shock", health_factor(0.70, reuse))
    print()

print("hardnav_50_plus_50", 100.0)
print("hardnav_retention_20pct_shock", hardnav_retention(0.80))
print("hardnav_retention_30pct_shock", hardnav_retention(0.70))

for y in [0.05,0.10,0.20]:
    print("hardnav_after_real_yield", y, 100*(1+y))
