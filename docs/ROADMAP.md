# ROADMAP

## M1 — Accounting baseline
Status: complete.

- internal mint excluded from HardNAV;
- canonical dividend accounting;
- residual HardNAV;
- 100 WPOL normalization.

## M2 — Dynamic allocator
Status: complete in simulation.

- marginal return allocation;
- finite strategy capacity;
- nonlinear slippage;
- working-capital target;
- dividend cash-out target.

## M3 — Security baseline
Status: partially complete.

- owner control;
- robot allowlist;
- pause;
- nonReentrant;
- owner emergency withdrawal;
- two-step ownership transfer.

Remaining:
- fuzz/invariant test suite;
- static analysis;
- symbolic execution;
- adversarial adapter mocks.

## M4 — Stochastic V5
Next.

Replace constant opportunities with:
- stochastic edge;
- stochastic gas;
- stochastic MEV;
- stochastic capacity;
- missed fills;
- edge decay;
- competition;
- regime shifts.

Optimize median and lower-tail canonical dividends rather than deterministic best-case multiplier.

## M5 — Polygon Mainnet Fork

- fixed block;
- exactly 100 WPOL starting capital;
- actual WETH/WPOL/USDC pools;
- executable quotes;
- gas estimates;
- fork-only transactions;
- repeated snapshot/revert.

Metrics:
- final residual WPOL-equivalent;
- owner dividend WPOL-equivalent;
- max drawdown;
- failed-fill rate;
- realized net edge;
- multiplier distribution.

## M6 — Security audit gate

No live deployment before:
- Foundry fuzz;
- invariant tests;
- Slither;
- symbolic execution;
- oracle manipulation tests;
- sandwich/adverse execution tests;
- external review.

## Main research KPI

Maximize:

canonical dividends + residual canonical HardNAV

subject to:
- finite external capacity;
- positive realized net alpha;
- no double counting;
- no internal-token mark inflation;
- explicit downside controls.
