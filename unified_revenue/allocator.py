from dataclasses import dataclass
from block_revenue.models import Opportunity, BlockDecision
from block_revenue.scheduler import BlockRevenueScheduler, SchedulerConfig

@dataclass(slots=True)
class UnifiedRevenueConfig:
    hardnav_units: float = 50.0
    reserve_fraction: float = 0.20
    max_atomic_fraction_of_reserve: float = 0.95
    min_profit_units: float = 0.001
    min_confidence: float = 0.70
    max_opportunities_per_block: int = 4
    max_capital_per_opportunity_fraction: float = 0.50

class UnifiedRevenueAllocator:
    """
    V11 allocator for mutually-exclusive hard-capital opportunities.

    Supported kinds:
      - graph_external_settlement
      - borrower_refinance
      - own_flash_demand
      - flash_funded_arbitrage
      - flash_funded_liquidation
      - collateral_yield

    Closed internal graph-arbitrage should NOT be submitted here as hard-income
    because it is consolidated-HardNAV neutral.
    """

    HARDNAV_PRODUCING_KINDS = {
        "graph_external_settlement",
        "borrower_refinance",
        "own_flash_demand",
        "flash_funded_arbitrage",
        "flash_funded_liquidation",
        "collateral_yield",
    }

    def __init__(self, cfg: UnifiedRevenueConfig):
        self.cfg = cfg
        self.scheduler = BlockRevenueScheduler(
            SchedulerConfig(
                hardnav_units=cfg.hardnav_units,
                reserve_fraction=cfg.reserve_fraction,
                max_atomic_fraction_of_reserve=cfg.max_atomic_fraction_of_reserve,
                min_profit_units=cfg.min_profit_units,
                min_confidence=cfg.min_confidence,
                max_opportunities_per_block=cfg.max_opportunities_per_block,
                max_capital_per_opportunity_fraction=cfg.max_capital_per_opportunity_fraction,
            )
        )

    def decide(self, block_number: int, opportunities: list[Opportunity]) -> BlockDecision:
        filtered: list[Opportunity] = []
        rejected: list[tuple[str, str]] = []

        for op in opportunities:
            if op.kind not in self.HARDNAV_PRODUCING_KINDS:
                rejected.append((op.kind, "not_hardnav_producing"))
                continue
            filtered.append(op)

        decision = self.scheduler.decide(block_number, filtered)
        decision.rejected.extend(rejected)
        return decision
