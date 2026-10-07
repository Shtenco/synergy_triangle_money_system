# POLYGON MAINNET FORK TEST PLAN

## Goal

Validate the 100 WPOL system against a fixed Polygon Mainnet state without broadcasting transactions.

## Canonical graph

- WETH/WPOL
- WPOL/USDC
- WETH/USDC

## Procedure

1. Fork a fixed Polygon block.
2. Seed exactly 100 WPOL into the research treasury.
3. Deploy internal research tokens and system-owned pools.
4. Read actual external pool state.
5. Query executable routes.
6. Apply real fees and gas estimates.
7. Apply slippage from actual liquidity.
8. Reject any route with non-positive expected net edge.
9. Execute route on fork only.
10. Settle back to canonical.
11. Recompute HardNAV.
12. Apply research dividend policy.
13. Record residual WPOL-equivalent and cumulative dividends.
14. Snapshot/revert.
15. Repeat across blocks and seeds.

## PASS condition

A route counts as profitable only if:

final canonical owner-equivalent
+
residual canonical system value

is greater than the initial 100 WPOL equivalent after all costs.

## Required stress tests

- stale quote;
- thin liquidity;
- sudden gas spike;
- failed route;
- sandwich-like adverse price move;
- bridge latency;
- partial fill;
- oracle mismatch;
- agent proposes invalid route;
- repeated stale signal.
