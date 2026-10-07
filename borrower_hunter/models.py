from dataclasses import dataclass, asdict

@dataclass(slots=True)
class BorrowPosition:
    protocol: str
    chain_id: int
    account: str
    market_id: str
    debt_asset: str
    collateral_asset: str
    debt_usd: float
    collateral_usd: float
    borrow_apy: float
    liquidation_ltv: float
    health_factor: float
    source: str
    fresh: bool = True

    @property
    def ltv(self) -> float:
        return self.debt_usd / self.collateral_usd if self.collateral_usd > 0 else float("inf")

    def to_dict(self):
        return asdict(self)

@dataclass(slots=True)
class RefinanceQuote:
    protocol: str
    account: str
    market_id: str
    principal_usd: float
    current_borrow_apy: float
    offered_apy: float
    savings_apy: float
    annual_borrower_savings_usd: float
    annual_protocol_hard_income_usd: float
    annual_protocol_hard_income_units: float
    required_collateral_usd: float
    expected_gas_usd: float
    score: float
    eligible: bool
    reason: str

    def to_dict(self):
        return asdict(self)
