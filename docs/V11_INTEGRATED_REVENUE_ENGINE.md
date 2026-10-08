# V11 Integrated Revenue Engine

V11 combines the V7 block-level revenue infrastructure with the V10 graph-arbitrage HardNAV engine.

The protocol now treats every block as a capital-allocation problem.

## Revenue channels competing for the same hard capital

1. Graph external settlement
   - Internal triangle repricing is converted into real outside USDC/WPOL settlement.
   - Closed internal graph cycles are NOT counted as HardNAV income.

2. Borrower refinance / credit
   - Borrower Hunter discovers expensive external debt.
   - Hard-denominated interest becomes realised revenue.

3. Protocol-owned flash lending
   - Free Treasury reserve can be lent intra-transaction.
   - Only flash fee counts as HardNAV income.

4. Flash-funded arbitrage
   - Morpho/Aave external flash liquidity can fund atomic strategies.
   - Only net profit after repayment, premium, gas and slippage counts.

5. Flash-funded liquidation
   - Same accounting rule: liquidation bonus minus all external costs.

6. Real collateral yield
   - Only actual hard-asset yield is counted.

## One-reserve rule

A single unit of WPOL/USDC cannot be allocated simultaneously to:
- a graph-settlement route,
- a flash loan to an external searcher,
- our own liquidation,
- our own arbitrage.

The unified scheduler reserves capital for the highest risk-adjusted positive HardNAV opportunity in the block.

This prevents double use of the 20% hard-reserve.

## Priority is not hard-coded by strategy name

The scheduler compares net hard profit after:
- funding fee,
- gas,
- slippage,
- minimum-profit buffer,
- confidence,
- capital requirement.

Example:
if graph external settlement needs 3 WPOL and produces 0.10 net WPOL,
while an external flash borrower offers only 0.02 WPOL on the same 3 WPOL,
the graph route wins for that block.

## Closed internal graph arbitrage

A closed triangle such as:

USDC -> Z -> X -> USDC

can increase the arb wallet balance while decreasing protocol-owned LP hard reserves.

Therefore it is marked HardNAV-neutral and is excluded from the unified revenue allocator.

It may still be used for:
- rebalancing,
- free Treasury extraction,
- BUY+BURN funding,
- price convergence.

## Integrated block flow

New block
-> collect fresh borrower/refinance candidates
-> scan graph mispricing and external settlement quotes
-> scan liquidation opportunities
-> scan arbitrage opportunities
-> observe external flash-loan demand
-> calculate real collateral yield opportunities
-> normalize all into Opportunity objects
-> discard non-HardNAV-producing or negative-net-PnL routes
-> allocate the available hard-capital budget
-> execute only the selected set
-> assert consolidated HardNAV before/after
-> pass residual price imbalance to adaptive MM.

## Important ordering with V9

Graph settlement should run before aggressive adaptive stabilization.

Reason:
V9 MINT/BURN can destroy the same price discrepancy that V10 could have crystallized into external hard assets.

Preferred order:

external swap
-> graph scan
-> external HardNAV crystallization if profitable
-> flash/refinance/liquidation competition
-> V9 adaptive stabilization on residual imbalance
-> ADDLP / reserve update.

## Current source modules

V7/V6:
- src/FlashLiquidityLender.sol
- src/AtomicRevenueExecutor.sol
- src/HardRevenueEngine.sol
- borrower_hunter/
- block_revenue/

V10:
- v10/src/GraphArbHardNavEngine.sol
- v10/src/MockExternalSettlement.sol

V11:
- unified_revenue/

The current V11 branch intentionally keeps the original experiments available for auditability while adding the unified allocator above them.
