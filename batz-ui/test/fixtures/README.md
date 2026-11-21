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
