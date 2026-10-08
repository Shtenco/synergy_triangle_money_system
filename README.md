# SYNERGY V11 — Integrated Block Revenue & HardNAV Engine

Текущая архитектура репозитория — V11. Она объединяет V7 Block Revenue Engine, V6 Borrower Hunter, V9 Adaptive Market Maker и V10 Graph Arbitrage HardNAV Engine в одну систему выбора лучшего способа заработать реальный hard-asset income на каждом блоке.

## Что система делает на каждом блоке

Новый блок рассматривается как задача распределения капитала.

Движок собирает кандидатов из нескольких независимых источников дохода:

- graph external settlement: внутренний треугольник RUBX/RUBZ/hard asset создаёт переоценку, которая кристаллизуется во внешний USDC/WPOL через RFQ/aggregator/external venue;
- borrower refinance: Borrower Hunter ищет дорогой DeFi-долг и предлагает более выгодную ставку;
- own flash lending: свободный Treasury reserve выдаётся во flash loan и зарабатывает external fee;
- flash-funded arbitrage: Morpho/Aave flash liquidity используется только если после repayment, premium, gas и slippage остаётся положительный hard PnL;
- flash-funded liquidation: аналогично, в HardNAV засчитывается только чистый liquidation profit;
- real collateral yield: фактически полученный hard-yield.

Все возможности приводятся к единому объекту Opportunity и сравниваются по чистому ожидаемому HardNAV-profit.

## Главное правило V11

Один и тот же WPOL/USDC не может одновременно:

- быть выданным внешнему flash borrower;
- финансировать наш graph-settlement;
- финансировать liquidation;
- финансировать arbitrage;
- использоваться в другом несовместимом atomic route.

Unified Revenue Allocator резервирует hard-capital только за выбранным набором операций текущего блока.

Closed internal graph-arbitrage вида USDC -> Z -> X -> USDC не считается доходом, даже если отдельный arb wallet получил прибыль. Если все три ребра принадлежат протоколу, consolidated HardNAV остаётся тем же.

HardNAV-producing graph route обязан иметь внешний settlement-edge.

## Порядок обработки блока

1. Получить новые external swaps и состояние трёх/пяти пулов.
2. Сначала запустить Graph Arb Scanner.
3. Если есть executable external hard-settlement с положительным net PnL — сформировать graph opportunity.
4. Получить Borrower Hunter refinance candidates.
5. Получить external flash-loan demand.
6. Получить flash-funded arbitrage/liquidation candidates.
7. Учесть real collateral yield.
8. Unified Revenue Allocator сравнивает все opportunities.
9. Отклоняет stale, negative-PnL, low-confidence и превышающие capital limits.
10. Резервирует капитал лучшим операциям.
11. Исполняет только выбранные atomic routes.
12. Проверяет consolidated HardNAV before/after.
13. Только после этого V9 Adaptive MM стабилизирует оставшийся ценовой дисбаланс.
14. Остаточный hard-surplus может идти в ADDLP / reserve / BUY+BURN.

Именно такой порядок важен: если V9 сначала полностью погасит переоценку MINT/BURN, он уничтожит часть graph-arbitrage opportunity до того, как та будет превращена во внешний hard asset.

## Доходные каналы V11

### 1. Graph Arbitrage + External Settlement

Внутренние пулы создают amount-aware graph. Движок ищет маршрут, например:

USDC -> RUBZ -> RUBX -> external USDC

Внутренние ребра только перераспределяют активы протокола.

Последнее внешнее ребро приносит реальный hard asset.

На детерминированном V10-примере первичный внешний 0.10 USDC flow открыл дополнительный внешний settlement примерно 0.0252 USDC, то есть совокупный hard-flow multiplier около 1.25x для конкретного сценария.

Это не гарантированная доходность: сила эффекта определяется реальной внешней executable capacity, slippage, gas и MEV.

### 2. Borrower Refinance / Credit

Borrower Hunter сканирует Morpho и Euler discovery-источники, нормализует существующие borrow positions и ранжирует кандидатов по:

- текущему borrow APY;
- предлагаемой SYNERGY ставке;
- health factor;
- collateral coverage;
- размеру позиции;
- gas/cost edge;
- доступной protocol credit capacity.

HardNAV увеличивается только на реально оплаченный hard-interest.

### 3. Own Flash Lending

Свободный hard reserve может быть использован внутри одной транзакции через FlashLiquidityLender.

Principal обязан вернуться в той же транзакции.

В HardNAV записывается только external flash fee.

### 4. External Flash Funding

AtomicRevenueExecutor умеет работать с Morpho/Aave-style flash funding.

Маршрут исполняется только если:

final hard balance >= repayment + premium + minProfit.

Если условие не выполняется, транзакция должна revert.

### 5. Liquidation / Arbitrage

Любой liquidation или external arbitrage считается доходом только после:

- funding fee;
- gas;
- slippage;
- premium;
- safety buffer.

Internal circular fee между нашими же контрактами не считается доходом.

### 6. Real Collateral Yield

Только фактически начисленный hard-yield увеличивает HardNAV.

## Актуальные модули

Core collateral / accounting:
- src/Treasury.sol
- src/CollateralVault.sol
- src/RecursiveEngine.sol
- src/HardRevenueEngine.sol

V7 revenue:
- src/FlashLiquidityLender.sol
- src/AtomicRevenueExecutor.sol
- block_revenue/

Borrower acquisition:
- borrower_hunter/

V9 adaptive stabilization:
- v9/src/AdaptiveMM.sol
- v9/test/V9.t.sol

V10 graph HardNAV:
- v10/src/GraphArbHardNavEngine.sol
- v10/src/MockExternalSettlement.sol
- v10/test/V10GraphArb.t.sol

V11 unification:
- unified_revenue/allocator.py
- tests/test_unified_revenue.py
- docs/V11_INTEGRATED_REVENUE_ENGINE.md

## Главный экономический принцип

V11 больше не пытается заставить один механизм делать всё.

Каждый hard-dollar может выполнять разные функции во времени:

- collateral;
- LP capital;
- refinance capacity;
- flash inventory;
- graph-arb capital;
- liquidation capital;
- yield-bearing reserve.

Но один и тот же hard-dollar нельзя одновременно считать размещённым в несовместимых операциях.

На каждом блоке система выбирает лучший доступный положительный net-HardNAV канал.

---


## Историческая collateral-модель и расчёты

# SYNERGY Recursive Collateral Money System — current architecture

Этот репозиторий содержит только текущую версию системы. Главная задача системы — найти честный множитель на каждый входящий hard-доллар/WPOL без подмены внутреннего оборота внешним доходом.

## Главный результат

Каждый входящий 1 WPOL не может сам по себе превратиться во >1 WPOL чистого HardNAV только за счёт внутренних MINT, SELL, BUY, BURN, ADDLP, взаимного обеспечения пулов и внутренних арбитражей.

Но тот же 1 WPOL может создать больше 1 WPOL-эквивалента рабочей ликвидности и collateral capacity.

В текущей модели найдено два режима.

Базовый безопасный режим:

- hard reserve floor: 20%
- первичное размещение hard-capital: 80%
- LP collateral factor: 65%
- reuse: 50%
- haircut рекурсивного LP: 25%
- минимальный health factor: 1.25

Результат:

- 1 WPOL HardNAV
- 0.80 WPOL реально размещено в hard-side LP
- 0.2829931973 WPOL-эквивалента дополнительной внутренней collateral capacity
- productive liquidity multiplier = 2.1659863946x
- stress health factor при -30% = 1.6733200531
- HardNAV retention при -30% = 86.9328021227%

То есть каждый новый 1 WPOL поддерживает примерно 2.166 WPOL-эквивалента продуктивной ликвидности без внешних пулов.

Агрессивный, но ещё проходящий -30% stress режим:

- hard reserve floor: 20%
- первичное размещение hard-capital: 80%
- LP collateral factor: 80%
- reuse: 65%
- haircut рекурсивного LP: 25%
- минимальный health factor: 1.25

Результат:

- 1 WPOL HardNAV
- 0.80 WPOL реально размещено в hard-side LP
- 0.4781609195 WPOL-эквивалента дополнительной collateral capacity
- productive liquidity multiplier = 2.5563218391x
- stress health factor при -30% = 1.2871692716
- HardNAV retention при -30% = 86.9328021227%

Это текущий найденный максимальный рабочий множитель при заданном лимите reuse 65%, collateral factor 80% и требовании HF >= 1.25 при падении RUBX/RUBZ на 30%.

## Что именно умножается

HardNAV и productive liquidity — разные величины.

HardNAV — только реально принадлежащие системе hard assets: WPOL и другой внешний collateral.

Productive liquidity — ликвидность, которую один hard-доллар способен поддерживать через hard/soft LP и haircutted recursive collateral credit.

Внутренний MINT RUBX/RUBZ не увеличивает HardNAV.

Добавление RUBX/RUBZ к hard-side через ADDLP увеличивает глубину и TVL, но не создаёт новый WPOL.

LP-token одного пула может быть залогом для создания ограниченной внутренней collateral capacity другого пула. Эта capacity является кредитным/синтетическим слоем и не считается новым HardNAV.

## Пять пулов

Система использует пять protocol-owned CPMM pools:

1. RUBX/WPOL
2. RUBZ/WPOL
3. RUBX/RUBZ
4. RUBX/COLL
5. RUBZ/COLL

Внешние DEX-пулы для внутренней архитектуры не нужны.

RUBX/RUBZ используется как внутренний слой маршрутизации, переоценки и балансировки. Он не получает hard collateral weight.

RUBX/WPOL, RUBZ/WPOL, RUBX/COLL и RUBZ/COLL несут hard-side и могут участвовать в collateral valuation.

## Механизм множителя на каждый входящий WPOL

Каждый новый WPOL сначала становится частью HardNAV.

До 20% остаётся свободным hard-reserve.

До 80% может быть размещено как hard-side в protocol-owned LP.

К каждому hard-side система может MINT'ить RUBX или RUBZ как вторую сторону пары.

Поэтому 0.80 WPOL hard-side создаёт 1.60 WPOL-эквивалента первичной LP-ликвидности.

Protocol-owned LP затем закладывается в CollateralVault.

Vault считает только hard-side LP, а не полную mark-to-market стоимость RUBX/RUBZ.

Primary LP получает collateral factor.

Из eligible collateral разрешается только ограниченный reuse.

LP, созданный уже за счёт рекурсивного кредита, получает дополнительный haircut 75% и учитывается только на 25% от первичного LP.

Это создаёт затухающую геометрическую collateral-рекурсию.

В базовом режиме она добавляет 0.2829931973 collateral capacity на 1 WPOL.

В агрессивном режиме она добавляет 0.4781609195 collateral capacity на 1 WPOL.

Эта capacity может использоваться только как внутренний слой обеспечения и ликвидности. Она не должна отображаться как новый hard asset.

## Конкретный сценарий: старт 50 WPOL + вход ещё 50 WPOL

Изначально:

HardNAV = 50 WPOL.

В систему входит ещё 50 WPOL и остаётся в протоколе.

Немедленно:

HardNAV = 100 WPOL.

Никаких 118.88 WPOL из самого collateral-loop больше не заявляется. Это было следствием неверно подмешанного предположения о внешнем turnover и удалено из текущей модели.

### Базовый режим

Productive liquidity multiplier = 2.1659863946x.

Маржинальный эффект новых 50 WPOL:

50 × 2.1659863946 = 108.2993197279 WPOL-equivalent productive liquidity.

Для всей системы после 50+50:

100 × 2.1659863946 = 216.5986394558 WPOL-equivalent productive liquidity.

HardNAV при этом остаётся:

100 WPOL

до появления реального yield/fees/external PnL.

### Агрессивный stress-safe режим

Productive liquidity multiplier = 2.5563218391x.

Маржинальный эффект новых 50 WPOL:

50 × 2.5563218391 = 127.8160919540 WPOL-equivalent productive liquidity.

Для всей системы после 50+50:

100 × 2.5563218391 = 255.6321839080 WPOL-equivalent productive liquidity.

HardNAV:

100 WPOL

до фактического получения hard-income.

## Как HardNAV становится больше 100 WPOL

Чтобы получить настоящий HardNAV multiplier, нужен реальный hard-income.

Внешний пул для этого не обязателен.

Допустимые источники:

- yield-bearing hard collateral
- native staking yield
- реальные комиссии внешних пользователей в наших собственных пулах
- внешняя бизнес-выручка протокола
- внешний arbitrage PnL
- liquidation revenue
- другие реальные hard-asset inflows

Если весь hard-collateral обёрнут в yield-bearing asset с доходностью Y за расчётный период, HardNAV растёт на фактически начисленный yield.

Пример:

- 100 WPOL HardNAV
- 5% фактического yield за период
- итоговый HardNAV = 105 WPOL

При 10%:

- итоговый HardNAV = 110 WPOL

При 20%:

- итоговый HardNAV = 120 WPOL

Collateral multiplier не умножает yield сам по себе, если дополнительный hard-capital не был реально заимствован извне. Он умножает ликвидность, которую способен поддерживать исходный hard-capital.

## Почему внутренние круговые сделки не являются источником HardNAV

Если Treasury, Vault, Engine и все пять пулов принадлежат одному протоколу, то MINT+SELL может перевести WPOL из собственного пула в Treasury.

Treasury WPOL увеличится, но WPOL в protocol-owned pool уменьшится на ту же величину.

Consolidated HardNAV не изменится.

То же относится к внутренним комиссиям между собственными кошельками протокола.

Поэтому тесты отдельно проверяют no-free-HardNAV invariant.

## Stress -20% / -30%

Для hard/soft CPMM при реальном внешнем sell shock hard-side reserve уменьшается.

В текущей аналитической модели при 80% hard deployment:

- -20% RUBX/RUBZ shock: HardNAV retention ≈ 91.5541752799%
- -30% RUBX/RUBZ shock: HardNAV retention ≈ 86.9328021227%

Health factor определяется прежде всего reuse.

При reuse 50%:

- HF после -30% ≈ 1.6733

При reuse 65%:

- HF после -30% ≈ 1.2872

Поэтому 65% выбран как агрессивная верхняя рабочая точка при target HF >= 1.25.

## Контракты

src/SoftToken.sol — RUBX/RUBZ mint/burn token.

src/MockHardToken.sol — тестовый WPOL/COLL.

src/CPMMPool.sol — constant-product AMM и LP shares.

src/Treasury.sol — hard reserve и отдельный realized revenue bucket.

src/RiskOracle.sol — valuation hard collateral.

src/CollateralVault.sol — hard-only LP valuation, collateral factor, reuse, recursive haircut и health factor.

src/RecursiveEngine.sol — MINT/SELL, ADDLP, LP pledge, internal credit deployment и consolidated HardNAV invariants.

src/EconomicModel.sol — on-chain fixed-point расчёт текущего multiplier.

## Основные инварианты

1. 1 новый WPOL увеличивает HardNAV ровно на 1 WPOL до фактического дохода.
2. MINT RUBX/RUBZ не создаёт HardNAV.
3. SELL в собственный pool не создаёт consolidated HardNAV.
4. Internal ADDLP не создаёт HardNAV.
5. Internal credit не считается новым hard asset.
6. RUBX/RUBZ mark value не используется как hard collateral.
7. Recursive LP получает дополнительный haircut.
8. Reserve floor не может быть нарушен.
9. При -30% stress health factor должен оставаться >= 1.25.
10. Productive liquidity multiplier и HardNAV multiplier показываются отдельно.

## Текущий итог

Базовый безопасный multiplier:

1 WPOL → 2.1659863946 WPOL-equivalent productive liquidity.

Агрессивный stress-safe multiplier:

1 WPOL → 2.5563218391 WPOL-equivalent productive liquidity.

50 новых WPOL:

→ 108.2993197279 productive liquidity в базовом режиме

или

→ 127.8160919540 productive liquidity в агрессивном режиме.

Система 50 + 50:

HardNAV = 100 WPOL.

Productive liquidity capacity:

216.5986394558 WPOL-equivalent в базовом режиме

или

255.6321839080 WPOL-equivalent в агрессивном режиме.

HardNAV выше 100 появляется только из фактически реализованного hard-income.
