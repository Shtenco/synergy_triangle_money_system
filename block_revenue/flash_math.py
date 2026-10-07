from dataclasses import dataclass

@dataclass(slots=True)
class FlashFeeQuote:
    amount_units: float
    fee_bps: float
    fee_units: float
    gross_annualized_if_every_block: float

def own_flash_fee(amount_units: float, fee_bps: float) -> float:
    if amount_units < 0 or fee_bps < 0:
        raise ValueError("amount and fee must be non-negative")
    return amount_units * fee_bps / 10_000.0

def morpho_flash_fee(amount_units: float) -> float:
    # Morpho Blue flash fee is currently zero by protocol design.
    return 0.0

def aave_flash_fee(amount_units: float, premium_bps: float) -> float:
    if amount_units < 0 or premium_bps < 0:
        raise ValueError("amount and premium must be non-negative")
    return amount_units * premium_bps / 10_000.0
