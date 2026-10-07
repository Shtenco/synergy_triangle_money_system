import unittest
from borrower_hunter.adapters.euler import EulerPolygonDiscovery
from borrower_hunter.adapters.morpho import MorphoPolygonAdapter

class FakeHttp:
    def __init__(self, replies):
        self.replies=list(replies)
    def post(self, url, payload):
        return self.replies.pop(0)

class TestAdapters(unittest.TestCase):
    def test_euler_entry_parser(self):
        account='0x'+'11'*20
        vault='0x'+'22'*20
        a,v=EulerPolygonDiscovery.parse_entry(account+vault[2:])
        self.assertEqual(a,account)
        self.assertEqual(v,vault)

    def test_morpho_normalization(self):
        market={"marketId":"m1"}
        pos={"marketPositions":{"items":[{
            "market":{
                "marketId":"m1",
                "lltv":.86,
                "loanAsset":{"symbol":"USDC"},
                "collateralAsset":{"symbol":"WETH"},
                "state":{"borrowApy":.12}
            },
            "user":{"address":"0xabc"},
            "state":{"borrowAssetsUsd":1000,"collateralUsd":2000}
        }]}}
        http=FakeHttp([
            {"data":{"markets":{"items":[market]}}},
            {"data":pos},
        ])
        rows=MorphoPolygonAdapter('x',http=http).scan()
        self.assertEqual(len(rows),1)
        self.assertAlmostEqual(rows[0].health_factor,1.72)
        self.assertEqual(rows[0].chain_id,137)

if __name__ == "__main__":
    unittest.main()
