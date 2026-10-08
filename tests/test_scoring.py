import unittest
from borrower_hunter import HunterConfig, BorrowerHunter, BorrowPosition

class TestHunter(unittest.TestCase):
    def setUp(self):
        self.cfg = HunterConfig(
            hardnav_units=50.0,
            hard_asset_price_usd=100.0,
            expected_gas_usd=0.25,
            min_net_annual_savings_usd=1.0,
            max_single_borrower_fraction=1.0,
        )
        self.hunter = BorrowerHunter(self.cfg)

    def p(self, apy=.10, debt=1000, coll=2000, hf=1.5):
        return BorrowPosition(
            "morpho",137,"0xabc","m1","USDC","WETH",
            debt,coll,apy,.86,hf,"fixture"
        )

    def test_capacity_units(self):
        self.assertAlmostEqual(self.cfg.gross_credit_capacity_units, 20.8, places=9)
        self.assertAlmostEqual(self.cfg.lendable_capacity_units, 16.64, places=9)
        self.assertAlmostEqual(self.cfg.gross_credit_capacity_usd, 2080.0, places=9)
        self.assertAlmostEqual(self.cfg.lendable_capacity_usd, 1664.0, places=9)

    def test_good_candidate_is_eligible(self):
        q = self.hunter.rank([self.p()], 1)[0]
        self.assertTrue(q.eligible)
        self.assertAlmostEqual(q.principal_usd, 1000.0, places=9)
        self.assertAlmostEqual(q.annual_protocol_hard_income_usd, 50.0, places=9)
        self.assertAlmostEqual(q.annual_protocol_hard_income_units, .5, places=9)
        self.assertGreater(q.annual_borrower_savings_usd, 0)

    def test_low_rate_rejected(self):
        q = self.hunter.rank([self.p(apy=.055)], 1)[0]
        self.assertFalse(q.eligible)
        self.assertIn("insufficient_rate_edge", q.reason)

    def test_projection(self):
        q = self.hunter.rank([self.p()], 1)
        r = self.hunter.hardnav_projection(q, hard_yield_rate=.01)
        self.assertAlmostEqual(r["annual_credit_income_usd"], 50.0, places=9)
        self.assertAlmostEqual(r["annual_yield_income_usd"], 50.0, places=9)
        self.assertAlmostEqual(r["projected_hardnav_usd"], 5100.0, places=9)
        self.assertAlmostEqual(r["hardnav_multiplier"], 1.02, places=9)

if __name__ == "__main__":
    unittest.main()
