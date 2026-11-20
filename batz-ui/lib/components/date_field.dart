import 'package:flutter/material.dart';

import '../domain/calendar_date.dart';
import '../helpers/formats.dart';
import '../l10n/app_localizations.dart';

/// A date typed as `31.12.2026`, or picked from a calendar.
class DateField extends StatelessWidget {
  const DateField({super.key, required this.controller, required this.label, this.onChanged, this.fieldKey});

  final TextEditingController controller;
  final String label;
  final VoidCallback? onChanged;

  /// Key of the text field itself.
  final Key? fieldKey;

  /// The date in [controller], or null if it is not a valid date.
  static CalendarDate? read(TextEditingController controller) {
    final parsed = parseDate(controller.text);
    return parsed == null ? null : CalendarDate.of(parsed);
  }

  static String text(CalendarDate date) => formatDate(date.toDateTime());

  Future<void> _pick(BuildContext context) async {
    final current = read(controller) ?? CalendarDate.today();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(current.year, current.month, current.day),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked == null) return;
    controller.text = text(CalendarDate.of(picked));
    onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: fieldKey,
      controller: controller,
      keyboardType: TextInputType.datetime,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: IconButton(
          tooltip: AppLocalizations.of(context).pickDate,
          icon: const Icon(Icons.calendar_today_outlined),
          onPressed: () => _pick(context),
        ),
      ),
      onChanged: (_) => onChanged?.call(),
    );
  }
}
