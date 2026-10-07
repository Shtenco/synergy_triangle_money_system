# CONTROLLED STRUCTURAL EDGE MODEL

## 1. Главное исправление

Внутренний edge треугольника — это не внешняя рыночная возможность.

Он является **контролируемой геометрией системы**.

Определим:

\[
\epsilon_t =
p_{SYNA/WPOL}
\cdot
p_{SYNR/SYNA}
\cdot
p_{WPOL/SYNR}
-1
\]

или эквивалентный замкнутый треугольник через SYNA/SYNR/SUSD и canonical legs.

Governor задаёт:

\[
\epsilon_t \rightarrow \epsilon_{target}
\]

через:

- mint;
- burn;
- weighted rebalance;
- depth management;
- LP replenishment.

Поэтому baseline может держать:

\[
\epsilon_{target}=const
\]

до тех пор, пока система способна поддерживать требуемые резервы.

---

# 2. Что действительно ограничивает цикл

Постоянный internal edge сам по себе не означает бесконечную canonical прибыль.

Для каждого цикла нужно вести canonical accounting.

Пусть:

- \(Q_t\) — canonical, извлечённая из внутренних LP;
- \(R_t\) — canonical, возвращённая в LP после settlement/replenishment;
- \(D_t\) — canonical dividend owner;
- \(C_t\) — все внешние costs;
- \(A_t\) — реально полученная canonical alpha вне внутренних mark-prices.

Тогда:

\[
Y_{t+1}=Y_t-Q_t+R_t
\]

и допустимый owner dividend:

\[
D_t \le A_t - C_t - RequiredReplenishment_t
\]

если требуется сохранять canonical depth.

---

# 3. Ключевой invariant

Внутренний edge можно удерживать сколько угодно долго только при сохранении solvency:

\[
CanonicalReserves_t \ge ReserveFloor
\]

и:

\[
HardNAV_t + CumulativeDividends_t
\]

не должен расти только из-за mark-price внутренних токенов.

Следовательно:

\[
InternalEdge = controllable
\]

но:

\[
CashableCanonicalMultiplier
\]

ограничивается тем, сколько canonical реально остаётся после полного цикла и replenishment.

---

# 4. Правильный V5

Новый V5 называется:

**Controlled Edge / Canonical Settlement Governor**

Не stochastic-edge model.

Внутренние controlled variables:

- \(\epsilon_{target}\);
- mint rate;
- burn rate;
- cycle size;
- D_high / D_low;
- safe_cycle_pct;
- LP target depths;
- reinvestment ratio;
- dividend ratio.

Внешние uncertain variables:

- gas;
- MEV;
- external execution slippage;
- latency;
- bridge delay;
- canonical spot prices;
- fill quality.

---

# 5. Оптимизация

Для каждого \(\epsilon_{target}\) ищем:

\[
\max
\left(
M_D,\ DividendRate,\ ResidualHardNAV
\right)
\]

при:

\[
CanonicalReserve_t \ge ReserveFloor
\]

\[
HardNAV_t \ge HardNAVFloor
\]

\[
\epsilon_t \approx \epsilon_{target}
\]

\[
OwnerDividend_t \le RealizedCanonicalSurplus_t
\]

---

# 6. Что нужно sweep'ить

Structural edge:

\[
0.5\%,1\%,2\%,3\%,5\%,10\%,20\%,30\%,50\%,100\%+
\]

Cycle size:

\[
0.5\%-30\%
\]

от доступной canonical depth.

Replenishment ratio:

\[
0\%-100\%
\]

Dividend take:

\[
0\%-100\%
\]

Начальный капитал:

\[
100\ WPOL
\]

Горизонты:

\[
10,\ 100,\ 1000,\ 10000
\]

циклов.

---

# 7. Главный тест

Нужно найти максимальный такой \(\epsilon_{target}\), при котором одновременно:

1. internal triangle edge восстанавливается после каждого цикла;
2. canonical LP не истощается;
3. owner получает положительные canonical dividends;
4. residual HardNAV не падает ниже floor;
5. полный цикл остаётся solvent после costs.

Это и есть реальный максимум устойчивого controlled-edge multiplier.
