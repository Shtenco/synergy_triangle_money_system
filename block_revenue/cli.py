import argparse
import json

from .models import Opportunity
from .scheduler import BlockRevenueScheduler, SchedulerConfig

def main():
    p = argparse.ArgumentParser(description="SYNERGY V7 Block Revenue Scheduler")
    p.add_argument("--block", type=int, required=True)
    p.add_argument("--hardnav-units", type=float, default=50.0)
    p.add_argument("--reserve-fraction", type=float, default=0.20)
    p.add_argument("--opportunity-json", action="append", default=[])
    args = p.parse_args()

    cfg = SchedulerConfig(
        hardnav_units=args.hardnav_units,
        reserve_fraction=args.reserve_fraction,
    )
    scheduler = BlockRevenueScheduler(cfg)

    opportunities = []
    for raw in args.opportunity_json:
        opportunities.append(Opportunity(**json.loads(raw)))

    print(json.dumps(
        scheduler.decide(args.block, opportunities).to_dict(),
        indent=2
    ))

if __name__ == "__main__":
    main()
