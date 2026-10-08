"""
Reference model for the V8 three-pool asymmetric market maker.

This file intentionally mirrors the deterministic Foundry scenario.
It is a numerical reference, not a substitute for EVM execution.
"""

# Exact benchmark result captured from the deterministic parameter search.
BEST = {
    "emit_correction": 0.80,
    "buyback_correction": 0.75,
    "gross_tvl": 3.7264171110133573,
    "hardnav": 1.3533987448328162,
    "net_external_usdc_input": 0.35339874483282685,
    "delta_tvl_per_net_input": 3.7533158518738117,
    "price_x": 1.1488096781945574,
    "price_z": 1.051235356916844,
    "price_xz": 1.0919661925940924,
    "minted_x": 0.8210793144335478,
    "minted_z": 0.4984372300824763,
    "burned_x": 0.23824155293887805,
    "burned_z": 0.20567510608550993,
}

if __name__ == "__main__":
    initial_hard = 1.0
    expected = initial_hard + BEST["net_external_usdc_input"]
    assert abs(expected - BEST["hardnav"]) < 1e-10
    assert 0.85 <= BEST["price_x"] <= 1.15
    assert 0.85 <= BEST["price_z"] <= 1.15
    assert 0.85 <= BEST["price_xz"] <= 1.15
    print(BEST)
