/// The ZIP of an export: the eighteen CSV files and a `LISEZMOI.txt`, built
/// in memory and handed to the save dialog. Nothing is written anywhere else,
/// and nothing to the journal.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../calendar_date.dart';
import '../ledger/ledger.dart';
import 'ledger_export.dart';

/// The name of the file that explains the export.
const readmeFileName = 'LISEZMOI.txt';

/// `batz-export-2026-11-21.zip`.
String exportFileName(CalendarDate date) => 'batz-export-${date.encode()}.zip';

/// An export ready to be saved.
class ExportArchive {
  const ExportArchive({
    required this.fileName,
    required this.bytes,
    required this.csvFiles,
    required this.transactions,
  });

  final String fileName;
  final Uint8List bytes;

  /// The number of CSV files, `LISEZMOI.txt` aside.
  final int csvFiles;

  /// The number of transactions exported: the number the app holds.
  final int transactions;
}

/// The export of [ledger] made on [date] by the app of [appVersion].
ExportArchive buildExportArchive(Ledger ledger, {required CalendarDate date, required String appVersion}) {
  final files = exportFiles(ledger);
  final archive = Archive();
  for (final file in files) {
    archive.addFile(ArchiveFile.bytes(file.name, file.bytes));
  }
  final readme = exportReadme(files, date: date, appVersion: appVersion, transactions: ledger.transactions.length);
  archive.addFile(ArchiveFile.bytes(readmeFileName, readme));
  return ExportArchive(
    fileName: exportFileName(date),
    bytes: ZipEncoder().encodeBytes(archive),
    csvFiles: files.length,
    transactions: ledger.transactions.length,
  );
}

/// The text of `LISEZMOI.txt`: UTF-8 with a byte order mark and CR LF, so
/// that the Notepad of Windows reads it as well as any other editor.
Uint8List exportReadme(
  List<ExportFile> files, {
  required CalendarDate date,
  required String appVersion,
  required int transactions,
}) {
  final width = files.map((f) => f.name.length).reduce((a, b) => a > b ? a : b);
  final lines = [
    'Export de batz',
    '==============',
    '',
    "Date de l'export : ${date.encode()}",
    "Version de l'app : $appVersion",
    'Transactions : $transactions',
    '',
    'Tout ce qui a été saisi ou importé sur cet appareil, dans son état du jour.',
    "Ce fichier n'est pas chiffré : quiconque l'ouvre lit ces données. Gardez-le en lieu sûr.",
    '',
    'Fichiers, avec leur nombre de lignes (la ligne des en-têtes non comptée) :',
    '',
    for (final f in files) '  ${f.name.padRight(width)}  ${f.rows.length}',
    '  ${readmeFileName.padRight(width)}  ce fichier',
    '',
    "Ce qui n'est pas exporté : ce que l'app calcule (la vue annuelle, la fortune, la",
    "courbe, le diagramme de flux), l'historique des modifications, ce qui a été",
    "supprimé, les relevés PDF d'origine (ils restent sur le serveur) et",
    "l'association au serveur.",
    '',
    'Format des fichiers CSV',
    '-----------------------',
    '',
    "- UTF-8 avec marque d'ordre des octets, séparateur point-virgule, fins de ligne",
    '  CR LF. La première ligne porte les en-têtes.',
    '- Une valeur qui contient un point-virgule, un guillemet ou un retour à la ligne',
    '  est entre guillemets ; un guillemet y est doublé.',
    '- Montants en francs, avec un point décimal et sans séparateur de milliers :',
    "  1234.50, -85.00. Un montant est négatif quand l'argent sort du compte.",
    "- Pourcentages : 50.00. Taux de base d'un impôt : 2.5000. kWh : 1900.5.",
    '- Dates : 2026-12-31. Oui ou non : oui, non. Valeur absente : vide.',
    '- Un texte qui commence par =, +, - ou @ est précédé d\'une apostrophe, pour',
    "  qu'un tableur ne le prenne pas pour une formule.",
    '- Les colonnes id… placées à la fin de chaque fichier relient les fichiers',
    '  entre eux : idCompte renvoie à la colonne id de comptes.csv, et ainsi de',
    '  suite.',
    '',
    'Ouvrir un fichier dans Excel',
    '----------------------------',
    '',
    'Données > À partir d\'un fichier texte/CSV, puis : origine « 65001 : Unicode',
    '(UTF-8) », délimiteur « Point-virgule ». Si les montants restent du texte,',
    'choisir « Transformer les données » et indiquer, pour leurs colonnes, le type',
    '« Nombre décimal » avec les paramètres régionaux « Anglais (États-Unis) ».',
    '',
    'La description complète de chaque fichier et de ses colonnes est dans',
    'docs/features.md (section « Export »), dans le dépôt de batz.',
  ];
  return Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode('${lines.join('\r\n')}\r\n')]);
}
