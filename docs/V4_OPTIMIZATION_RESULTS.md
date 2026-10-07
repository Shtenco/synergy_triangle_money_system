# V4 OPTIMIZATION RESULTS — 100 WPOL

## Objective

Initial canonical capital: 100 WPOL.

Optimize:
- canonical dividends;
- residual working WPOL;
- total canonical value;
- capital utilization.

## Dynamic marginal allocation

The allocator does not use fixed strategy weights.

Each additional WPOL is assigned to the engine with the highest remaining positive marginal expected return.

For engine i:

Profit_i(q) = a_i * q - k * q^3 / C_i^2

Marginal return:

dProfit_i/dq = a_i - 3 * k * q^2 / C_i^2

This naturally moves capital away from an engine as its capacity becomes saturated.

## Controlled baseline

Effective utilization: 93.5%.

Arbitrage engine:
- gross edge: 3.0%
- capacity: 500 WPOL

Bridge engine:
- gross edge: 0.8%
- capacity: 300 WPOL

Fee-flow engine:
- gross capture: 0.3%
- capacity: 700 WPOL

## Best modeled result — 100 cycles

Working target: 325 WPOL.

Residual working capital: 325 WPOL.

Cumulative canonical dividends: 381.648458 WPOL.

Dividend multiplier:

3.816485x

Total generated canonical value:

706.648458 WPOL

Total multiplier:

7.066485x

## Best modeled result — 1000 cycles

Working target: 975 WPOL.

Residual working capital: 975 WPOL.

Cumulative canonical dividends:

10901.517042 WPOL

Dividend multiplier:

109.015170x

Total generated canonical value:

11876.517042 WPOL

Total multiplier:

118.765170x

Approximate saturated allocation:
- Arbitrage: 500.00 WPOL
- Bridge: 180.57 WPOL
- Fee-flow: 231.05 WPOL

## Improvement versus static allocation

Earlier static allocation modeled dividend multiplier:

about 104.68x

V4 dynamic marginal allocation:

about 109.02x

The improvement comes from capital routing rather than internal token mint.

## Critical caveat

These are simulated controlled-model results.

They are not claims that Polygon Mainnet currently offers persistent 3% arbitrage opportunities or the modeled capacities.

The next validation level is a Polygon fixed-block fork with real pool state and executable quotes.
