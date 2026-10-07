import unittest

from block_revenue import Opportunity, BlockRevenueScheduler, SchedulerConfig
from block_revenue.flash_math import own_flash_fee, morpho_flash_fee, aave_flash_fee

class TestBlockRevenue(unittest.TestCase):
    def setUp(self):
        self.cfg = SchedulerConfig(
            hardnav_units=50.0,
            reserve_fraction=0.20,
            max_atomic_fraction_of_reserve=0.95,
            min_profit_units=0.001,
            min_confidence=0.70,
            max_capital_per_opportunity_fraction=0.60,
        )
        self.scheduler = BlockRevenueScheduler(self.cfg)

    def op(self, kind, capital, gross, fee=.0, gas=.0, slip=.0, confidence=.9):
        return Opportunity(
            kind=kind,
            source="fixture",
            block_number=100,
            hard_asset="WPOL",
            capital_units=capital,
            gross_profit_units=gross,
            funding_fee_units=fee,
            gas_cost_units=gas,
            slippage_units=slip,
            confidence=confidence,
            atomic=True,
            metadata={},
        )

    def test_budget_from_free_reserve(self):
        self.assertAlmostEqual(self.cfg.reserve_units, 10.0)
        self.assertAlmostEqual(self.cfg.atomic_budget_units, 9.5)

    def test_selects_positive_ev(self):
        arb = self.op("arb", 4.0, .08, fee=.01, gas=.01, slip=.01)
        flash = self.op("own_flash_demand", 3.0, .004)
        d = self.scheduler.decide(100, [arb, flash])
        self.assertEqual(len(d.selected), 2)
        self.assertAlmostEqual(d.expected_net_profit_units, .054)

    def test_rejects_negative_after_costs(self):
        op = self.op("arb", 2.0, .01, fee=.005, gas=.004, slip=.003)
        d = self.scheduler.decide(100, [op])
        self.assertEqual(len(d.selected), 0)
        self.assertIn(("arb", "below_min_profit"), d.rejected)

    def test_morpho_fee_is_zero(self):
        self.assertEqual(morpho_flash_fee(100), 0.0)

    def test_flash_fee_math(self):
        self.assertAlmostEqual(own_flash_fee(100, 5), .05)
        self.assertAlmostEqual(aave_flash_fee(100, 5), .05)

if __name__ == "__main__":
    unittest.main()
