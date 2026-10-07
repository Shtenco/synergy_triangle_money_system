from dataclasses import dataclass
from .models import Opportunity, BlockDecision

@dataclass(slots=True)
class SchedulerConfig:
    hardnav_units: float = 50.0
    reserve_fraction: float = 0.20
    max_atomic_fraction_of_reserve: float = 0.95
    min_profit_units: float = 0.001
    min_confidence: float = 0.70
    max_opportunities_per_block: int = 4
    max_capital_per_opportunity_fraction: float = 0.50

    @property
    def reserve_units(self) -> float:
        return self.hardnav_units * self.reserve_fraction

    @property
    def atomic_budget_units(self) -> float:
        return self.reserve_units * self.max_atomic_fraction_of_reserve

class BlockRevenueScheduler:
    """
    Selects mutually budget-compatible positive-EV opportunities for a block.
    It does not create a transaction itself; execution happens only after fresh
    on-chain simulation and minProfit protection.
    """

    def __init__(self, cfg: SchedulerConfig):
        self.cfg = cfg

    def decide(self, block_number: int, opportunities: list[Opportunity]) -> BlockDecision:
        budget = self.cfg.atomic_budget_units
        max_per_opp = budget * self.cfg.max_capital_per_opportunity_fraction

        selected: list[Opportunity] = []
        rejected: list[tuple[str, str]] = []

        candidates = []
        for op in opportunities:
            if op.block_number != block_number:
                rejected.append((op.kind, "wrong_block"))
                continue
            if not op.atomic:
                rejected.append((op.kind, "not_atomic"))
                continue
            if op.confidence < self.cfg.min_confidence:
                rejected.append((op.kind, "low_confidence"))
                continue
            if op.net_profit_units < self.cfg.min_profit_units:
                rejected.append((op.kind, "below_min_profit"))
                continue
            if op.capital_units <= 0 or op.capital_units > max_per_opp:
                rejected.append((op.kind, "capital_limit"))
                continue

            roi = op.net_profit_units / op.capital_units
            candidates.append((roi, op.net_profit_units, op))

        candidates.sort(key=lambda x: (x[0], x[1]), reverse=True)

        used = 0.0
        for _, _, op in candidates:
            if len(selected) >= self.cfg.max_opportunities_per_block:
                rejected.append((op.kind, "block_opportunity_limit"))
                continue
            if used + op.capital_units > budget:
                rejected.append((op.kind, "reserve_budget"))
                continue
            selected.append(op)
            used += op.capital_units

        return BlockDecision(
            block_number=block_number,
            selected=selected,
            rejected=rejected,
            expected_net_profit_units=sum(x.net_profit_units for x in selected),
            capital_used_units=used,
        )
