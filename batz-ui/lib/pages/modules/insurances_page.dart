import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../components/date_field.dart';
import '../../data/documents/documents.dart';
import '../../data/files.dart';
import '../../domain/calendar_date.dart';
import '../../domain/ids.dart';
import '../../domain/modules/insurances.dart';
import '../../l10n/app_localizations.dart';
import '../../services.dart';
import '../ledger_cubit.dart';
import '../ledger_texts.dart';

/// The reason a document could not be added or opened, for the user.
String documentErrorText(AppLocalizations l, DocumentError error) => switch (error) {
  DocumentError.notPaired => l.documentNotPaired,
  DocumentError.unreachable => l.documentUnreachable,
  DocumentError.serverChanged => l.documentServerChanged,
  DocumentError.serverTooOld => l.documentServerTooOld,
  DocumentError.tooLarge => l.documentTooLarge,
  DocumentError.empty => l.documentEmpty,
  DocumentError.missing => l.documentMissing,
};

String _period(AppLocalizations l, InsuranceTranche t) => t.end == null
    ? l.insuranceTrancheTitle(DateField.text(t.start))
    : l.insuranceTrancheTitleEnd(DateField.text(t.start), DateField.text(t.end!));

/// Plus › « Assurances »: each insurance with its tranche in force.
class InsurancesPage extends StatelessWidget {
  const InsurancesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final ledger = context.watch<LedgerCubit>().state.ledger;
    final today = context.read<AppServices>().today();
    final insurances = ledger.insurances;
    return Scaffold(
      appBar: AppBar(title: Text(l.insurancesTitle)),
      floatingActionButton: FloatingActionButton(
        key: const Key('insuranceNew'),
        tooltip: l.insuranceNew,
        onPressed: () => _create(context),
        child: const Icon(Icons.add),
      ),
      body: insurances.isEmpty
          ? Center(child: Text(l.insurancesEmpty))
          : ListView(
              padding: const EdgeInsets.only(bottom: 88),
              children: [
                for (final i in insurances)
                  () {
                    final active = i.activeAt(today);
                    return ListTile(
                      key: ValueKey('insurance-${i.id}'),
                      leading: const Icon(Icons.shield_outlined),
                      title: Text(i.name),
                      subtitle: Text(
                        active == null
                            ? l.insuranceNoActive
                            : [
                                active.end == null
                                    ? l.insuranceActiveSince(DateField.text(active.start))
                                    : l.insuranceActiveUntil(DateField.text(active.start), DateField.text(active.end!)),
                                l.insuranceDocumentsCount(active.documents.length),
                              ].join(' · '),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () =>
                          Navigator.of(context)
                              .push(MaterialPageRoute<void>(builder: (_) => InsurancePage(insuranceId: i.id))),
                    );
                  }(),
              ],
            ),
    );
  }

  Future<void> _create(BuildContext context) async {
    final today = context.read<AppServices>().today();
    final created = await showDialog<(String, CalendarDate)>(
      context: context,
      builder: (_) => _NewInsuranceDialog(today: today),
    );
    if (created == null || !context.mounted) return;
    final id = newId();
    final saved = await applyToLedger(
      context,
      (ledger) => ledger.createInsurance(
        id,
        newId(),
        name: created.$1,
        first: InsuranceTrancheDraft(start: created.$2),
      ),
    );
    if (saved && context.mounted) {
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => InsurancePage(insuranceId: id)));
    }
  }
}

class _NewInsuranceDialog extends StatefulWidget {
  const _NewInsuranceDialog({required this.today});

  final CalendarDate today;

  @override
  State<_NewInsuranceDialog> createState() => _NewInsuranceDialogState();
}

class _NewInsuranceDialogState extends State<_NewInsuranceDialog> {
  final _name = TextEditingController();
  late final _start = TextEditingController(text: DateField.text(widget.today));

  @override
  void dispose() {
    _name.dispose();
    _start.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.insuranceNew),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const Key('insuranceName'),
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: l.insuranceName, hintText: l.insuranceNameHint),
          ),
          DateField(controller: _start, label: l.insuranceTrancheStart, fieldKey: const Key('insuranceStart')),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l.cancel)),
        FilledButton(
          key: const Key('insuranceCreate'),
          onPressed: () {
            final start = DateField.read(_start);
            if (start == null) {
              showMessage(context, l.errorDateInvalid);
              return;
            }
            Navigator.of(context).pop((_name.text, start));
          },
          child: Text(l.save),
        ),
      ],
    );
  }
}

/// An insurance: its tranche in force, with its documents, links and note;
/// the other tranches folded until asked for.
class InsurancePage extends StatefulWidget {
  const InsurancePage({super.key, required this.insuranceId});

  final String insuranceId;

  @override
  State<InsurancePage> createState() => _InsurancePageState();
}

class _InsurancePageState extends State<InsurancePage> {
  var _showOthers = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final ledger = context.watch<LedgerCubit>().state.ledger;
    final insurance = ledger.modules.insurances[widget.insuranceId];
    if (insurance == null) return Scaffold(appBar: AppBar(title: Text(l.insurancesTitle)));
    final today = context.read<AppServices>().today();
    final active = insurance.activeAt(today);
    final others = [
      for (final t in insurance.tranches.reversed)
        if (t != active) t,
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(insurance.name),
        actions: [
          PopupMenuButton<String>(
            key: const Key('insuranceMenu'),
            onSelected: (action) => switch (action) {
              'rename' => _rename(context, insurance),
              'tranche' => _editTranche(context, insurance, null),
              _ => _delete(context, insurance),
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'tranche', child: Text(l.insuranceTrancheNew)),
              PopupMenuItem(value: 'rename', child: Text(l.insuranceRename)),
              PopupMenuItem(value: 'delete', child: Text(l.insuranceDelete)),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
        children: [
          if (active != null)
            _TrancheCard(insurance: insurance, tranche: active, active: true)
          else
            ListTile(title: Text(l.insuranceNoActive)),
          if (others.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const Key('insuranceOthers'),
                icon: Icon(_showOthers ? Icons.expand_less : Icons.expand_more),
                label: Text(_showOthers ? l.insuranceOthersHide : l.insuranceOthers(others.length)),
                onPressed: () => setState(() => _showOthers = !_showOthers),
              ),
            ),
          if (_showOthers)
            for (final t in others) _TrancheCard(insurance: insurance, tranche: t, active: false),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('insuranceTrancheNew'),
              icon: const Icon(Icons.add),
              label: Text(l.insuranceTrancheNew),
              onPressed: () => _editTranche(context, insurance, null),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _rename(BuildContext context, Insurance insurance) async {
    final l = AppLocalizations.of(context);
    final name = await _textDialog(context, title: l.insuranceRename, label: l.insuranceName, initial: insurance.name);
    if (name == null || !context.mounted) return;
    await applyToLedger(context, (ledger) => ledger.renameInsurance(insurance.id, name));
  }

  Future<void> _delete(BuildContext context, Insurance insurance) async {
    final l = AppLocalizations.of(context);
    if (!await _confirm(context, l.insuranceDeleteConfirm(insurance.name)) || !context.mounted) return;
    if (await applyToLedger(context, (ledger) => ledger.deleteInsurance(insurance.id)) && context.mounted) {
      showMessage(context, l.insuranceDeleted);
      Navigator.of(context).pop();
    }
  }
}

/// Creates a tranche of [insurance], or modifies [tranche].
Future<void> _editTranche(BuildContext context, Insurance insurance, InsuranceTranche? tranche) async {
  final today = context.read<AppServices>().today();
  final dates = await showDialog<(CalendarDate, CalendarDate?)>(
    context: context,
    builder: (_) => _TrancheDialog(tranche: tranche, today: today),
  );
  if (dates == null || !context.mounted) return;
  final draft = InsuranceTrancheDraft(start: dates.$1, end: dates.$2, note: tranche?.note ?? '');
  await applyToLedger(
    context,
    (ledger) => tranche == null
        ? ledger.addInsuranceTranche(insurance.id, newId(), draft)
        : ledger.updateInsuranceTranche(tranche.id, draft),
  );
}

class _TrancheDialog extends StatefulWidget {
  const _TrancheDialog({required this.tranche, required this.today});

  final InsuranceTranche? tranche;
  final CalendarDate today;

  @override
  State<_TrancheDialog> createState() => _TrancheDialogState();
}

class _TrancheDialogState extends State<_TrancheDialog> {
  late final _start = TextEditingController(text: DateField.text(widget.tranche?.start ?? widget.today));
  late final _end = TextEditingController(
    text: widget.tranche?.end == null ? '' : DateField.text(widget.tranche!.end!),
  );

  @override
  void dispose() {
    _start.dispose();
    _end.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.tranche == null ? l.insuranceTrancheNew : l.insuranceTrancheEdit),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DateField(controller: _start, label: l.insuranceTrancheStart, fieldKey: const Key('trancheStart')),
          DateField(controller: _end, label: l.insuranceTrancheEnd, fieldKey: const Key('trancheEnd')),
          if (widget.tranche == null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(l.insuranceTrancheHint, style: Theme.of(context).textTheme.bodySmall),
            ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l.cancel)),
        FilledButton(
          key: const Key('trancheSave'),
          onPressed: () {
            final start = DateField.read(_start);
            final end = _end.text.trim().isEmpty ? null : DateField.read(_end);
            if (start == null || (_end.text.trim().isNotEmpty && end == null)) {
              showMessage(context, l.errorDateInvalid);
              return;
            }
            Navigator.of(context).pop((start, end));
          },
          child: Text(l.save),
        ),
      ],
    );
  }
}

/// A tranche: its period, its note, its documents and its links.
class _TrancheCard extends StatelessWidget {
  const _TrancheCard({required this.insurance, required this.tranche, required this.active});

  final Insurance insurance;
  final InsuranceTranche tranche;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final t = tranche;
    return Card(
      key: ValueKey('tranche-${t.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            title: Text(_period(l, t), style: theme.textTheme.titleMedium),
            subtitle: active ? Text(l.insuranceTrancheActive) : null,
            trailing: PopupMenuButton<String>(
              key: ValueKey('trancheMenu-${t.id}'),
              onSelected: (action) => switch (action) {
                'edit' => _editTranche(context, insurance, t),
                _ => _deleteTranche(context),
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'edit', child: Text(l.insuranceTrancheEdit)),
                PopupMenuItem(value: 'delete', child: Text(l.insuranceTrancheDelete)),
              ],
            ),
          ),
          ListTile(
            key: ValueKey('trancheNote-${t.id}'),
            dense: true,
            title: Text(l.insuranceNote, style: theme.textTheme.labelLarge),
            subtitle: Text(t.note.isEmpty ? l.insuranceNoNote : t.note),
            trailing: IconButton(
              tooltip: l.insuranceNoteEdit,
              icon: const Icon(Icons.edit_note),
              onPressed: () => _editNote(context),
            ),
          ),
          _header(context, l.insuranceDocuments, l.insuranceDocumentAdd, Key('documentAdd-${t.id}'), _addDocument),
          for (final d in t.documents) _document(context, d),
          _header(context, l.insuranceLinks, l.insuranceLinkAdd, Key('linkAdd-${t.id}'), (c) => _editLink(c, null)),
          for (final link in t.links) _link(context, link),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _header(
    BuildContext context,
    String title,
    String add,
    Key key,
    Future<void> Function(BuildContext context) onAdd,
  ) => ListTile(
    dense: true,
    title: Text(title, style: Theme.of(context).textTheme.labelLarge),
    trailing: IconButton(key: key, tooltip: add, icon: const Icon(Icons.add), onPressed: () => onAdd(context)),
  );

  Widget _document(BuildContext context, InsuranceDocument d) {
    final l = AppLocalizations.of(context);
    return ListTile(
      key: ValueKey('document-${d.id}'),
      leading: Icon(switch (d.mediaType) {
        'application/pdf' => Icons.picture_as_pdf_outlined,
        final type when type.startsWith('image/') => Icons.image_outlined,
        _ => Icons.insert_drive_file_outlined,
      }),
      title: Text(d.name),
      subtitle: Text('${_kind(l, d.kind)} · ${_size(d.size)}'),
      onTap: () => _open(context, d),
      trailing: PopupMenuButton<String>(
        key: ValueKey('documentMenu-${d.id}'),
        onSelected: (action) => switch (action) {
          'open' => _open(context, d),
          'save' => _save(context, d),
          'edit' => _editDocument(context, d),
          _ => _deleteDocument(context, d),
        },
        itemBuilder: (_) => [
          PopupMenuItem(value: 'open', child: Text(l.insuranceDocumentOpen)),
          PopupMenuItem(value: 'save', child: Text(l.insuranceDocumentSave)),
          PopupMenuItem(value: 'edit', child: Text(l.insuranceDocumentEdit)),
          PopupMenuItem(value: 'delete', child: Text(l.insuranceDocumentDelete)),
        ],
      ),
    );
  }

  Widget _link(BuildContext context, InsuranceLink link) {
    final l = AppLocalizations.of(context);
    return ListTile(
      key: ValueKey('link-${link.id}'),
      leading: const Icon(Icons.link),
      title: Text(link.label),
      subtitle: link.label == link.url ? null : Text(link.url, maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: () async {
        if (!await context.read<AppServices>().files.openLink(link.url) && context.mounted) {
          showMessage(context, l.insuranceLinkCannotOpen);
        }
      },
      trailing: PopupMenuButton<String>(
        key: ValueKey('linkMenu-${link.id}'),
        onSelected: (action) => action == 'edit'
            ? _editLink(context, link)
            : applyToLedger(context, (ledger) => ledger.deleteInsuranceLink(link.id)),
        itemBuilder: (_) => [
          PopupMenuItem(value: 'edit', child: Text(l.insuranceLinkEdit)),
          PopupMenuItem(value: 'delete', child: Text(l.insuranceLinkDelete)),
        ],
      ),
    );
  }

  Future<void> _deleteTranche(BuildContext context) async {
    final l = AppLocalizations.of(context);
    if (!await _confirm(context, l.insuranceTrancheDeleteConfirm) || !context.mounted) return;
    await applyToLedger(context, (ledger) => ledger.deleteInsuranceTranche(tranche.id));
  }

  Future<void> _editNote(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final note = await _textDialog(
      context,
      title: l.insuranceNoteEdit,
      label: l.insuranceNote,
      initial: tranche.note,
      lines: 5,
    );
    if (note == null || !context.mounted) return;
    await applyToLedger(
      context,
      (ledger) => ledger.updateInsuranceTranche(
        tranche.id,
        InsuranceTrancheDraft(start: tranche.start, end: tranche.end, note: note),
      ),
    );
  }

  /// Picks a file, sends it to the server and keeps its copy, then writes
  /// what describes it.
  Future<void> _addDocument(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final services = context.read<AppServices>();
    final picked = await services.files.pickDocument();
    if (picked == null || !context.mounted) return;
    final dot = picked.name.lastIndexOf('.');
    final described = await showDialog<(InsuranceDocumentKind, String)>(
      context: context,
      builder: (_) => _DocumentDialog(
        kind: InsuranceDocumentKind.contract,
        name: dot > 0 ? picked.name.substring(0, dot) : picked.name,
      ),
    );
    if (described == null || !context.mounted) return;
    showMessage(context, l.insuranceDocumentAdding);
    final String fingerprint;
    try {
      fingerprint = await services.documents.add(picked.bytes);
    } on DocumentException catch (e) {
      if (context.mounted) showMessage(context, documentErrorText(l, e.error));
      return;
    }
    if (!context.mounted) return;
    final saved = await applyToLedger(
      context,
      (ledger) => ledger.addInsuranceDocument(
        tranche.id,
        newId(),
        InsuranceDocumentDraft(
          kind: described.$1,
          name: described.$2,
          fingerprint: fingerprint,
          size: picked.bytes.length,
          mediaType: mediaTypeOf(picked.name),
        ),
      ),
    );
    if (saved && context.mounted) showMessage(context, l.insuranceDocumentAdded);
  }

  Future<void> _open(BuildContext context, InsuranceDocument d) async {
    final l = AppLocalizations.of(context);
    final services = context.read<AppServices>();
    try {
      final bytes = await services.documents.read(d.fingerprint);
      if (!await services.files.openDocument(_fileName(d), bytes) && context.mounted) {
        showMessage(context, l.insuranceDocumentCannotOpen);
      }
    } on DocumentException catch (e) {
      if (context.mounted) showMessage(context, documentErrorText(l, e.error));
    }
  }

  Future<void> _save(BuildContext context, InsuranceDocument d) async {
    final l = AppLocalizations.of(context);
    final services = context.read<AppServices>();
    try {
      final bytes = await services.documents.read(d.fingerprint);
      if (await services.files.saveDocument(_fileName(d), bytes) && context.mounted) {
        showMessage(context, l.insuranceDocumentSaved);
      }
    } on DocumentException catch (e) {
      if (context.mounted) showMessage(context, documentErrorText(l, e.error));
    }
  }

  Future<void> _editDocument(BuildContext context, InsuranceDocument d) async {
    final described = await showDialog<(InsuranceDocumentKind, String)>(
      context: context,
      builder: (_) => _DocumentDialog(kind: d.kind, name: d.name),
    );
    if (described == null || !context.mounted) return;
    await applyToLedger(
      context,
      (ledger) => ledger.updateInsuranceDocument(d.id, kind: described.$1, name: described.$2),
    );
  }

  Future<void> _deleteDocument(BuildContext context, InsuranceDocument d) async {
    final l = AppLocalizations.of(context);
    if (!await _confirm(context, l.insuranceDocumentDeleteConfirm(d.name)) || !context.mounted) return;
    await applyToLedger(context, (ledger) => ledger.deleteInsuranceDocument(d.id));
  }

  Future<void> _editLink(BuildContext context, InsuranceLink? link) async {
    final entered = await showDialog<(String, String)>(
      context: context,
      builder: (_) => _LinkDialog(link: link),
    );
    if (entered == null || !context.mounted) return;
    await applyToLedger(
      context,
      (ledger) => link == null
          ? ledger.addInsuranceLink(tranche.id, newId(), label: entered.$1, url: entered.$2)
          : ledger.updateInsuranceLink(link.id, label: entered.$1, url: entered.$2),
    );
  }

  static String _kind(AppLocalizations l, InsuranceDocumentKind kind) => switch (kind) {
    InsuranceDocumentKind.contract => l.insuranceDocumentContract,
    InsuranceDocumentKind.policy => l.insuranceDocumentPolicy,
    InsuranceDocumentKind.other => l.insuranceDocumentOther,
  };

  static String _size(int bytes) =>
      bytes < 1024 * 1024 ? '${(bytes / 1024).ceil()} Ko' : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} Mo';

  /// The name of the file of [d], with the extension of its type.
  static String _fileName(InsuranceDocument d) => switch (d.mediaType) {
    'application/pdf' => '${d.name}.pdf',
    'image/jpeg' => '${d.name}.jpg',
    'image/png' => '${d.name}.png',
    _ => d.name,
  };
}

/// The kind and the name of a document.
class _DocumentDialog extends StatefulWidget {
  const _DocumentDialog({required this.kind, required this.name});

  final InsuranceDocumentKind kind;
  final String name;

  @override
  State<_DocumentDialog> createState() => _DocumentDialogState();
}

class _DocumentDialogState extends State<_DocumentDialog> {
  late var _kind = widget.kind;
  late final _name = TextEditingController(text: widget.name);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.insuranceDocuments),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedButton<InsuranceDocumentKind>(
            key: const Key('documentKind'),
            segments: [
              ButtonSegment(value: InsuranceDocumentKind.contract, label: Text(l.insuranceDocumentContract)),
              ButtonSegment(value: InsuranceDocumentKind.policy, label: Text(l.insuranceDocumentPolicy)),
              ButtonSegment(value: InsuranceDocumentKind.other, label: Text(l.insuranceDocumentOther)),
            ],
            selected: {_kind},
            onSelectionChanged: (s) => setState(() => _kind = s.single),
          ),
          TextField(
            key: const Key('documentName'),
            controller: _name,
            decoration: InputDecoration(labelText: l.insuranceDocumentName),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l.cancel)),
        FilledButton(
          key: const Key('documentSave'),
          onPressed: () => Navigator.of(context).pop((_kind, _name.text)),
          child: Text(l.save),
        ),
      ],
    );
  }
}

/// The label and the address of a link.
class _LinkDialog extends StatefulWidget {
  const _LinkDialog({required this.link});

  final InsuranceLink? link;

  @override
  State<_LinkDialog> createState() => _LinkDialogState();
}

class _LinkDialogState extends State<_LinkDialog> {
  late final _label = TextEditingController(
    text: widget.link == null || widget.link!.label == widget.link!.url ? '' : widget.link!.label,
  );
  late final _url = TextEditingController(text: widget.link?.url ?? 'https://');

  @override
  void dispose() {
    _label.dispose();
    _url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.link == null ? l.insuranceLinkAdd : l.insuranceLinkEdit),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const Key('linkLabel'),
            controller: _label,
            decoration: InputDecoration(labelText: l.insuranceLinkLabel),
          ),
          TextField(
            key: const Key('linkUrl'),
            controller: _url,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(labelText: l.insuranceLinkUrl),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l.cancel)),
        FilledButton(
          key: const Key('linkSave'),
          onPressed: () => Navigator.of(context).pop((_label.text, _url.text)),
          child: Text(l.save),
        ),
      ],
    );
  }
}

Future<bool> _confirm(BuildContext context, String text) async {
  final l = AppLocalizations.of(context);
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          content: Text(text),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l.cancel)),
            TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l.delete)),
          ],
        ),
      ) ??
      false;
}

/// A text to enter; null when cancelled.
Future<String?> _textDialog(
  BuildContext context, {
  required String title,
  required String label,
  required String initial,
  int lines = 1,
}) => showDialog<String>(
  context: context,
  builder: (_) => _TextDialog(title: title, label: label, initial: initial, lines: lines),
);

class _TextDialog extends StatefulWidget {
  const _TextDialog({required this.title, required this.label, required this.initial, required this.lines});

  final String title;
  final String label;
  final String initial;
  final int lines;

  @override
  State<_TextDialog> createState() => _TextDialogState();
}

class _TextDialogState extends State<_TextDialog> {
  late final _text = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        key: const Key('textDialogField'),
        controller: _text,
        autofocus: true,
        minLines: widget.lines,
        maxLines: widget.lines,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(labelText: widget.label),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l.cancel)),
        FilledButton(
          key: const Key('textDialogSave'),
          onPressed: () => Navigator.of(context).pop(_text.text),
          child: Text(l.save),
        ),
      ],
    );
  }
}
