/// The monthly follow-up: the tasks done each month to keep the accounts up
/// to date (import the statements, enter the cash, update the debts…),
/// checked month by month. A task linked to a detailed account is done for
/// a month once the imports of that account cover the month's last day.
library;

import 'package:equatable/equatable.dart';

import '../allocation.dart';
import '../calendar_date.dart';
import '../ids.dart';
import '../journal/journal_entry.dart';
import '../ledger/ledger.dart';
import '../ledger/ledger_exception.dart';

/// Journal entity and fields of a task of the monthly follow-up.
abstract final class MonthlyTaskFields {
  static const entity = 'monthlyTask';
  static const name = 'name';

  /// Its place in the list, from 0.
  static const position = 'position';

  /// A detailed account: its imports check the task.
  static const accountId = 'accountId';

  /// The first month the task applies to, `2026-11`.
  static const since = 'since';
}

/// Journal entity and fields of a box checked, or unchecked, by the user.
abstract final class MonthlyCheckFields {
  static const entity = 'monthlyCheck';
  static const taskId = 'taskId';

  /// `2026-11`.
  static const month = 'month';
  static const done = 'done';
}

class MonthlyTask extends Equatable {
  const MonthlyTask({
    required this.id,
    required this.name,
    required this.position,
    required this.since,
    this.accountId,
  });

  final String id;
  final String name;
  final int position;
  final YearMonth since;
  final String? accountId;

  @override
  List<Object?> get props => [id, name, position, since, accountId];
}

class MonthlyCheck extends Equatable {
  const MonthlyCheck({required this.id, required this.taskId, required this.month, required this.done});

  final String id;
  final String taskId;
  final YearMonth month;
  final bool done;

  @override
  List<Object?> get props => [id, taskId, month, done];
}

/// What the user enters for a task.
class MonthlyTaskDraft {
  const MonthlyTaskDraft({required this.name, required this.since, this.accountId});

  final String name;
  final YearMonth since;
  final String? accountId;
}

/// Identifier of the box of [taskId] for [month]: computed, so that two
/// devices checking it write one record.
String monthlyCheckId(String taskId, YearMonth month) => derivedId('monthly-check/$taskId/$month');

/// Reads `2026-11`; null for anything else.
YearMonth? parseYearMonth(Object? value) {
  if (value is! String) return null;
  final match = RegExp(r'^(\d{4})-(\d{2})$').firstMatch(value);
  if (match == null) return null;
  final month = int.parse(match.group(2)!);
  return month < 1 || month > 12 ? null : YearMonth(int.parse(match.group(1)!), month);
}

YearMonth monthOf(CalendarDate date) => YearMonth(date.year, date.month);

/// How a task stands for a month.
enum MonthlyTaskState {
  /// Checked by the user.
  checked,

  /// Done by the imports of its account.
  imported,
  toDo,
}

/// A task in a month, and how it stands.
class MonthlyTaskStatus extends Equatable {
  const MonthlyTaskStatus(this.task, this.state, {this.coveredUntil});

  final MonthlyTask task;
  final MonthlyTaskState state;

  /// For a task linked to an account: the last day its imports cover.
  final CalendarDate? coveredUntil;

  bool get done => state != MonthlyTaskState.toDo;

  @override
  List<Object?> get props => [task, state, coveredUntil];
}

/// A month of the follow-up: its tasks, in their order.
class MonthStatus extends Equatable {
  const MonthStatus(this.month, this.tasks);

  final YearMonth month;
  final List<MonthlyTaskStatus> tasks;

  int get doneCount => tasks.where((t) => t.done).length;
  bool get complete => doneCount == tasks.length;

  @override
  List<Object?> get props => [month, tasks];
}

/// The tasks of the monthly follow-up and their operations.
extension MonthlyTaskOperations on Ledger {
  /// The tasks, in their order.
  List<MonthlyTask> get monthlyTasks => [...modules.monthlyTasks.values]
    ..sort((a, b) {
      final byPosition = a.position.compareTo(b.position);
      return byPosition != 0 ? byPosition : a.id.compareTo(b.id);
    });

  /// Creates the task [id], last of the list. Refused without a name, or
  /// linked to an account that is not detailed.
  Modification createMonthlyTask(String id, MonthlyTaskDraft draft) {
    final last = monthlyTasks.lastOrNull;
    return Modification.set(MonthlyTaskFields.entity, id, {
      ..._taskFields(draft),
      MonthlyTaskFields.position: last == null ? 0 : last.position + 1,
    });
  }

  Modification updateMonthlyTask(String id, MonthlyTaskDraft draft) {
    _task(id);
    return Modification.set(MonthlyTaskFields.entity, id, _taskFields(draft));
  }

  /// Deletes the task [id] and its boxes.
  Modification deleteMonthlyTask(String id) {
    _task(id);
    return Modification([
      FieldChange(MonthlyTaskFields.entity, id, deletedField, true),
      for (final check in modules.monthlyChecks.values)
        if (check.taskId == id) FieldChange(MonthlyCheckFields.entity, check.id, deletedField, true),
    ]);
  }

  /// Moves the task [id] one place up (`-1`) or down (`1`): the positions
  /// of the whole list are written, in its new order.
  Modification moveMonthlyTask(String id, int offset) {
    final tasks = monthlyTasks;
    final from = tasks.indexWhere((t) => t.id == id);
    if (from < 0) throw const LedgerException(LedgerError.unknownMonthlyTask);
    final to = (from + offset).clamp(0, tasks.length - 1);
    tasks.insert(to, tasks.removeAt(from));
    return Modification([
      for (final (position, task) in tasks.indexed)
        FieldChange(MonthlyTaskFields.entity, task.id, MonthlyTaskFields.position, position),
    ]);
  }

  /// Checks, or unchecks, the box of [taskId] for [month].
  Modification setMonthlyCheck(String taskId, YearMonth month, {required bool done}) {
    _task(taskId);
    return Modification.set(MonthlyCheckFields.entity, monthlyCheckId(taskId, month), {
      MonthlyCheckFields.taskId: taskId,
      MonthlyCheckFields.month: '$month',
      MonthlyCheckFields.done: done,
    });
  }

  /// The last day the imports of [accountId] cover: the end of its latest
  /// statement (for an export, the day of its latest import).
  CalendarDate? importedUntil(String accountId) => lastStatementOf(accountId)?.periodEnd;

  /// How [task] stands for [month]: checked by the user, done by the imports
  /// of its account once they reach the month's last day, or to do.
  MonthlyTaskStatus monthlyTaskStatus(MonthlyTask task, YearMonth month) {
    final until = task.accountId == null ? null : importedUntil(task.accountId!);
    final lastDay = CalendarDate(month.year, month.month, month.days);
    if (until != null && !until.isBefore(lastDay)) {
      return MonthlyTaskStatus(task, MonthlyTaskState.imported, coveredUntil: until);
    }
    final checked = modules.monthlyChecks[monthlyCheckId(task.id, month)]?.done ?? false;
    return MonthlyTaskStatus(task, checked ? MonthlyTaskState.checked : MonthlyTaskState.toDo, coveredUntil: until);
  }

  /// Every month of the follow-up, the most recent first: from the first
  /// month a task applies to, up to the month of [today]. Each month holds
  /// the tasks that apply to it.
  List<MonthStatus> monthlyStatuses(CalendarDate today) {
    final tasks = monthlyTasks;
    if (tasks.isEmpty) return const [];
    final current = monthOf(today);
    var first = tasks.map((t) => t.since).reduce((a, b) => a.compareTo(b) <= 0 ? a : b);
    if (first.compareTo(current) > 0) first = current;
    final months = <MonthStatus>[];
    for (var m = first; m.compareTo(current) <= 0; m = m.next) {
      months.add(
        MonthStatus(m, [
          for (final task in tasks)
            if (task.since.compareTo(m) <= 0) monthlyTaskStatus(task, m),
        ]),
      );
    }
    return months.reversed.toList();
  }

  /// The month to finish: the oldest month before the month of [today]
  /// with a task to do, or else the month of [today]; null without tasks.
  MonthStatus? monthToFinish(CalendarDate today) {
    final months = monthlyStatuses(today);
    if (months.isEmpty) return null;
    final current = monthOf(today);
    for (final m in months.reversed) {
      if (m.month.compareTo(current) < 0 && m.tasks.isNotEmpty && !m.complete) return m;
    }
    return months.first;
  }

  /// A first list: one import per detailed account, the cash and the debts,
  /// from the month of [today]. Their identifiers are computed: the list
  /// proposed on two devices is one list.
  Modification createSuggestedMonthlyTasks(
    CalendarDate today, {
    required String Function(String account) importName,
    required String cashName,
    required String debtsName,
  }) {
    final since = monthOf(today);
    final drafts = <(String, MonthlyTaskDraft)>[
      for (final account in sortedAccounts)
        if (account.isDetailed && !account.archived)
          (
            'account/${account.id}',
            MonthlyTaskDraft(name: importName(account.name), since: since, accountId: account.id),
          ),
      ('cash', MonthlyTaskDraft(name: cashName, since: since)),
      ('debts', MonthlyTaskDraft(name: debtsName, since: since)),
    ];
    final start = (monthlyTasks.lastOrNull?.position ?? -1) + 1;
    return Modification([
      for (final (index, (key, draft)) in drafts.indexed)
        for (final field in {..._taskFields(draft), MonthlyTaskFields.position: start + index}.entries)
          FieldChange(MonthlyTaskFields.entity, derivedId('monthly-task/suggested/$key'), field.key, field.value),
    ]);
  }

  Map<String, Object?> _taskFields(MonthlyTaskDraft draft) {
    if (draft.name.trim().isEmpty) throw const LedgerException(LedgerError.nameRequired);
    if (draft.accountId case final id?) {
      final account = accounts[id];
      if (account == null) throw const LedgerException(LedgerError.unknownAccount);
      if (!account.isDetailed) throw const LedgerException(LedgerError.monthlyTaskAccountNotDetailed);
    }
    return {
      MonthlyTaskFields.name: draft.name.trim(),
      MonthlyTaskFields.accountId: draft.accountId,
      MonthlyTaskFields.since: '${draft.since}',
    };
  }

  MonthlyTask _task(String id) {
    final task = modules.monthlyTasks[id];
    if (task == null) throw const LedgerException(LedgerError.unknownMonthlyTask);
    return task;
  }
}
