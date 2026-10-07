# SYNERGY V7 — Block Revenue Engine

V7 turns the protocol into a block-by-block capital allocator.

The system does not assume there is a profitable opportunity in every block.
Instead, every new block is treated as a decision window. Capital is deployed only when expected hard-asset PnL remains positive after funding fee, gas, slippage and safety buffers.

## Revenue channels

### 1. Long-duration collateralized credit

V5/V6 continue to provide collateralized RUBX/RUBZ refinancing credit.

This channel monetizes internal credit capacity through hard-denominated interest.

### 2. Protocol-owned flash lending

The free Treasury reserve can be exposed through an ERC-3156-compatible lender.

The loan exists only inside one transaction.

The borrower must return:

principal + fee

before the transaction ends.

Therefore the reserve can remain available at block boundaries while still generating fee income intra-block.

Only the external fee is booked as realised HardNAV income.

The principal is never counted as income.

### 3. External zero/low-cost flash funding

The protocol may use external flash liquidity for its own atomic strategies.

Morpho Blue is especially attractive as a funding source because the current Blue flash-loan fee is zero.

Aave V3 flashLoanSimple can also be used, but the current premium must always be queried from the Pool rather than hardcoded.

Euler EVault flash liquidity is another candidate for future adapters.

### 4. Atomic arbitrage

Only allowlisted targets may be called.

A strategy must finish with:

final hard balance >= flash repayment + minProfit

otherwise the transaction reverts.

Internal circular movement between protocol-owned pools is not revenue.

Only hard assets remaining after all external repayment and costs count as realised revenue.

### 5. Liquidation

The same AtomicRevenueExecutor can later execute liquidation opportunities where:

liquidation bonus
minus flash funding fee
minus gas
minus swap slippage
minus safety buffer

is positive.

No liquidation opportunity is executed from an off-chain estimate alone. It must be re-simulated against the exact target block/state before submission.

### 6. Refinance

Borrower Hunter V6 discovers expensive existing debt.

V7 can use flash funding to repay old debt atomically, migrate collateral and open the new SYNERGY position.

The borrower must explicitly authorize the migration.

## Every-block scheduler

The Block Revenue Scheduler receives opportunities for the current block.

Each opportunity contains:

- strategy type
- capital required
- expected gross hard profit
- flash funding fee
- gas cost
- slippage
- confidence
- atomic/non-atomic flag

The scheduler rejects opportunities that are:

- stale / wrong block
- non-atomic where atomicity is required
- below the minimum confidence threshold
- below minimum net hard profit
- too large for the free reserve budget
- too concentrated

The remaining opportunities are sorted primarily by net return on capital.

This means the same free reserve is not simultaneously promised to several incompatible transactions.

## Reserve economics

With 50 WPOL HardNAV and a 20% reserve floor:

free reserve target = 10 WPOL.

At 95% maximum intra-transaction flash utilization:

up to 9.5 WPOL can be exposed during a flash-loan transaction.

At 5 bps fee, a fully utilized 9.5 WPOL external flash loan earns:

9.5 × 0.0005 = 0.00475 WPOL

for that successful transaction.

If there are 100 real external flash-loan transactions of that size:

0.475 WPOL

of gross fee revenue is produced.

This example does not assume there will be 100 borrowers. Demand must be observed.

## Why own flash lending is not automatically the best use of reserve

Morpho Blue currently offers zero-fee flash loans.

Therefore a searcher will not pay SYNERGY 5 bps for identical readily available liquidity unless SYNERGY offers some advantage such as:

- token/liquidity unavailable elsewhere
- larger available amount
- lower total route gas
- integrated execution path
- unique pool access
- reduced slippage
- priority access or bundled route

The Block Revenue Scheduler therefore compares external flash-loan demand with our own atomic opportunities.

If our own atomic strategy has higher risk-adjusted expected WPOL profit, the reserve should be used internally for that block.

## HardNAV accounting

Revenue channels count only:

- external borrower interest
- external flash-loan fees
- external liquidation profit
- external arbitrage profit
- real hard collateral yield
- explicitly charged refinance/origination fees

The following are not HardNAV income:

- moving WPOL between Treasury and our own pool
- fees paid by one protocol-owned wallet to another
- minting RUBX/RUBZ
- internal mark-to-market appreciation
- flash-loan principal
- borrower collateral that must be returned

## Contracts

### FlashLiquidityLender.sol

ERC-3156-style flash lender backed by Treasury hard liquidity.

Properties:

- supported-token whitelist
- configurable fee
- max intra-transaction lend fraction
- callback verification
- atomic principal return
- fee routed to Treasury realised revenue
- reentrancy guard

### AtomicRevenueExecutor.sol

Atomic execution engine with:

- Morpho Blue flash funding
- Aave V3 flashLoanSimple funding
- allowlisted external targets
- plan hash commitment
- minimum hard-profit check
- all-or-nothing execution
- realised profit routed to Treasury

This contract deliberately does not include arbitrary public strategy execution.

## Off-chain Block Revenue Scheduler

The Python scheduler is the decision layer.

It does not sign arbitrary transactions.

Future V8 execution should require:

- exact block simulation
- signed strategy bundle
- max gas
- minProfit
- deadline
- target allowlist
- oracle freshness
- MEV protection/private submission where useful

## Next implementation targets

1. Polygon RPC live block listener.
2. Morpho liquidation/opportunity scanner.
3. Aave liquidation scanner.
4. Euler liquidation scanner.
5. DEX quote adapters for Polygon venues.
6. exact gas estimator.
7. transaction simulator.
8. private transaction / bundle submission.
9. flash-loan demand analytics.
10. adaptive fee controller for our FlashLiquidityLender.
11. per-block PnL ledger.
12. circuit breakers and daily loss limits.
