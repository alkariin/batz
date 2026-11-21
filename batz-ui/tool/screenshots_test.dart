// Makes the screenshots of the README from invented data. From `batz-ui/`:
//
//     flutter test tool/screenshots_test.dart
//
// writes `docs/images/annee.png`, `fortune.png`, `flux.png` and
// `validation.png`: the app at the size of a phone, with the fonts of the
// Flutter SDK. It is not part of `flutter test`, which runs `test/` only.
//
// The year shown is invented: a salary, a rent, groceries, taxes paid by
// instalments, a trip, two accounts of savings. The validation screen shows
// the fictitious January statement of the server's test set.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:batz/app.dart';
import 'package:batz/domain/calendar_date.dart';
import 'package:batz/domain/ids.dart';
import 'package:batz/domain/journal/journal_entry.dart';
import 'package:batz/domain/ledger/account.dart';
import 'package:batz/domain/ledger/balance.dart';
import 'package:batz/domain/ledger/category.dart';
import 'package:batz/domain/ledger/ledger.dart';
import 'package:batz/domain/ledger/rule.dart';
import 'package:batz/domain/ledger/transaction.dart';
import 'package:batz/domain/modules/salary.dart';
import 'package:batz/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/support/services.dart';
import '../test/support/statements.dart';

const _images = '../docs/images';
const _phone = Size(400, 860);
const _pixelRatio = 2.0;
const _shot = Key('screenshot');
final _today = CalendarDate(2026, 12, 31);

CalendarDate _d(int month, int day, [int year = 2026]) => CalendarDate(year, month, day);

/// Roboto and the Material icons, from the Flutter SDK that runs the test.
Future<void> _loadFonts() async {
  final fonts = '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts';
  Future<ByteData> font(String name) async => ByteData.sublistView(await File('$fonts/$name').readAsBytes());
  final roboto = FontLoader('Roboto');
  for (final name in ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf', 'Roboto-Light.ttf']) {
    roboto.addFont(font(name));
  }
  await roboto.load();
  await (FontLoader('MaterialIcons')..addFont(font('MaterialIcons-Regular.otf'))).load();
}

Future<void> _write(AppServices services, Modification Function(Ledger l) build) async =>
    services.ledger.write(build(await services.ledger.load()));

/// The invented year 2026: 84'000.00 of income, 47'285.00 of expenses.
Future<void> _year(AppServices services) async {
  Future<void> write(Modification Function(Ledger l) build) => _write(services, build);

  await write(
    (l) => l.createAccount('private', const AccountDraft(name: 'Compte privé', type: AccountType.privateAccount)),
  );
  await write((l) => l.createAccount('savings', const AccountDraft(name: 'Épargne', type: AccountType.savings)));
  await write((l) => l.createAccount('pillar', const AccountDraft(name: '3e pilier', type: AccountType.pillar3)));
  await write((l) => l.createTree(2026));
  final income = defaultGroupId(2026, CategoryNature.income);
  await write((l) => l.addCategory('salary', year: 2026, name: 'Salaire', parentId: income));
  await write((l) => l.addCategory('interest', year: 2026, name: 'Intérêts', parentId: income));
  const groups = {
    'housing': ('Logement', {'rent': 'Loyer', 'power': 'Électricité'}),
    'daily': ('Quotidien', {'groceries': 'Courses', 'restaurant': 'Restaurant', 'transport': 'Transports'}),
    'leisure': ('Loisirs', {'trips': 'Vacances', 'outings': 'Sorties'}),
    'duties': ('Obligations', {'taxes': 'Impôts', 'insurance': 'Assurances'}),
  };
  for (final MapEntry(key: id, value: (name, categories)) in groups.entries) {
    await write((l) => l.addCategory(id, year: 2026, name: name, nature: CategoryNature.expense));
    for (final MapEntry(key: categoryId, value: categoryName) in categories.entries) {
      await write((l) => l.addCategory(categoryId, year: 2026, name: categoryName, parentId: id));
    }
  }

  // The tree starts with one group of expenses: the year has its own four.
  await write((l) => l.removeCategory(defaultGroupId(2026, CategoryNature.expense)));

  var entries = 0;
  Future<void> entry(
    String category,
    CalendarDate date,
    int cents,
    String description, {
    String account = 'private',
    Direction direction = Direction.outflow,
    CalendarDate? from,
    CalendarDate? to,
  }) {
    final id = 'entry-${entries++}';
    return write(
      (l) => l.recordEntry(
        id,
        '$id-line',
        EntryDraft(
          accountId: account,
          date: date,
          cents: cents,
          direction: direction,
          categoryId: category,
          description: description,
          periodStart: from,
          periodEnd: to,
        ),
      ),
    );
  }

  const groceries = [61250, 58940, 66310, 63475, 60820, 67990, 52260, 64105, 65730, 62385, 68845, 75890];
  for (var month = 1; month <= 12; month++) {
    await entry('salary', _d(month, 25), 698800, 'Salaire', direction: Direction.inflow);
    await entry('rent', _d(month, 1), 165000, 'Loyer');
    await entry('groceries', _d(month, 15), groceries[month - 1], 'Courses du mois');
    await entry('restaurant', _d(month, 20), 12000, 'Restaurant');
    await entry('transport', _d(month, 3), 7500, 'Abonnement de transport');
    await entry('outings', _d(month, 12), 9000, 'Cinéma et sorties');
    if (month <= 10) await entry('taxes', _d(month, 10), 120000, 'Acompte d\'impôts');
    await write(
      (l) => l.recordTransfer(
        'saving-$month',
        TransferDraft(
          fromAccountId: 'private',
          toAccountId: 'savings',
          date: _d(month, 28),
          cents: 150000,
          description: 'Épargne du mois',
        ),
      ),
    );
  }
  await entry('insurance', _d(1, 5), 144000, 'Assurance ménage', from: _d(1, 1), to: _d(12, 31));
  await entry('power', _d(5, 15), 48000, 'Électricité', from: _d(1, 1), to: _d(4, 30));
  await entry('power', _d(11, 15), 54000, 'Électricité', from: _d(5, 1), to: _d(10, 31));
  await entry('trips', _d(3, 12), 64000, 'Billets d\'avion', from: _d(7, 10), to: _d(7, 24));
  await entry('trips', _d(7, 11), 120000, 'Hôtel');
  await entry('trips', _d(7, 20), 8500, 'Restaurant de vacances');
  await entry('interest', _d(12, 31), 14400, 'Intérêts', account: 'savings', direction: Direction.inflow);
  await write(
    (l) => l.recordTransfer(
      'pillar-2026',
      TransferDraft(
        fromAccountId: 'private',
        toAccountId: 'pillar',
        date: _d(1, 15),
        cents: 705600,
        description: 'Versement 3e pilier',
      ),
    ),
  );

  // Balances declared at the end of 2025, in the middle and at the end of
  // 2026; the third pillar gained 1'124.00 in value.
  for (final (account, date, cents) in [
    ('private', _d(12, 31, 2025), 420000),
    ('savings', _d(12, 31, 2025), 2400000),
    ('pillar', _d(12, 31, 2025), 2130000),
    ('savings', _d(6, 30), 3300000),
    ('private', _d(12, 31), 1571500),
    ('savings', _d(12, 31), 4214400),
    ('pillar', _d(12, 31), 2948000),
  ]) {
    await write((l) => l.declareBalance(account, date, cents, today: _today));
  }

  await write(
    (l) => l.saveSalarySheet(
      const SalarySheetDraft(
        year: 2026,
        gross: 9600000,
        net: 8385600,
        deductions: [
          DeductionDraft(label: 'AVS', amount: 508800),
          DeductionDraft(label: 'AC', amount: 105600),
          DeductionDraft(label: 'LPP', amount: 600000),
        ],
      ),
      newId: newId,
    ),
  );
}

/// The fictitious January statement of the test set, imported, with rules
/// that propose a classification for part of its lines.
Future<void> _statement(AppServices services) async {
  Future<void> write(Modification Function(Ledger l) build) => _write(services, build);
  final january = fixtureStatement('2026-01');

  await write(
    (l) => l.createAccount(
      'bank',
      const AccountDraft(
        name: 'Compte privé',
        type: AccountType.privateAccount,
        importFormat: ImportFormat.postfinance,
      ),
    ),
  );
  await write((l) => l.createAccount('savings', const AccountDraft(name: 'Épargne', type: AccountType.savings)));
  await write((l) => l.createTree(2026));
  final income = defaultGroupId(2026, CategoryNature.income), expenses = defaultGroupId(2026, CategoryNature.expense);
  await write((l) => l.addCategory('salary', year: 2026, name: 'Salaire', parentId: income));
  for (final (id, name) in [('rent', 'Loyer'), ('groceries', 'Courses'), ('insurance', 'Assurances')]) {
    await write((l) => l.addCategory(id, year: 2026, name: name, parentId: expenses));
  }
  for (final (id, keyword, category) in [
    ('r-groceries', 'épicerie du coin', 'groceries'),
    ('r-bakery', 'boulangerie des tests', 'groceries'),
    ('r-rent', 'gérance imaginaire', 'rent'),
    ('r-salary', 'employeur fictif', 'salary'),
    ('r-insurance', 'assurance fictive', 'insurance'),
  ]) {
    await write((l) => l.createRule(id, RuleDraft(year: 2026, keywords: [keyword], targetCategoryId: category)));
  }
  await write(
    (l) => l.createRule(
      'r-savings',
      const RuleDraft(year: 2026, keywords: ['compte épargne'], targetAccountId: 'savings'),
    ),
  );
  await write((l) => l.importStatement('bank', january.statement, fingerprint: january.fingerprint).modification);
}

/// Lets database work complete, then redraws.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pumpAndSettle();
  }
}

Future<void> _open(WidgetTester tester, Future<void> Function(AppServices services) data, CalendarDate today) async {
  tester.view.physicalSize = _phone * _pixelRatio;
  tester.view.devicePixelRatio = _pixelRatio;
  addTearDown(tester.view.reset);
  await tester.runAsync(_loadFonts);
  final services = (await tester.runAsync(() => testServices(today: () => today)))!;
  addTearDown(() => tester.runAsync(services.database.close));
  await tester.runAsync(() => data(services));
  await tester.pumpWidget(
    RepaintBoundary(
      key: _shot,
      child: BatzApp(services: services),
    ),
  );
  await _settle(tester);
}

Future<void> _save(WidgetTester tester, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(_shot));
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: _pixelRatio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  });
  File('$_images/$name.png')
    ..parent.createSync(recursive: true)
    ..writeAsBytesSync(bytes!);
}

Future<void> _section(WidgetTester tester, String label) async {
  await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text(label)));
  await _settle(tester);
}

/// Shadows are replaced by black outlines in tests: draw the real ones for
/// the pictures, and put the setting back, as the test binding checks it.
Future<void> _withShadows(Future<void> Function() body) async {
  debugDisableShadows = false;
  try {
    await body();
  } finally {
    debugDisableShadows = true;
  }
}

void main() {
  testWidgets('the year, the wealth and the flow diagram of an invented year', (tester) async {
    await _withShadows(() async {
      await _open(tester, _year, _today);

      await _section(tester, 'Année');
      await _save(tester, 'annee');

      await tester.tap(find.byKey(const Key('yearFlow')));
      await _settle(tester);
      await _save(tester, 'flux');
      await tester.tap(find.byType(BackButton));
      await _settle(tester);

      await _section(tester, 'Fortune');
      await _save(tester, 'fortune');
    });
  });

  testWidgets('the validation of a fictitious statement', (tester) async {
    await _withShadows(() async {
      await _open(tester, _statement, CalendarDate(2026, 2, 2));

      await tester.tap(find.byKey(const Key('taskLinesToValidate')));
      await _settle(tester);
      await tester.tap(find.byKey(const Key('tabProposed')));
      await _settle(tester);
      await _save(tester, 'validation');
    });
  });
}
