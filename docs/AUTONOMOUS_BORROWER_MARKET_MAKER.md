# SYNERGY Autonomous Borrower Market Maker — V6

## Goal

V6 converts the V5 internal credit capacity into a real borrower acquisition engine.

The protocol does not wait for somebody to discover RUBX/RUBZ manually.

Instead it scans existing DeFi borrowing positions on Polygon, identifies borrowers paying a higher rate than SYNERGY can offer, calculates a refinance quote, checks collateral and health constraints, and exposes the best candidates for a one-click migration flow.

## Economic link to HardNAV

The current aggressive V5 credit settings are:

- hard deployment: 80%
- LP collateral factor: 80%
- reuse: 65%
- maximum utilization: 80%

Therefore:

- gross credit capacity = 0.416 hard units per 1 unit of HardNAV
- lendable capacity = 0.3328 hard units per 1 unit of HardNAV

For 50 WPOL HardNAV:

- gross credit capacity = 20.8 WPOL-equivalent
- maximum lendable capacity = 16.64 WPOL-equivalent

The Hunter never assumes WPOL = $1.

It receives the current WPOL/USD price from configuration/oracle and converts capacity into USD only for candidate comparison.

If 16.64 WPOL-equivalent is fully lent at 5% annual hard interest, gross annual hard revenue is:

0.832 WPOL.

That is real HardNAV income only when the borrower actually pays the interest in hard asset.

## Data sources

### Morpho

Morpho is used as a direct position discovery source.

The adapter:

1. lists Polygon markets;
2. obtains current market borrow APY;
3. obtains market positions;
4. normalizes debt USD, collateral USD, LLTV and health factor;
5. sends normalized positions to the scoring engine.

### Euler

Euler's Polygon subgraph is used only for discovery.

The subgraph's trackingActiveAccounts entity can identify account/vault borrow relationships, but the Hunter does not trust subgraph data as final debt/APY/health state.

Before an Euler quote becomes executable it must be refreshed through Euler Lens, Data API or direct on-chain reads.

## Candidate filter

A position is rejected when any of the following is true:

- state is stale;
- debt is below the minimum deal size;
- debt exceeds the configured maximum;
- health factor is below the minimum;
- collateral/debt ratio is below the SYNERGY requirement;
- the existing borrow rate is not sufficiently above our offered rate;
- annual savings do not cover gas/transaction costs;
- current available SYNERGY capacity is too small.

## Default baseline

- target offered APY: 5%
- minimum borrower rate advantage: 1.5 percentage points
- minimum health factor: 1.20
- minimum collateral ratio: 150%
- maximum utilization: 80%
- maximum allocation to one borrower: 35%
- minimum annual net borrower savings: $5

These are research defaults, not production risk parameters.

## Score

Candidates are ranked using:

- interest-rate edge;
- economically useful position size;
- health factor;
- collateral coverage.

The score is for ordering candidates only. Hard risk constraints are applied separately and cannot be overridden by score.

## Refinance flow

Discovery:
Morpho/Euler -> normalized debt position -> risk refresh -> candidate score.

Quote:
existing APR -> SYNERGY offered APR -> borrower savings -> gas/cost check -> available capacity check.

Execution target:
old debt is repaid, collateral is moved atomically or under an explicit user transaction, the new SYNERGY debt is created, and the protocol starts receiving hard-denominated interest.

No transaction is executed merely because the off-chain Hunter found a position. The borrower must authorize the migration.

## Security boundary

The Hunter is intentionally read-only in V6.

It does not hold private keys and does not submit arbitrary refinancing transactions.

A future executor must enforce:

- explicit borrower authorization;
- signed quote expiry;
- max slippage;
- maximum gas;
- collateral whitelist;
- oracle freshness;
- minimum health factor after migration;
- maximum single-borrower exposure;
- global utilization ceiling;
- pause/emergency controls.

## Running

Example:

python -m borrower_hunter.cli --source morpho --hardnav-units 50 --hard-price-usd <CURRENT_WPOL_USD> --rate 0.05 --top 25

Euler discovery:

python -m borrower_hunter.cli --source euler-discovery --top 25

## Next step

V7 should add:

- fresh Euler on-chain state adapter;
- Polygon RPC price/oracle adapter;
- Morpho refinance bundle builder;
- signed quote format;
- RefinanceRouter Solidity contract;
- dry-run transaction simulation;
- keeper/CRE automation;
- persistent candidate database and deduplication.
