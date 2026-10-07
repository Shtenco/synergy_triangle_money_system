from dataclasses import dataclass
import os

@dataclass(slots=True)
class HunterConfig:
    chain_id: int = 137
    min_debt_usd: float = 100.0
    max_debt_usd: float = 1_000_000.0
    target_borrow_apy: float = 0.05
    min_savings_apy: float = 0.015
    min_health_factor: float = 1.20
    min_collateral_ratio: float = 1.50
    expected_gas_usd: float = 0.50
    min_net_annual_savings_usd: float = 5.0
    hardnav_units: float = 50.0
    hard_asset_price_usd: float = 0.0
    deploy_fraction: float = 0.80
    collateral_factor: float = 0.80
    reuse_fraction: float = 0.65
    max_utilization: float = 0.80
    max_single_borrower_fraction: float = 0.35
    morpho_graphql: str = "https://api.morpho.org/graphql"
    euler_polygon_subgraph: str = "https://api.goldsky.com/api/public/project_cm4iagnemt1wp01xn4gh1agft/subgraphs/euler-simple-polygon/latest/gn"

    @property
    def hardnav_usd(self) -> float:
        if self.hard_asset_price_usd <= 0:
            raise ValueError("hard_asset_price_usd must be set from an oracle/current market price before quoting")
        return self.hardnav_units * self.hard_asset_price_usd

    @property
    def gross_credit_capacity_units(self) -> float:
        return self.hardnav_units * self.deploy_fraction * self.collateral_factor * self.reuse_fraction

    @property
    def lendable_capacity_units(self) -> float:
        return self.gross_credit_capacity_units * self.max_utilization

    @property
    def gross_credit_capacity_usd(self) -> float:
        return self.gross_credit_capacity_units * self.hard_asset_price_usd

    @property
    def lendable_capacity_usd(self) -> float:
        return self.lendable_capacity_units * self.hard_asset_price_usd

    @classmethod
    def from_env(cls) -> "HunterConfig":
        c = cls()
        for field in c.__dataclass_fields__:
            key = f"SYNERGY_{field.upper()}"
            if key not in os.environ:
                continue
            current = getattr(c, field)
            raw = os.environ[key]
            if isinstance(current, int):
                value = int(raw)
            elif isinstance(current, float):
                value = float(raw)
            else:
                value = raw
            setattr(c, field, value)
        return c
