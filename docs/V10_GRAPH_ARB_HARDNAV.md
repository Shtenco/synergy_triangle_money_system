# V10 Graph Arbitrage HardNAV Engine

V10 tests the hypothesis that graph arbitrage can turn pool repricing into real HardNAV growth.

The answer is split into two different classes of graph cycle.

## 1. Closed internal cycle

Example:

USDC -> Z -> X -> USDC

where all three swap edges are protocol-owned pools.

A real CPMM arbitrage profit can appear in the arbitrage wallet.

Example reference calculation after a 0.10 USDC external X buy:

- cycle size: about 0.030246 USDC
- cycle output: about 0.037621 USDC
- arb wallet profit: about 0.007375 USDC

However:

- protocol hard reserves in owned LP fall by about 0.007375 USDC;
- arb Treasury rises by about 0.007375 USDC;
- consolidated HardNAV is unchanged.

Therefore closed internal cycles are useful for:

- rebalancing;
- free Treasury extraction;
- BUY+BURN funding;
- capital routing;
- price convergence;

but they are HardNAV-neutral.

## 2. Graph cycle with an external settlement edge

This is the HardNAV-producing case.

Example:

1. External seller pushes X/USDC down.
2. Protocol uses internal USDC to buy cheap X from its own X/USDC pool.
3. Because the USDC moved from protocol Treasury to a protocol-owned pool, this internal leg does not change consolidated HardNAV.
4. The acquired X is sold to a real outside counterparty for USDC.
5. The outside USDC enters the protocol and increases HardNAV.

Reference calculation:

Initial HardNAV:
1.000000 USDC

External seller sells 0.10 X into X/USDC and receives:
about 0.0798079 USDC

HardNAV becomes:
about 0.9201921 USDC

Protocol routes 0.08 USDC internally to acquire:
about 0.0997119 X

The internal move alone does not change consolidated HardNAV.

The X is then sold externally at 1 USDC/X for:
about 0.0997119 USDC

Final HardNAV:
about 1.0199041 USDC

So one complete repricing + external settlement event moves:

1.000000 -> about 1.019904 HardNAV

The extra hard value is real, but it came from an outside hard-settlement counterparty.

## Critical accounting rule

The graph engine must classify edges.

INTERNAL edge:
value transfer between protocol-owned pools, Treasury or inventory.

EXTERNAL edge:
value transfer across the protocol boundary.

Only net external hard settlement can change consolidated HardNAV.

Therefore:

internal graph arbitrage != new HardNAV

but:

internal repricing + external settlement arbitrage = real HardNAV PnL

## Production graph

Nodes:
- USDC
- RUBX
- RUBZ
- external USDC settlement
- optional WPOL/WETH collateral nodes later

Internal edges:
- RUBX/USDC
- RUBZ/USDC
- RUBX/RUBZ
- Treasury inventory
- MINT/BURN
- ADDLP

External edges:
- aggregator fills
- RFQ counterparties
- outside DEX routes
- liquidation settlement
- order-flow auctions
- external borrowers
- external token buyers

The engine should search amount-aware paths, because CPMM edge weights depend on trade size.

## Safety limits needed before production

An unlimited fixed-price external buyer would make the model meaningless.

Production V10 must therefore include:

- per-block external capacity;
- executable quote expiration;
- max slippage;
- min hard profit;
- gas and MEV costs;
- external venue credit/counterparty risk;
- soft-token issuance limits;
- price corridor;
- maximum inventory extraction;
- no self-controlled external counterparty;
- consolidated HardNAV before/after assertion.

V10 therefore treats external settlement as a scarce market opportunity, not an infinite hard-money source.
