from math import sqrt

PRIMARY = 0.50
CF = 0.65
REUSE = 0.50
RECURSIVE_TIER = 0.25
RESERVE_FLOOR = 0.20
CAPTURE = 0.0027

first_credit = PRIMARY * CF * REUSE
credit_ratio = CF * REUSE * RECURSIVE_TIER
secondary_credit = first_credit / (1.0 - credit_ratio)
deployed = min(PRIMARY + secondary_credit, 1.0 - RESERVE_FLOOR)
tvl_per_hard = 2.0 * deployed

def multiplier(turnover):
    q = tvl_per_hard * turnover * CAPTURE
    if q >= 1.0:
        raise ValueError("unstable recursive regime")
    return 1.0 / (1.0 - q)

def stress_retention(shock_price):
    return (1.0 - deployed) + deployed * sqrt(shock_price)

def health_factor(shock_price):
    eligible = (PRIMARY + secondary_credit * RECURSIVE_TIER) * CF
    return eligible * sqrt(shock_price) / secondary_credit

print("primary_deployment", PRIMARY)
print("first_credit", first_credit)
print("recursive_credit_ratio", credit_ratio)
print("secondary_credit_converged", secondary_credit)
print("hard_deployed_per_hardnav", deployed)
print("free_hard_reserve", 1.0 - deployed)
print("hard_pool_tvl_per_hardnav", tvl_per_hard)

for t in [5,10,20,30,50,75,100]:
    print("turnover", t, "multiplier", multiplier(t))

m75 = multiplier(75)
initial = 50.0
incoming_retained = 50.0
final_hnav = initial + incoming_retained * m75
first_order = initial + incoming_retained * (1.0 + tvl_per_hard * 75 * CAPTURE)

print("50+50 immediate_hardnav", initial + incoming_retained)
print("50+50 first_order_hardnav_75x", first_order)
print("50+50 recursive_final_hardnav_75x", final_hnav)

flow_only_seed = 50.0 * CAPTURE
print("50 flow-only recursive contribution", flow_only_seed * m75)
print("50 flow-only final_hardnav", initial + flow_only_seed * m75)

for shock in [0.80,0.70]:
    r = stress_retention(shock)
    print("shock", shock, "retention", r, "health_factor", health_factor(shock), "mature_50_50_hnav", final_hnav*r)
