import unittest

from block_revenue.models import Opportunity
from unified_revenue.allocator import UnifiedRevenueAllocator, UnifiedRevenueConfig

class UnifiedAllocatorTest(unittest.TestCase):
    def setUp(self):
        self.alloc = UnifiedRevenueAllocator(
            UnifiedRevenueConfig(
                hardnav_units=50.0,
                reserve_fraction=0.20,
                max_atomic_fraction_of_reserve=0.95,
                min_profit_units=0.001,
                min_confidence=0.70,
                max_opportunities_per_block=4,
                max_capital_per_opportunity_fraction=0.70,
            )
        )

    def op(self, kind, capital, gross, fee=0.0, gas=0.0, slip=0.0, conf=.9):
        return Opportunity(
            kind=kind,
            source="fixture",
            block_number=777,
            hard_asset="WPOL",
            capital_units=capital,
            gross_profit_units=gross,
            funding_fee_units=fee,
            gas_cost_units=gas,
            slippage_units=slip,
            confidence=conf,
            atomic=True,
            metadata={},
        )

    def test_closed_internal_arb_rejected(self):
        d=self.alloc.decide(777,[self.op("closed_internal_graph_arb",1,.1)])
        self.assertEqual(len(d.selected),0)
        self.assertIn(("closed_internal_graph_arb","not_hardnav_producing"),d.rejected)

    def test_graph_vs_flash_uses_best_net_roi(self):
        graph=self.op("graph_external_settlement",3,.12,gas=.01,slip=.01)
        flash=self.op("own_flash_demand",3,.02)
        d=self.alloc.decide(777,[graph,flash])
        self.assertEqual(d.selected[0].kind,"graph_external_settlement")

    def test_same_reserve_not_double_allocated(self):
        # Atomic budget = 50 * 20% * 95% = 9.5
        a=self.op("graph_external_settlement",6,.12)
        b=self.op("flash_funded_liquidation",6,.11)
        d=self.alloc.decide(777,[a,b])
        self.assertEqual(len(d.selected),1)
        self.assertLessEqual(d.capital_used_units,9.5)

    def test_negative_atomic_edge_rejected(self):
        a=self.op("flash_funded_arbitrage",2,.01,fee=.004,gas=.004,slip=.004)
        d=self.alloc.decide(777,[a])
        self.assertEqual(len(d.selected),0)

if __name__ == "__main__":
    unittest.main()
