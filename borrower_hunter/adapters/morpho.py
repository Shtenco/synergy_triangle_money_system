from ..models import BorrowPosition
from ..http import JsonHttp

MARKETS_QUERY = """
query PolygonMarkets($first: Int!) {
  markets(
    first: $first
    orderBy: BorrowAssetsUsd
    orderDirection: Desc
    where: { chainId_in: [137], listed: true }
  ) {
    items {
      marketId
      lltv
      loanAsset { address symbol }
      collateralAsset { address symbol }
      state {
        borrowApy
        borrowAssetsUsd
        collateralAssetsUsd
        liquidityAssetsUsd
        utilization
      }
    }
  }
}
"""

POSITIONS_QUERY = """
query MarketPositions($first: Int!, $marketIds: [String!]!) {
  marketPositions(
    first: $first
    orderBy: BorrowShares
    orderDirection: Desc
    where: { marketUniqueKey_in: $marketIds }
  ) {
    items {
      market {
        marketId
        lltv
        loanAsset { address symbol }
        collateralAsset { address symbol }
        state { borrowApy }
      }
      user { address }
      state { borrowAssetsUsd collateralUsd }
    }
  }
}
"""

class MorphoPolygonAdapter:
    def __init__(self, graphql_url: str, http: JsonHttp | None = None):
        self.graphql_url = graphql_url
        self.http = http or JsonHttp()

    def _graphql(self, query: str, variables: dict) -> dict:
        body = self.http.post(self.graphql_url, {"query": query, "variables": variables})
        if body.get("errors"):
            raise RuntimeError(f"Morpho GraphQL error: {body['errors']}")
        return body["data"]

    def list_market_ids(self, limit: int = 100) -> list[str]:
        data = self._graphql(MARKETS_QUERY, {"first": limit})
        return [x["marketId"] for x in data.get("markets", {}).get("items", [])]

    def scan(self, market_limit: int = 100, position_limit: int = 500) -> list[BorrowPosition]:
        ids = self.list_market_ids(market_limit)
        if not ids:
            return []
        out: list[BorrowPosition] = []
        for i in range(0, len(ids), 50):
            data = self._graphql(
                POSITIONS_QUERY,
                {"first": position_limit, "marketIds": ids[i:i + 50]},
            )
            for row in data.get("marketPositions", {}).get("items", []):
                market = row["market"]
                state = row["state"]
                debt = float(state.get("borrowAssetsUsd") or 0.0)
                collateral = float(state.get("collateralUsd") or 0.0)
                if debt <= 0 or collateral <= 0:
                    continue
                lltv = float(market.get("lltv") or 0.0)
                if lltv > 10:
                    lltv /= 1e18
                hf = collateral * lltv / debt if debt else 0.0
                out.append(BorrowPosition(
                    protocol="morpho",
                    chain_id=137,
                    account=row["user"]["address"],
                    market_id=market["marketId"],
                    debt_asset=(market.get("loanAsset") or {}).get("symbol") or (market.get("loanAsset") or {}).get("address", ""),
                    collateral_asset=(market.get("collateralAsset") or {}).get("symbol") or (market.get("collateralAsset") or {}).get("address", ""),
                    debt_usd=debt,
                    collateral_usd=collateral,
                    borrow_apy=float((market.get("state") or {}).get("borrowApy") or 0.0),
                    liquidation_ltv=lltv,
                    health_factor=hf,
                    source="https://api.morpho.org/graphql",
                    fresh=True,
                ))
        return out
