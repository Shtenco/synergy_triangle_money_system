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

## M4 — Controlled Structural Edge Governor
Next.

Ключевая корректировка: структурный edge внутреннего треугольника НЕ моделируется как внешний случайный edge.

Он является управляемой переменной системы:

- target structural edge epsilon_target;
- mint/burn SYNA/SYNR/SUSD;
- weighted rebalance;
- depth control;
- D_high / D_low;
- safe_cycle_pct;
- replenishment.

Цель Governor:

1. удерживать structural edge около epsilon_target;
2. не допускать истощения canonical LP;
3. разрешать цикл только если canonical settlement после всех издержек не ухудшает HardNAV;
4. после цикла восстанавливать глубину и повторно создавать target geometry.

Стохастическими остаются только внешние условия реализации:
- gas;
- MEV;
- external conversion slippage;
- fill quality;
- latency;
- bridge delay;
- canonical market prices.

Не stochastic:
- внутренний target edge;
- mint/burn policy;
- target depth ratios;
- owner-controlled cycle geometry.

## M5 — Polygon Mainnet Fork

- fixed block;
- exactly 100 WPOL starting capital;
- internal triangle edge controlled by system policy;
- actual WETH/WPOL/USDC external pools used only for canonical settlement/valuation;
- executable quotes;
- gas estimates;
- fork-only transactions;
- repeated snapshot/revert.

Metrics:
- maintained internal structural edge;
- canonical extracted per cycle;
- canonical replenished per cycle;
- final residual WPOL-equivalent;
- owner dividend WPOL-equivalent;
- max drawdown;
- failed-fill rate;
- realized settlement costs;
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
- internal structural edge is owner/system-controlled;
- canonical settlement remains solvent;
- no double counting;
- no internal-token mark inflation;
- explicit downside controls.
