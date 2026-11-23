import 'package:batz/domain/calendar_date.dart';
import 'package:batz/domain/journal/journal_entry.dart';
import 'package:batz/domain/ledger/account.dart';
import 'package:batz/domain/ledger/category.dart';
import 'package:batz/domain/ledger/ledger.dart';
import 'package:batz/domain/ledger/ledger_exception.dart';
import 'package:batz/domain/ledger/proposal.dart';
import 'package:batz/domain/ledger/rule.dart';
import 'package:batz/domain/ledger/statement.dart';
import 'package:batz/domain/ledger/transaction.dart';
import 'package:batz/domain/views/year_view.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/ledger_fixture.dart';
import '../../support/ledger_harness.dart';
import '../../support/statements.dart';

final january = fixtureStatement('2026-01');

RuleDraft rule(List<String> lines, {String? category, String? account}) =>
    RuleDraft(year: 2026, lines: lines, targetCategoryId: category, targetAccountId: account);

LedgerError? refusal(void Function() build) {
  try {
    build();
  } on LedgerException catch (e) {
    return e.error;
  }
  return null;
}

void main() {
  late LedgerHarness h;
  late String statement;

  /// The lines of January whose raw text contains [text].
  Future<List<LedgerTransaction>> linesWith(String text) async {
    final ledger = await h.ledger();
    return [
      for (final t in ledger.linesOf(statement))
        if (t.rawText!.contains(text)) t,
    ];
  }

  Future<RuleOutcome> outcomeOfFirst(String text) async {
    final line = (await linesWith(text)).first;
    return (await h.ledger()).proposals[line.id]!;
  }

  setUp(() async {
    h = await LedgerHarness.open();
    await seedLedger(h);
    await h.apply(
      (l) => l.addCategory('car', year: 2026, name: 'Voiture', parentId: defaultGroupId(2026, CategoryNature.expense)),
    );
    await h.apply((l) => l.createAccount('savings', const AccountDraft(name: 'Épargne', type: AccountType.savings)));
    final import = (await h.ledger()).importStatement('bank', january.statement, fingerprint: january.fingerprint);
    await h.repository.write(import.modification);
    statement = import.statementId;
  });
  tearDown(() => h.close());

  group('lines', () {
    test('one line found is enough; the terms of a line joined by ET are all required, anywhere', () async {
      await h.apply((l) => l.createRule('r1', rule(['épicerie ET boulangerie'], category: 'food')));
      expect(await outcomeOfFirst('Épicerie du Coin'), const NoRule());
      await h.apply((l) => l.updateRule('r1', rule(['coin ET épicerie'], category: 'food')));
      expect(await outcomeOfFirst('Épicerie du Coin'), isA<Proposed>(), reason: 'in any order, not side by side');
      await h.apply((l) => l.updateRule('r1', rule(['boulangerie', 'épicerie du coin'], category: 'food')));
      expect(await outcomeOfFirst('Épicerie du Coin'), isA<Proposed>(), reason: 'lines are alternatives');
      await h.apply((l) => l.updateRule('r1', rule(['épicerie coin'], category: 'food')));
      expect(await outcomeOfFirst('Épicerie du Coin'), const NoRule(), reason: 'without ET, the words follow');
    });

    test('ET joins terms only in capitals, between spaces: « et » is a word of the text', () {
      final line = RuleLine('Bar et Café ET re:\\d+ET');
      expect(line.terms.map((t) => t.text), ['Bar et Café', r're:\d+ET']);
      expect(line.matches(normalizeText('BAR ET CAFE 12et')), isTrue);
      expect(RuleLine(' ET coin').terms.map((t) => t.text), ['ET coin'], reason: 'nothing before it: a word');
      expect(isValidRuleLine('coin ET  ET '), isTrue, reason: 'empty terms are left out');
      expect(isValidRuleLine('  '), isFalse);
    });

    test('a rule written as keywords, before lines existed, reads as one line of required terms', () async {
      expect(legacyRuleLine(['gérance', ' bail ', '']), 'gérance ET bail');
      await h.repository.write(
        Modification.set(RuleFields.entity, 'old', {
          RuleFields.year: 2026,
          RuleFields.keywords: encodeRuleLines(['épicerie', 'boulangerie']),
          RuleFields.targetCategoryId: 'food',
        }),
      );
      var ledger = await h.ledger();
      expect(ledger.rules['old']!.lines, ['épicerie ET boulangerie']);
      expect(await outcomeOfFirst('Épicerie du Coin'), const NoRule(), reason: 'still all required');

      // Modified, it is written as lines and its keywords are cleared.
      await h.apply((l) => l.updateRule('old', rule(['épicerie', 'boulangerie'], category: 'food')));
      ledger = await h.ledger();
      expect(ledger.rules['old']!.lines, ['épicerie', 'boulangerie']);
      expect((await h.tables(['rules']))['rules']!.single['keywords'], isNull);
      expect(await outcomeOfFirst('Épicerie du Coin'), isA<Proposed>());
    });

    test('deleting a category deletes the rules that classify in it', () async {
      await h.apply((l) => l.createRule('food', rule(['épicerie'], category: 'food')));
      await h.apply((l) => l.createRule('car', rule(['station'], category: 'car')));
      await h.apply((l) => l.removeCategory('car'));
      expect((await h.ledger()).rules.keys, ['food']);
    });

    test('without regard to case, accents and repeated spaces, across the lines of the text', () async {
      await h.apply((l) => l.createRule('r1', rule(['EPICERIE   du coin fictiville'], category: 'food')));
      final outcome = await outcomeOfFirst('Épicerie du Coin');
      expect(outcome, isA<Proposed>().having((p) => p.classification.categoryId, 'category', 'food'));
    });

    test('a keyword may be a regular expression, refused when written invalid', () async {
      await h.apply(
        (l) => l.createRule('r1', rule([r're:^achat/service du \d{2}\.01\.2026 .* epicerie'], category: 'food')),
      );
      expect((await linesWith('Épicerie du Coin')).length, greaterThan(3));
      final ledger = await h.ledger();
      for (final line in await linesWith('Épicerie du Coin')) {
        expect(ledger.proposals[line.id], isA<Proposed>(), reason: line.rawText);
      }
      expect(isValidRuleLine('re:(unclosed'), isFalse);
      expect(isValidRuleLine('re:'), isFalse);
      expect(isValidRuleLine('(plain text is never an expression'), isTrue);
      expect(
        refusal(() => ledger.createRule('r2', rule(['re:[a-', 'coin'], category: 'food'))),
        LedgerError.ruleKeywordInvalid,
      );
      expect(
        refusal(() => ledger.createRule('r2', rule(['coin ET re:[a-'], category: 'food'))),
        LedgerError.ruleKeywordInvalid,
      );
    });

    test('a regular expression keeps its escapes: \\S is not \\s', () {
      final keyword = Keyword(r're:carte no \S+0000');
      expect(keyword.matches(normalizeText('ACHAT/SERVICE DU 05.01.2026\nCARTE NO XXXX0000\nÉpicerie')), isTrue);
      expect(Keyword(r're:carte no \S+ 0000').matches(normalizeText('CARTE NO XXXX0000')), isFalse);
      expect(Keyword('re:ÉPICERIE').matches(normalizeText('Épicerie')), isTrue, reason: 'accents ignored there too');
    });

    test('a rule reads the raw text, never the description', () async {
      final line = (await linesWith('Épicerie du Coin')).first;
      await h.apply((l) => l.updateImportedDetails(line.id, description: 'Courses de la semaine', note: ''));
      await h.apply((l) => l.createRule('r1', rule(['courses'], category: 'food')));
      expect((await h.ledger()).proposals[line.id], const NoRule(), reason: 'the description is not read');
      await h.apply((l) => l.updateRule('r1', rule(['carte no xxxx0000 ET coin'], category: 'food')));
      expect((await h.ledger()).proposals[line.id], isA<Proposed>(), reason: 'generic lines of the raw text are read');
    });

    test('at least one line; the same term twice in a line counts once', () async {
      final ledger = await h.ledger();
      expect(
        refusal(() => ledger.createRule('r1', rule(['  ', ''], category: 'food'))),
        LedgerError.ruleKeywordsRequired,
      );
      expect(
        MappingRule(
          id: 'x',
          year: 2026,
          lines: ['Coin ET COIN ET  coin '],
          targetCategoryId: 'food',
        ).weightFor(normalizeText('coin')),
        1,
      );
    });
  });

  group('priority', () {
    test('the rule whose matching line has the most terms wins', () async {
      await h.apply((l) => l.createRule('one', rule(['épicerie', 'coin ET station ET service'], category: 'food')));
      await h.apply((l) => l.createRule('two', rule(['épicerie ET coin'], category: 'car')));
      final outcome = await outcomeOfFirst('Épicerie du Coin');
      expect(outcome, isA<Proposed>().having((p) => p.rule.id, 'rule', 'two'));
      expect((outcome as Proposed).classification.categoryId, 'car');
    });

    test('a tie of different results is reported, with the rules in competition', () async {
      await h.apply((l) => l.createRule('b', rule(['épicerie'], category: 'food')));
      await h.apply((l) => l.createRule('a', rule(['coin'], category: 'car')));
      final outcome = await outcomeOfFirst('Épicerie du Coin');
      expect(outcome, isA<Conflict>().having((c) => c.rules.map((r) => r.id), 'rules', ['a', 'b']));
      final ledger = await h.ledger();
      final line = (await linesWith('Épicerie du Coin')).first;
      expect(ledger.validationStateOf(line), ValidationState.toComplete);
    });

    test('a tie of the same target is no conflict', () async {
      await h.apply((l) => l.createRule('b', rule(['épicerie'], category: 'food')));
      await h.apply((l) => l.createRule('a', rule(['coin'], category: 'food')));
      expect(await outcomeOfFirst('Épicerie du Coin'), isA<Proposed>().having((p) => p.rule.id, 'rule', 'a'));
    });
  });

  group('proposals', () {
    test('a proposal is for the payment date', () async {
      await h.apply((l) => l.createRule('rent', rule(['gérance'], category: 'rent')));
      final line = (await linesWith('Gérance')).single;
      final p = (await h.ledger()).proposals[line.id]! as Proposed;
      expect(line.date, CalendarDate(2026, 1, 5));
      expect((p.classification.periodStart, p.classification.periodEnd), (line.date, line.date));
    });

    test(
      'a rule created during the validation classifies the other lines at once; validated lines do not change',
      () async {
        final lines = await linesWith('Épicerie du Coin');
        expect(lines, hasLength(5));
        // The first one is validated in another category.
        await h.apply(
          (l) => l.classify(
            lines.first.id,
            Classification.category('car', periodStart: lines.first.date, periodEnd: lines.first.date),
          ),
        );
        final before = await h.journal.entries();
        await h.apply((l) => l.createRule('food', rule(['épicerie du coin'], category: 'food')));
        final written = (await h.journal.entries()).skip(before.length).toList();
        expect(written.map((e) => e.entity).toSet(), {RuleFields.entity}, reason: 'only the rule is written');

        final ledger = await h.ledger();
        for (final line in lines.skip(1)) {
          expect(ledger.validationStateOf(ledger.transactions[line.id]!), ValidationState.proposed);
          expect(ledger.categoryOf(ledger.transactions[line.id]!)?.id, 'food');
        }
        final validated = ledger.transactions[lines.first.id]!;
        expect(ledger.validationStateOf(validated), ValidationState.validated);
        expect(ledger.categoryOf(validated)?.id, 'car');

        // Modified or deleted, the rule takes the lines to validate along.
        await h.apply((l) => l.updateRule('food', rule(['épicerie du coin'], category: 'rent')));
        expect((await h.ledger()).categoryOf((await h.ledger()).transactions[lines[1].id]!)?.id, 'rent');
        await h.apply((l) => l.deleteRule('food'));
        final after = await h.ledger();
        expect(after.validationStateOf(after.transactions[lines[1].id]!), ValidationState.toComplete);
        expect(after.categoryOf(after.transactions[lines.first.id]!)?.id, 'car');
      },
    );

    test(
      'proposed lines count in their category; the others as unclassified; a proposed transfer in neither',
      () async {
        await h.apply((l) => l.createRule('food', rule(['épicerie du coin'], category: 'food')));
        await h.apply((l) => l.createRule('savings', rule(['compte épargne'], account: 'savings')));
        final ledger = await h.ledger();
        final totals = ledger.views.of(2026, ViewKind.cash)!;
        final food = (await linesWith('Épicerie du Coin')).fold(0, (a, t) => a + t.amount);
        final saving = (await linesWith('Compte épargne')).single;
        final all = january.statement.lines.fold(0, (a, l) => a + l.amount);
        expect(totals.totalOf('food'), food);
        expect(totals.unclassified.total, all - food - saving.amount);
        expect(ledger.kindOf(saving), TransactionKind.transfer);
        expect(totals.expenses.total, food);
      },
    );

    test('how many lines a rule would classify, before it is created', () async {
      final ledger = await h.ledger();
      expect(ledger.linesClassifiedBy(rule(['épicerie du coin'], category: 'food')), 5);
      expect(ledger.linesClassifiedBy(rule(['épicerie du coin', 're:[invalid'], category: 'food')), 5);
      expect(ledger.linesClassifiedBy(rule(['inexistant'], category: 'food')), 0);
      await h.apply((l) => l.createRule('two', rule(['épicerie ET coin'], category: 'car')));
      expect(
        (await h.ledger()).linesClassifiedBy(rule(['épicerie du coin'], category: 'food')),
        0,
        reason: 'a stronger rule wins',
      );
    });
  });

  group('validation', () {
    group('the keyword proposed by « Créer une règle »', () {
      test('is the longest run of words of the description found in the bank text', () {
        // A short label whose lines are not consecutive in the bank text: an
        // IBAN line was left out between them.
        const raw = "CRÉDIT\nDONNEUR D'ORDRE:\nEmployeur Exemple SA\nCH0000000000000000009\nSalaire janvier";
        expect(suggestedKeyword('Employeur Exemple SA Salaire janvier', raw), 'Employeur Exemple SA');
        expect(
          suggestedKeyword('Épicerie du Coin Fictiville', 'ACHAT\nEpicerie  du coin\nFictiville'),
          'Épicerie du Coin Fictiville',
        );
        // The user's own description: the line with the most letters, the
        // type of operation left aside.
        expect(suggestedKeyword('Courses', raw), 'Employeur Exemple SA');
        expect(suggestedKeyword('', 'PRIX POUR\nTENUE DE COMPTE 12.2025'), 'TENUE DE COMPTE 12.2025');
        // « du » alone would match most lines.
        expect(
          suggestedKeyword(
            'Journal du dimanche',
            'ACHAT/SERVICE DU 05.04.2026\nCARTE NO XXXX0000\nKiosque Fictif\nFictiville',
          ),
          'Kiosque Fictif',
        );
        // Never a regular expression by accident.
        expect(suggestedKeyword('re:x', 'Paiement re:x\nre:x'), 'Paiement re:x');
        expect(suggestedKeyword('Courses', '  \n '), isNull);
      });

      test('classifies at least the line it starts from, for every line of the test set', () async {
        // February and March follow January; April holds labels whose lines
        // are not consecutive in the bank text, and a description the user
        // rewrote.
        for (final name in ['2026-02', '2026-03']) {
          final s = fixtureStatement(name);
          await h.repository.write(
            (await h.ledger()).importStatement('bank', s.statement, fingerprint: s.fingerprint).modification,
          );
        }
        final march = fixtureStatement('2026-03').statement;
        const lines = [
          ("CRÉDIT\nDONNEUR D'ORDRE:\nEmployeur Exemple SA\nCH0000000000000000009\nSalaire avril", 500000),
          ('ACHAT/SERVICE DU\n04.04.2026\nCommerce Inventé\nCARTE NO XXXX0000\nFictiville', -2350),
          ('ACHAT/SERVICE DU 05.04.2026\nCARTE NO XXXX0000\nKiosque Fictif\nFictiville', -800),
        ];
        final april = ExtractedStatement(
          format: 'postfinance',
          iban: march.iban,
          currency: 'CHF',
          periodStart: d(2026, 4, 1),
          periodEnd: d(2026, 4, 30),
          openingBalance: march.closingBalance,
          closingBalance: march.closingBalance + lines.fold(0, (sum, line) => sum + line.$2),
          totalCredits: 500000,
          totalDebits: 3150,
          lines: [
            for (final (i, (raw, amount)) in lines.indexed)
              ExtractedLine(
                date: d(2026, 4, 4 + i),
                amount: amount,
                rawText: raw,
                label: [
                  'Employeur Exemple SA Salaire avril',
                  'Commerce Inventé Fictiville',
                  'Kiosque Fictif Fictiville',
                ][i],
              ),
          ],
        );
        final import = (await h.ledger()).importStatement('bank', april, fingerprint: 'f' * 64);
        await h.repository.write(import.modification);
        final kiosk = (await h.ledger()).linesOf(import.statementId).last;
        await h.apply((l) => l.updateImportedDetails(kiosk.id, description: 'Journal du dimanche', note: ''));

        final ledger = await h.ledger();
        final all = ledger.linesToValidate;
        expect(all, hasLength(27 + 21 + 12 + 3));
        for (final t in all) {
          final keyword = suggestedKeyword(t.description, t.rawText!);
          expect(keyword, isNotNull, reason: t.rawText);
          final draft = RuleDraft(year: 2026, lines: [keyword!], targetCategoryId: 'food');
          final probe = MappingRule(id: 'probe', year: 2026, lines: [keyword], targetCategoryId: 'food');
          expect(
            outcomeOf(t.rawText!, [probe], (r) => ledger.ruleClassification(r, t.date)),
            isA<Proposed>(),
            reason: '« $keyword » in ${t.rawText}',
          );
          expect(ledger.linesClassifiedBy(draft), greaterThanOrEqualTo(1), reason: keyword);
        }

        // Written, the rule proposes its line.
        final employer = (await h.ledger()).linesOf(import.statementId).first;
        final keyword = suggestedKeyword(employer.description, employer.rawText!)!;
        expect(keyword, 'Employeur Exemple SA');
        await h.apply((l) => l.createRule('employer', rule([keyword], category: 'salary')));
        final proposal = (await h.ledger()).proposals[employer.id];
        expect(proposal, isA<Proposed>().having((p) => p.rule.id, 'rule', 'employer'));
      });
    });

    test('a line to complete is classified one by one, with a category and a period', () async {
      final line = (await linesWith('Gérance')).single;
      await h.apply(
        (l) => l.classify(
          line.id,
          Classification.category('rent', periodStart: CalendarDate(2026, 2, 1), periodEnd: CalendarDate(2026, 2, 28)),
        ),
      );
      final t = (await h.ledger()).transactions[line.id]!;
      expect(t.status, TransactionStatus.validated);
      expect((t.line!.id, t.line!.categoryId, t.line!.amount), ('${line.id}-line', 'rent', line.amount));
      expect((t.line!.periodStart, t.line!.periodEnd), (CalendarDate(2026, 2, 1), CalendarDate(2026, 2, 28)));
      expect((t.amount, t.date, t.rawText), (line.amount, line.date, line.rawText));
    });

    test('an imported transfer keeps the sign of the statement', () async {
      final out = (await linesWith('Compte épargne')).single;
      final inflow = (await linesWith('Alex Modèle')).single;
      expect(out.amount, isNegative);
      expect(inflow.amount, isPositive);
      await h.apply((l) => l.classify(out.id, const Classification.transfer('savings')));
      await h.apply((l) => l.classify(inflow.id, const Classification.transfer('cash')));
      final ledger = await h.ledger();
      final o = ledger.transactions[out.id]!, i = ledger.transactions[inflow.id]!;
      expect(
        (o.accountId, o.counterpartAccountId, o.amount),
        ('bank', 'savings', out.amount),
        reason: 'money goes to savings',
      );
      expect(
        (i.accountId, i.counterpartAccountId, i.amount),
        ('bank', 'cash', inflow.amount),
        reason: 'money comes from cash',
      );
      expect((ledger.kindOf(o), ledger.kindOf(i)), (TransactionKind.transfer, TransactionKind.transfer));
      expect(o.lines, isEmpty);
      final totals = ledger.views.of(2026, ViewKind.cash)!;
      expect(
        totals.unclassified.total,
        january.statement.lines.fold(0, (a, l) => a + l.amount) - out.amount - inflow.amount,
      );
      expect(refusal(() => ledger.classify(out.id, const Classification.transfer('bank'))), LedgerError.sameAccount);
    });

    test('the proposals are confirmed in one modification, the lines to complete left out', () async {
      await h.apply((l) => l.createRule('food', rule(['épicerie du coin'], category: 'food')));
      await h.apply((l) => l.createRule('bakery', rule(['boulangerie'], category: 'food')));
      final ledger = await h.ledger();
      final ids = [for (final t in ledger.linesToValidate) t.id];
      final modifications = ledger.confirmProposals(ids);
      expect(modifications, hasLength(1));
      await h.repository.write(modifications.single);
      final after = await h.ledger();
      final validated = after.linesOf(statement).where((t) => t.isValidated).toList();
      expect(validated, hasLength(5 + (await linesWith('Boulangerie')).length));
      for (final t in validated) {
        expect(t.line!.categoryId, 'food');
      }
      final bread = after.transactions[(await linesWith('Boulangerie')).first.id]!;
      expect((bread.line!.periodStart, bread.line!.periodEnd), (bread.date, bread.date));
      expect(after.linesToValidate, hasLength(27 - validated.length));
      expect(after.confirmProposals([for (final t in after.linesToValidate) t.id]), isEmpty);
    });

    test('correcting a proposal validates the line; a validated line stays modifiable', () async {
      await h.apply((l) => l.createRule('food', rule(['épicerie du coin'], category: 'food')));
      final line = (await linesWith('Épicerie du Coin')).first;
      await h.apply(
        (l) => l.classify(line.id, Classification.category('car', periodStart: line.date, periodEnd: line.date)),
      );
      var t = (await h.ledger()).transactions[line.id]!;
      expect((t.status, t.line!.categoryId), (TransactionStatus.validated, 'car'));
      await h.apply((l) => l.classify(line.id, const Classification.transfer('savings')));
      t = (await h.ledger()).transactions[line.id]!;
      expect(t.counterpartAccountId, 'savings');
      expect(t.lines, isEmpty);
      await h.apply(
        (l) => l.classify(line.id, Classification.category('food', periodStart: line.date, periodEnd: line.date)),
      );
      t = (await h.ledger()).transactions[line.id]!;
      expect((t.counterpartAccountId, t.line?.categoryId), (null, 'food'), reason: 'the line comes back');
      await h.apply((l) => l.updateImportedDetails(line.id, description: 'Pain', note: 'Note'));
      expect((await h.ledger()).transactions[line.id]!.status, TransactionStatus.validated);
    });

    test('a category that cannot hold a transaction, or a period ending before it starts, is refused', () async {
      final ledger = await h.ledger();
      final line = ledger.linesOf(statement).first;
      expect(
        refusal(
          () => ledger.classify(
            line.id,
            Classification.category('housing', periodStart: line.date, periodEnd: line.date),
          ),
        ),
        LedgerError.categoryNotAssignable,
      );
      expect(
        refusal(
          () => ledger.classify(
            line.id,
            Classification.category('food', periodStart: line.date, periodEnd: line.date.addDays(-1)),
          ),
        ),
        LedgerError.periodInvalid,
      );
      expect(
        refusal(() => ledger.classify('unknown', const Classification.transfer('cash'))),
        LedgerError.unknownTransaction,
      );
    });
  });

  group('unusable targets', () {
    test('a rule whose category is deleted, detached or became a group, or whose account is archived, proposes nothing and is listed', () async {
      await h.apply((l) => l.createRule('food', rule(['épicerie'], category: 'food')));
      await h.apply((l) => l.createRule('car', rule(['station service'], category: 'car')));
      await h.apply((l) => l.createRule('rent', rule(['gérance'], category: 'rent')));
      await h.apply((l) => l.createRule('savings', rule(['compte épargne'], account: 'savings')));
      expect((await h.ledger()).unusableRules, isEmpty);

      // The category deleted on another device, detached, made a group; the
      // account archived.
      await h.repository.write(Modification.delete(CategoryFields.entity, 'food'));
      await h.repository.write(
        Modification.set(CategoryFields.entity, 'housing', {CategoryFields.parentId: 'nowhere'}),
      );
      await h.apply((l) => l.addCategory('fuel', year: 2026, name: 'Carburant', parentId: 'car'));
      await h.apply((l) => l.removeAccount('savings').modification);

      final ledger = await h.ledger();
      expect(ledger.unusableRules.map((r) => r.id).toSet(), {'food', 'car', 'rent', 'savings'});
      expect(await outcomeOfFirst('Épicerie du Coin'), isA<UnusableRule>());
      expect(await outcomeOfFirst('Station Service'), isA<UnusableRule>());
      expect(await outcomeOfFirst('Gérance'), isA<UnusableRule>());
      expect(await outcomeOfFirst('Compte épargne'), isA<UnusableRule>());
      expect(ledger.validationStateOf((await linesWith('Gérance')).single), ValidationState.toComplete);
    });

    test('an unusable rule still wins over a rule with fewer terms: the line is to complete', () async {
      await h.apply((l) => l.createRule('weak', rule(['épicerie'], category: 'rent')));
      await h.apply((l) => l.createRule('strong', rule(['épicerie ET coin'], account: 'savings')));
      await h.apply((l) => l.removeAccount('savings').modification);
      expect(await outcomeOfFirst('Épicerie du Coin'), isA<UnusableRule>().having((u) => u.rule.id, 'rule', 'strong'));
    });

    test('a target must be usable when the rule is written', () async {
      final ledger = await h.ledger();
      expect(
        refusal(() => ledger.createRule('r', rule(['x'], category: 'housing'))),
        LedgerError.categoryNotAssignable,
      );
      expect(refusal(() => ledger.createRule('r', rule(['x'], account: 'bank'))), LedgerError.detailedAccountManual);
      expect(refusal(() => ledger.createRule('r', rule(['x']))), LedgerError.ruleTargetRequired);
      expect(
        refusal(() => ledger.createRule('r', rule(['x'], category: 'food', account: 'cash'))),
        LedgerError.ruleTargetRequired,
      );
      expect(
        refusal(() => ledger.createRule('r', const RuleDraft(year: 2030, lines: ['x'], targetCategoryId: 'food'))),
        LedgerError.noTree,
      );
    });
  });

  test('the rules follow the copy of the tree, with computed identifiers and transposed targets', () async {
    await h.apply((l) => l.createRule('food', rule(['épicerie', 'coin ET marché'], category: 'food')));
    await h.apply((l) => l.createRule('savings', rule(['compte épargne'], account: 'savings')));
    await h.apply((l) => l.createTree(2027));
    final ledger = await h.ledger();
    final copies = ledger.rulesOf(2027);
    expect(copies.map((r) => r.id).toSet(), {copiedRuleId('food', 2027), copiedRuleId('savings', 2027)});
    final food = ledger.rules[copiedRuleId('food', 2027)]!;
    expect(food.targetCategoryId, copiedCategoryId('food', 2027));
    expect(ledger.trees[2027]!.byId[food.targetCategoryId]!.name, 'Nourriture');
    expect(food.lines, ['épicerie', 'coin ET marché']);
    expect(ledger.rules[copiedRuleId('savings', 2027)]!.targetAccountId, 'savings');
    expect(ledger.unusableRules, isEmpty);
    expect(
      ledger.treeOrPreview(2028).byId.keys,
      isNot(contains(copiedRuleId('food', 2028))),
      reason: 'the preview holds categories only',
    );
  });

  test('lines validated offline, in bulk and one by one, reach another device validated', () async {
    final other = await LedgerHarness.open(deviceId: 'bbbbbbbb-0000-4000-8000-000000000000');
    await other.journal.merge(await h.journal.entries());
    // Offline: a rule, a confirmation in bulk, one line classified.
    await h.apply((l) => l.createRule('food', rule(['épicerie du coin'], category: 'food')));
    final ledger = await h.ledger();
    for (final m in ledger.confirmProposals([for (final t in ledger.linesToValidate) t.id])) {
      await h.repository.write(m);
    }
    final rent = (await linesWith('Gérance')).single;
    await h.apply(
      (l) => l.classify(rent.id, Classification.category('rent', periodStart: rent.date, periodEnd: rent.date)),
    );
    // Back online.
    await other.journal.merge(await h.journal.entries());
    final there = await other.ledger();
    expect(there.linesOf(statement).where((t) => t.isValidated), hasLength(6));
    expect(there.transactions[rent.id]!.line!.categoryId, 'rent');
    expect(there.views.of(2026, ViewKind.cash)!.totals, (await h.ledger()).views.of(2026, ViewKind.cash)!.totals);
    await other.close();
  });
}
