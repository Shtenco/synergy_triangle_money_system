# V9 Adaptive Market Maker

V9 replaces the fixed 80/75 controller with a state-feedback controller.

The pools are unchanged:

- RUBX/USDC
- RUBZ/USDC
- RUBX/RUBZ

The objective is unchanged:

maximize delta GrossTVL / net external USDC input

while preserving consolidated HardNAV accounting and keeping final prices inside the reference corridor.

## State inputs used every block

The controller observes:

1. absolute block-over-block price move;
2. GrossTVL / HardNAV;
3. free USDC Treasury / HardNAV.

These state variables determine the emission and buyback correction percentages for the current block.

## Emission rule

Before feedback:

- minimum emission correction = 58%
- maximum base emission correction = 74.8%
- a 5% block move corresponds to the full movement factor

TVL feedback then modifies this value.

Target GrossTVL/HardNAV:

3.55x.

When current TVL/HardNAV is below target, emission is allowed to increase.

When TVL/HardNAV rises above target, emission is reduced.

The multiplier is bounded between 0.40x and 1.25x.

In the 100-block reference run, effective emission correction ranged approximately from 72.7% to 93.5%.

## BUY+BURN rule

Before Treasury feedback:

- minimum buyback correction = 2%
- maximum base buyback correction = 60%

Large negative block moves therefore receive more aggressive support than small negative moves.

Treasury target:

0.40% of HardNAV.

If free Treasury falls below that level, buyback strength is scaled down proportionally.

If Treasury is comfortably above the target, buyback can be boosted up to 1.25x.

In the reference run, effective BUY+BURN correction ranged approximately from 16.9% to 75%.

## Reference result

Same deterministic 100-block scenario as V8.

V9 adaptive:

- GrossTVL = 3.7524034447
- HardNAV = 1.3565856073
- net external USDC input = 0.3565856073
- delta GrossTVL / net input = 3.7926473111x
- X/USDC = 1.1489914475
- Z/USDC = 1.0761031609
- X/Z = 1.0665834248
- Treasury USDC = 0.0005433439

Fixed V8 80/75 reference:

- delta GrossTVL / net input = 3.7501851853x

Adaptive improvement:

approximately +1.13% on the multiplier in this exact scenario.

## HardNAV invariant

The adaptive controller does not change the accounting rule.

Initial HardNAV:

1.0 USDC.

Net external USDC input:

0.3565856073.

Expected final HardNAV:

1.3565856073.

Reference-model final HardNAV:

1.3565856073.

Internal MINT+SELL and BUY+BURN therefore do not create hard assets in the accounting model.

## Why V9 is better than a fixed coefficient

A fixed controller spends the same fraction of every move regardless of state.

V9 behaves differently:

- small move -> lower correction;
- large move -> stronger correction;
- low TVL/HardNAV -> more expansion allowed;
- high TVL/HardNAV -> emission throttled;
- low Treasury -> buyback automatically weakened;
- high Treasury -> stronger buyback is allowed.

This creates a real state-feedback loop rather than a single static percentage.

## EVM tests

The isolated V9 Foundry test suite checks:

- 100 deterministic blocks;
- HardNAV conservation;
- positive reserves in all three pools;
- final price corridor;
- adaptive multiplier above 3.77x;
- larger move produces stronger emission and buyback;
- higher TVL/HardNAV reduces emission;
- lower Treasury reduces buyback;
- an actual down block performs BUY+BURN.

The numerical reference is not treated as a substitute for a successful EVM run.
