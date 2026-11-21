# The modules

The screens made to measure of the specification (chapter 4.7): the salary
sheet, the flow diagram, the taxes, the vacations, the electricity and the
subscriptions. The debts, the seventh module, are described in
`docs/wealth.md`. The functional reference is `docs/specification.md` (in
French); the choices made for phase 6 are in `docs/plan/phase-6.md`
(decisions H1 to H8, rules of calculation) and `docs/decisions.md` (6.0 to
6.7).

Code: `batz-ui/lib/domain/modules/` (one file per module, plus `settings.dart`
for the linked categories and `module_records.dart` for what is entered);
screens in `batz-ui/lib/pages/modules/`. Tests: `batz-ui/test/domain/modules/`
and `batz-ui/test/pages/modules/`.

## Principles

- **A module reads, it never classifies nor spreads again.** The category of
  a line (its own, its proposal for a line to validate, the expense's for an
  attached refund, the category of the same name in another year) and its
  shares by month come from the annual view (`YearViews.linesIn`,
  `YearViews.linesNamed`, `docs/year-view.md`).
- **Only what is entered is stored**: the salary sheets and their
  deductions, the fiscal years and their lines, the sheets of the trips and
  the manual lines, the kWh, the subscriptions and their tranches, the names
  of the linked categories. Trips, totals, ratios, the control of the taxes
  and the diagram are computed when their screen opens, never at the reload.
- **No effect on the accounts**: no module writes a transaction or changes an
  amount of the annual view or of the wealth; the tests check it for each
  module.
- **Nothing blocks**: a category not found, a sheet whose line is gone, kWh
  left on a line that left the category are shown as such.
- **No floating point**: amounts in cents, base rates in ten-thousandths of a
  percent, coefficients and the marginal rate in hundredths of a percent,
  energy in Wh. One rounding per result, halves away from zero.

## Linked category

Each module that reads a category (salary, taxes, vacations, electricity)
has a name, the same for every year: « Salaire », « Impôts », « Vacances »,
« Électricité » by default, changed on the screen of the module. The name is
looked up in the tree of each year as names are compared between years
(without case, accents or surrounding spaces). The category found counts
with everything below it, so a group can be named. When a year's tree has
no such name, the module says so for that year, without error.

The taxes and the electricity read, in one year, what the economic view
places in the category, before redistribution. The vacations read the lines
classified in the category of the tree of their year, every year together.

## Salary sheet

One sheet per year (two employers: add them up), with its gross, a free list
of deductions and its net. A new sheet proposes the labels of the closest
earlier sheet, otherwise AVS, AC and LPP.

**Gap** = gross − deductions − net, shown when it is not zero; it never
prevents saving.

**Example.** Gross 96'000.00; AVS 5'088.00, AC 1'056.00, LPP 6'000.00, that is
12'144.00 of deductions; net 83'856.00: gap 0.00. With a net of 83'800.00, a
gap of 56.00.

## Flow diagram

For a year and the view shown on the « Année » screen (cash flow or
economic), with its amounts, redistribution included. Each node has a
positive amount; a node of zero is left out.

- **Left**: the salary; each top-level group of income; « À classer » of
  income; « Puisé dans la fortune » when the expenses exceed the income.
- **Right**: « Impôts »; each top-level group of expenses; « À classer » of
  expenses; « Épargne » when the income exceeds the expenses.
- A designated category (salary, taxes) weighs what it adds to its
  top-level group, its redistribution lines included; its group is shown for
  the rest, « Groupe hors Catégorie ».
- **From the gross**: when the salary sheet of the year exists and the
  salary category is found, « Salaire brut » is the net received in the
  category plus the deductions of the sheet, and it splits between each
  deduction, on the right, and the net. Otherwise the diagram starts from
  the net. **Gap signalled**: net received plus deductions, minus the gross
  entered.
- **Signs**: a group of expenses in gain goes to the left, a negative income
  to the right.
- « Épargne » and « Puisé dans la fortune » come from the view (income minus
  expenses), not from a remainder of the diagram. Both sides make the same
  total; the tests check it on random data, with the nodes giving back the
  income, the expenses and the savings of the view.
- « Non classé » is not in the diagram; the screen recalls it.

The bands match both columns stacked in their order: each part of the left
stack flows to the part of the right stack at the same height, so the gross
flows first into the deductions.

**Example**, 2026: « Revenus » holds « Salaire » (83'856.00 received) and
« Intérêts » (144.00). Expenses: « Logement » 24'000.00, « Quotidien »
18'000.00, « Obligations » 21'000.00 of which « Impôts » 15'000.00. Income
84'000.00, expenses 63'000.00, savings 21'000.00.

| Side | With the sheet of the example | Without sheet |
|---|---|---|
| Left | Salaire brut 96'000.00; Revenus hors Salaire 144.00 | Salaire 83'856.00; Revenus hors Salaire 144.00 |
| Right | AVS 5'088.00; AC 1'056.00; LPP 6'000.00; Impôts 15'000.00; Logement 24'000.00; Quotidien 18'000.00; Obligations hors Impôts 6'000.00; Épargne 21'000.00 | Impôts 15'000.00; Logement 24'000.00; Quotidien 18'000.00; Obligations hors Impôts 6'000.00; Épargne 21'000.00 |
| Total of each side | 96'144.00 | 84'000.00 |

With only 83'000.00 received in « Salaire », the gross of the diagram is
95'144.00 and the gap with the gross entered, −856.00, is signalled.

## Taxes

Five fixed lines per fiscal year: federal, cantonal and communal income;
cantonal and communal wealth. Each line of income has its base; both lines
of wealth use the taxable wealth of the year, entered once. Base rate in
percent with four decimals at most; coefficient in percent with two
decimals at most, 100 by default; marginal rate (« TMI ») entered.

- **Total rate** of a line = base rate × coefficient, shown with four
  decimals.
- **Amount** of a line = base × base rate × coefficient, rounded once, to
  the cent. A line without base or rate counts 0.
- **Total** = the sum of the five amounts.
- **Shares** of the gross and of the net of the salary sheet of the same
  year, in percent with two decimals; none without sheet.
- **Paid for the year** = what the economic view of the year counts in the
  taxes category: instalments, a balance paid the next year with the period
  of the year, refunds deducted. **Gap** = total − paid: left to pay, or
  paid too much. A year before the first category tree can be entered,
  without control.

**Example**, fiscal year 2026, with the salary sheet of the example:

| Line | Base | Base rate | Coefficient | Total rate | Amount |
|---|---|---|---|---|---|
| Federal income | 80'000.00 | 2.5000 % | 100.00 % | 2.5000 % | 2'000.00 |
| Cantonal income | 78'000.00 | 6.5000 % | 155.00 % | 10.0750 % | 7'858.50 |
| Communal income | 78'000.00 | 6.5000 % | 79.00 % | 5.1350 % | 4'005.30 |
| Cantonal wealth | 200'000.00 | 0.2500 % | 155.00 % | 0.3875 % | 775.00 |
| Communal wealth | 200'000.00 | 0.2500 % | 79.00 % | 0.1975 % | 395.00 |
| **Total** | | | | | **15'033.80** |

Share of the gross: 15.66 %. Share of the net: 17.93 %.

Control: ten instalments of 1'200.00 paid in 2026 for 2026; 3'000.00 paid on
15.4.2027 with the period 2026; 2'500.00 paid in 2026 with the period 2025.
Paid for 2026: 15'000.00. Gap: 33.80, left to pay. The cash-flow view of 2026
shows 14'500.00: the control does not use it.

## Vacations

- **Gap between two lines**: the days from the end of the period of one to
  the start of the period of the other; 0 when they touch or overlap.
- **Trip**: lines joined one to the next by gaps of 15 days or less. Each
  line of the category is in one trip and one only (sorted by start, a line
  joins the trip while it starts at most 15 days after the latest end so
  far).
- **Automatic date**: the first day of the oldest period. **Automatic
  amount**: the opposite of the sum of the whole lines, refunds deducted. A
  trip over two years stays one trip, in the year of its date.
- **Sheet of a trip**: place, days, and the date and amount that replace the
  automatic ones, kept on a sheet attached to the first line of the trip. A
  replaced amount stays fixed when other transactions join; the automatic
  value is shown beside it, and « Rétablir » returns to it. When two sheets
  meet on one trip, the one of the oldest line applies, the other is
  signalled; a sheet whose line left the category is listed apart.
- **Manual line**: a trip by itself, its date and its amount required.
- **Price per day** = amount ÷ days, to the cent; none without days.

**Example.** A flight ticket of 640.00 paid on 12.3.2026 for 10.7 – 24.7.2026;
a hotel of 1'200.00 paid on 11.7; a restaurant of 85.00 paid on 20.7; 100.00
refunded on 5.8 and attached to the hotel; 300.00 paid on 9.8. Two trips:
the first on 10.7.2026, 1'825.00, with 14 days entered, 130.36 a day; the
second on 9.8.2026, 300.00, 16 days after the first. Without its period, the
flight ticket would form a trip of its own on 12.3.2026.

## Electricity

kWh are entered line by line, on the screen of the module. For a year:

- **Price**: the total of the category in the economic view of the year.
- **kWh**: the kWh of each line are spread over its months like its amount
  (same rule, the last share takes the remainder); the year receives the
  months where its amount falls.
- **Days**: the days of the year covered by the period of at least one line
  (an instalment and a final invoice over the same days count them once).
- **Ratios**: CHF per day = price ÷ days; CHF per kWh = price ÷ kWh, four
  decimals; kWh per day = kWh ÷ days, two decimals. None when the divisor is
  zero. The screen counts the lines without kWh, which overestimate the price
  per kWh.

**Example.**

| Invoice | Paid on | Period | Amount | kWh |
|---|---|---|---|---|
| 1 | 15.5.2026 | 1.1 – 30.4.2026 | 480.00 | 1'900 |
| 2 | 15.11.2026 | 1.5 – 31.10.2026 | 540.00 | 2'000 |
| 3 | 20.1.2027 | 1.11.2026 – 31.1.2027 | 300.00 | 1'200 |

| Year | Price | kWh | Days | CHF per day | CHF per kWh | kWh per day |
|---|---|---|---|---|---|---|
| 2026 | 1'220.00 | 4'700 | 365 | 3.34 | 0.2596 | 12.88 |
| 2027 | 100.00 | 400 | 31 | 3.23 | 0.2500 | 12.90 |

The cash-flow view of 2026 shows 1'020.00: the module does not use it.

## Subscriptions

Informative, linked to nothing else: a name, a note and tranches (amount,
monthly or yearly, start, optional end). A change of price or a resumption
is a new tranche; adding one closes the previous tranche the day before, if
it had no end. The tranches of a subscription do not overlap.

- **Monthly cost** of a tranche: its amount if monthly, its amount ÷ 12 to
  the cent if yearly. **Yearly cost**: its amount × 12 if monthly, its amount
  if yearly.
- A subscription is **current** when one of its tranches has started and is
  not over; its cost is that tranche's. Then come those **to come**, then
  those **ended**.
- **Totals**: the sums of the monthly and of the yearly costs shown, current
  subscriptions only.

**Example**, seen on 21.11.2026: « Streaming », 12.90 a month from 1.3.2025
to 31.12.2025, then 14.90 a month from 1.1.2026; « Assurance vélo », 95.00 a
year from 1.6.2024; « Salle de sport », ended on 30.9.2025.

| Subscription | A month | A year |
|---|---|---|
| Streaming | 14.90 | 178.80 |
| Assurance vélo | 7.92 | 95.00 |
| **Total** | **22.82** | **273.80** |

## What the journal holds

| Entity | Table | Identifier |
|---|---|---|
| `moduleSetting` | `module_settings` | computed from the module |
| `salarySheet` | `salary_sheets` | computed from the year |
| `salaryDeduction` | `salary_deductions` | random |
| `taxYear` | `tax_years` | computed from the year |
| `taxLine` | `tax_lines` | computed from the year and the tax |
| `tripSheet` | `trip_sheets` | computed from its line; random for a manual line |
| `electricityReading` | `electricity_readings` | computed from its line |
| `subscription` | `subscriptions` | random |
| `subscriptionTranche` | `subscription_tranches` | random |

Two devices entering the same salary sheet, fiscal year, setting or kWh of a
line write one record; known limits are in `docs/decisions.md` (6.1).

## Performance

With 10 000 transactions over five years and the data of step 6.7 (300
vacation lines, 60 electricity invoices with kWh, 5 salary sheets, 5 fiscal
years, 40 subscriptions of 3 tranches; `test/data/performance_test.dart`),
the reload after a write takes about 100 ms on the development machine, and
each screen of a module and the diagram take 0 to about 40 ms once the data
are loaded.
