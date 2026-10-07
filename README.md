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


## V5 — HardNAV multiplier engine

V5 adds a concrete mechanism that converts internal collateral capacity into real hard-asset income without requiring an external DEX.

The mechanism is:

1. Every 1 WPOL of protocol HardNAV creates a bounded soft-credit capacity.
2. With the aggressive stress-safe settings:
   - hard deployment = 80%
   - collateral factor = 80%
   - reuse = 65%
   - soft-credit capacity = 0.416 RUBX/RUBZ-equivalent per 1 WPOL HardNAV.
3. An external borrower must post 150% WPOL collateral.
4. The borrower receives RUBX or RUBZ principal.
5. On repayment, the soft principal is returned and burned.
6. Interest is paid in WPOL.
7. Borrower collateral is returned and is never counted as protocol Net HardNAV.
8. Only earned WPOL interest enters Treasury realised revenue and increases HardNAV.

### Per 1 WPOL HardNAV

Credit capacity:

0.416.

At 80% utilization:

0.3328 RUBX/RUBZ-equivalent is actually lent.

At 5% hard-denominated interest per credit cycle:

0.01664 WPOL real hard income.

Therefore the credit engine alone gives:

1.00000 -> 1.01664 HardNAV per completed credit cycle

provided that 80% utilization is actually achieved and borrowers really pay the 5% WPOL interest.

### Adding real yield-bearing collateral

If the entire 1 WPOL HardNAV is held in a wrapper or strategy that really earns 1% hard yield over the same economic cycle, then:

yield income = 0.01000 WPOL

credit income = 0.01664 WPOL

total hard income = 0.02664 WPOL

so:

1.00000 -> 1.02664 HardNAV.

If only the 80% deployed hard-capital earns the 1% yield while the 20% reserve earns zero, then:

yield income = 0.00800 WPOL

credit income = 0.01664 WPOL

total hard income = 0.02464 WPOL

so the stricter multiplier is:

1.00000 -> 1.02464 HardNAV.

### 50 + 50 WPOL case

Start:

50 WPOL HardNAV.

Retained new input:

+50 WPOL.

Immediate HardNAV:

100 WPOL.

At the aggressive stress-safe V5 credit settings:

credit capacity = 41.6 RUBX/RUBZ-equivalent.

At 80% utilization:

33.28 is lent.

At 5% hard-interest:

credit income = 1.664 WPOL.

If all 100 WPOL also earns 1% real hard yield during the same cycle:

yield income = 1.000 WPOL.

End-of-cycle HardNAV:

102.664 WPOL.

If only 80 WPOL of the 100 WPOL earns 1% real yield:

yield income = 0.800 WPOL.

End-of-cycle HardNAV:

102.464 WPOL.

These values are the current concrete V5 HardNAV multipliers.

They do not depend on an assumed 75x trading turnover.

They do depend on two real external economic events:

- an external borrower paying WPOL interest;
- a real hard-yield source if the yield component is enabled.

The external DEX is optional. The external payer of hard value is not.

### What V5 still needs before production use

The current V5 research branch must still add and test:

- borrower liquidation;
- collateral-price shocks;
- bad-debt accounting;
- partial repayment;
- interest accrual over time;
- maximum loan duration;
- oracle failure handling;
- reentrancy protection;
- emergency pause;
- borrower collateral segregation;
- stress testing of simultaneous RUBX/RUBZ depeg plus borrower default.

Until those tests are GREEN, V5 is a research prototype rather than a production lending protocol.
