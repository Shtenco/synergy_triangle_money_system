# V8 Three-Pool Asymmetric Market Maker

This experiment isolates the core system into exactly three pools:

- RUBX/USDC
- RUBZ/USDC
- RUBX/RUBZ

All three pools use constant-product AMM logic.

## Per-block controller

At the end of every simulated block each pool compares its current spot price with the previous block close.

If price increased:

- mint the relevant soft token;
- sell it into the pool;
- move price part-way back toward the previous block;
- recycle 70% of harvested USDC back into the hard pools as proportional LP;
- recycle 50% of harvested Z back into X/Z LP.

If price decreased:

- spend only already-available treasury asset;
- buy the soft token;
- burn it;
- move price part-way back toward the previous block.

No future mint is allowed to finance BUY+BURN.

## Objective

Maximize:

delta GrossTVL / net external USDC input

subject to:

- consolidated HardNAV accounting is conserved;
- no internal operation creates hard assets;
- final X and Z prices remain within approximately ±15% of the reference;
- all pool reserves remain positive.

## Seed state

X/USDC:
0.4 X + 0.4 USDC

Z/USDC:
0.4 Z + 0.4 USDC

X/Z:
0.4 X + 0.4 Z

Treasury:
0.2 USDC

Initial consolidated HardNAV:
1.0 USDC

Initial marked GrossTVL:
2.4 USD

## Deterministic 100-block scenario

The reference scenario injects a total of 1.0 USDC of external buys across 100 blocks with asymmetric X/Z demand.

Every 10 blocks there is an external soft-token sell shock.

The X/Z pool also receives small cross-pool arbitrage pressure toward the implied X/Z ratio.

## Parameter search

A fine grid search over asymmetric correction coefficients found the best feasible point in the tested region at:

- emission correction: 80%
- buyback/burn correction: 75%

This means that after an upward block the controller attempts to erase 80% of the block-over-block price move through MINT+SELL.

After a downward block it attempts to erase 75% of the move through BUY+BURN, limited by actual treasury balance.

The coefficients are intentionally asymmetric.

## Reference-model result for 80/75

For the exact deterministic reference scenario:

GrossTVL:
3.7264171110

Consolidated HardNAV:
1.3533987448

Net external USDC input:
0.3533987448

Delta GrossTVL:
1.3264171110

Delta GrossTVL / net external input:
3.7533158519x

Final X/USDC price:
1.1488096782

Final Z/USDC price:
1.0512353569

Final X/Z price:
1.0919661926

Minted X:
0.8210793144

Minted Z:
0.4984372301

Burned X:
0.2382415529

Burned Z:
0.2056751061

HardNAV invariant:

initial HardNAV + net external USDC input
=
1.0 + 0.3533987448
=
1.3533987448

which matches consolidated HardNAV in the reference model.

## Comparison points

The same deterministic model gives approximately:

50/50:
- GrossTVL 3.6428623321
- HardNAV 1.2535039728
- net input 0.2535039728
- delta TVL / net input 4.9027331535x
- but X price ≈1.439 and Z≈1.202, which violates the ±15% price corridor.

100/100:
- GrossTVL 3.7877898477
- HardNAV 1.4026493474
- net input 0.4026493474
- delta TVL / net input 3.4466462112x
- final X≈1.000 and Z≈0.912.

Therefore the raw unconstrained metric alone would prefer 50/50, but it is rejected by the price-risk constraint.

Among the asymmetric candidates that remain inside the tested price corridor, 80/75 is the current best point in the fine-grid search.

## EVM test

The isolated Foundry project is under v8/.

Tests:

1. deploy three tokens and three CPMM pools;
2. seed the exact initial state;
3. run 100 deterministic blocks;
4. compare 80/75, 50/50 and 100/100;
5. assert all reserves remain positive;
6. assert consolidated HardNAV equals initial hard + net external USDC flow;
7. assert a down block triggers BUY+BURN;
8. emit benchmark state for each configuration.

Important execution status:

The Solidity/Foundry test suite is written and isolated from V5-V7.

The current ChatGPT local container has no forge/anvil/solc installed.

The external GitHub runner currently fails before forge test execution, including when switched to a Foundry container image.

Therefore the numerical benchmark above is confirmed by the deterministic reference model, but is NOT yet being represented as a successful EVM execution result.

The branch is deliberately kept separate until a real Foundry run returns GREEN.
