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
| 400 | `BAD_REQUEST` | Malformed JSON, or a body over 1 MiB. |
| 400 | `DEVICE_NAME_INVALID` | Device name empty or longer than 64 characters. |
| 401 | `PAIRING_CODE_INVALID` | No such pairing code. |
| 401 | `PAIRING_CODE_EXPIRED` | The code is older than its validity. |
| 401 | `PAIRING_CODE_USED` | The code already paired a device. |
| 401 | `DEVICE_KEY_MISSING` | No `Authorization: Bearer` header. |
| 401 | `DEVICE_KEY_INVALID` | Unknown device key. |
| 401 | `DEVICE_REVOKED` | The device was revoked. |
| 404 | `DEVICE_NOT_FOUND` | No device with this id. |
| 404 | `NOT_FOUND` | No such route. |
| 500 | `INTERNAL` | Unexpected failure, logged by the server. |

## `GET /healthz`

No authentication.

```json
{ "status": "ok", "version": "v0.1.0", "minAppVersion": "0.1.0" }
```

`version` is the server build (`dev` for a local build); `minAppVersion` is
the oldest app version the server works with. The app warns when it is older.

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

## Later phases

`POST /api/v1/sync`, `POST /api/v1/imports` and
`GET /api/v1/imports/{id}/pdf` come with phases 2 and 3 (specification,
chapter 8).
