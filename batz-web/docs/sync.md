# Synchronisation

How the apps exchange their change journal through the server. The
functional decisions are in `docs/plan/phase-2.md` (H1 to H6); the technical
ones, with their evidence, in `docs/decisions.md`.

## Principle

1. **The server stores, it does not interpret.** It keeps the journal entries
   exactly as the apps send them. Conflicts are resolved by the apps, with the
   rule in place since phase 0: field by field, the latest change wins.
2. **Known state.** Every copy of the journal (each device, and the server)
   knows, for each *origin* device, up to which timestamp it holds that
   device's entries. During an exchange each side sends the other what it
   lacks, **whatever the origin**.
3. **One mechanism.** There is no cursor and no recovery mode. A new device,
   an empty server, or a server restored from an old copy are ordinary
   exchanges: the known state of the other side is simply shorter. This is
   what lets the server be rebuilt from any device.
4. **Invariant** (below).
5. **One route**, `POST /api/v1/sync`, called in a loop.
6. **Replaying changes nothing.** An entry already held is ignored. An
   interrupted exchange resumes at the next one, without loss or duplicate.
7. **Server checks.** Device authenticated and not revoked, protocol number,
   app version, shape of every entry, size of the page. An incorrect page is
   refused as a whole.

## Entries, timestamps and origins

An entry is one field of one record set to one value: `entity`, `recordId`,
`field`, `value`, stamped with a timestamp of the hybrid logical clock of the
device that made the change:

```
001763647200000:0000:3f2c1a9e-8b7d-4c6e-9f10-2a3b4c5d6e7f
└─ wall time, ms ┘└ctr┘└──────────── origin device ────────┘
```

The fixed width makes the text order the time order, in Dart, in SQLite and in
Go. The origin is the journal identifier of the device (created at its first
start, replaced only when its data are replaced, see H1), not the identifier
the server gives at pairing. All entries of one modification share one
timestamp: a timestamp identifies a modification.

The reserved field `_deleted` (a boolean) records a deletion; it is resolved
like any other field, so an older edit arriving later does not bring a deleted
record back.

A modification writes only the fields whose value changes: a screen submits
every field of a record, and without this rule the latest modification would
overwrite, once synchronised, what another device changed in other fields.

## Known state

For each origin, the latest timestamp held:

```json
{ "3f2c1a9e-…": "001763647200000:0003:3f2c1a9e-…", "8b1d…": "001763650000000:0000:8b1d…" }
```

What a copy with known state `K` lacks: every entry of origin `o` stamped
after `K[o]`, and every entry of an origin absent from `K`.

## Invariant

**For each origin, every copy holds that origin's entries from the first one,
without a gap.** The known state is meaningful only because of it.

It holds because:

- A device's own entries are stamped in increasing order (the clock never goes
  back, even across restarts).
- What is sent is selected from the receiver's known state and **sorted by
  timestamp**; for each origin a page thus holds a contiguous run that starts
  right after what the receiver held.
- A page is **integrated in one transaction**: all of it or nothing.
- A page **never cuts a modification**: the entries sharing a timestamp travel
  together (a single modification larger than a page is sent whole).
- A page carries `since`: for each origin present, the receiver's known
  timestamp it was computed from. The receiver refuses a page that continues
  from more than it holds (on the server: `409 SYNC_STATE_CHANGED`), which
  would leave a gap, for instance when the server was restored from an older
  copy between two calls.

A device whose data are replaced by the server's (H1) takes a new journal
identifier, so that its new entries never follow, under the same origin,
entries that were erased.

## Protocol

Before exchanging, the app calls `GET /healthz` and checks compatibility:

| Server says | App does |
|---|---|
| `minAppVersion` above the app version | refuses: app too old |
| no `syncProtocol` (server before 0.3.0), or a smaller one | refuses: server too old |
| a larger `syncProtocol` | refuses: app too old |

Then it calls `POST /api/v1/sync` in a loop (request and answer formats in
[api.md](api.md)):

```
server := unknown, more := true
loop
    page := server unknown ? nothing : what the server lacks according to `server`
    stop if server is known, page is empty and not more
    answer := POST /sync { known: my known state, since: page.since, entries: page }
    (first answer only) H1 check, see below
    integrate answer.entries in one transaction (refused if answer.since > what I hold)
    server := answer.known, more := answer.more
    remember `server` (to count the modifications waiting)
remember the date of the exchange
```

- The first call sends no entry: it learns the server state.
- The server integrates the page in one transaction, then answers with its
  state *after* integrating it and a page of what the device lacks according
  to the `known` of the request.
- `SYNC_STATE_CHANGED`: the app starts again from the server's current state,
  at most three times.
- An answer announcing `more` without any entry, or a page from the server
  that would leave a gap, stops the exchange as a protocol error.
- Local modifications made during an exchange are picked up by the next call
  of the loop.

Page sizes: the app sends 500 entries (or 4 MiB) per call and asks for 1 000;
the server accepts up to 10 000 entries and 32 MiB per call, and sends at most
the size asked, stopping at 8 MiB. A modification holds at most 10 000
changes. The value of an entry travels as its JSON text and is at most
256 KiB; the server checks that it is null, a boolean, a 64-bit integer or a
string, then stores and returns that text unchanged.

### Measure

A first exchange of 20 000 entries, measured on the development machine
(`batz-ui/benchmark/first_exchange_test.dart`): 2.9 s to send them to an
empty server, 3.0 s for a new device to receive them. Received pages are
integrated with a few set-based SQL statements per page.

## Integration on the device

Each page goes into a temporary table; entries already held are dropped, the
others are inserted into the journal; then, for each field touched, the latest
new entry is applied to the derived table if it is newer than the version of
that field (`field_versions`). The result is the one of applying entries one
by one with the resolution rule, in any order. Entries of an entity or field
the running version does not know are kept in the journal only; a later
version applies them when it rebuilds its derived tables.

## When it runs (H2)

- When the app opens, when it comes back to the foreground, 3 seconds after
  the last modification, every 5 minutes while it is shown, and from the
  button « Synchroniser ».
- One exchange at a time; a trigger during an exchange schedules exactly one
  more.
- An unreachable server shows « Hors ligne », never an error.
- After an exchange that received entries, every screen reloads.

The home screen and Plus › Serveur show the status (never synchronised, in
progress, up to date, offline, revoked, server changed, incompatible
versions, first exchange question, error), the date of the last exchange,
the number of modifications waiting (timestamps held beyond the server state
remembered at the last exchange), and a warning when the device clock is more
than 5 minutes away from the server's (H5; the offset is measured at each
call, and never blocks anything).

## First exchange of a device used separately (H1)

When the device and the server both hold entries and their known states have
no origin in common, they never exchanged. The app checks this on the first
answer, before integrating or sending anything, and asks:

- **Fusionner**: an ordinary exchange. Duplicates it may create are listed as
  tasks (H4).
- **Remplacer les données de cet appareil**: the app asks the server as a
  device holding nothing; with the first answer, in one transaction, it erases
  its journal and derived tables, takes a new journal identifier and
  integrates the page; the exchange then continues as usual. Nothing is erased
  if the server does not answer. Modifications not sent are lost: the app
  says so before confirming. The same action is in Plus › Serveur.

## Revoked device, lost server (H6)

- A revoked device (`401 DEVICE_REVOKED`) stops its automatic exchanges and
  says so. Its data stay and it remains usable. Paired again, its first
  exchange sends everything the server lacks, unsent modifications included.
- A server that presents another certificate, or no longer knows the device's
  key (`401 DEVICE_KEY_INVALID`), was probably reinstalled: the app says « Le
  serveur a changé » and invites to pair again. After pairing, the ordinary
  exchange rebuilds it from the device; the other devices pair again the same
  way and send what they hold. Since they share origins with the rebuilt
  server, they are not asked the question of H1.
- A server restored from an older copy needs nothing: each device's next
  exchange sends what the copy lacks.

## Inconsistencies after a merge (H4)

Each device checks the business rules against its own data only. After a
merge the data can hold two categories with the same name in one year,
several detailed accounts, or categories detached from their tree (a loop
made by two moves at the same time, a parent deleted on one device while a
child was added on another). None of them blocks anything: they are listed
under « À faire » on the home screen and corrected through the usual screens;
detached categories are listed under « À replacer » in the categories screen,
with the action that moves them back.

## Known limits

- A tree copied on two devices offline: if one device copies a year's tree and
  then renames or moves a copied category, and another device, not yet
  synchronised, copies the same tree later, the rename is undone after
  synchronisation (H3). Both devices show the same tree; nothing is
  duplicated or deleted.
- The order of changes depends on the device clocks: a device whose clock is
  far behind loses its concurrent changes. The clock warning (H5) is there for
  that.
- A device's database restored from an older file backup keeps its journal
  identifier but forgets entries it had already sent; if its clock is behind,
  its next entries could take timestamps the server already holds for that
  origin and never be sent. Android backups are disabled; on a desktop, do not
  restore the database file: install afresh and pair, the server sends
  everything back.

## Tests

| What | Where |
|---|---|
| Entry shape, pages never cutting a modification, `since`, size and version checks, a page refused as a whole and accepted twice without duplicate | `batz-web/src/internal/domain/journal`, `internal/application/sync_test.go`, `internal/infrastructure/web/sync_test.go` |
| Two simulated devices through the real binary over HTTPS | `batz-web/src/test/e2e` |
| Known state, pages, integration in one operation, gap refused, copies holding a prefix of every origin | `batz-ui/test/data/journal_exchange_test.dart` |
| Engine edge cases (restart after a state change, protocol errors, clock offset, H1) | `batz-ui/test/data/sync_engine_test.dart` |
| Concurrent edits of different fields, the same field in both orders, deletions, an exchange cut between two pages, replace and merge (H1) | `batz-ui/test/e2e/sync_e2e_test.dart` |
| Revoked device, server rebuilt (new certificate, or database lost), restored copy | `batz-ui/test/e2e/rebuild_e2e_test.dart` |
| Convergence: random operations of the app on four devices with skewed clocks, random exchanges, random cuts | `batz-ui/test/e2e/convergence_e2e_test.dart` |
| Triggers, statuses, versions, clock warning | `batz-ui/test/pages/sync` |
