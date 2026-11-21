// Convergence: devices apply random operations of the app, with skewed
// clocks, and exchange through a real batz-web in a random order, sometimes
// cut in the middle. Once everything is exchanged, every table is identical
// on every device.
import 'dart:math';

import 'package:batz/data/server/server_client.dart';
import 'package:batz/domain/calendar_date.dart';
import 'package:batz/domain/journal/journal_entry.dart';
import 'package:batz/domain/ledger/account.dart';
import 'package:batz/domain/ledger/category.dart';
import 'package:batz/domain/ledger/ledger.dart';
import 'package:batz/domain/ledger/ledger_exception.dart';
import 'package:batz/domain/ledger/redistribution.dart';
import 'package:batz/domain/ledger/refund.dart';
import 'package:batz/domain/ledger/transaction.dart';
import 'package:batz/domain/views/share_operations.dart';
import 'package:batz/domain/views/year_view.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/ledger_fixture.dart' show seedLedger;
import 'server_harness.dart';
import 'sync_device.dart';

const _names = ['Loyer', 'Nourriture', 'Impôts', 'Vacances', 'Salaire', 'Électricité', 'Divers', 'Logement'];
const _accountNames = ['Espèces', 'UBS', 'Épargne', 'Carte', 'Dettes'];

T _pick<T>(Random r, List<T> list) => list[r.nextInt(list.length)];

/// A random operation of the app on [l], or null when there is nothing to
/// do it on. The domain may refuse it ([LedgerException]).
Modification? randomOperation(Ledger l, Random r, String id) {
  final active = l.accounts.values.where((a) => !a.archived).toList();
  final manual = active.where((a) => !a.isDetailed && a.type != AccountType.debts).toList();
  final year = 2026 + r.nextInt(2);
  final categories = l.categories.values.toList();
  final entries = l.transactions.values.where((t) => !t.isTransfer && t.line != null).toList();
  CalendarDate date() => CalendarDate(year, 1 + r.nextInt(12), 1 + r.nextInt(28));

  // The operations of phase 4, now and then.
  if (r.nextInt(100) < 12) return _phase4Operation(l, r, id, year);

  // Weighted: mostly entries and their corrections, like real use.
  final roll = r.nextInt(100);
  final kind = [5, 10, 20, 28, 36, 40, 65, 65, 85, 90, 95, 100].indexWhere((limit) => roll < limit);
  switch (kind) {
    case 0:
      final type = _pick(r, AccountType.values);
      return l.createAccount(
        'acc-$id',
        AccountDraft(
          name: _pick(r, _accountNames),
          type: type,
          importFormat: r.nextInt(6) == 0 ? ImportFormat.postfinance : null,
        ),
      );
    case 1:
      return l.createTree(year);
    case 2:
      final parents = l.trees[year]?.ordered ?? const <Category>[];
      if (parents.isEmpty) return null;
      return l.addCategory('cat-$id', year: year, name: _pick(r, _names), parentId: _pick(r, parents).id);
    case 3:
      if (categories.isEmpty) return null;
      return l.renameCategory(_pick(r, categories).id, '${_pick(r, _names)} ${r.nextInt(3)}');
    case 4:
      if (categories.isEmpty) return null;
      final moved = _pick(r, categories);
      final targets = l.trees[moved.year]!.ordered.where((c) => c.id != moved.id).toList();
      if (targets.isEmpty || r.nextInt(4) == 0) {
        return l.moveCategory(moved.id, nature: _pick(r, CategoryNature.values));
      }
      return l.moveCategory(moved.id, parentId: _pick(r, targets).id);
    case 5:
      if (categories.isEmpty) return null;
      return l.removeCategory(_pick(r, categories).id);
    case 6 || 7:
      if (manual.isEmpty) return null;
      final assignable = l.treeOrPreview(year).assignable;
      if (assignable.isEmpty) return null;
      return l.recordEntry(
        'tx-$id',
        'ln-$id',
        EntryDraft(
          accountId: _pick(r, manual).id,
          date: date(),
          cents: 1 + r.nextInt(100000),
          direction: _pick(r, Direction.values),
          categoryId: _pick(r, assignable).id,
          description: 'op $id',
          periodStart: r.nextInt(4) == 0 ? CalendarDate(year, 1, 1) : null,
          periodEnd: r.nextInt(4) == 0 ? CalendarDate(year + 1, 6, 30) : null,
        ),
      );
    case 8:
      if (entries.isEmpty) return null;
      final t = _pick(r, entries);
      final assignable = l.treeOrPreview(t.date.year).assignable;
      final line = t.line!;
      return l.updateEntry(
        t.id,
        EntryDraft(
          accountId: t.accountId,
          date: t.date,
          cents: r.nextBool() ? t.amount.abs() : 1 + r.nextInt(100000),
          direction: t.amount < 0 ? Direction.outflow : Direction.inflow,
          categoryId: r.nextBool() || assignable.isEmpty ? line.categoryId ?? '' : _pick(r, assignable).id,
          description: t.description,
          note: r.nextBool() ? t.note : 'note $id',
          periodStart: line.periodStart,
          periodEnd: line.periodEnd,
        ),
      );
    case 9:
      if (active.length < 2) return null;
      return l.recordTransfer(
        'tx-$id',
        TransferDraft(
          fromAccountId: _pick(r, active).id,
          toAccountId: _pick(r, active).id,
          date: date(),
          cents: 1 + r.nextInt(50000),
        ),
      );
    case 10:
      if (l.transactions.isEmpty) return null;
      return l.deleteTransaction(_pick(r, l.transactions.keys.toList()));
    default:
      if (l.accounts.isEmpty) return null;
      final account = _pick(r, l.accounts.values.toList());
      return r.nextBool()
          ? l.removeAccount(account.id).modification
          : l.updateAccount(account.id, AccountDraft.of(account).copyWithArchived(!account.archived));
  }
}

/// The operations of phase 4: redistribution rules, refunds attached and
/// detached, answers to the shares to classify.
Modification? _phase4Operation(Ledger l, Random r, String id, int year) {
  final roll = r.nextInt(3);
  if (roll == 0) return _refundOperation(l, r);
  if (roll == 1) return _answerOperation(l, r);
  final existing = l.redistributionsOf(year).where((rule) => l.redistributions.containsKey(rule.id)).toList();
  if (existing.isNotEmpty && r.nextInt(3) == 0) {
    final rule = _pick(r, existing);
    if (r.nextBool()) return l.deleteRedistribution(rule.id);
    return l.updateRedistribution(
      rule.id,
      RedistributionDraft(
        year: year,
        sourceId: rule.sourceId,
        targetId: rule.targetId,
        basisPoints: 1 + r.nextInt(6000),
      ),
    );
  }
  final leaves = l.trees[year]?.assignable ?? const <Category>[];
  if (leaves.length < 2) return null;
  return l.createRedistribution(
    'red-$id',
    RedistributionDraft(
      year: year,
      sourceId: _pick(r, leaves).id,
      targetId: _pick(r, leaves).id,
      basisPoints: 1 + r.nextInt(6000),
    ),
  );
}

Modification? _answerOperation(Ledger l, Random r) {
  final pending = l.views.pendingShares;
  if (pending.isEmpty) return null;
  final group = _pick(r, pending);
  final tree = l.views.treeOf(group.year)!;
  final candidates = [
    for (final c in tree.assignable)
      if (tree.natureOf(c.id) == group.nature) c,
  ];
  if (candidates.isEmpty) return null;
  final lines = r.nextBool() ? group.shares.map((s) => s.lineId) : [_pick(r, group.shares).lineId];
  return l.classifyShares(group.year, lines, _pick(r, candidates).id);
}

Modification? _refundOperation(Ledger l, Random r) {
  final inflows = l.transactions.values.where((t) => t.amount > 0 && !t.isTransfer).toList();
  if (inflows.isEmpty) return null;
  final refund = _pick(r, inflows);
  if (refund.line?.refundedLineId != null && r.nextInt(3) == 0) return l.detachRefund(refund.id);
  final expenses = [
    for (final t in l.transactions.values)
      if (t.line != null && l.isExpenseLine(t, t.line!)) t.line!.id,
  ];
  if (expenses.isEmpty) return null;
  return l.attachRefund(refund.id, _pick(r, expenses));
}

extension on AccountDraft {
  AccountDraft copyWithArchived(bool archived) =>
      AccountDraft(name: name, type: type, importFormat: importFormat, archived: archived);
}

void main() {
  for (final seed in [1, 2, 3]) {
    test('random operations and exchanges on four devices converge (seed $seed)', () async {
      final r = Random(seed);
      final server = await LocalServer.start();
      addTearDown(() async {
        await server.stop();
        server.dataDir.deleteSync(recursive: true);
      });
      final base = DateTime.utc(2026, 11, 20).millisecondsSinceEpoch;
      // Clocks up to ten minutes apart.
      final walls = [for (var i = 0; i < 4; i++) base + r.nextInt(1200000) - 600000];
      final devices = <SimDevice>[];
      for (var i = 0; i < 4; i++) {
        final d = await SimDevice.create(
          'D$i',
          deviceId: '${'$i' * 8}-0000-4000-8000-000000000000',
          now: () => walls[i],
          pageSize: 2 + r.nextInt(8),
          requestedPageSize: 2 + r.nextInt(8),
        );
        addTearDown(d.close);
        await d.pair(server);
        devices.add(d);
      }
      // A shared starting point: accounts and a 2026 tree.
      await seedLedger(devices.first.ledger);
      for (final d in devices) {
        await d.sync();
      }

      var applied = 0, refused = 0, exchanges = 0, cuts = 0;
      for (var step = 0; step < 300; step++) {
        final i = r.nextInt(4);
        final d = devices[i];
        if (r.nextInt(4) == 0) {
          exchanges++;
          if (r.nextInt(5) == 0) {
            cuts++;
            final failAt = 1 + r.nextInt(4);
            final afterServer = r.nextBool();
            try {
              await d.sync(
                wrap: (c) => CutTransport(c, failAt: failAt, afterServer: afterServer),
              );
            } on ServerUnreachableException {
              // Cut; the next exchange resumes.
            }
          } else {
            await d.sync();
          }
          continue;
        }
        walls[i] += r.nextInt(3000);
        try {
          final m = randomOperation(await d.ledger.ledger(), r, 'D$i-$step');
          if (m == null) continue;
          await d.ledger.repository.write(m);
          applied++;
        } on LedgerException {
          refused++;
        }
      }

      for (var pass = 0; pass < 2; pass++) {
        for (final d in devices) {
          await d.sync();
        }
      }
      final reference = await devices.first.state();
      for (final d in devices.skip(1)) {
        expect(await d.state(), reference, reason: '${d.name}, seed $seed');
      }
      final ledger = await devices.first.ledger.ledger();
      expect(applied, greaterThan(120), reason: 'refused $refused');
      expect(ledger.transactions, isNotEmpty);
      // ignore: avoid_print
      print(
        'seed $seed: $applied operations ($refused refused), $exchanges exchanges ($cuts cut), '
        '${(reference['journal']! as List).length} journal entries, ${ledger.transactions.length} transactions, '
        '${ledger.categories.length} categories, ${ledger.forest.detached.length} detached, '
        '${ledger.redistributions.length} redistribution rules, ${ledger.refundsByExpenseLine.length} expenses refunded, '
        '${ledger.shareClassifications.length} answers',
      );
      // About ten seconds alone, much more while the other test files run:
      // hundreds of calls with pages of a few entries.
    }, timeout: const Timeout(Duration(minutes: 3)));
  }
}
