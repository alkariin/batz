# The annual view

What each year costs: the « Année » screen of the app, its key figures on
the home screen, and the rules that compute them. The functional reference
is `docs/specification.md` (chapters 4.1, 4.2 and 4.6, in French); the
choices made for phase 4 are in `docs/plan/phase-4.md` (decisions H1 to H8)
and `docs/decisions.md` (4.0 to 4.7).

Code: `batz-ui/lib/domain/views/year_view.dart` (the calculation),
`share_operations.dart` (answering the shares to classify),
`batz-ui/lib/domain/ledger/redistribution.dart` and `refund.dart` (the rules
and their operations). Tests: `batz-ui/test/domain/views/`.

## Nothing is stored

Every amount of the screen is computed from what the user entered, each time
the data are loaded: totals, months, redistributed amounts, net costs,
period offsets, the questions waiting. The journal holds only three new
things: the redistribution rules, the link from a refund to its expense, and
the answers given for shares to classify. Two devices with the same journal
therefore show the same views, and a change on one (a category renamed, a
period corrected) changes every view at the next load, on every device.

## Two views, one calculation

A payment has a date and concerns a period (by default, its date). Each line
of a transaction gives amounts dated by month:

- the **cash-flow view** (« Trésorerie ») places the whole amount in the
  month of its payment;
- the **economic view** (« Économique ») places one share per month of its
  period: each month weighs its covered days over its days, shares are
  rounded to the cent, halves away from zero, and the last month takes what
  remains, so that the shares always add up to the amount.

Everything after that is the same for both views: the category chosen in the
tree of the month's year, the sums of the groups, the redistribution, the
totals. The two views can only differ by where amounts fall.

A line to validate counts as its rules propose it, category and period; a
line whose rules propose a transfer counts nowhere, like any transfer.

**Example** (the criterion of the specification). 2'100 paid on 1.9.2026 for
1.9.2026 – 31.8.2027, in « Loyer »:

| | 2026 | 2027 |
|---|---|---|
| Cash flow | 2'100 (September) | 0 |
| Economic | 700 (175 a month, September to December) | 1'400 (175 a month, January to August) |
| Paid this year for other years | 1'400 | 0 |
| Paid in other years for this year | 0 | 1'400 |

## Lines of the view

For one year and one view:

- each **category** of the tree shows twelve monthly amounts and their sum;
  a category without children shows what is classified in it; a **group**
  shows the sum of its children and of their redistribution lines;
- **income** is the sum of the income groups and « À classer » of income;
  **expenses** likewise; **savings** = income − expenses;
- **« Non classé »**: lines without a usable category (to validate without a
  proposal, a validated line without category, or whose category is no
  longer in the tree of its payment year). They count at their payment date
  in both views, outside income and expenses;
- **« À classer »**, one line per nature: amounts that fell in this year from
  a category of another year that has no counterpart here (see below). They
  count in the income or the expenses of their nature.

For every line, the total of the year is the sum of its twelve months.

On the screen, expenses show as costs, without a minus sign; a refund makes
them smaller, and shows with a minus sign when it is alone in a month.
Income shows as received.

## Period offsets

For a year Y, with amounts signed as a result (income positive, expenses
negative):

- *paid in Y for other years*: the economic shares outside Y of what was
  paid in Y;
- *paid in other years for Y*: the economic shares in Y of what was paid in
  another year.

Then, for every year:

```
cash-flow result = economic result + paid in Y for other years − paid in other years for Y
```

The tests check it to the cent on random data, redistribution and refunds
included; over all the years shown, both views add up to the same total.

## Years shown

The years go from the first year that has a tree to the latest of the
current year, the latest tree and the latest month an amount concerns.

- A **year to come without a tree** (2027 seen from 2026) is shown with the
  tree and the redistribution rules its copy will receive: the shares that
  fall in it go to the identifiers the copy will write.
- A **year before the first tree** (2025) is not shown. Its shares, for
  instance taxes of 2025 paid in 2026, leave the economic view of the year
  of payment and appear only in its offsets.

## Between years: the same name

A share that falls in another year than its payment goes:

1. to the category **of the same name** in the tree of that year (names
   compared without case, accents or surrounding spaces), if it can hold
   transactions (a category of the same name that became a group cannot);
2. otherwise to the category of the **answer** given for that line and that
   year, while the answer holds;
3. otherwise to **« À classer »** of its nature.

Nothing is fixed: renaming a category changes the correspondence at once.

**Example.** « Nourriture » of 2026 is renamed « Alimentation » in 2027. A
food expense of 1'200 for 1.7.2026 – 30.6.2027 shows 600 in « Nourriture »
of 2026 and 600 in « À classer » of the expenses of 2027, until the question
is answered; renamed back to « nourriture », the 2027 share is found again
by its name.

## Redistribution

A rule of a year moves, month by month, a percentage of what a source
category shows to a target category (specification, 4.1), in both views
(H1).

- Source and target are two categories without children of the same year
  and of the same nature; the percentage goes from 0.01 to 100 % with two
  decimals at most, stored in hundredths of a percent; the rules from one
  source add up to 100 % at most; a target cannot be a source (H2).
- Each month, the percentage of the source's amount *before any
  redistribution* (proposed lines, refunds and shares from other years
  included), rounded to the cent, halves away from zero, leaves the source
  and joins the target. It shows on a line of its own on each side; the
  categories keep showing their own amounts; the groups add the lines.
- The total of a group that holds both does not change, nor do income,
  expenses and savings. The amount of a redistribution line for the year is
  the sum of its twelve months.
- A rule that no longer applies is kept, left out and listed in the tasks:
  source or target missing, now a group, detached; natures that differ;
  after a merge of two devices, rules from one source above 100 % (all of
  them), or a target that is also a source (the rules in cause).
- The rules follow the copy of a tree, with computed identifiers.

**Example.** 10 % of « Nourriture » to « Entretien ménage »: in March,
« Nourriture » shows 345.67 and below it « Vers Entretien ménage · 10 % »
−34.57; « Entretien ménage » shows its own amount and below it « Depuis
Nourriture · 10 % » 34.57. The expenses of the year are unchanged. With
60.01 paid on 30 June for June and July, the cash-flow view moves 6.00 in
June, the economic view 3.00 in June and 3.00 in July (shares of 30.01 and
30.00, each rounded).

## Refunds attached to their expense

Money that came in (not a transfer), entered by hand or imported, can be
attached to a validated expense of any account and any year (H4). The
journal keeps only the link, on the line of the refund.

- While the link holds, the refund takes the category and the period of its
  expense, even if they change afterwards. In the cash-flow view it counts at
  its own payment date; in the economic view it is spread over the period of
  the expense, year by year with the expense's answers (H3).
- The expense shows its refunds and its **net cost**: its amount plus its
  refunds.
- The refund keeps a category of its own (the one of the same name as the
  expense's in the tree of its payment year, when there is one) and its date:
  detached, or when the link breaks (the expense or its statement deleted,
  the expense classified otherwise), it counts there again, and the tasks
  list it until it is detached or attached again.
- A link is followed one step only: a chain made by two devices leads to a
  refund, never an expense, and has no effect.

**Example** (the criterion of the plan). An expense of 300 for January to
March and a refund of 120 received in May, attached: the economic view shows
a net cost of 60 a month from January to March and nothing in May; the
cash-flow view shows 300 in January and −120 in May.

## Shares to classify

When a share falls in a year with no category of the same name, it counts in
« À classer » and a question waits; nothing is blocked (H5).

- The home screen shows the task « Parts à classer »; the « À classer » line
  of the year opens the same screen.
- Questions are grouped by category of origin and by year, with each line
  and its amounts. One answer serves the whole group; each line can be
  answered alone. The answer must be a category of the year, without
  children, of the same nature.
- The answer is kept per line and year (identifier computed from both), with
  the category of origin it was given for. It holds while the line keeps
  that category and the category chosen can still hold transactions; then
  the question comes back.
- Answering for a year whose tree is still the copy to come writes the tree
  in the same modification.
- A line to validate can be asked about too, under the identifier its line
  will have once validated; the shares of an attached refund follow the
  expense's answers.

## Key figures

The home screen shows the income, expenses and savings of the current year
in the economic view, and opens « Année » (H8). The screen opens on the
economic view the first time, then on the view chosen last on the device
(H7); that choice is kept on the device only.

## Performance

With 10 000 transactions over five years, 200 mapping rules, redistribution
rules, attached refunds and answers (`test/data/performance_test.dart`), the
reload after a write takes about 100 ms on the development machine (database
read, ledger, proposals, tasks, questions waiting and key figures), and both
views of a year about 10 ms once the data are loaded.
