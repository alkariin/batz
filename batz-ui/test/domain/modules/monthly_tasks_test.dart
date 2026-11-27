import 'package:batz/domain/allocation.dart';
import 'package:batz/domain/ledger/account.dart';
import 'package:batz/domain/ledger/ledger_exception.dart';
import 'package:batz/domain/modules/monthly_tasks.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../domain/ledger/exports_test.dart' show export, line;
import '../../support/ledger_fixture.dart';
import '../../support/ledger_harness.dart';
import '../../support/statements.dart';

final january = fixtureStatement('2026-01');
final february = fixtureStatement('2026-02');

Matcher refusedWith(LedgerError error) => throwsA(isA<LedgerException>().having((e) => e.error, 'error', error));

void main() {
  late LedgerHarness h;
  setUp(() async {
    h = await LedgerHarness.open();
    await seedLedger(h);
    await h.apply(
      (l) => l.createAccount(
        'neon',
        const AccountDraft(name: 'Neon', type: AccountType.privateAccount, importFormat: ImportFormat.neon),
      ),
    );
  });
  tearDown(() => h.close());

  const jan = YearMonth(2026, 1), feb = YearMonth(2026, 2), mar = YearMonth(2026, 3);

  test('tasks are created in order, moved, refused without a name or with an account not imported', () async {
    await h.apply(
      (l) => l.createMonthlyTask('pf', const MonthlyTaskDraft(name: 'PostFinance', since: jan, accountId: 'bank')),
    );
    await h.apply((l) => l.createMonthlyTask('cash', const MonthlyTaskDraft(name: ' Espèces ', since: feb)));
    var ledger = await h.ledger();
    expect(ledger.monthlyTasks.map((t) => (t.id, t.name, t.position, t.since)), [
      ('pf', 'PostFinance', 0, jan),
      ('cash', 'Espèces', 1, feb),
    ]);
    ledger = await h.apply((l) => l.moveMonthlyTask('cash', -1));
    expect(ledger.monthlyTasks.map((t) => t.id), ['cash', 'pf']);

    expect(
      () => ledger.createMonthlyTask('x', const MonthlyTaskDraft(name: ' ', since: jan)),
      refusedWith(LedgerError.nameRequired),
    );
    expect(
      () => ledger.createMonthlyTask('x', const MonthlyTaskDraft(name: 'Espèces', since: jan, accountId: 'cash')),
      refusedWith(LedgerError.monthlyTaskAccountNotDetailed),
    );
    expect(() => ledger.setMonthlyCheck('gone', jan, done: true), refusedWith(LedgerError.unknownMonthlyTask));
  });

  test('a task linked to an account is done once its imports cover the last day of the month', () async {
    await h.apply(
      (l) => l.createMonthlyTask('pf', const MonthlyTaskDraft(name: 'PostFinance', since: jan, accountId: 'bank')),
    );
    await h.apply(
      (l) => l.createMonthlyTask('neon', const MonthlyTaskDraft(name: 'Neon', since: jan, accountId: 'neon')),
    );
    await h.apply((l) => l.createMonthlyTask('debts', const MonthlyTaskDraft(name: 'Dettes', since: feb)));
    for (final f in [january, february]) {
      await h.apply((l) => l.importStatement('bank', f.statement, fingerprint: f.fingerprint).modification);
    }
    // An export imported on 3.3: January and February are complete there.
    await h.apply(
      (l) => l
          .importStatement(
            'neon',
            export([line(d(2026, 1, 10), -500, 'Kiosque')]),
            fingerprint: 'a' * 64,
            closingBalance: 1000,
            today: d(2026, 3, 3),
          )
          .modification,
    );
    final ledger = await h.ledger();
    final months = ledger.monthlyStatuses(d(2026, 3, 20));
    expect(months.map((m) => m.month), [mar, feb, jan], reason: 'the most recent first, up to today');
    String states(MonthStatus m) => [for (final t in m.tasks) '${t.task.id}:${t.state.name}'].join(' ');
    expect(states(months[2]), 'pf:imported neon:imported', reason: 'the debts start in February');
    expect(states(months[1]), 'pf:imported neon:imported debts:toDo');
    expect(states(months[0]), 'pf:toDo neon:toDo debts:toDo');
    expect(months[0].tasks.first.coveredUntil, d(2026, 2, 28));
    expect(months[0].tasks[1].coveredUntil, d(2026, 3, 3));
    expect((months[2].complete, months[1].doneCount), (true, 2));
  });

  test('the user checks and unchecks a box; the month to finish is the oldest past month with a task to do', () async {
    await h.apply((l) => l.createMonthlyTask('cash', const MonthlyTaskDraft(name: 'Espèces', since: jan)));
    var ledger = await h.ledger();
    expect(ledger.monthToFinish(d(2026, 3, 20))?.month, jan);

    ledger = await h.apply((l) => l.setMonthlyCheck('cash', jan, done: true));
    expect(ledger.monthlyTaskStatus(ledger.monthlyTasks.single, jan).state, MonthlyTaskState.checked);
    expect(ledger.monthToFinish(d(2026, 3, 20))?.month, feb);
    ledger = await h.apply((l) => l.setMonthlyCheck('cash', feb, done: true));
    expect(ledger.monthToFinish(d(2026, 3, 20))?.month, mar, reason: 'every past month done: the current one');
    ledger = await h.apply((l) => l.setMonthlyCheck('cash', jan, done: false));
    expect(ledger.monthToFinish(d(2026, 3, 20))?.month, jan);
    expect(ledger.modules.monthlyChecks.keys, {monthlyCheckId('cash', jan), monthlyCheckId('cash', feb)});

    // Deleting the task deletes its boxes.
    ledger = await h.apply((l) => l.deleteMonthlyTask('cash'));
    expect((ledger.monthlyTasks.length, ledger.modules.monthlyChecks.length), (0, 0));
    expect(ledger.monthToFinish(d(2026, 3, 20)), isNull);
  });

  test(
    'the list proposed: one import per detailed account, the cash, the debts; the same records on two devices',
    () async {
      Future<Set<String>> propose(LedgerHarness device) async {
        final ledger = await device.apply(
          (l) => l.createSuggestedMonthlyTasks(
            d(2026, 11, 27),
            importName: (account) => 'Importer $account',
            cashName: 'Espèces',
            debtsName: 'Dettes',
          ),
        );
        expect(ledger.monthlyTasks.map((t) => (t.name, t.accountId, t.since)), [
          ('Importer Neon', 'neon', const YearMonth(2026, 11)),
          ('Importer PostFinance', 'bank', const YearMonth(2026, 11)),
          ('Espèces', null, const YearMonth(2026, 11)),
          ('Dettes', null, const YearMonth(2026, 11)),
        ]);
        return ledger.modules.monthlyTasks.keys.toSet();
      }

      final other = await LedgerHarness.open(deviceId: 'bbbbbbbb-0000-4000-8000-000000000000');
      addTearDown(other.close);
      await other.journal.merge(await h.journal.entries());
      expect(await propose(h), await propose(other));
    },
  );
}
