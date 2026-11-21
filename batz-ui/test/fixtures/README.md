# Test fixtures

- `v0.1.0/batz.db`: a desktop (unencrypted) database created by version 0.1.0
  of the app (commit `5a10d1a`), through `openLocalDatabase` and
  `Journal.open`. Device identifier `a0000000-0000-4000-8000-000000000001`.
  Its journal holds three entries of an `account` entity unknown to 0.1.0,
  merged as if they came from another device
  (`b0000000-0000-4000-8000-000000000002`): name `Espèces`, type `cash`,
  archived `false`. Used by `test/data/upgrade_test.dart`. Never regenerate
  it with a later version.
- `v0.2.0/batz.db`: a desktop (unencrypted) database created by version 0.2.0
  of the app (commit `ce7076b`) through `openLocalDatabase`, `Journal.open` and
  the operations of `Ledger`, with a fixed clock. Device identifier
  `a0000000-0000-4000-8000-000000000002`. Its 140 journal entries hold two
  accounts (a third one deleted), the trees 2026 and 2027 (the 2027 one copied
  by the first transaction of 2027), an expense corrected once, a payment
  spread over two years, a transfer and a deleted expense. Used by
  `test/data/upgrade_test.dart`. Never regenerate it with a later version.
- `v0.3.0/batz.db`: a desktop (unencrypted) database created by version 0.3.0
  of the app (commit `806a457`) through `openLocalDatabase`, `Journal.open`
  and the operations of `Ledger`, with a fixed clock. Device identifier
  `a0000000-0000-4000-8000-000000000003`. Its 76 journal entries hold three
  accounts (one detailed), the 2026 tree, an expense, a transfer, a deleted
  expense, and a category rename integrated as an exchange page from device
  `b0000000-0000-4000-8000-000000000004`; `local_state` remembers the server
  of pairing `c0000000-0000-4000-8000-000000000005` after an exchange. Used
  by `test/data/upgrade_test.dart`. Never regenerate it with a later version.
- `v0.4.1/batz.db`: a desktop (unencrypted) database created by version 0.4.1
  of the app (commit `f906f86`, whose app is that of `81d0921`) through
  `openLocalDatabase`, `Journal.open` and the operations of `Ledger`, with a
  fixed clock. Device identifier `a0000000-0000-4000-8000-000000000041`. Its
  419 journal entries hold three accounts (`acc-bank` detailed), the 2026
  tree and its copy for 2027, three mapping rules of 2026 (a category, a
  category with the next month as period, a transfer) and their copies, the
  fictitious statement `2026-01` of the server's test set imported (27
  lines: the 7 proposals confirmed, the insurance classified by hand over
  2026 with a description and a note, 19 lines to validate), a manual expense
  over 1.9.2026 – 31.8.2027 and one paid in 2027. Used by
  `test/data/upgrade_test.dart`. Never regenerate it with a later version.
- `v0.5.0/batz.db`: a desktop (unencrypted) database created by version 0.5.0
  of the app (commit `ce5e4b2`) through `openLocalDatabase`, `Journal.open`
  and the operations of `Ledger`, with a fixed clock. Device identifier
  `a0000000-0000-4000-8000-000000000050`. Its 139 journal entries hold three
  accounts (`acc-bank` detailed), the 2026 tree and its copy for 2027 (where
  « Nourriture » is renamed « Alimentation »), a redistribution rule of 10 %
  from « Nourriture » to « Entretien ménage » and its copy, an expense over
  January to March 2026 with a refund attached to it, a payment over 2026
  and 2027 whose share of 2027 is answered, and a transfer from cash to
  savings. Used by `test/data/upgrade_test.dart`. Never regenerate it with a
  later version.
