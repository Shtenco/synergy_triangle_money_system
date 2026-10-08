import math
from .models import BorrowPosition, RefinanceQuote
from .config import HunterConfig

class CandidateScorer:
    def __init__(self, cfg: HunterConfig):
        self.cfg = cfg

    def quote(self, p: BorrowPosition, remaining_capacity_usd: float | None = None) -> RefinanceQuote:
        cap = self.cfg.lendable_capacity_usd if remaining_capacity_usd is None else max(0.0, remaining_capacity_usd)
        principal = min(p.debt_usd, cap)
        offered = self.cfg.target_borrow_apy
        savings_apy = p.borrow_apy - offered
        annual_savings = principal * max(0.0, savings_apy) - self.cfg.expected_gas_usd
        annual_income = principal * offered
        annual_income_units = annual_income / self.cfg.hard_asset_price_usd if self.cfg.hard_asset_price_usd > 0 else 0.0
        required_collateral = principal * self.cfg.min_collateral_ratio

        reasons = []
        if not p.fresh:
            reasons.append("stale_state")
        if p.debt_usd < self.cfg.min_debt_usd:
            reasons.append("debt_too_small")
        if p.debt_usd > self.cfg.max_debt_usd:
            reasons.append("debt_too_large")
        if p.health_factor < self.cfg.min_health_factor:
            reasons.append("health_too_low")
        if p.collateral_usd / max(p.debt_usd, 1e-9) < self.cfg.min_collateral_ratio:
            reasons.append("insufficient_collateral_ratio")
        if savings_apy < self.cfg.min_savings_apy:
            reasons.append("insufficient_rate_edge")
        if annual_savings < self.cfg.min_net_annual_savings_usd:
            reasons.append("savings_do_not_cover_costs")
        if principal < self.cfg.min_debt_usd:
            reasons.append("capacity_too_small")

        size_score = min(1.0, math.log10(max(principal, 1.0)) / 5.0)
        edge_score = min(1.0, max(0.0, savings_apy) / 0.10)
        health_score = min(1.0, max(0.0, p.health_factor - 1.0))
        collateral_score = min(1.0, p.collateral_usd / max(required_collateral, 1e-9))
        score = 100.0 * (
            0.35 * edge_score
            + 0.25 * size_score
            + 0.20 * health_score
            + 0.20 * collateral_score
        )

        return RefinanceQuote(
            protocol=p.protocol,
            account=p.account,
            market_id=p.market_id,
            principal_usd=principal,
            current_borrow_apy=p.borrow_apy,
            offered_apy=offered,
            savings_apy=savings_apy,
            annual_borrower_savings_usd=annual_savings,
            annual_protocol_hard_income_usd=annual_income,
            annual_protocol_hard_income_units=annual_income_units,
            required_collateral_usd=required_collateral,
            expected_gas_usd=self.cfg.expected_gas_usd,
            score=score,
            eligible=not reasons,
            reason="eligible" if not reasons else ",".join(reasons),
        )
