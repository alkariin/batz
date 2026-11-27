# Features

How the app computes and shows what the user entered: the classification
rules, the annual view, the wealth, the modules and the export. How the data are stored and synchronised
is in [architecture](architecture.md).

Only what the user enters or imports is stored. Every figure below is
computed from it each time it is shown and written nowhere: two devices with
the same journal show the same figures, and a change on one (a category
renamed, a period corrected) changes every view on every device at the next
load. Amounts are kept in cents, never in floating point; a result
is rounded once, to the cent, halves away from zero.

## Classification rules

A mapping rule of a year classifies the lines to validate: in its category,
or as a transfer with an account. « Plus › Catégories et règles » shows the
tree of the year with, under each category, the rules that classify in it;
then the transfer rules under their account, and the rules whose target can
no longer be used. A tap on a category opens the same menu as its button:
add a rule, a sub-category, rename, move, up, down, delete. Deleting a
category deletes its rules with it. A button explains the rules.

- A rule has **lines**, one of which must be found in the raw text of the
  bank: lines are alternatives (OU). Within a line, terms joined by `ET`, in
  capitals between spaces, are each required, anywhere and in any order
  (« coop ET pronto »); without `ET`, the line is looked for as written,
  words side by side. « et » in lower case is a word of the text.
- Case, accents and repeated spaces do not count; a term written `re:…` is a
  regular expression.
- The **weight** of a rule for a text is the number of terms of its
  heaviest matching line. The heaviest rules win; a tie between different
  targets is a conflict and the line stays « à compléter ».
- A rule always proposes the **payment date** as the period; the period is
  changed on the line itself.
- Proposals are computed at each load, never stored: a rule created,
  modified or deleted changes only the lines still to validate.
- The list « Proposées » confirms the proposals all at once, or one line at
  a time with its own button; a line opened is corrected before it is
  validated.
- A rule written by version 0.8 or earlier had keywords, all required: it
  reads as the single line `a ET b`, and its period model is no longer read.
  Modified, it is written as lines.

**Example.** « Restaurant » has the lines `mcdonald` and `coop ET pronto`;
« Courses » has `coop`. « COOP PRONTO SHOP 123 » goes to « Restaurant »
(two terms against one); « Coop City » goes to « Courses ».

## Annual view

What each year costs: the « Année » screen and the key figures of the home
screen, which shows the income, expenses and savings of the current year in
the economic view. « Année » opens on the economic view the first time, then
on the view last chosen on the device. Code: `year_view.dart` and
`share_operations.dart` in `batz-ui/lib/domain/views/`, `redistribution.dart`
and `refund.dart` in `batz-ui/lib/domain/ledger/`.

### Two views, one calculation

A payment has a date and concerns a period (by default, its date). Each line
of a transaction gives amounts dated by month:

- the **cash-flow view** (« Trésorerie ») places the whole amount in the
  month of its payment;
- the **economic view** (« Économique ») places one share per month of its
  period: each month weighs its covered days over its days, shares are
  rounded to the cent and the last month takes what remains, so that the
  shares always add up to the amount.

The rest is the same for both views: the category chosen in the tree of the
month's year, the groups, the redistribution, the totals. A line to validate
counts as its rules propose it, category and period; a line whose rules
propose a transfer counts nowhere, like any transfer.

**Example.** 2'100 paid on 1.9.2026 for 1.9.2026 – 31.8.2027, in « Loyer »:

| | 2026 | 2027 |
|---|---|---|
| Cash flow | 2'100 (September) | 0 |
| Economic | 700 (175 a month, September to December) | 1'400 (175 a month, January to August) |
| Paid this year for other years | 1'400 | 0 |
| Paid in other years for this year | 0 | 1'400 |

### Split transactions

« Ventiler », on a manual expense or income and on an imported line being
validated, splits the transaction between categories. Each line has its
category, its amount and its period, and counts as a transaction of its own
in both views; the lines add up to the amount of the transaction. Rules
never split: a split is entered by hand.

- The **first line takes the rest**: the other lines are typed, the first
  gets what they leave of the amount, which must stay above zero. A new
  line starts over the period of the first one; lines over the payment date
  follow it when it changes.
- Lines take the sign of the transaction and may mix natures (a salary with
  a refund of expenses); the **main line**, the largest, gives the type
  shown. An imported line keeps its own line identifier for the first line,
  the one its answers to shares were given for.
- Each line keeps its identifier when the transaction is modified, so that
  refunds, kWh and answers stay attached; a line removed is deleted, and
  removing all but one brings the transaction back to one category.
- The list shows the categories joined by « + »; the category filter and
  the search find the transaction by any of them; the detail lists the
  lines and adds their shares month by month.
- A **refund** can be attached to each line of a split expense (the picker
  lists the lines apart), and the expense counts them all in its net cost.
  A refund attached to an expense is not split: attaching a split
  transaction brings it back to one line, and a split repayment of a debt
  stays as it is. A debt that came from a split expense is refunded to its
  largest expense line.

**Example.** 120 at the supermarket, split 100 in « Nourriture » and 20 in
« Entretien ménage » for May and June: May shows −100 and −10, June −10.

### Lines of the view

For one year and one view, every line shows twelve monthly amounts and
their sum:

- a **category** without children shows what is classified in it; a
  **group** shows the sum of its children and of their redistribution lines;
- **income** is the sum of the income groups and « À classer » of income;
  **expenses** likewise; **savings** = income − expenses;
- **« Non classé »**: lines without a usable category (to validate without a
  proposal, validated without category, or whose category is no longer in
  the tree of its payment year), and the difference between a transaction's
  amount and the sum of its lines, which only a merge can leave. They count
  at their payment date in both views, outside income and expenses, so that
  the cash-flow result plus « Non classé » is the sum of the payments of the
  year outside transfers;
- **« À classer »**, one line per nature: shares that fell in this year from
  a category of another year with no counterpart here
  ([below](#between-years-the-same-name)), counted in the income or the
  expenses of their nature.

Expenses show as costs, without a minus sign; a refund makes them smaller,
and shows with a minus sign when it is alone in a month.

### Period offsets and years shown

For a year Y, with amounts signed as a result (income positive, expenses
negative), *paid in Y for other years* is the economic shares outside Y of
what was paid in Y, and *paid in other years for Y* the economic shares in Y
of what was paid in another year. For every year, as tests check to the
cent on random data:

```
cash-flow result = economic result + paid in Y for other years − paid in other years for Y
```

The years shown go from the first year that has a tree to the latest of the
current year, the latest tree and the latest month an amount concerns; over
all of them, both views add up to the same total. A **year to come without a
tree** (2027 seen from 2026) is shown with the tree and the redistribution
rules its copy will receive, the shares that fall in it going to the
identifiers the copy will write. A **year before the first tree** is not
shown: its shares (taxes of 2025 paid in 2026) leave the economic view of
the year of payment and appear only in its offsets. Its tree, created by
hand or by its first transaction (a subscription paid in December 2025 for
2026), copies the first tree, so that its shares find the same names.

### Between years: the same name

A share that falls in another year than its payment goes:

1. to the category **of the same name** in the tree of that year (names
   compared without case, accents or surrounding spaces), if it can hold
   transactions (not one that became a group);
2. otherwise to the category of the **answer** given for that line and that
   year, while it holds (see [Shares to classify](#shares-to-classify));
3. otherwise to **« À classer »** of its nature.

Nothing is fixed: renaming a category changes the correspondence at once.
If « Nourriture » of 2026 is renamed « Alimentation » in 2027, a food
expense of 1'200 for 1.7.2026 – 30.6.2027 shows 600 in « Nourriture » of
2026 and 600 in « À classer » of 2027 until the question is answered;
renamed back to « nourriture », the 2027 share is found again by its name.

### Redistribution

A rule of a year moves, in both views, part of what a source category shows
to a target category: a percentage, month by month, or a fixed amount of
each payment.

- Source and target are categories without children of the same year and
  nature; a rule has either a percentage, from 0.01 to 100 % with two
  decimals at most (kept in hundredths of a percent), or a fixed amount in
  cents, more than zero; the percentages from one source add up to 100 % at
  most; a target cannot be a source.
- **Fixed amounts** come first, payment by payment: each payment classified
  in the source (an expense going out, an income coming in; refunds give
  nothing) gives the amount of each rule of the source in turn, until the
  payment is used up. The cash-flow view moves it at the payment date, the
  economic view spreads it over the period of the payment like the payment
  itself.
- **Percentages** then take, each month, their share of what the source
  shows once its fixed amounts are out (proposed lines, refunds and shares
  from other years included), rounded to the cent.
- What moves leaves the source and joins the target on a line of its own on
  each side. Categories keep showing their own amounts and groups add the
  lines, so a group holding both, the income, the expenses and the savings
  do not change.
- A rule that no longer applies is kept, left out and listed in the tasks:
  source or target missing, now a group or detached; natures that differ;
  after a merge of two devices, both or neither of a percentage and an
  amount, percentages from one source above 100 % (all of them) or a target
  that is also a source (the rules in cause).
- The rules follow the copy of a tree, with computed identifiers.

**Example.** 10 % of « Nourriture » to « Entretien ménage »: in March,
« Nourriture » shows 345.67 and below it « Vers Entretien ménage · 10 % »
−34.57; « Entretien ménage » shows its own amount and below it « Depuis
Nourriture · 10 % » 34.57. With 60.01 paid on 30 June for June and July,
the cash-flow view moves 6.00 in June, the economic view 3.00 in June and
3.00 in July (shares of 30.01 and 30.00, each rounded).

**Example of fixed amounts.** A rent of 2'000.00 includes 250.00 of charges
and 100.00 of parking space: two rules from « Loyer », 250.00 to « Charges »
and 100.00 to « Place de parc ». Each month « Loyer » shows 2'000.00 with
« Vers Charges · 250.00 par paiement » −250.00 and « Vers Place de parc ·
100.00 par paiement » −100.00 below it: 1'650.00 of rent. A payment of
300.00 gives 250.00 and 50.00; a refund of the rent gives nothing.

### Refunds attached to their expense

Money that came in (not a transfer), entered or imported, can be attached to
a validated expense of any account and any year; only the link is stored, on
the refund's line.

- While the link holds, the refund takes the category and the period of its
  expense, even if they change later: the cash-flow view counts it at its
  own payment date, the economic view spreads it over the period of the
  expense, year by year with the expense's answers. The expense shows its
  refunds and its **net cost**, its amount plus its refunds.
- The refund keeps a category of its own (the one named as the expense's in
  the tree of its payment year, when there is one) and its date: detached,
  or when the link breaks (the expense or its statement deleted, the expense
  classified otherwise), it counts there again, and the tasks list it until
  it is detached or attached again.
- A link is followed one step only: a chain made by two devices leads to a
  refund, never an expense, and has no effect.

**Example.** An expense of 300 for January to March and a refund of 120
received in May, attached: the economic view shows a net cost of 60 a month
from January to March and nothing in May; the cash-flow view 300 in January
and −120 in May.

### Shares to classify

A share counted in « À classer » raises a question; nothing is blocked. The
task « Parts à classer » of the home screen, also opened from the
« À classer » line of the year, groups the questions by category of origin
and year, with each line and its amounts; one answer serves the group, or
each line is answered alone. The answer is a category of the year, without
children, of the same nature.

The answer is kept per line and year (identifier computed from both) with
the category of origin it was given for, and holds while the line keeps that
category and the category chosen can still hold transactions; then the
question comes back. Answering for a year whose tree is still the copy to
come writes the tree in the same modification. A line to validate can be
asked about too, under the identifier its line will have once validated; the
shares of an attached refund follow the expense's answers.

## Wealth

How the net wealth evolves: the « Fortune » screen, the screen of an account
and the debts table. The user declares balances and enters debts; the rest
is computed. A declared balance creates no transaction and changes nothing
in the annual view: a value variation is never an income nor an expense.
Every date is the end of its day. Code: `batz-ui/lib/domain/ledger/`
(`balance.dart`, `debt.dart`) and `batz-ui/lib/domain/views/`
(`balances.dart`, `wealth.dart`).

### Balance of an account

The *points* of an account are the balances it is known to hold:

- each **declared balance**: a date, an amount, which may be negative (a
  loan), and a free note. One per account and per day: declaring twice the
  same day replaces it, on one device or two;
- for an account with statements, the **opening balance of its first
  statement, the day before it starts** (31.12.2025 for a statement starting
  on 1.1.2026). The detailed account enters the wealth that way; no balance
  is declared on it.

A debts account has no point (the debts table counts instead), nor has an
account that no longer exists. A balance is refused, with its reason, on an
unknown account, the detailed account or a debts account, and for a date
after today. An archived account accepts one: it stays in the wealth with
its last balance, and a balance of 0 takes it out. An account with declared
balances is archived rather than deleted.

The *movements* of an account are the amount of each transaction on it and
the opposite of each transfer of which it is the counterpart, validated or
proposed (a line to validate whose rules propose a transfer counts as that
transfer). Before the first point, the account is not in the wealth. After
it, the **balance at a date** is the last point at or before that date plus
the movements dated after that point, up to the date included: a movement
of the day of a point is part of that point. The wealth, the curve and the
table all use this one calculation.

### Value variation and old balances

For each point after the first, the **balance expected** that day is the
point before plus the movements since. The **value variation** is the point
minus the balance expected, dated the day of the point, in full, even if it
built up over several years. The screen of an account lists its balances,
each with the balance expected and the value variation. **Example.**
« Épargne » is declared at 10'000.00 on 31.12.2025 and enters the wealth
that day; 500.00 arrive on 15.3.2026, so its balance is 10'500.00 from 15.3
to 29.6; declared at 10'800.00 on 30.6.2026, it shows a value variation of
+300.00 that day.

An account not archived, neither detailed nor a debts account, whose last
declared balance is before the same day six months earlier is a task of the
home screen, marked « ancien » (the day is clamped to the month: on 31.8,
the limit is 28.2). An account without declared balance is no task:
« Fortune » shows it « sans solde, hors fortune ».

### Debts

A debt has a direction (« on me doit », « je dois »), a person, an amount, a
percentage (0.01 to 100, 100 by default, kept in hundredths of a percent),
the dates of the event, of the transaction of the invoice, of the request
and of the transaction of the repayment, a description and whether it is
repaid; the app also records the days it was entered and checked.

- **From a transaction**: « Créer une dette » on the screen of a
  transaction (not a transfer), or of a line being validated (not as a
  transfer), starts a debt from it: « on me doit » for money that left,
  « je dois » for money that came in, its amount, its description (for a
  line being validated, the one typed so far), its date as the date of the
  event. The debt keeps the link; its date of invoice is the date of the
  transaction. A line being validated stays to validate until it is.
- **Repaid by a transaction**: « Rembourse une dette » on the screen of a
  transaction, or of a line being validated, lists the open debts it can
  repay (owed to me for money that came in, owed by me for money that went
  out). The debt is checked, repaid on the date of the transaction, and
  keeps the link. When it is owed to me and comes from an expense, the
  transaction becomes the refund of that expense (and a line to validate is
  validated by it), unless it already refunds another one. Unchecking the
  debt drops the link to its repayment; the refund stays until detached.

- **Total**: amount × percentage, rounded to the cent (200.00 at 50 % is
  100.00).
- **When it counts**: from the day of the event (failing that, the day it was
  entered) to the day before its receipt (failing that, the day before it
  was checked as repaid); not repaid, from its start on. Checking proposes
  today as the date of the repayment; unchecking makes it count again.
- **Sign**: « on me doit » adds to the wealth, « je dois » takes from it.
  The wealth shows one line « Dettes », the signed sum of the debts that
  count that day, whether a debts account exists or not: such an account
  only serves as the counterpart of the transfers of a loan.
- **Split**: there is no partial repayment. « Scinder » asks for the first
  part, taken from the total; the debt becomes two with the same direction,
  person, dates, description and state, each with its part as amount, at
  100 %; their totals make the original total exactly.

Refused, with the reason: no person, an amount of zero or less, a percentage
out of bounds, a receipt before the event, a first part not strictly between
zero and the total. The same debt split on two devices offline keeps both
second parts, a known limit ([decisions](decisions.md)).

### Wealth at a date

The **wealth at a date** is the balance of every account that has one at
that date plus the debts that count that day. It starts on the first point
of an account or the first day a debt counts. « Fortune » shows the wealth
of the day and its change since 31 December, each account with its balance
and its date (the end of the last statement for the detailed account), the
accounts without balance, the line « Dettes », the **curve**, which gives
the wealth at the end of each month up to the current one, valued today,
and the table of each year from the first to the current one.

Accounts follow the order chosen in « Plus › Comptes », where each moves up
or down by its menu; until the first move they go by type, then name. In
« Fortune » they group by type, the groups in the order of their first
account. An account **declared in the tax return** (a switch of its form)
shows its name and balance in another colour, the text only, with a legend
below the accounts.

### Explanation table

For a year A, the table explains to the cent why the wealth changed between
the end of A − 1 and the end of A, or today for the current year, which
stops there: what is paid after today does not count yet, in the results
nor in the wealth.

| Line | Calculation |
|---|---|
| Résultat économique | Income minus expenses of the economic view of A |
| + Décalages de période | Paid in A for other years, minus paid in other years for A |
| = Résultat de trésorerie | Income minus expenses of the cash-flow view of A |
| + Variations de valeur | Per account, the value variations of its points dated in A |
| + Comptes ajoutés | Per account, its first point, when it is dated in A |
| + Variation des dettes ouvertes | Open debts at the end of A minus at the end of A − 1, minus the movements of A on the debts accounts |
| + Non classé | « Non classé » of the cash-flow view of A |
| + Hors fortune | The opposite of the movements of A on accounts that had no balance before their day, or that no longer exist; shown only when not zero |
| = Variation de la fortune | Wealth at the end of A minus wealth at the end of A − 1 |

No line is a remainder: each is computed for itself, the change of the
wealth too, and tests check on random ledgers that they add up every year.
They do because the movements of a year add up to the cash-flow result plus
« Non classé », and each falls on an account of the wealth, on a debts
account (taken out by the line of the debts, which counts the debt instead)
or outside the wealth (« Hors fortune »).

A year before the first category tree has no annual view: its three results
are zero, its « Non classé » holds every payment of the year outside
transfers (which only a merge can leave), and its table shows the balances
and debts that enter the wealth.

**Reference example.** End of 2025: the first statement of the private
account (detailed) starts on 1.1.2026 with 5'000.00; « Épargne » is
declared at 10'000.00 on 31.12.2025. Wealth: 15'000.00. In 2026, on the
private account: 60'000.00 of salary; 48'000.00 of expenses, among which
2'100.00 of rent paid on 1.9.2026 for 1.9.2026 – 31.8.2027, and 200.00 of
restaurant paid for two; 6'000.00 transferred to « Épargne »; 7'056.00
transferred on 15.1 to « 3e pilier », which has no balance yet; a line of
−35.00 left to complete. « Épargne » is declared at 16'250.00 on 31.12.2026.
« 3e pilier » gets its first balance, 7'100.00, on 30.6.2026. A debt « on me
doit 100.00 » (200.00 at 50 %) is open.

| Line | Amount |
|---|---|
| Résultat économique | 13'400.00 |
| + Décalages de période | −1'400.00 |
| = Résultat de trésorerie | 12'000.00 |
| + Variations de valeur (Épargne) | 250.00 |
| + Comptes ajoutés (3e pilier) | 7'100.00 |
| + Variation des dettes ouvertes | 100.00 |
| + Non classé | −35.00 |
| + Hors fortune (3e pilier) | −7'056.00 |
| = Variation de la fortune | 12'359.00 |

End of 2026: private account 3'909.00, « Épargne » 16'250.00, « 3e pilier »
7'100.00, debts 100.00. Wealth: 27'359.00, that is 15'000.00 + 12'359.00.
The table of 2025 shows 15'000.00 of accounts added (the private account and
« Épargne ») and nothing else. Two more cases:

- **A pure loan** of 500.00 is a transfer to « Dettes » and a debt « on me
  doit 500.00 », later a transfer back and the debt checked. The wealth never
  changes: the line of the debts is the change of the open debts (+500.00)
  minus the movement on « Dettes » (+500.00), zero.
- **An expense advanced for two**: 200.00 of restaurant and a debt « on me
  doit 100.00 », created from the expense, (200.00 at 50 %) give a cash-flow result of −200.00 and
  +100.00 on the line of the debts. Paid back later by a transfer that
  repays the debt: it becomes the refund of the restaurant, and the debt is
  checked that day: −100.00 and 0.

## Modules

The screens made to measure: salary sheet, flow diagram, taxes, vacations,
electricity and subscriptions. The debts, the seventh module, are under
[Debts](#debts). Code: `batz-ui/lib/domain/modules/` (one file per module),
screens in `batz-ui/lib/pages/modules/`.

### Principles

- **A module reads, it never classifies nor spreads again**: the category of
  a line (its own, its proposal, the expense's for an attached refund, the
  one of the same name in another year) and its monthly shares come from the
  [annual view](#annual-view) (`YearViews.linesIn`, `YearViews.linesNamed`).
- **Only what is entered is stored**; trips, totals, ratios, the control of
  the taxes and the diagram are computed when their screen opens. A salary
  sheet, a fiscal year, a setting or the kWh of a line has an identifier
  computed from its year, module or line: two devices entering the same one
  write one record.
- **No effect on the accounts**: no module writes a transaction or changes
  the annual view or the wealth; tests check it for each module.
- **Nothing blocks**: a category not found, a sheet whose line is gone, kWh
  on a line that left the category are shown as such.
- Base rates are kept in ten-thousandths of a percent, coefficients and the
  marginal rate in hundredths of a percent, energy in Wh.

### Linked category

Each module that reads a category (salary, taxes, vacations, electricity)
has a name, the same for every year: « Salaire », « Impôts », « Vacances »,
« Électricité » by default, changed on the screen of the module. The name is
looked up in each year's tree as names are compared between years (without
case, accents or surrounding spaces). The category found counts with
everything below it, so a group can be named. A year whose tree has no such
name is shown as such, without error.

The taxes and the electricity read, in one year, what the economic view
places in the category, before redistribution. The vacations read the lines
classified in the category of the tree of their year, every year together.

### Salary sheet

One sheet per year (two employers: add them up), with its gross, a free list
of deductions and its net. A new sheet proposes the labels of the closest
earlier sheet, otherwise AVS, AC and LPP. **Gap** = gross − deductions −
net, shown when not zero; it never prevents saving.

**Example.** Gross 96'000.00; AVS 5'088.00, AC 1'056.00, LPP 6'000.00, that
is 12'144.00 of deductions; net 83'856.00: gap 0.00. With a net of
83'800.00, a gap of 56.00.

### Flow diagram

For a year and the view shown on the « Année » screen (cash flow or
economic), with its amounts, redistribution included. Each node has a
positive amount; a node of zero is left out.

- **Left**: the salary; each top-level group of income; « À classer » of
  income; « Puisé dans la fortune » when the expenses exceed the income.
- **Right**: « Impôts »; each top-level group of expenses; « À classer » of
  expenses; « Épargne » when the income exceeds the expenses.
- A designated category (salary, taxes) weighs what it adds to its
  top-level group, its redistribution lines included; its group is shown
  for the rest, « Groupe hors Catégorie ».
- **From the gross**: when the salary sheet of the year exists and the
  salary category is found, « Salaire brut » is the net received in the
  category plus the deductions of the sheet, and it splits between each
  deduction, on the right, and the net. Otherwise the diagram starts from
  the net. **Gap signalled**: net received plus deductions, minus the gross
  entered.
- **Signs**: a group of expenses in gain goes to the left, a negative income
  to the right. « Non classé » is not in the diagram; the screen recalls it.
- « Épargne » and « Puisé dans la fortune » come from the view (income minus
  expenses), not from a remainder of the diagram. Both sides make the same
  total; tests check it on random data, the nodes giving back the income,
  the expenses and the savings of the view.

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

### Taxes

Five fixed lines per fiscal year: federal, cantonal and communal income;
cantonal and communal wealth. Each line of income has its base; both lines
of wealth use the taxable wealth of the year, entered once. Base rate in
percent with four decimals at most; coefficient in percent with two
decimals at most, 100 by default; marginal rate (« TMI ») entered.

- **Total rate** of a line = base rate × coefficient, shown with four
  decimals; **amount** = base × base rate × coefficient, rounded once, to the
  cent, 0 without base or rate; **total** = the sum of the five amounts.
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

Share of the gross: 15.66 %; of the net: 17.93 %. Control: ten instalments
of 1'200.00 paid in 2026 for 2026; 3'000.00 paid on 15.4.2027 with the
period 2026; 2'500.00 paid in 2026 with the period 2025. Paid for 2026:
15'000.00. Gap: 33.80, left to pay. The cash-flow view of 2026 shows
14'500.00: the control does not use it.

### Vacations

- **Gap between two lines**: the days from the end of the period of one to
  the start of the period of the other; 0 when they touch or overlap.
- **Trip**: lines joined one to the next by gaps of 15 days or less. Each
  line of the category is in one trip only (sorted by start, a line joins
  the trip while it starts at most 15 days after the latest end so far).
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

**Example.** A flight ticket of 640.00 paid on 12.3.2026 for 10.7 –
24.7.2026; a hotel of 1'200.00 paid on 11.7; a restaurant of 85.00 paid on
20.7; 100.00 refunded on 5.8 and attached to the hotel; 300.00 paid on 9.8.
Two trips: the first on 10.7.2026, 1'825.00, with 14 days entered, 130.36 a
day; the second on 9.8.2026, 300.00, 16 days after the first. Without its
period, the flight ticket would form a trip of its own on 12.3.2026.

### Electricity

kWh are entered line by line, on the screen of the module. For a year:

- **Price**: the total of the category in the economic view of the year.
- **kWh**: the kWh of each line are spread over its months like its amount
  (same rule, the last share takes the remainder); the year receives the
  months where its amount falls.
- **Days**: the days of the year covered by the period of at least one line
  (an instalment and a final invoice over the same days count them once).
- **Ratios**: CHF per day = price ÷ days; CHF per kWh = price ÷ kWh, four
  decimals; kWh per day = kWh ÷ days, two decimals; none when the divisor
  is zero. The screen counts the lines without kWh, which overestimate the
  price per kWh.

**Example.** Three invoices: 480.00 and 1'900 kWh for 1.1 – 30.4.2026;
540.00 and 2'000 kWh for 1.5 – 31.10.2026; 300.00 and 1'200 kWh for
1.11.2026 – 31.1.2027, paid on 20.1.2027.

| Year | Price | kWh | Days | CHF per day | CHF per kWh | kWh per day |
|---|---|---|---|---|---|---|
| 2026 | 1'220.00 | 4'700 | 365 | 3.34 | 0.2596 | 12.88 |
| 2027 | 100.00 | 400 | 31 | 3.23 | 0.2500 | 12.90 |

### Subscriptions

Informative, linked to nothing else: a name, a note and tranches (amount,
monthly or yearly, start, optional end). A change of price or a resumption
is a new tranche; adding one closes the previous tranche the day before, if
it had no end. The tranches of a subscription do not overlap.

- **Monthly cost** of a tranche: its amount if monthly, its amount ÷ 12 to
  the cent if yearly (95.00 a year: 7.92). **Yearly cost**: its amount × 12
  if monthly (14.90 a month: 178.80), its amount if yearly.
- A subscription is **current** when one of its tranches has started and is
  not over, and costs what that tranche costs. Then come those **to come**,
  then those **ended**. The **totals** add the costs of the current ones.

## Export

Everything entered or imported, as a ZIP of CSV files a spreadsheet opens:
« Plus › Réglages › Exporter les données ». Code: `batz-ui/lib/domain/export/`;
the expected files of an example ledger are in `batz-ui/test/fixtures/export/`.

### What it is

- Made on demand, on any device, offline: the export reads the local data
  and nothing else. It writes nothing to the journal and does not go
  through the server.
- One file, `batz-export-YYYY-MM-DD.zip`, saved through the dialog of the
  system. The app keeps no copy of it.
- **The file is not encrypted.** It holds everything the app holds, readable
  by anyone who opens it. The screen says so before exporting.
- There is no way back: the app does not import an export.
- Two synchronised devices export the same CSV files, byte for byte (the
  rows of each file are sorted by its own data; the ZIP itself carries the
  time it was made).

### What it holds

Everything entered or imported, in its state of the day: accounts, declared
balances, statements, the category tree of each year, mapping and
redistribution rules, transactions and their lines, the answers for carried
shares, debts, and what is entered in the modules.

Not exported:

- what the app computes: the annual view, the wealth, its curve, the flow
  diagram, the proposals of the rules for the lines to validate;
- the history of the modifications, and what was deleted;
- the original PDF statements (they stay on the server);
- the pairing with the server and the choices of the device.

A few computed values are written all the same, so that a row reads on its
own: the path of a category (« Logement > Loyer »), the type of a validated
transaction, the total of a debt, the amount of a tax line, and the trips
as the « Vacances » screen groups them.

`export_schema.dart` gives the file and column of every field of every
entity of the journal; a test compares it with the tables of the app, so an
entity or a field added later and not exported fails it.

### Format

- UTF-8 with a byte order mark; lines end with CR LF; the first line holds
  the headers. File names, headers and values are in French, as in the app.
- Fields are separated by semicolons. A value holding a semicolon, a quote
  or a line break is quoted, its quotes doubled.
- Amounts in francs, with a decimal point and no thousands separator:
  `1234.50`, `-85.00`. An amount is negative when money leaves the account.
- Percentages `50.00`; base rates of a tax `2.5000`; kWh `1900`, `1900.5`.
- Dates `2026-12-31`. Yes and no: `oui`, `non`. An absent value is empty.
- A text entered by the user or coming from the bank that starts with `=`,
  `+`, `-` or `@` is preceded by an apostrophe, so that a spreadsheet does
  not run it as a formula: `=A1+1` is written `'=A1+1`. A negative amount is
  not a text and stays `-85.00`.
- The identifiers are in columns named `id…`, at the end of each file. They
  link the files: `idCompte` of a transaction is the `id` of a row of
  `comptes.csv`. Beside them, the name is written in clear.

### Opening a file in Excel

Double-clicking works where Windows uses the semicolon as list separator
and the point as decimal symbol. Otherwise: Data › From Text/CSV, origin
« 65001: Unicode (UTF-8) », delimiter « Semicolon »; if the amounts stay
text, « Transform Data » and give their columns the type « Decimal Number »
with the locale « English (United States) ». `LISEZMOI.txt`, in the ZIP,
says the same in French.

### Files

Seventeen CSV files, always present (a file without data holds its headers),
and `LISEZMOI.txt`: the date of the export, the version of the app, the
number of transactions, each file with its number of rows, what is left out,
the format, how to open a file in Excel, and a pointer to this section.

| File | One row per | Columns |
|---|---|---|
| `comptes.csv` | account | Nom; Type; Format d'import; Archivé; Déclaré aux impôts; Position; id |
| `soldes.csv` | declared balance | Compte; Date; Montant; Note; id; idCompte |
| `releves.csv` | imported statement | Compte; Format; IBAN; Début de période; Fin de période; Solde initial; Solde final; Empreinte du fichier; id; idCompte |
| `categories.csv` | category of a year | Année; Chemin; Nom; Nature; Groupe parent; Position; id; idParent |
| `regles.csv` | mapping rule | Année; Lignes; Catégorie cible; Compte cible; id; idCatégorieCible; idCompteCible |
| `redistributions.csv` | redistribution rule | Année; Catégorie source; Catégorie cible; Pourcentage; Montant fixe; id; idCatégorieSource; idCatégorieCible |
| `transactions.csv` | line of a transaction | Date; Compte; Montant; Texte de la banque; Description; Note; Statut; Type; Catégorie; Début de période; Fin de période; Montant de la ligne; Compte de contrepartie; Relevé; Rang dans le relevé; Dépense remboursée; idTransaction; idLigne; idCompte; idCatégorie; idCompteContrepartie; idRelevé; idLigneRemboursée |
| `parts-reportees.csv` | answer for a carried share | Date de paiement; Description; Montant; Année; Catégorie choisie; Catégorie d'origine; id; idLigne; idTransaction; idCatégorieChoisie; idCatégorieOrigine |
| `dettes.csv` | debt | Sens; Personne; Montant; Pourcentage; Total; Date de l'événement; Date de la transaction de la facture; Date de la demande; Date de la transaction du remboursement; Description; Remboursée; Saisie le; Cochée le; id; idTransactionFacture; idTransactionRemboursement |
| `fiches-salaire.csv` | salary sheet | Année; Brut; Net; id |
| `deductions-salaire.csv` | deduction of a sheet | Année; Rang; Libellé; Montant; id; idFiche |
| `annees-fiscales.csv` | fiscal year | Année; Fortune imposable; TMI; id |
| `impots.csv` | tax line | Année; Impôt; Base; Taux de base; Coefficient; Montant; id |
| `voyages.csv` | trip | Année; Date; Lieu; Jours; Montant; Date automatique; Montant automatique; Date remplacée; Montant remplacé; Nombre de transactions; Ligne manuelle; Remarque; id; idLigne |
| `electricite.csv` | line that carries kWh | Date de paiement; Description; Début de période; Fin de période; Montant; kWh; id; idLigne; idTransaction |
| `abonnements.csv` | tranche of a subscription | Abonnement; Note; Montant; Fréquence; Début; Fin; id; idAbonnement |
| `reglages-modules.csv` | module | Module; Nom de la catégorie liée; Nom choisi; id |

Notes:

- **`transactions.csv`** has one row per line of a transaction, and one row
  for a transaction without line (a transfer, a line to validate): then the
  category and the period are empty. « Montant » is the amount of the
  transaction, « Montant de la ligne » the amount of the line. « Type »
  (dépense, remboursement, revenu, transfert) is empty for a line to
  validate. « Relevé » is the period of the statement the line came from;
  « Dépense remboursée » the date and description of the expense a refund
  is attached to.
- **`categories.csv`**: « Chemin » goes from the top-level group to the
  category; « Nature » (revenus, dépenses) is the one of its top-level
  group. Rows follow the order of the tree.
- **`regles.csv`**: the lines of a rule are written one per line in their
  cell, `ET` kept; a rule written as keywords shows its single line
  `a ET b`.
- **`redistributions.csv`**: « Pourcentage » or « Montant fixe », the other
  empty.
- **`comptes.csv`**: « Position » is empty until the accounts are first
  reordered.
- **`impots.csv`**: « Montant » is base × base rate × coefficient, as the
  screen shows it; empty while the base or the rate is missing. The lines
  of wealth have no base of their own: the taxable wealth is in
  `annees-fiscales.csv`.
- **`voyages.csv`**: one row per trip as the screen groups them, with what
  its sheet says; then one row per other sheet, with its « Remarque »:
  « fiche en trop » (a second sheet on a trip), « fiche sans transaction »
  (its line left the category or is gone), « ligne manuelle incomplète ».
- **`electricite.csv`**: kWh whose line is gone keep their row, without the
  columns of the transaction.
- **`abonnements.csv`**: one row per tranche, and one for a subscription
  without tranche.
- **`reglages-modules.csv`**: one row per module; « Nom choisi » is `non`
  while the default name is used.
