import '../../domain/ledger/category.dart';
import '../../helpers/formats.dart';
import '../../l10n/app_localizations.dart';

/// An amount as the « Année » screen shows it (decision H7): an expense as a
/// cost, without a minus sign, which a refund diminishes; an income, or an
/// amount without nature (« Non classé »), as it was paid.
int shownCents(int cents, CategoryNature? nature) => nature == CategoryNature.expense ? -cents : cents;

String shownAmount(int cents, CategoryNature? nature) => formatAmount(shownCents(cents, nature));

/// The short name of [month], from 1 to 12.
String monthName(AppLocalizations l, int month) => l.yearMonths.split(',')[month - 1];
