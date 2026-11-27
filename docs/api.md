# API

The HTTP API of `batz-web`. HTTPS only, JSON bodies. Base URL:
`https://<server>:8443`. How the apps use it is in
[architecture](architecture.md).

The certificate is self-signed: clients pin its SHA-256 fingerprint (upper
case hex pairs separated by colons, as printed by `batz-web pairing-code`).

Every route under `/api/v1` but the pairing is authenticated with the header
`Authorization: Bearer <device key>`; a missing, unknown or revoked key is
refused with `401`.

## Errors

Every error has the same body:

```json
{ "code": "PAIRING_CODE_EXPIRED", "message": "pairing code has expired" }
```

Clients rely on `code` (and `check` for a refused statement); `message` is
for humans.

| Status | Code | When |
|---|---|---|
| 400 | `BAD_REQUEST` | Malformed JSON, an unknown field in an exchange, or a body over 1 MiB (pairing and devices). |
| 400 | `DEVICE_NAME_INVALID` | Device name empty or longer than 64 characters. |
| 401 | `PAIRING_CODE_INVALID` | No such pairing code. |
| 401 | `PAIRING_CODE_EXPIRED` | The code is older than its validity. |
| 401 | `PAIRING_CODE_USED` | The code already paired a device. |
| 401 | `DEVICE_KEY_MISSING` | No `Authorization: Bearer` header. |
| 401 | `DEVICE_KEY_INVALID` | Unknown device key. |
| 401 | `DEVICE_REVOKED` | The device was revoked. |
| 404 | `DEVICE_NOT_FOUND` | No device with this id. |
| 400 | `SYNC_PROTOCOL_UNSUPPORTED` | The exchange protocol of the request is not the server's. |
| 426 | `APP_VERSION_UNSUPPORTED` | The app is older than `minAppVersion`. |
| 413 | `SYNC_PAGE_TOO_LARGE` | More than 10 000 entries, or a body over 32 MiB. |
| 400 | `SYNC_PAGE_INVALID` | A malformed entry, known state or `since`; entries not sorted, sent twice, or not after `since`. The whole page is refused. |
| 409 | `SYNC_STATE_CHANGED` | The page continues from more than the server holds (`since`); start again from the server's state. |
| 422 | `IMPORT_UNREADABLE` | The file is a PDF pdftotext cannot read. |
| 422 | `IMPORT_UNKNOWN_FORMAT` | The file is no statement in a format the server knows (a PostFinance PDF, a Neon CSV). |
| 422 | `IMPORT_INCONSISTENT` | The statement fails a check, named in `check`: `layout`, `currency`, `period`, `runningBalance`, `totals`, `closingBalance`. |
| 413 | `IMPORT_TOO_LARGE` | A statement file over 10 MiB. |
| 404 | `IMPORT_PDF_NOT_FOUND` | The server holds no original file with that fingerprint (never sent, or the server was rebuilt). |
| 400 | `DOCUMENT_EMPTY` | A document of no byte. |
| 413 | `DOCUMENT_TOO_LARGE` | A document over 25 MiB. |
| 404 | `DOCUMENT_NOT_FOUND` | The server holds no document with that fingerprint. |
| 404 | `NOT_FOUND` | No such route. |
| 500 | `INTERNAL` | Unexpected failure, logged by the server. |

## `GET /healthz`

No authentication.

```json
{ "status": "ok", "version": "v0.8.0-alpha", "minAppVersion": "0.7.0", "syncProtocol": 1, "importFormats": ["postfinance", "neon"], "documents": true }
```

| Field | Meaning |
|---|---|
| `version` | The server build (`dev` for a local build). |
| `minAppVersion` | The oldest app version the server works with. |
| `syncProtocol` | The version of the exchange protocol it speaks (absent before 0.3.0). |
| `importFormats` | The statement formats it reads (absent before 0.4.0; `neon` since 0.11.0). |
| `documents` | Whether it keeps documents (absent before 0.11.0). |

The app checks them before synchronising and importing, and says why it
refuses ([protocol](architecture.md#protocol)).

## `POST /api/v1/pairing`

No authentication: the one-time code is the credential.

Request:

```json
{ "code": "ABCD-1234", "name": "Téléphone" }
```

The code is case-insensitive; spaces and dashes are ignored, and `O`, `I`,
`L` are read as `0`, `1`, `1`.

Response `201`:

```json
{ "deviceId": "3f2c1a9e-8b7d-4c6e-9f10-2a3b4c5d6e7f", "deviceKey": "<43 characters>" }
```

The key is returned only here; the server keeps its hash.

## `GET /api/v1/devices`

Every paired device, revoked ones included, oldest first; `current` marks
the caller.

```json
{
  "devices": [
    {
      "id": "3f2c1a9e-…",
      "name": "Téléphone",
      "createdAt": "2026-11-20T18:02:11.204Z",
      "lastSeenAt": "2026-11-20T18:05:40.010Z",
      "revokedAt": null,
      "current": true
    }
  ]
}
```

## `DELETE /api/v1/devices/{id}`

Revokes the device: its key is refused from then on. Revoking the caller
itself is how an app unpairs. Revoking an already revoked device keeps its
first revocation date.

Response `204`, or `404 DEVICE_NOT_FOUND`.

## `POST /api/v1/sync`

One call of an exchange of the change journal; the app calls it in a loop
until nothing is left to exchange. Principle, invariant and loop:
[Synchronisation](architecture.md#synchronisation).

Request:

```json
{
  "protocol": 1,
  "appVersion": "0.8.0-alpha",
  "known": { "3f2c1a9e-…": "001763647200000:0003:3f2c1a9e-…" },
  "since": { "3f2c1a9e-…": "001763640000000:0000:3f2c1a9e-…" },
  "entries": [
    {
      "hlc": "001763647200000:0003:3f2c1a9e-…",
      "entity": "transaction",
      "recordId": "9d0e…",
      "field": "note",
      "value": "\"Avec les fruits\""
    }
  ],
  "limit": 1000
}
```

| Field | Meaning |
|---|---|
| `protocol` | Exchange protocol of the app; must be the server's. |
| `appVersion` | Version of the app; refused if older than `minAppVersion`. |
| `known` | The app's known state: for each origin device, the latest timestamp it holds. The answer's entries are computed from it. |
| `since` | For each origin present in `entries`, the server's known timestamp the page was computed from (absent: from the first entry of that origin). |
| `entries` | Entries the server lacks, sorted by timestamp, at most 10 000, never cutting a modification (entries sharing a timestamp). |
| `limit` | Largest page wanted back; 1 000 by default, at most 10 000. |

An entry: `hlc` is a timestamp (`15 digits:4 hex digits:origin`, lower case),
`entity` and `field` are names (`[a-z][a-zA-Z0-9]*`, `field` may also be
`_deleted`), `recordId` is 1 to 128 bytes, and `value` is the JSON text of the
value: `null`, `true`, `false`, a 64-bit integer or a string, at most 256 KiB;
`_deleted` takes a boolean. Unknown fields are refused.

The server checks the whole page first, then, in one transaction, checks
`since` against what it holds, stores the entries it does not hold yet
(others are ignored: the same page can be sent twice), and computes the
answer.

Response `200`:

```json
{
  "protocol": 1,
  "serverTime": "2026-11-20T21:04:05.123Z",
  "known": { "3f2c1a9e-…": "001763647200000:0003:3f2c1a9e-…", "8b1d…": "001763650000000:0000:8b1d…" },
  "since": { "8b1d…": "001763600000000:0000:8b1d…" },
  "entries": [ { "hlc": "…", "entity": "…", "recordId": "…", "field": "…", "value": "…" } ],
  "more": false,
  "added": 1
}
```

| Field | Meaning |
|---|---|
| `serverTime` | The server clock, for the app's clock warning. |
| `known` | The server's known state after integrating the request's entries. |
| `since` | For each origin present in `entries`, the app's known timestamp they continue from (from the request's `known`). |
| `entries` | Entries the app lacks according to `known`, sorted, never cutting a modification, at most `limit` or 8 MiB (a single larger modification goes whole). |
| `more` | True when the server may hold more entries the app lacks. |
| `added` | How many entries of the request were new to the server. |

## `POST /api/v1/imports`

Sends a bank statement: the file is the raw request body, 10 MiB at most: a
PDF statement of PostFinance (`Content-Type: application/pdf`) or a CSV
export of Neon. The server tells the format by the content. The flow, the
checks and the formats: [Import of statements](architecture.md#import-of-statements).

Response `200`:

```json
{
  "fingerprint": "5f01af3b…",
  "statement": {
    "format": "postfinance",
    "iban": "CH0090000000123456789",
    "currency": "CHF",
    "periodStart": "2026-01-01",
    "periodEnd": "2026-01-31",
    "openingBalance": 234567,
    "closingBalance": 499022,
    "totalCredits": 587199,
    "totalDebits": 322744,
    "lines": [
      {
        "date": "2026-01-05",
        "amount": -4785,
        "rawText": "ACHAT/SERVICE DU 04.01.2026\nCARTE NO XXXX0000\nÉpicerie du Coin\nFictiville",
        "label": "Épicerie du Coin Fictiville",
        "balance": 64782
      }
    ]
  }
}
```

| Field | Meaning |
|---|---|
| `fingerprint` | SHA-256 of the file, lower-case hex: the server keeps the file under it. |
| `format` | `postfinance` or `neon`. |
| `iban` | The account's IBAN, without spaces; empty for an export. |
| `periodStart`, `periodEnd` | The period of the statement; for an export, the dates of its first and last lines. |
| `openingBalance`, `closingBalance`, `totalCredits`, `totalDebits` | Integer cents; totals as printed, both positive. Absent for an export, which prints none. |
| `lines[].date` | Booking date. |
| `lines[].amount` | Signed integer cents: positive for a credit. |
| `lines[].rawText` | The bank's text, lines separated by `\n`, page furniture removed. |
| `lines[].label` | The short label: the text without its generic lines. |
| `lines[].balance` | The balance printed after this line, when the statement prints one. |

The server writes nothing to the journal: the app decides whether the
statement follows the previous one and writes it. When the server did not
hold the file, it first writes a dated copy of its database, then stores the
file. The same file always gets the same answer, and no new copy.

Refusals: `422` with `IMPORT_UNREADABLE`, `IMPORT_UNKNOWN_FORMAT` or
`IMPORT_INCONSISTENT` (and `check`), `413 IMPORT_TOO_LARGE`:

```json
{ "code": "IMPORT_INCONSISTENT", "check": "totals", "message": "inconsistent statement (totals): printed totals: …" }
```

## `GET /api/v1/imports/{fingerprint}/pdf`

The original file of a statement, as `application/pdf`, or as
`text/csv; charset=utf-8` for an export (the route keeps its name);
`404 IMPORT_PDF_NOT_FOUND` when the server does not hold it.

## `POST /api/v1/documents`

Sends a document of the insurances: the file is the raw request body, 25
MiB at most. The server keeps it under its fingerprint and knows nothing
else of it: the journal says what it is attached to.

Response `201` (a file the server did not hold) or `200` (the same file
again: nothing written):

```json
{ "fingerprint": "5f01af3b…", "size": 120345 }
```

Refusals: `400 DOCUMENT_EMPTY`, `413 DOCUMENT_TOO_LARGE`. The logs hold the
size and the start of the fingerprint, never the content.

## `GET /api/v1/documents/{fingerprint}`

The document, as `application/octet-stream` (the app knows its type);
`404 DOCUMENT_NOT_FOUND` when the server does not hold it (never sent, or
the server was rebuilt).
