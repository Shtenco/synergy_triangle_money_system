from dataclasses import dataclass, asdict

@dataclass(slots=True)
class Opportunity:
    kind: str
    source: str
    block_number: int
    hard_asset: str
    capital_units: float
    gross_profit_units: float
    funding_fee_units: float
    gas_cost_units: float
    slippage_units: float
    confidence: float
    atomic: bool
    metadata: dict

    @property
    def net_profit_units(self) -> float:
        return (
            self.gross_profit_units
            - self.funding_fee_units
            - self.gas_cost_units
            - self.slippage_units
        )

    def to_dict(self) -> dict:
        d = asdict(self)
        d["net_profit_units"] = self.net_profit_units
        return d

@dataclass(slots=True)
class BlockDecision:
    block_number: int
    selected: list[Opportunity]
    rejected: list[tuple[str, str]]
    expected_net_profit_units: float
    capital_used_units: float

    def to_dict(self) -> dict:
        return {
            "block_number": self.block_number,
            "selected": [x.to_dict() for x in self.selected],
            "rejected": self.rejected,
            "expected_net_profit_units": self.expected_net_profit_units,
            "capital_used_units": self.capital_used_units,
        }
