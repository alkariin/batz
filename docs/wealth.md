# The wealth

How the net wealth evolves: the « Fortune » screen of the app, the screen of
an account, the debts table, and the rules that compute them. The
functional reference is `docs/specification.md` (chapters 4.3, 4.6 and 4.7,
in French); the choices made for phase 5 are in `docs/plan/phase-5.md`
(decisions H1 to H8, rules of calculation) and `docs/decisions.md` (5.0 to
5.6).

Code: `batz-ui/lib/domain/ledger/balance.dart` and `debt.dart` (the records
and their operations), `batz-ui/lib/domain/views/balances.dart` (the
balance of an account at any date) and `wealth.dart` (the wealth, its
curve and the table that explains it). Tests: `batz-ui/test/domain/views/`
(`balances_test.dart`, `wealth_test.dart`) and
`batz-ui/test/domain/ledger/debts_test.dart`.

## Nothing is stored but balances and debts

The journal holds two new kinds of records: the balances the user declares
and the debts. Everything else is computed at each load: the balance of an
account at a date, the value variations, the wealth, its curve and every
line of the table. Two devices with the same journal show the same wealth.

Declaring a balance creates no transaction and changes no amount of the
annual view: a value variation is never an income nor an expense.

Every date is the end of its day.

## Balances

### Points

The *points* of an account are the balances it is known to hold:

- each **declared balance**: an account, a date and an amount, which may be
  negative (a loan). One per account and per day: declaring twice the same
  day replaces the balance, on one device or two (its identifier is computed
  from the account and the date);
- for an account that has statements, the **opening balance of its first
  statement, the day before it starts**: 31.12.2025 for a statement that
  starts on 1.1.2026. The detailed account enters the wealth that way, and
  its statements give its balance: no balance is declared on it.

A debts account has no point: the debts table gives the wealth instead. An
account that no longer exists has none either.

A balance is refused, with its reason, on an unknown account, on the
detailed account, on a debts account, and for a date after today. An
archived account accepts one: it stays in the wealth with its last balance
(H4), and a balance of 0 takes it out. An account that has declared
balances is archived rather than deleted.

### Movements

The *movements* of an account are the amount of each transaction on it and
the opposite of each transfer of which it is the counterpart, validated or
proposed: a line to validate whose rules propose a transfer already counts
as that transfer. A transaction outside transfers counts for exactly its
amount.

### Balance at a date

There is no balance before the first point: the account is not in the
wealth yet. After it, the balance at a date is **the last point at or before
that date, plus the movements dated after that point, up to the date
included**. One function computes it; the wealth, the curve and the table
all go through it.

A movement of the day of a point is part of that point: a declared balance
is the balance at the end of its day.

### Value variation

For each point after the first, the **balance expected** that day is the
point before plus the movements since, up to that day included — the same
calculation. The **value variation** is the point minus the balance
expected. It is dated the day of the point, in full, even if it built up
over several years.

**Example** (the criterion of the plan). « Épargne » is declared at
10'000.00 on 31.12.2025; 500.00 arrive on 15.3.2026; it is declared at
10'800.00 on 30.6.2026.

| Date | Balance | |
|---|---|---|
| 31.12.2025 | 10'000.00 | first point: the account enters the wealth |
| 15.3 to 29.6.2026 | 10'500.00 | the point plus the 500.00 |
| 30.6.2026 | 10'800.00 | expected 10'500.00, value variation +300.00 |

### Old balances

An account not archived, neither detailed nor a debts account, whose last
declared balance is before the same day six months earlier is a task of the
home screen and is marked « ancien » (the day is clamped to the month: on
31.8, the limit is 28.2). An account without any declared balance is not a
task: « Fortune » shows it « sans solde, hors fortune ».

## Debts

A line of the debts table has a direction (« on me doit », « je dois »), a
person, an amount, a percentage (from 0.01 to 100, 100 by default, kept in
hundredths of a percent), the dates of the event, of the invoice, of the
request and of receipt, a description, and whether it is repaid; the app
also records the day it was entered and the day it was checked.

- **Total**: amount × percentage, rounded to the cent, halves away from
  zero. 200.00 at 50 % is 100.00.
- **When it counts**: from the day of the event (failing that, the day it
  was entered) to the day before its receipt (failing that, the day before
  it was checked as repaid). Not repaid, it counts from its start on.
  Checking proposes today as the date of receipt; unchecking makes it count
  again.
- **Sign**: « on me doit » adds to the wealth, « je dois » takes from it.
  The wealth shows one line « Dettes », the signed sum of the debts that
  count that day, whether a debts account exists or not: such an account
  only serves as the counterpart of the transfers of a loan.
- **Split**: there is no partial repayment. « Scinder » asks for the first
  part, taken from the total; the line becomes two lines with the same
  direction, person, dates, description and state, each carrying its part
  as amount, at 100 %. Their totals make the original total exactly.

Refused, with the reason: no person, an amount of zero or less, a percentage
out of bounds, a receipt before the event, a first part of a split that is
not strictly between zero and the total. The same debt split on two devices
offline keeps both second parts (a known limit, `docs/decisions.md` 5.2).

## The wealth

The **wealth at a date** is the balance of every account that has one at
that date, plus the debts that count that day.

It starts on its first day: the first point of an account or the first day a
debt counts. The **curve** gives the wealth at the end of each month, from
that month to the current one, whose value is today's. The tables go from
that year to the current one.

## The explanation table

For a year A, the table explains, to the cent, why the wealth changed
between the end of A − 1 and the end of A — or today, for the current year,
which stops there (H8): what is paid after today does not count yet, in the
results nor in the wealth.

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
wealth too. That they add up is checked by the tests, on the examples below
and on random ledgers, for every year.

Why they do: over a year, the movements of all the accounts, both sides of
every transfer included, add up to the payments outside transfers, which
are the cash-flow result plus « Non classé ». Each movement falls on an
account of the wealth (its balance follows it), on a debts account (the line
of the debts takes it out, since the debt it pays for is counted there), or
on an account without balance yet or that no longer exists (« Hors
fortune »). An account's balance changes over the year by its movements in
the wealth, its value variations, and its first point if it enters then.

A year before the first category tree has no annual view: its three results
are zero, and its « Non classé » holds every payment of the year outside
transfers, which only a merge can leave. Its table shows the balances and
debts that enter the wealth.

### Example of reference

End of 2025: the first statement of the private account (detailed) starts on
1.1.2026 with 5'000.00; « Épargne » is declared at 10'000.00 on 31.12.2025.
Wealth: 15'000.00.

In 2026, on the private account: 60'000.00 of salary; 48'000.00 of
expenses, among which 2'100.00 of rent paid on 1.9.2026 for 1.9.2026 –
31.8.2027, and 200.00 of restaurant paid for two; 6'000.00 transferred to
« Épargne »; 7'056.00 transferred on 15.1 to « 3e pilier », which has no
balance yet; a line of −35.00 left to complete. « Épargne » is declared at
16'250.00 on 31.12.2026. « 3e pilier » gets its first balance, 7'100.00, on
30.6.2026. A debt « on me doit 100.00 » (200.00 at 50 %) is open.

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

The table of 2025 shows 15'000.00 of accounts added (the private account
and « Épargne ») and nothing else.

### A pure loan, an advanced expense

- **A pure loan** of 500.00 is a transfer to « Dettes », with a debt
  « on me doit 500.00 » opened the same day, then a transfer back from
  « Dettes » and the debt checked. At each step the wealth does not change:
  the private account loses 500.00 while the debt counts 500.00; the line of
  the debts is the change of the open debts (+500.00) minus the movement on
  « Dettes » (+500.00): zero.
- **An expense advanced for two**: 200.00 of restaurant, then a debt « on
  me doit 100.00 » (200.00 at 50 %). The year shows a cash-flow result of
  −200.00 and +100.00 on the line of the debts: the wealth falls by 100.00.
  The 100.00 paid back later is a refund in « Restaurant » and the debt is
  checked: the result becomes −100.00 and the line of the debts 0.

## Screens

- **Fortune**: the net wealth of the day and its change since 31 December;
  the accounts by type with their balance and its date (the end of the last
  statement for the detailed account), « ancien » when old, the accounts
  without balance, the line « Dettes »; the curve, where touching a point
  shows its month and amount; the table of a year, whose lines by account
  unfold, « Non classé » leading to the validation and the results to the
  « Année » screen.
- **An account**: its balance, its movements since the last balance, the
  history of its balances with the balance expected and the value variation
  of each and the movements between them; « Déclarer un solde » (amount,
  date today by default), and each declared balance modified or deleted.
  After a declaration, its value variation is shown.
- **Debts**: the debts not repaid first, the totals « on me doit », « je
  dois » and net; the form with every field and the total computed on
  screen; check, uncheck, split, delete.
- **Home**: a task per old balance; the net wealth among the key figures.

## Performance

With 10 000 transactions over five years, 12 accounts, 100 declared
balances and 200 debts (`test/data/performance_test.dart`), the reload after
a write, with the net wealth and the old balances of the home screen, takes
about 100 ms on the development machine, and the « Fortune » screen (the
accounts, 61 months of curve, the table of a year) 11 to 36 ms once the data
are loaded.
