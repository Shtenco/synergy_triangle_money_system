<!-- SCIENTIFIC-V5-2026:START -->
<img src="assets/readme/scientific-architecture-v5.svg" width="100%" alt="Recursive Collateral Money System research architecture"/>

**[Научное досье V5](docs/SCIENTIFIC_DOSSIER_V5_2026.md)** — source inventory, acceptance gates, ограничения и проверки. **Статус:** SIMULATION / EVM LAB. Исторический текст README сохранён ниже.

<!-- SCIENTIFIC-V5-2026:END -->

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
