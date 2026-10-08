from dataclasses import dataclass
from ..http import JsonHttp

VAULTS_QUERY = """
query Vaults($first: Int!) {
  vaults(first: $first, orderBy: id, orderDirection: asc) { id factory }
  _meta { block { number } }
}
"""

ACTIVE_ACCOUNTS_QUERY = """
query ActiveAccounts($first: Int!, $skip: Int!) {
  trackingActiveAccounts(first: $first, skip: $skip) {
    id
    deposits
    borrows
  }
}
"""

@dataclass(slots=True)
class EulerDiscoveredBorrow:
    account_prefix: str
    sub_account: str
    vault: str
    indexed_block: int | None

class EulerPolygonDiscovery:
    """Discovery only. Refresh debt/APY/health with Euler Lens/V3/on-chain reads before quoting."""

    def __init__(self, subgraph_url: str, http: JsonHttp | None = None):
        self.subgraph_url = subgraph_url
        self.http = http or JsonHttp()

    def _graphql(self, query: str, variables: dict) -> dict:
        body = self.http.post(self.subgraph_url, {"query": query, "variables": variables})
        if body.get("errors"):
            raise RuntimeError(f"Euler subgraph error: {body['errors']}")
        return body["data"]

    @staticmethod
    def parse_entry(entry: str) -> tuple[str, str]:
        if not entry.startswith("0x") or len(entry) != 82:
            raise ValueError("Euler tracking entry must be 40-byte concatenated account+vault hex")
        return entry[:42], "0x" + entry[42:]

    def discover(self, page_size: int = 500, max_pages: int = 10) -> list[EulerDiscoveredBorrow]:
        meta = self._graphql(VAULTS_QUERY, {"first": 1})
        block = (((meta.get("_meta") or {}).get("block") or {}).get("number"))
        found: list[EulerDiscoveredBorrow] = []
        for page in range(max_pages):
            rows = self._graphql(
                ACTIVE_ACCOUNTS_QUERY,
                {"first": page_size, "skip": page * page_size},
            ).get("trackingActiveAccounts", [])
            if not rows:
                break
            for row in rows:
                for entry in row.get("borrows") or []:
                    account, vault = self.parse_entry(entry)
                    found.append(EulerDiscoveredBorrow(
                        row["id"],
                        account,
                        vault,
                        int(block) if block is not None else None,
                    ))
            if len(rows) < page_size:
                break
        return found
