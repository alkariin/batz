# API

HTTPS only, JSON bodies. Base URL: `https://<server>:8443`.

The certificate is self-signed: clients pin its SHA-256 fingerprint (upper
case hex pairs separated by colons, as printed by `batz-web pairing-code`).

## Errors

Every error has the same body:

```json
{ "code": "PAIRING_CODE_EXPIRED", "message": "pairing code has expired" }
```

Clients rely on `code`; `message` is for humans.

| Status | Code | When |
|---|---|---|
| 400 | `BAD_REQUEST` | Malformed JSON, an unknown field in an exchange, or a body over 1 MiB (other routes than `/sync`). |
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
| 404 | `NOT_FOUND` | No such route. |
| 500 | `INTERNAL` | Unexpected failure, logged by the server. |

## `GET /healthz`

No authentication.

```json
{ "status": "ok", "version": "v0.3.0", "minAppVersion": "0.3.0", "syncProtocol": 1 }
```

`version` is the server build (`dev` for a local build); `minAppVersion` is
the oldest app version the server works with; `syncProtocol` is the version of
the exchange protocol it speaks (absent before 0.3.0). The app refuses to
synchronise when it is older than `minAppVersion`, or when the protocols
differ, and says why.

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

Header `Authorization: Bearer <device key>`. Every paired device, revoked
ones included, oldest first; `current` marks the caller.

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

Header `Authorization: Bearer <device key>`. Revokes the device: its key is
refused from then on. Revoking the caller itself is how an app unpairs.
Revoking an already revoked device keeps its first revocation date.

Response `204`, or `404 DEVICE_NOT_FOUND`.

## `POST /api/v1/sync`

Header `Authorization: Bearer <device key>`. One call of an exchange of the
change journal; the app calls it in a loop until nothing is left to exchange.
Principle, invariant and loop: [sync.md](sync.md).

Request:

```json
{
  "protocol": 1,
  "appVersion": "0.3.0",
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

## Later phases

`POST /api/v1/imports` and `GET /api/v1/imports/{id}/pdf` come with phase 3
(specification, chapter 8).
