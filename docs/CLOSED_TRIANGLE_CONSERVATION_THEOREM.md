# CLOSED TRIANGLE CONSERVATION RESULT

## Цель теста

Проверить строгий случай:

- structural edge внутреннего треугольника полностью контролируется системой;
- все три LP принадлежат owner/system;
- trading robot тоже принадлежит owner/system;
- internal tokens можно mint/burn;
- начальный canonical principal = 100 WPOL-equivalent;
- после цикла structural edge можно восстановить;
- owner хочет вывести canonical dividend.

## Результат

Если внешний canonical value не входит в систему, то внутренний controlled edge не создаёт aggregate canonical wealth.

Для system-owned triangle:

RobotProfitCanonical = - SystemOwnedLPChangeCanonical

Следовательно:

AggregateCanonicalDelta = 0

до внешних costs.

С учётом внешнего gas/MEV/bridge costs:

AggregateCanonicalDelta <= 0

## Explicit three-pool test

Был смоделирован треугольник из трёх CPMM pools.

При разных structural mispricing:

| Edge factor | Robot canonical profit | LP canonical change | Aggregate delta |
|---:|---:|---:|---:|
| 1.02 | +0.000981 | -0.000981 | 0 |
| 1.05 | +0.013531 | -0.013531 | ~0 |
| 1.10 | +0.065196 | -0.065196 | 0 |
| 1.30 | +0.611599 | -0.611599 | ~0 |
| 1.50 | +1.611823 | -1.611823 | 0 |
| 2.00 | +5.578242 | -5.578242 | ~0 |
| 3.00 | +17.590534 | -17.590534 | ~0 |

Больший controlled edge увеличивает локальный PnL робота, но ровно на ту же сумму уменьшает canonical reserves system-owned LP.

## Internal QE extraction

Для CPMM fee 0.3% и target internal price fork F:

(1+F) = (1+z)(1+0.997z)

где z = minted internal token / internal reserve.

Canonical extraction fraction:

e = 0.997 z / (1 + 0.997 z)

Примеры:

| Internal fork | Canonical extraction |
|---:|---:|
| 0.5% | 0.248693% |
| 1% | 0.495539% |
| 2% | 0.983780% |
| 3% | 1.464901% |
| 5% | 2.406459% |
| 10% | 4.647075% |
| 20% | 8.700958% |
| 30% | 12.277998% |
| 50% | 18.327831% |
| 100% | 29.258202% |
| 200% | 42.228304% |
| 500% | 59.138863% |

Это extraction из собственных LP в treasury, а не создание нового canonical.

## Replenishment invariant

Пусть до цикла canonical reserve = Y.

QE извлекает Q.

После QE:

LP = Y - Q
Treasury = Q

Чтобы полностью восстановить canonical LP:

RequiredReplenishment = Q

Тогда максимально доступный устойчивый owner dividend из internal-only cycle:

Dividend = Q - RequiredReplenishment = 0

То есть:

SustainableInternalOnlyDividendPerCycle = 0

для любого structural edge.

## Temporary cash-out

Если canonical LP разрешено истощать, owner может временно выводить extracted canonical.

При постоянной extraction fraction e:

Y_n = Y_0 (1-e)^n

CumulativeDividend_n = Y_0 - Y_n

Следовательно максимальная временная выплата при reserve floor H_floor:

MaxTemporaryDividend <= Y_0 - H_floor

Это не multiplier.

Например при:

InitialCanonical = 100 WPOL
ReserveFloor = 50 WPOL

абсолютный максимум временного cash-out:

50 WPOL

независимо от величины edge.

Edge определяет только скорость истощения.

При 30% internal fork extraction примерно 12.278% за full cycle:
- 5 полных циклов;
- временный payout около 48.055 WPOL;
- remaining reserve около 51.945 WPOL.

При 100% internal fork:
- 2 полных цикла;
- payout около 49.956 WPOL;
- remaining reserve около 50.044 WPOL.

Итого generated canonical value остаётся около исходных 100 WPOL.

## Главный theorem

ControlledInternalEdge != ExternalCanonicalAlpha

Internal edge может быть:
- постоянным;
- программно удерживаемым;
- восстанавливаемым mint/burn;
- большим.

Но если counterparty и LP принадлежат той же системе, его PnL является внутренним transfer.

Для устойчивого canonical dividend нужен внешний canonical source:

- external trader fees;
- independent external price spread;
- bridge fees paid externally;
- external order flow;
- external revenue;
- market beta, если её сознательно считать отдельным источником.

## Исправление V4

Любой ранее рассчитанный multiplier, где internal structural edge был интерпретирован как независимая external alpha, не является доказанным cashable multiplier.

Он должен быть повторно посчитан через полный system-owned balance sheet.

## Следующий правильный тест

Нужно сохранить controlled internal edge, но явно добавить только измеримый внешний canonical source.

Тогда:

ExternalCanonicalSurplus =
ExternalRevenue
- Gas
- MEV
- Slippage
- RequiredReplenishment

OwnerDividend <= ExternalCanonicalSurplus

Это единственный способ получить устойчивый cashable dividend без истощения собственных LP.
