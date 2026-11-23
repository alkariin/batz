import 'package:flutter/material.dart';

import '../../components/date_field.dart';
import '../../domain/calendar_date.dart';
import '../../domain/ledger/category.dart';
import '../../domain/ledger/transaction.dart';
import '../../helpers/formats.dart';
import '../../l10n/app_localizations.dart';
import '../ledger_texts.dart';

/// One line of a transaction split between categories, as it is being
/// typed: its own identifier (kept when the transaction is modified), a
/// category, an amount without sign and a period.
class SplitLineEdit {
  SplitLineEdit({required this.id, this.categoryId, int? cents, required CalendarDate start, required CalendarDate end})
    : amount = TextEditingController(text: cents == null ? '' : formatAmount(cents)),
      start = TextEditingController(text: DateField.text(start)),
      end = TextEditingController(text: DateField.text(end));

  /// The lines of [t], its main line first: what the split editor starts
  /// from for a split transaction.
  static List<SplitLineEdit> of(LedgerTransaction t) => [
    for (final line in t.lines)
      SplitLineEdit(
        id: line.id,
        categoryId: line.categoryId,
        cents: line.amount.abs(),
        start: line.periodStart,
        end: line.periodEnd,
      ),
  ];

  final String id;
  String? categoryId;
  final TextEditingController amount;
  final TextEditingController start;
  final TextEditingController end;

  void dispose() {
    amount.dispose();
    start.dispose();
    end.dispose();
  }
}

/// The amount of the first line of a split: what the other lines leave of
/// [totalCents]; null while an amount cannot be read.
int? splitRest(int? totalCents, List<SplitLineEdit> lines) {
  if (totalCents == null) return null;
  var rest = totalCents;
  for (final line in lines.skip(1)) {
    final cents = parseAmount(line.amount.text);
    if (cents == null) return null;
    rest -= cents;
  }
  return rest;
}

/// The lines typed in [lines] for a transaction of [totalCents] (without
/// sign), the first one taking the rest; null, with the problem shown to
/// the user, when one is incomplete.
List<LineDraft>? splitDrafts(BuildContext context, List<SplitLineEdit> lines, int totalCents) {
  final l = AppLocalizations.of(context);
  // The amounts typed first: the rest of the first line depends on them.
  for (final line in lines.skip(1)) {
    final cents = parseAmount(line.amount.text);
    if (cents == null || cents <= 0 || line.amount.text.trim().startsWith('-')) {
      showMessage(context, l.errorSplitLineAmountInvalid);
      return null;
    }
  }
  final drafts = <LineDraft>[];
  for (final (i, line) in lines.indexed) {
    final cents = i == 0 ? splitRest(totalCents, lines) : parseAmount(line.amount.text);
    final start = DateField.read(line.start), end = DateField.read(line.end);
    final String? problem;
    if (cents == null || cents <= 0) {
      problem = l.splitOverTotal;
    } else if (line.categoryId == null) {
      problem = l.errorCategoryMissing;
    } else if (start == null || end == null) {
      problem = l.errorDateInvalid;
    } else {
      problem = null;
    }
    if (problem != null) {
      showMessage(context, problem);
      return null;
    }
    drafts.add(LineDraft(id: line.id, categoryId: line.categoryId!, cents: cents!, periodStart: start, periodEnd: end));
  }
  return drafts;
}

/// The lines of a split transaction: for each, a category of [tree], an
/// amount and a period. The first line takes what the others leave of
/// [totalCents] and cannot be removed; removing down to one line is the
/// parent's to handle ([onRemove]).
class SplitEditor extends StatelessWidget {
  const SplitEditor({
    super.key,
    required this.lines,
    required this.tree,
    required this.totalCents,
    required this.onChanged,
    required this.onAdd,
    required this.onRemove,
  });

  final List<SplitLineEdit> lines;
  final CategoryTree tree;
  final int? totalCents;
  final VoidCallback onChanged;
  final VoidCallback onAdd;
  final void Function(int index) onRemove;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final categories = tree.assignable;
    final rest = splitRest(totalCents, lines);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.splitTitle, style: theme.textTheme.titleSmall),
        Text(l.splitHint, style: theme.textTheme.bodySmall),
        const SizedBox(height: 8),
        for (final (i, line) in lines.indexed)
          KeyedSubtree(
            key: ValueKey('splitLine-${line.id}'),
            child: Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 4, 12),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: KeyedSubtree(
                            key: Key('splitCategory-$i'),
                            child: DropdownButtonFormField<String>(
                              key: ValueKey('splitCategory-${line.id}-${tree.year}-${line.categoryId}'),
                              initialValue: categories.any((c) => c.id == line.categoryId) ? line.categoryId : null,
                              isExpanded: true,
                              decoration: InputDecoration(labelText: l.fieldCategory),
                              items: [
                                for (final c in categories)
                                  DropdownMenuItem(
                                    value: c.id,
                                    child: Text(
                                      '${c.name} · ${natureText(l, tree.natureOf(c.id))}',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                              onChanged: (id) {
                                line.categoryId = id;
                                onChanged();
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 110,
                          child: i == 0
                              ? InputDecorator(
                                  decoration: InputDecoration(labelText: l.splitRest),
                                  child: Text(
                                    rest == null ? '—' : formatAmount(rest),
                                    key: const Key('splitRest'),
                                    style: rest != null && rest <= 0 ? TextStyle(color: theme.colorScheme.error) : null,
                                  ),
                                )
                              : TextField(
                                  key: Key('splitAmount-$i'),
                                  controller: line.amount,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: InputDecoration(labelText: l.fieldAmount),
                                  onChanged: (_) => onChanged(),
                                ),
                        ),
                        if (i == 0)
                          const SizedBox(width: 48)
                        else
                          IconButton(
                            key: Key('splitRemove-$i'),
                            tooltip: l.splitRemoveLine,
                            icon: const Icon(Icons.close),
                            onPressed: () => onRemove(i),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: DateField(
                              fieldKey: Key('splitStart-$i'),
                              controller: line.start,
                              label: l.periodStart,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DateField(fieldKey: Key('splitEnd-$i'), controller: line.end, label: l.periodEnd),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const Key('splitAdd'),
            icon: const Icon(Icons.add),
            label: Text(l.splitAddLine),
            onPressed: onAdd,
          ),
        ),
      ],
    );
  }
}
