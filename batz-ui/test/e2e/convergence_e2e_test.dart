// Convergence: devices apply random operations of the app, those of phase 5
// included, with skewed clocks, and exchange through a real batz-web in a
// random order, sometimes cut in the middle. Once everything is exchanged, every table is identical
// on every device.
import 'dart:math';

import 'package:batz/data/server/server_client.dart';
import 'package:batz/domain/export/ledger_export.dart';
import 'package:batz/domain/ledger/ledger_exception.dart';
import 'package:batz/domain/modules/taxes.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/ledger_fixture.dart' show seedLedger;
import '../support/random_operations.dart';
import 'server_harness.dart';
import 'sync_device.dart';

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
      // The same data give the same CSV files, byte for byte (principle 3
      // of phase 7).
      Future<Map<String, List<int>>> csv(SimDevice d) async => {
        for (final f in exportFiles(await d.ledger.ledger())) f.name: f.bytes,
      };
      final files = await csv(devices.first);
      for (final d in devices.skip(1)) {
        expect(await csv(d), files, reason: '${d.name}, seed $seed');
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
        '${ledger.shareClassifications.length} answers, ${ledger.declaredBalances.length} balances, '
        '${ledger.debts.length} debts, ${ledger.modules.salarySheets.length} salary sheets, '
        '${ledger.taxYears.length} fiscal years, ${ledger.modules.tripSheets.length} trip sheets, '
        '${ledger.modules.electricityReadings.length} kWh, ${ledger.modules.subscriptions.length} subscriptions',
      );
      // About ten seconds alone, much more while the other test files run:
      // hundreds of calls with pages of a few entries.
    }, timeout: const Timeout(Duration(minutes: 3)));
  }
}
