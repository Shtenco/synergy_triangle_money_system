# SYNERGY Recursive Collateral Money System — EVM V3

This repository contains only the current version of the system.

The previous triangle-only experiments, old conservation notes, old V4 files and old contracts have been removed from the active tree. The current architecture is a five-pool protocol-owned-liquidity system with recursive collateral reuse, hard-only collateral valuation, MINT/SELL, BUY/BURN, ADDLP, internal arbitrage, a treasury revenue bucket and explicit consolidated HardNAV accounting.

## 1. Current economic architecture

The system has four economic assets:

- RUBX — protocol-mintable internal token.
- RUBZ — protocol-mintable internal token.
- WPOL — primary hard collateral on Polygon.
- COLL — second hard collateral. In production this can be a yield-bearing or otherwise externally valuable collateral asset.

The protocol controls five CPMM pools:

1. RUBX/WPOL
2. RUBZ/WPOL
3. RUBX/RUBZ
4. RUBX/COLL
5. RUBZ/COLL

All five pools may be protocol-owned. External pools are not required for the internal architecture.

The external world is still required as a source of real economic value: outside trading volume, fees paid by users, collateral yield, external arbitrage, protocol revenue or another genuine hard-asset cash flow.

Internal MINT, BURN, ADDLP, swaps and collateral reuse are not counted as new HardNAV.

## 2. What the system is trying to maximize

The objective is not maximum paper TVL.

The objective is long-run consolidated HardNAV growth while keeping enough free hard reserve and surviving large RUBX/RUBZ sell shocks.

Three values must always be separated:

- Gross TVL — marked value of all pool sides.
- MarkNAV — mark-to-market value of protocol assets.
- HardNAV — actual protocol-owned WPOL and COLL in Treasury, Vault, Engine and protocol-owned pools.

Moving WPOL from Treasury to a protocol-owned pool does not increase HardNAV.

Minting RUBX and selling it into a protocol-owned RUBX/WPOL pool can move WPOL from the pool to Treasury, but it does not create new consolidated HardNAV.

Only an actual external hard inflow or realized external profit increases HardNAV.

## 3. Recursive collateral layer

Primary hard liquidity is deposited into RUBX/WPOL, RUBZ/WPOL, RUBX/COLL and RUBZ/COLL.

The LP tokens are protocol-owned and can be pledged to CollateralVault.

CollateralVault values only the hard side of each LP. The RUBX/RUBZ mark is never treated as independent hard collateral.

Baseline parameters:

- primary hard deployment: 50% of HardNAV
- minimum free hard reserve floor: 20% of HardNAV
- LP collateral factor: 65%
- collateral reuse ceiling: 50%
- recursively-created LP valuation factor: 25% of primary LP
- minimum health factor: 1.25
- CPMM fee: 0.30%
- modeled realized external capture: 0.27% of external fee-paying volume

The recursive credit loop is deliberately haircutted.

For each 1 unit of HardNAV, the baseline model deploys 0.50 units as primary hard liquidity.

The first internal hard draw supported by primary LP is 0.1625.

Recursively-created LP is worth only 25% of primary LP for collateral purposes, so later reuse layers rapidly decay.

The converged additional internal hard deployment is:

0.17687074829931973 per 1 HardNAV.

Total hard capital deployed into hard-side pools is therefore:

0.6768707482993197 per 1 HardNAV.

The remaining hard reserve is about:

0.3231292517006803 per 1 HardNAV.

This is above the 20% minimum reserve floor.

Because each hard side can be paired with freshly minted RUBX or RUBZ, the hard-pool TVL supported per 1 HardNAV is approximately:

1.3537414965986394.

This is capital efficiency, not creation of hard money.

## 4. Second-order HardNAV multiplier

The second-order multiplier appears only when the additional liquidity actually attracts external fee-paying turnover.

At the baseline external capture rate of 0.27%, one unit of new real HardNAV supports additional liquidity, that liquidity handles external turnover, and the captured fees/arb profit become new HardNAV. That new HardNAV can repeat the same process.

Baseline modeled multipliers:

| External turnover per period | Total HardNAV income from 1 unit of real seed income |
|---:|---:|
| 5x | 1.0186157220 |
| 10x | 1.0379376814 |
| 20x | 1.0788674094 |
| 30x | 1.1231576776 |
| 50x | 1.2236234236 |
| 75x | 1.3776621916 |
| 100x | 1.5760694757 |

These are conditional economic model outputs, not guaranteed yields.

They require actual outside turnover at the stated level and actual net hard-asset capture of 0.27%.

## 5. Exact requested scenario: 50 WPOL start + 50 WPOL hard input

### Case A — the incoming 50 WPOL remains inside the protocol

Initial HardNAV:

50 WPOL.

New retained hard input:

50 WPOL.

HardNAV immediately after the capital input, before any external turnover:

100 WPOL.

For the second 50 WPOL we then apply the baseline safe collateral policy.

At 75x turnover the liquidity created by each new unit of HardNAV supports approximately 101.5306122449 units of external volume per period.

For the new 50 WPOL seed this corresponds to approximately:

5,076.530612245 WPOL-equivalent external turnover.

With net hard capture of 0.27%, first-order realized hard revenue is:

13.7066326531 WPOL.

So after the first revenue layer:

113.7066326531 WPOL HardNAV.

The realized 13.7066326531 WPOL can itself be recursively reinvested under the same policy. The next modeled layers are:

- layer 2: +3.7574355737 WPOL
- layer 3: +1.0300357825 WPOL
- layer 4: +0.2823664418 WPOL
- layer 5: +0.0774058618 WPOL
- layer 6: +0.0212194743 WPOL
- layer 7: +0.0058169508 WPOL
- later layers rapidly converge

The converged second-order multiplier at 75x turnover is:

1.377662191607507.

Therefore the new retained 50 WPOL produces, under these assumptions:

68.8831095804 WPOL total hard contribution including the original 50 WPOL.

Adding the original system HardNAV of 50 WPOL:

FINAL MODELED HARDNAV = 118.8831095804 WPOL.

This is the headline baseline scenario for this repository.

It does NOT mean that 50 WPOL becomes 68.88 WPOL without outside activity. The additional 18.8831095804 WPOL is funded by modeled external fee-paying turnover and external economic capture.

### Case B — the incoming 50 WPOL is only trading flow and exits again

If 50 WPOL merely passes through the pools and is returned to the outside trader, it is not new protocol capital.

At 0.27% net capture, the first hard revenue from a single 50 WPOL flow is only:

0.135 WPOL.

If that realized 0.135 WPOL is then given the same 75x recursive multiplier, its modeled total contribution becomes approximately:

0.1859843959 WPOL.

In that interpretation:

50 WPOL initial HardNAV becomes approximately 50.1859843959 WPOL, not 118.883 WPOL.

This distinction is mandatory in all reports.

## 6. Stress model

The stress tests do not merely change an oracle.

The intended EVM stress sells RUBX and RUBZ into the protocol's hard pools until the real CPMM spot prices fall toward 0.80 or 0.70.

That removes actual WPOL/COLL from protocol-owned pools and transfers it to the external seller.

Under the baseline deployment ratio, the analytical hard-reserve retention is approximately:

- simultaneous 20% RUBX/RUBZ shock: 92.8540853772% of HardNAV retained
- simultaneous 30% RUBX/RUBZ shock: 88.9439949933% of HardNAV retained

Baseline analytical health factors:

- 20% shock: about 1.7889
- 30% shock: about 1.6733

Both remain above the configured minimum 1.25 in the current model.

If the mature 50+50 baseline scenario has reached 118.8831095804 WPOL before the shock, the same analytical deployment ratio implies approximately:

- after 20% shock: 110.3878240688 WPOL HardNAV
- after 30% shock: 105.7393870330 WPOL HardNAV

Actual EVM reserve movement is tested separately and is the authoritative implementation check.

## 7. Contract roles

### SoftToken.sol

Mintable/burnable RUBX/RUBZ-style ERC20 used by the engine.

### CPMMPool.sol

Minimal constant-product AMM with 0.30% baseline fee support, LP shares, add liquidity and exact-input swaps.

### Treasury.sol

Holds hard assets and tracks a separate realized external revenue bucket.

Dividends or external distributions cannot be paid from an empty realized-revenue bucket.

### RiskOracle.sol

Price registry for hard-collateral accounting. It is not used as a substitute for real AMM reserve movement in stress tests.

### CollateralVault.sol

Accepts protocol-owned LP as collateral.

Only the hard side of LP is eligible.

Primary LP and recursively-created LP are valued differently.

The vault enforces collateral factor, reuse ceiling and minimum health factor.

### RecursiveEngine.sol

Coordinates MINT/SELL, BUY/BURN primitives, ADDLP, LP pledging, internal hard redeployment and consolidated HardNAV checks.

Any internal redeployment path must preserve consolidated HardNAV.

### EconomicModel.sol

Pure fixed-point EVM implementation of the recursive collateral and second-order multiplier math.

It includes the exact 50 WPOL + 50 WPOL scenario used in this README.

## 8. Core invariants

The test suite is built around the following invariants:

1. Internal MINT/SELL cannot create consolidated HardNAV.
2. Internal hard movement between Treasury, Engine, Vault and owned pools cannot create consolidated HardNAV.
3. External retained hard input increases HardNAV one-for-one before profit.
4. Dividends cannot be paid without realized external revenue.
5. RUBX/RUBZ paper value is not counted as hard collateral.
6. Recursive LP receives the configured secondary haircut.
7. Internal collateral reuse cannot exceed the configured credit limit.
8. Free hard reserve cannot be silently counted twice.
9. Real sell shocks are modeled by swaps that remove hard assets from pools.
10. The second-order multiplier is reported separately from direct capital input.

## 9. Running the EVM tests

Install Foundry and run:

forge test -vvv

The GitHub Actions workflow also runs the Foundry suite on every push to main.

Run the numerical reference model with:

python3 model/simulate.py

The numerical model and EconomicModel.sol must agree on the baseline 50+50 scenario within fixed-point rounding tolerance.

## 10. What this system does and does not claim

The architecture can be fully internal at the pool level. It does not require an outside DEX to exist.

It does require real external economic activity if HardNAV is expected to grow above contributed hard capital.

The collateral loop increases capital efficiency.

ADDLP increases liquidity depth.

MINT/BURN manages the internal token supply.

Internal arbitrage synchronizes the five pools.

External turnover, fees, yield or external PnL are the source of new real hard value.

The target research question is therefore:

How much sustainable external turnover and follow-on HardNAV can one unit of genuine hard income support without violating the reserve floor or causing a liquidation cascade during 20–30% RUBX/RUBZ shocks?

The current baseline answer is conditional:

- safe modeled hard deployment: about 67.687% of HardNAV
- free hard reserve: about 32.313%
- 30% analytical stress retention: about 88.944%
- 30% analytical health factor: about 1.673
- 75x-turnover second-order multiplier: about 1.377662x
- 50 WPOL initial + 50 WPOL retained input + 75x modeled external turnover: about 118.88310958 WPOL final modeled HardNAV
