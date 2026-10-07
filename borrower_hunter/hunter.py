from .config import HunterConfig
from .models import BorrowPosition, RefinanceQuote
from .scoring import CandidateScorer

class BorrowerHunter:
    def __init__(self, cfg: HunterConfig):
        self.cfg = cfg
        self.scorer = CandidateScorer(cfg)

    def rank(self, positions: list[BorrowPosition], top_n: int = 50) -> list[RefinanceQuote]:
        remaining = self.cfg.lendable_capacity_usd
        quotes: list[RefinanceQuote] = []
        ordered = sorted(
            positions,
            key=lambda p: (p.borrow_apy - self.cfg.target_borrow_apy, p.debt_usd),
            reverse=True,
        )
        for p in ordered:
            single_cap = min(
                remaining,
                self.cfg.lendable_capacity_usd * self.cfg.max_single_borrower_fraction,
            )
            q = self.scorer.quote(p, single_cap)
            quotes.append(q)
            if q.eligible:
                remaining -= q.principal_usd
            if len(quotes) >= top_n:
                break
        return sorted(quotes, key=lambda q: (q.eligible, q.score), reverse=True)

    def hardnav_projection(self, quotes: list[RefinanceQuote], hard_yield_rate: float = 0.0) -> dict:
        accepted = [q for q in quotes if q.eligible]
        annual_credit_income = sum(q.annual_protocol_hard_income_usd for q in accepted)
        annual_yield_income = self.cfg.hardnav_usd * max(0.0, hard_yield_rate)
        start = self.cfg.hardnav_usd
        end = start + annual_credit_income + annual_yield_income
        return {
            "start_hardnav_units": self.cfg.hardnav_units,
            "hard_asset_price_usd": self.cfg.hard_asset_price_usd,
            "start_hardnav_usd": start,
            "lendable_capacity_units": self.cfg.lendable_capacity_units,
            "lendable_capacity_usd": self.cfg.lendable_capacity_usd,
            "accepted_quotes": len(accepted),
            "annual_credit_income_usd": annual_credit_income,
            "annual_credit_income_units": annual_credit_income / self.cfg.hard_asset_price_usd if self.cfg.hard_asset_price_usd > 0 else 0.0,
            "annual_yield_income_usd": annual_yield_income,
            "projected_hardnav_usd": end,
            "hardnav_multiplier": end / start if start else 0.0,
        }
