# SYNERGY TRIANGLE MONEY SYSTEM

## 100 WPOL → максимальный реализуемый canonical multiplier

Это отдельный исследовательский репозиторий для системы владельца (owner) и 2–3 его ML-роботов, работающих с одного контролируемого капитала.

Главная цель:

\[
100\ WPOL \rightarrow \max(
ResidualWPOL +
CanonicalDividendsWPOL
)
\]

при этом:

- внутренний mint SYNA/SYNR/SUSD **не считается прибылью**;
- HardNAV считается только в canonical assets;
- каждый дивиденд считается только после фактического вывода canonical;
- роботы не имеют права вывода;
- owner имеет мгновенный emergency withdrawal из каждого системного контракта;
- отрицательные сделки блокируются NO_TRADE governor;
- self-induced price impact не считается alpha.

---

# 1. Архитектура

## Internal money

- SYNA
- SYNR
- SUSD

## Polygon canonical assets

- WETH
- WPOL
- USDC

## Internal 9-pool graph

\`\`\`text
SYNA/WETH   SYNA/WPOL   SYNA/USDC
SYNR/WETH   SYNR/WPOL   SYNR/USDC
SUSD/WETH   SUSD/WPOL   SUSD/USDC
\`\`\`

## External alpha engines

1. CrossDEX / triangular arbitrage
2. Bridge inventory spread
3. External AMM / order-flow fee capture

## Agents

\`\`\`text
OWNER WALLET
   |
   +---- ML ROBOT #1: ARBITRAGE
   +---- ML ROBOT #2: BRIDGE
   +---- ML ROBOT #3: FEE / LIQUIDITY
\`\`\`

Роботы имеют только EXECUTOR-права.

**Только owner** может:

- добавить/удалить робота;
- mint internal money;
- менять risk parameters;
- pause/unpause;
- делать мгновенный вывод;
- менять owner;
- разрешать canonical tokens/system targets.

---

# 2. HardNAV

\[
HardNAV =
CanonicalTreasuryNAV +
SystemOwnedCanonicalLPNAV
\]

SYNA/SYNR/SUSD не входят в HardNAV.

\[
Mint \neq Profit
\]

\[
InternalFork \neq ExternalEdge
\]

---

# 3. Dividend multiplier

\[
M_D=
\frac{CumulativeCanonicalDividends}{InitialCanonicalPrincipal}
\]

Для данного репозитория:

\[
InitialCanonicalPrincipal=100\ WPOL
\]

Canonical dividend засчитывается только после физического уменьшения system balance и увеличения owner payout ledger.

---

# 4. V4 Dynamic Marginal Allocator

Вместо фиксированных процентов капитала V4 распределяет каждый marginal WPOL туда, где максимальна **предельная net alpha** после:

- fees;
- gas;
- MEV;
- slippage;
- capacity saturation.

Для engine \(i\):

\[
\Pi_i(q)
=
a_iq-k\frac{q^3}{C_i^2}
\]

где:

- \(a_i\) — gross edge минус постоянные costs;
- \(q\) — routed capital;
- \(C_i\) — capacity;
- \(k\) — nonlinear slippage coefficient.

Marginal alpha:

\[
\frac{d\Pi_i}{dq}
=
a_i-3k\frac{q^2}{C_i^2}
\]

Allocator распределяет капитал так, чтобы положительные marginal returns между активными engines были максимально выровнены.

---

# 5. Исследовательский baseline на 100 WPOL

Controlled-model assumptions:

### Arbitrage robot
- gross edge: 3.0%
- fee: 0.30%
- gas proxy: 0.015%
- MEV proxy: 0.025%
- profitable capacity: 500 WPOL/cycle

### Bridge robot
- gross spread: 0.80%
- fee: 0.10%
- gas: 0.015%
- MEV: 0.010%
- capacity: 300 WPOL/cycle

### Fee-flow robot
- gross fee capture: 0.30%
- gas: 0.005%
- capacity: 700 WPOL/cycle

### QE router
- base utilization: 90%
- QE gain: 35%
- effective utilization: 93.5%

Это **simulated research configuration**, не обещание реальной доходности.

---

# 6. Результаты V4

## 100 cycles

Оптимальный modeled working target:

\[
325\ WPOL
\]

Результат:

\[
Residual=325\ WPOL
\]

\[
CanonicalDividends=381.648458\ WPOL
\]

\[
M_D=3.816485x
\]

Total generated canonical value:

\[
706.648458\ WPOL
\]

\[
M_{total}=7.066485x
\]

## 1000 cycles

Dynamic allocator нашёл рабочую точку около:

\[
975\ WPOL
\]

Результат:

\[
Residual=975\ WPOL
\]

\[
CanonicalDividends=10\,901.517042\ WPOL
\]

\[
M_D=109.015170x
\]

Total modeled canonical value:

\[
11\,876.517042\ WPOL
\]

\[
M_{total}=118.765170x
\]

Финальное marginal allocation около saturation:

- Arbitrage: 500 WPOL
- Bridge: 180.57 WPOL
- Fee-flow: 231.05 WPOL

---

# 7. Почему V4 лучше статической модели

Предыдущая статическая V3 на 1000 циклах:

\[
M_D\approx104.68x
\]

V4:

\[
M_D\approx109.02x
\]

Улучшение получено **не увеличением фиктивного mint**, а более эффективным распределением реального canonical capital.

---

# 8. Security model

Все системные contracts наследуют общий OwnerRobotControl.

Обязательные механизмы:

- two-step ownership transfer;
- robot allowlist;
- pause;
- nonReentrant;
- safe ERC-20 transfers;
- canonical allowlist;
- system-target allowlist;
- per-transaction limits;
- NO_TRADE edge floor;
- max-slippage limit;
- owner-only parameter changes;
- owner-only instant withdrawal;
- owner-only instant withdraw-all;
- native-token rescue;
- event logging;
- robots cannot withdraw;
- robots cannot mint canonical;
- robots cannot change owner;
- robots cannot change limits.

## Важное следствие

Instant owner withdrawal означает **централизованную owner-custody модель**. Это сознательный дизайн данного проекта.

---

# 9. Instant owner withdrawal

Каждый системный contract получает:

\`\`\`text
ownerWithdrawToken(...)
ownerWithdrawAllToken(...)
ownerWithdrawNative(...)
\`\`\`

Пул дополнительно корректирует reserve accounting после owner withdrawal.

ML executor не может вызвать withdrawal.

---

# 10. Структура

\`\`\`text
README.md
docs/
  ARCHITECTURE.md
  MATHEMATICS.md
  SECURITY.md
  OWNER_AND_ROBOTS.md
  MODEL_100_WPOL.md
  POLYGON_FORK_TEST.md
contracts/
  security/OwnerRobotControl.sol
  tokens/InternalMoney.sol
  core/InternalCPMMPool.sol
  core/TriangleTreasury.sol
  core/TriangleGovernor.sol
sim/
  optimize_100_wpol.py
config/
  model_100_wpol.json
test/
  TriangleSecurity.t.sol
foundry.toml
\`\`\`

---

# 11. Что является реальным PASS

До Polygon Mainnet Fork multipliers считаются **simulated**.

Сильный PASS требует:

\[
OwnerCanonicalAfter
+
ResidualSystemCanonical
>
100\ WPOL
\]

после:

- реального pool state;
- Quoter;
- fees;
- gas;
- slippage;
- MEV reserve;
- failed fills;
- full settlement.

---

# 12. Следующая цель

1. Polygon Mainnet Fork.
2. 100 WPOL exact starting capital.
3. Реальные WETH/WPOL/USDC routes.
4. 2–3 robot strategies.
5. Dynamic allocator.
6. Cash-out every profitable epoch.
7. Owner instant withdrawal test.
8. Fuzz/invariant/security tests.
9. Найти максимальный **реально executable** \(M_D\), а не теоретический.
