# Test fixtures

- `v0.1.0/batz.db`: a desktop (unencrypted) database created by version 0.1.0
  of the app (commit `5a10d1a`), through `openLocalDatabase` and
  `Journal.open`. Device identifier `a0000000-0000-4000-8000-000000000001`.
  Its journal holds three entries of an `account` entity unknown to 0.1.0,
  merged as if they came from another device
  (`b0000000-0000-4000-8000-000000000002`): name `Espèces`, type `cash`,
  archived `false`. Used by `test/data/upgrade_test.dart`. Never regenerate
  it with a later version.
