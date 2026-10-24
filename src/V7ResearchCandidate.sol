// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
/// @notice Parameters selected by synthetic V7 study. NOT risk-validated.
/// @dev Research helper only. Pass these to V6 constructor when testing;
///      this helper intentionally cannot mutate deployed contracts.
library V7ResearchCandidate {
    uint256 internal constant BUY_WIDTH = 100_000 ether;
    uint256 internal constant SELL_FLAT = 1_200 ether;
    uint256 internal constant SELL_TAIL = 2_000 ether;
    uint256 internal constant INITIAL_PRICE_WAD = 1 ether;
    uint256 internal constant ORACLE_BAND_BPS = 100;
    uint256 internal constant ALPHA_SCALE_USDC_6D = 15_000 * 1e6;
    uint256 internal constant OWNER_SHARE_BPS = 3_000;
    uint256 internal constant RETAINED_SHARE_BPS = 7_000;
}
