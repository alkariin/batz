import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/modules/settings.dart';
import '../../l10n/app_localizations.dart';
import '../ledger_cubit.dart';
import '../ledger_texts.dart';

/// The category a module reads: its name, whether the tree of [year] has
/// it, and a dialog to change the name.
class ModuleCategoryTile extends StatelessWidget {
  const ModuleCategoryTile({super.key, required this.module, required this.year});

  final ModuleKind module;
  final int year;

  Future<void> _edit(BuildContext context, String current) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _NameDialog(current: current),
    );
    if (name == null || !context.mounted) return;
    await applyToLedger(context, (ledger) => ledger.setModuleCategory(module, name));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final ledger = context.watch<LedgerCubit>().state.ledger;
    final name = ledger.moduleCategoryName(module);
    final found = ledger.moduleCategory(module, year) != null;
    final theme = Theme.of(context);
    return ListTile(
      key: ValueKey('moduleCategory-${module.name}'),
      leading: const Icon(Icons.link),
      title: Text(l.moduleCategory(name)),
      subtitle: Text(
        found ? l.moduleCategoryFound('$year') : l.moduleCategoryMissing('$year'),
        key: ValueKey('moduleCategoryState-${module.name}'),
        style: found ? null : TextStyle(color: theme.colorScheme.error),
      ),
      trailing: const Icon(Icons.edit_outlined),
      onTap: () => _edit(context, name),
    );
  }
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.current});

  final String current;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _controller = TextEditingController(text: widget.current);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.moduleCategoryTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.moduleCategoryHint),
          TextField(
            key: const Key('moduleCategoryName'),
            controller: _controller,
            autofocus: true,
            decoration: InputDecoration(labelText: l.moduleCategoryName),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l.cancel)),
        FilledButton(
          key: const Key('moduleCategorySave'),
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(l.save),
        ),
      ],
    );
  }
}
