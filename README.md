# batz

Personal accounting app for a single user: where the money goes, what each year
really costs, and how net worth evolves.

- `batz-ui/`: Flutter app for Android, Windows and Ubuntu, fully usable offline.
- `batz-web/`: Go server, self-hosted on a home network, that extracts bank
  statements and keeps the reference copy of the change journal.
- `docs/specification.md`: functional and technical specification (French).

Work in progress: see `docs/plan/` for the current phase.

## Personal data

Bank statements, personal mapping configurations and signing keys are never
committed. `scripts/check-personal-files.sh` fails if git tracks such a file;
CI runs it on every change.

## Licence

MIT, see `LICENSE`.
