import argparse
import json
from dataclasses import asdict

from .config import HunterConfig
from .hunter import BorrowerHunter
from .adapters.morpho import MorphoPolygonAdapter
from .adapters.euler import EulerPolygonDiscovery

def main():
    parser = argparse.ArgumentParser(description="SYNERGY Autonomous Borrower Market Maker")
    parser.add_argument("--source", choices=["morpho", "euler-discovery"], default="morpho")
    parser.add_argument("--top", type=int, default=25)
    parser.add_argument("--hardnav-units", type=float, default=None)
    parser.add_argument("--hard-price-usd", type=float, default=None)
    parser.add_argument("--rate", type=float, default=None, help="offered borrow APY as decimal, e.g. 0.05")
    parser.add_argument("--hard-yield", type=float, default=0.0)
    args = parser.parse_args()

    cfg = HunterConfig.from_env()
    if args.hardnav_units is not None:
        cfg.hardnav_units = args.hardnav_units
    if args.hard_price_usd is not None:
        cfg.hard_asset_price_usd = args.hard_price_usd
    if args.rate is not None:
        cfg.target_borrow_apy = args.rate

    if args.source == "morpho":
        positions = MorphoPolygonAdapter(cfg.morpho_graphql).scan()
        hunter = BorrowerHunter(cfg)
        quotes = hunter.rank(positions, args.top)
        print(json.dumps({
            "config": {
                "hardnav_units": cfg.hardnav_units,
                "hard_asset_price_usd": cfg.hard_asset_price_usd,
                "hardnav_usd": cfg.hardnav_usd,
                "lendable_capacity_units": cfg.lendable_capacity_units,
                "lendable_capacity_usd": cfg.lendable_capacity_usd,
                "target_borrow_apy": cfg.target_borrow_apy,
            },
            "quotes": [q.to_dict() for q in quotes],
            "projection": hunter.hardnav_projection(quotes, args.hard_yield),
        }, indent=2))
    else:
        rows = EulerPolygonDiscovery(cfg.euler_polygon_subgraph).discover()
        print(json.dumps({
            "warning": "Euler subgraph is discovery-only. Refresh each position with Euler Lens/V3/on-chain state before quoting.",
            "count": len(rows),
            "rows": [asdict(r) for r in rows[:args.top]],
        }, indent=2))

if __name__ == "__main__":
    main()
