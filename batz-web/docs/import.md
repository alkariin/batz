# Import of bank statements

Each month the user sends the PDF statement of the bank to the server, which
reads and checks it; the app checks that it follows the previous one and
writes the statement and its lines into the journal, where they wait to be
validated. The functional reference is `docs/specification.md` (chapters 4.4
and 4.5) and `docs/plan/phase-3.md` (decisions H1 to H8); the technical
decisions and their evidence are in `docs/decisions.md`.

## Who does what

| Part | Does | Does not |
|---|---|---|
| Server | Reads the PDF with `pdftotext`, checks its internal consistency, keeps the file under its fingerprint after a dated copy of its database, answers with the lines. | Write anything to the journal; know which statements were imported. |
| App | Checks the continuity with the account's previous statement, writes the statement and all its lines in **one** modification, proposes a classification from the rules, validates. | Read PDF files. |

The rules of the domain stay in the app, in one implementation. Writing the
statement in one modification makes the import all or nothing, on this
device and on every device that receives it.

## The flow

1. Transactions › « Importer un relevé » first runs a synchronisation. If no
   server is paired, or it cannot be reached, or the exchange does not go to
   its end (revoked device, other server, incompatible versions, a question
   pending), the import does not start and the screen says why.
2. The user picks the detailed account and the PDF file.
3. The app computes the fingerprint of the file (SHA-256). If its journal
   already holds the statement of that file on that account, it refuses it
   without sending it (decision H1: the journal knows, even after the server
   was rebuilt).
4. The app checks that the server announces the account's format in
   `/healthz` (`importFormats`), then sends the file:
   `POST /api/v1/imports` ([API](api.md)).
5. The server extracts and checks the statement (below). Accepted, it keeps
   the file and answers with the statement and its fingerprint; refused, it
   answers `422` with the code and the check in cause.
6. The app checks the statement against its ledger (below). The first
   statement of an account asks for a confirmation: it sets the starting
   balance, and no earlier statement can be imported afterwards (H7).
7. The app writes the statement, its lines (status « à valider ») and the copy
   of the category tree of each year a line opens, in one modification. The
   result shows the period, the number of lines, how many the rules propose
   and how many are to complete. The modification is sent to the server at
   the next exchange, like any other.

The validation can then happen anywhere, offline: it only writes to the
local journal.

## What the server checks

The statement is read in full, then checked in this order; the first failure
refuses it as a whole.

| Check | Refused when |
|---|---|
| `layout` | It cannot be read entirely: a movement without a date or a label, the opening or closing balance or the totals missing, two IBANs. |
| `currency` | The account is not in Swiss francs (the currency is printed after the IBAN on the first page). |
| `period` | A movement is dated outside the period of the statement, or before the movement above it. |
| `runningBalance` | A balance printed in the course of the statement (after the last movement of a day) differs from the opening balance plus the movements up to it. |
| `totals` | The printed total of credits or of debits differs from the movements. |
| `closingBalance` | The opening balance plus all the movements differs from the closing balance. |

Amounts are integer cents throughout; no floating point is involved.

## What the app checks

| Reason | Refused when |
|---|---|
| Account not detailed | Import is not enabled on the account (or for another format). |
| Already imported | The account already holds the statement of this file (its identifier is computed from the account and the fingerprint). |
| Other account | The IBAN differs from the account's latest statement; both IBANs are shown. |
| Not contiguous | The statement does not start the day after the latest one, or its opening balance is not that one's closing balance; what was expected and what was found are shown. |
| Sum | Its lines do not add up to the difference between its balances. |
| Too large | It would not fit in one modification (about 1 200 lines). |

A refused statement writes nothing: the journal does not change.

## Refusals, as the user reads them

| Code (server) or reason (app) | Message |
|---|---|
| `IMPORT_UNREADABLE` | Ce fichier n'est pas un PDF lisible. |
| `IMPORT_UNKNOWN_FORMAT` | Ce PDF n'est pas un relevé PostFinance. |
| `IMPORT_INCONSISTENT` | Relevé incohérent, rien n'est importé : *the check in cause*. |
| `IMPORT_TOO_LARGE` | Ce fichier dépasse 10 Mo. |
| Server without `importFormats` | Le serveur (version …) est trop ancien pour importer des relevés. |
| Server unreachable while sending | Le serveur ne répond plus : le relevé n'a pas été envoyé. |
| Already imported | Ce relevé est déjà importé. |
| Other account | Ce relevé est celui d'un autre compte : IBAN …, alors que les relevés précédents portent l'IBAN …. |
| Not contiguous | Ce relevé ne suit pas le précédent : il commence le … avec un solde de …, alors que le suivant doit commencer le … avec un solde de …. |

## The PostFinance format

The only format is PostFinance, PDF, in French (specification, 4.4). Each
format is a module of the server: `internal/infrastructure/extraction/postfinance`.

The text comes from `pdftotext -layout -enc UTF-8 - -`: the PDF on standard
input, the text on standard output, without a shell, within 30 seconds and
8 MiB of text. The same text comes out of `pdftotext` 24.02 (Ubuntu 24.04)
and 25.12 (the image), byte for byte.

What is read, line by line:

- the period, from « Extrait de compte dd.mm.yyyy - dd.mm.yyyy »;
- the IBAN, and the currency printed after it on the first page; the IBAN
  repeated on the other pages must be the same;
- the table header « Date Texte Crédit Débit Valeur Solde » of each page: an
  amount belongs to the credit or the debit column whose header it ends
  nearest to, counted in characters (columns move from page to page);
- « Etat de compte » with the opening, then the closing balance; « Total »
  with the printed totals;
- a movement: the booking date (only on the first movement of a day, so a day
  can go on over a page without its date), the first line of its text, its
  amount, its value date, and the balance after the last movement of the day;
  the following lines of text, until the next movement;
- the page furniture, removed from the texts: the form code printed
  vertically in the margin, « Page n / m », the header block repeated on
  each page (« Extrait de compte … », « IBAN … », « Numéro de compte … »,
  « BIC … », « Date dd.mm.yyyy »);
- an amount on a line of its own (pdftotext puts it after the vertical form
  code when the code's top falls between the top of a label and the top of
  its amount): its label is the line above, and its date is the one on its
  line when there is one.

The amount of a line is signed (positive for a credit), its date is the
booking date (decision H2), its raw text is the bank's text with its lines
separated by line breaks.

**Short label** (decision H3): when the first line is a type of operation the
module recognises (upper-case words ending with « DU » and maybe its date,
or « DÉBIT », « CRÉDIT », « CRÉDIT POSTFINANCE CARD », « PRIX POUR »), the
generic lines are left out: that first line, the date on the next line, the
card line (« CARTE NO … », « CARTE N° … »), the IBAN of the other party and
« DONNEUR D'ORDRE: ». What is left, on one line, is the initial description;
otherwise the whole text is. The raw text is kept whole and never changes;
the rules read only it.

If the bank changes its layout, the extraction refuses its statements with
the check `layout` or `IMPORT_UNKNOWN_FORMAT` rather than read them wrongly:
the checks of balances and totals catch a line read in the wrong column.

## The lines in the app

- Records: a `statement` (account, format, IBAN, period, balances,
  fingerprint) and one `transaction` per line (account, date, amount, raw
  text, description, status, statement, rank). Their identifiers are computed
  from the account, the fingerprint and the rank: two devices importing the
  same file write the same records, never a line twice.
- On the detailed account, the amount, date, account and raw text of a line
  never change, no line is entered or deleted by hand; category, period,
  description and note change.
- The journal records two statuses: « à valider » and « validée ». For a line
  to validate, the classification shown and counted is computed at each load
  from the rules of its year: « proposée » when one result wins, « à
  compléter » otherwise (no rule, rules of equal weight with different
  results, or a winning rule whose target can no longer be used). Creating or
  modifying a rule writes only the rule.
- Validating writes the category and period, or the counterpart account of a
  transfer, and the status. A transfer keeps the statement's sign: negative,
  the money goes to the other account; positive, it comes from it.
- « Supprimer le dernier relevé » (Relevés du compte) deletes the latest
  statement of the account and all its lines, after a confirmation (H8). Only
  the latest, so that the others stay contiguous. It can then be imported
  again; its lines come back to validate.

## The original files

The server keeps each accepted file in `statements/<fingerprint>.pdf` of its
data directory; the fingerprint is in the statement of the journal, which is
all the app needs to fetch it again: Relevés du compte › « Enregistrer le PDF
d'origine » (`GET /api/v1/imports/{fingerprint}/pdf`). A server rebuilt
since the import no longer has the file: the app says so, without error. The
loss of the original files is acceptable (specification, chapter 9).

## Copies of the server database

Before it stores a file it did not hold, the server writes a copy of its
database: `backups/batz-<UTC time>.db` in its data directory (`VACUUM INTO`,
a consistent copy taken while it runs). It keeps the latest `BATZ_BACKUPS`
copies (12 by default). Sending a file it already holds writes no copy.

To restore one (for instance after an import made by mistake, before the
devices exchanged it):

1. Stop the server: `docker stop batz-web`.
2. In the data directory, move `batz.db`, `batz.db-wal` and `batz.db-shm`
   aside, and copy the chosen `backups/batz-….db` to `batz.db` (owned by uid
   10001, like the rest of the folder).
3. Start the server: `docker start batz-web`.

The certificate stays (it is in `tls/`, not in the database); the paired
devices are those of the copy's date, so a device paired since must be paired
again. The devices then send at their next exchange what the copy lacks: a
restored copy does not remove from the devices what they already hold. To
undo an import on every device, delete the last statement in the app instead
(H8).

## Checking the extraction

- `batz-web extract <file.pdf>` prints the JSON of the result (exit code 2
  when the statement is refused); `-summary` prints only the verdict and the
  number of lines, `-amounts` the date and amount of each line.
- The test set, `src/internal/infrastructure/extraction/postfinance/testdata`,
  is written by the generator in `…/postfinance/fake`: PDF files laid out like
  real statements, with invented content, and for each the JSON the
  extraction must give (`go test ./internal/infrastructure/extraction/postfinance/fake -update`
  rewrites them). Three consecutive months, a statement of another account,
  three altered statements and an invoice.
- `batz-web/scripts/check-image-extraction.sh <image>` extracts the test set
  inside a server image and compares; CI runs it on every change.
- `scripts/check-real-statements.sh` extracts the real statements kept at the
  root of the repository (never committed) and prints only, per file, the
  verdict and the number of lines, and whether the dates and amounts are those
  of the CSV of the original script.
