# 100 WPOL MODEL

## Initial state

Initial canonical principal:

100 WPOL

## Controlled research engines

ARBITRAGE:
- modeled gross edge: 3.0%
- modeled capacity: 500 WPOL per cycle

BRIDGE:
- modeled gross edge: 0.8%
- modeled capacity: 300 WPOL per cycle

FEE FLOW:
- modeled gross value capture: 0.3%
- modeled capacity: 700 WPOL per cycle

Effective utilization:
93.5%

This is a controlled simulation configuration, not a live-market forecast.

## Dynamic marginal allocator

For engine i:

Profit_i(q) = a_i q - k q^3 / C_i^2

Marginal return:

dProfit_i/dq = a_i - 3 k q^2 / C_i^2

The allocator places each additional WPOL into the engine with the highest remaining positive marginal return.

## Best modeled results

100 cycles:
- target working capital: 325 WPOL
- residual: 325 WPOL
- cumulative dividends: 381.648458 WPOL
- dividend multiplier: 3.816485x
- total generated-value multiplier: 7.066485x

1000 cycles:
- target working capital: 975 WPOL
- residual: 975 WPOL
- cumulative dividends: 10901.517042 WPOL
- dividend multiplier: 109.015170x
- total generated-value multiplier: 118.765170x

Approximate terminal marginal allocation:
- Arbitrage: 500 WPOL
- Bridge: 180.57 WPOL
- Fee flow: 231.05 WPOL

## Interpretation

The improvement over the previous static allocator comes from better capital routing, not from internal mint.

The next objective is to replace fixed assumptions with stochastic and fork-measured opportunity processes.
