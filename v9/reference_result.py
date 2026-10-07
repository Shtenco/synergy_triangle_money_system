RESULT = {
    "controller": "V9 adaptive",
    "gross_tvl": 3.7524034447165624,
    "hardnav": 1.35658560730399,
    "net_external_usdc_input": 0.3565856073039967,
    "delta_tvl_per_net_input": 3.792647311094669,
    "price_x": 1.148991447539799,
    "price_z": 1.076103160932517,
    "price_xz": 1.0665834248012944,
    "minted_x": 0.8401017420360272,
    "minted_z": 0.48582282332699606,
    "burned_x": 0.20458756051160792,
    "burned_z": 0.20581308179891347,
    "treasury_usdc": 0.000543343923426455,
}

FIXED_80_75 = {
    "delta_tvl_per_net_input": 3.750185185271245,
    "gross_tvl": 3.726668839153889,
    "hardnav": 1.3537608874261249,
}

if __name__ == "__main__":
    assert RESULT["delta_tvl_per_net_input"] > FIXED_80_75["delta_tvl_per_net_input"]
    assert 0.85 <= RESULT["price_x"] <= 1.15
    assert 0.85 <= RESULT["price_z"] <= 1.15
    assert 0.85 <= RESULT["price_xz"] <= 1.15
    assert abs(1.0 + RESULT["net_external_usdc_input"] - RESULT["hardnav"]) < 1e-10
    print(RESULT)
