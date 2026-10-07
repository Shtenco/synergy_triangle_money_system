# SECURITY AND THREAT MODEL

## Threat assumptions

Any ML agent can be wrong or compromised.

Therefore the design must assume that an agent may:
- submit an incorrect route;
- overestimate edge;
- underestimate slippage;
- repeat stale signals;
- attempt an unauthorized action.

## Required safeguards for fork/testnet validation

- owner-only administration;
- robot allowlist;
- adapter allowlist;
- token allowlist;
- per-trade limits;
- global exposure limits;
- pause;
- reentrancy protection;
- minimum-output checks;
- positive-edge gate;
- stale-price rejection;
- explicit accounting invariants;
- event logging;
- no arbitrary external calls;
- no robot withdrawal rights.

## Withdrawal model

For research purposes owner withdrawal is modeled as an accounting action:
canonical assets removed from working capital are added to cumulative owner dividends.

The fork/test suite must verify:

ResidualHardNAV + CumulativeDividends
=
TotalGeneratedCanonicalValue

without double counting.

## Pre-mainnet requirements

Before any real-money use:
- Foundry fuzz;
- Foundry invariant;
- Slither;
- symbolic execution;
- fork tests at fixed Polygon blocks;
- adversarial router tests;
- oracle manipulation tests;
- MEV / sandwich stress;
- failed-fill stress;
- bridge-delay stress;
- independent external security audit.

No claim of complete vulnerability elimination is valid without these steps.
