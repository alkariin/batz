// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'batz';

  @override
  String get navHome => 'Accueil';

  @override
  String get navTransactions => 'Transactions';

  @override
  String get navYear => 'Année';

  @override
  String get navWealth => 'Fortune';

  @override
  String get navMore => 'Plus';

  @override
  String get emptyPage => 'Rien ici pour l\'instant.';

  @override
  String get startupErrorTitle => 'batz ne peut pas démarrer';

  @override
  String get startupErrorBody => 'La base de données locale n\'a pas pu être ouverte. Détail technique :';

  @override
  String get cancel => 'Annuler';

  @override
  String get confirm => 'Confirmer';

  @override
  String get serverTitle => 'Serveur';

  @override
  String get serverPaired => 'Associé au serveur';

  @override
  String get serverNotPaired => 'Non associé';

  @override
  String get serverPairingIntro =>
      'Sur le serveur, lancez « batz-web pairing-code » puis saisissez ici son adresse et le code affiché.';

  @override
  String get serverAddress => 'Adresse du serveur';

  @override
  String get serverCode => 'Code d\'association';

  @override
  String get serverDeviceName => 'Nom de cet appareil';

  @override
  String get serverPair => 'Associer';

  @override
  String serverAddressValue(String address) {
    return 'Adresse : $address';
  }

  @override
  String serverVersion(String version) {
    return 'Version du serveur : $version';
  }

  @override
  String get serverFingerprint => 'Empreinte du certificat (à comparer avec celle affichée par le serveur)';

  @override
  String serverIncompatible(String version) {
    return 'Cette version de l\'app est trop ancienne pour le serveur, qui demande au moins la version $version. Mettez l\'app à jour.';
  }

  @override
  String get serverDevices => 'Appareils associés';

  @override
  String serverThisDevice(String name) {
    return '$name (cet appareil)';
  }

  @override
  String serverDeviceSince(String date) {
    return 'Associé le $date';
  }

  @override
  String serverDeviceRevoked(String date) {
    return 'Révoqué le $date';
  }

  @override
  String get serverRevoke => 'Révoquer';

  @override
  String serverRevokeConfirm(String name) {
    return 'Révoquer « $name » ? Cet appareil ne pourra plus accéder au serveur.';
  }

  @override
  String get serverRefresh => 'Actualiser';

  @override
  String get serverUnpair => 'Dissocier cet appareil';

  @override
  String get serverUnpairConfirm => 'Dissocier cet appareil ? Sa clé sera révoquée sur le serveur.';

  @override
  String get serverForget => 'Oublier ce serveur sur cet appareil';

  @override
  String get serverErrorAddress => 'Adresse invalide. Exemple : 192.168.1.95:8443.';

  @override
  String get serverErrorUnreachable =>
      'Serveur injoignable. Vérifiez qu\'il est allumé et que vous êtes sur le réseau de la maison.';

  @override
  String get serverErrorCertificate =>
      'Le serveur présente un autre certificat que celui mémorisé lors de l\'association. Connexion refusée.';

  @override
  String get serverErrorCodeInvalid => 'Code d\'association incorrect.';

  @override
  String get serverErrorCodeExpired => 'Ce code a expiré. Demandez-en un nouveau au serveur.';

  @override
  String get serverErrorCodeUsed => 'Ce code a déjà été utilisé. Demandez-en un nouveau au serveur.';

  @override
  String get serverErrorName => 'Le nom de l\'appareil doit compter de 1 à 64 caractères.';

  @override
  String get serverErrorRevoked => 'Cet appareil a été révoqué. Oubliez ce serveur puis associez-le à nouveau.';

  @override
  String get serverErrorOther => 'Le serveur a répondu par une erreur inattendue.';

  @override
  String get save => 'Enregistrer';

  @override
  String get delete => 'Supprimer';

  @override
  String get accountsTitle => 'Comptes';

  @override
  String get accountsEmpty => 'Aucun compte. Créez-en un avec le bouton +.';

  @override
  String get accountsArchivedSection => 'Archivés';

  @override
  String get accountNew => 'Nouveau compte';

  @override
  String get accountEdit => 'Modifier le compte';

  @override
  String get accountName => 'Nom';

  @override
  String get accountType => 'Type';

  @override
  String get accountImport => 'Import des relevés PostFinance';

  @override
  String get accountImportHint =>
      'Compte détaillé : ses transactions viennent uniquement des relevés. Un seul compte peut l\'être.';

  @override
  String get accountArchived => 'Archivé';

  @override
  String get accountDetailed => 'Détaillé';

  @override
  String accountDeleteConfirm(String name) {
    return 'Supprimer le compte « $name » ? S\'il est utilisé par des transactions, il sera archivé.';
  }

  @override
  String accountArchivedInstead(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions l\'utilisent',
      one: 'une transaction l\'utilise',
    );
    return 'Compte archivé et non supprimé : $_temp0.';
  }

  @override
  String get accountDeleted => 'Compte supprimé.';

  @override
  String get accountTypePrivateAccount => 'Compte privé';

  @override
  String get accountTypeSavings => 'Épargne';

  @override
  String get accountTypePillar3 => '3e pilier';

  @override
  String get accountTypePillar2 => '2e pilier';

  @override
  String get accountTypeInvestments => 'Investissements';

  @override
  String get accountTypeVehicle => 'Véhicule';

  @override
  String get accountTypeRentDeposit => 'Garantie de loyer';

  @override
  String get accountTypeCash => 'Espèces';

  @override
  String get accountTypeDebts => 'Dettes';

  @override
  String get accountTypeOther => 'Autre';

  @override
  String get errorNameRequired => 'Le nom est obligatoire.';

  @override
  String get errorSecondDetailedAccount =>
      'Un seul compte peut être détaillé : l\'import est déjà activé sur un autre compte.';

  @override
  String get errorUnknownAccount => 'Ce compte n\'existe plus.';

  @override
  String get categoriesTitle => 'Catégories';

  @override
  String get categoriesYear => 'Année';

  @override
  String categoriesNoTree(int year) {
    return 'Pas encore d\'arbre pour $year.';
  }

  @override
  String categoriesNoTreeCopy(int source, int year) {
    return 'Il sera copié de l\'arbre $source, puis modifiable sans effet sur $source. La première transaction de $year le crée aussi.';
  }

  @override
  String categoriesNoTreeDefault(int year) {
    return 'Il partira de deux groupes vides, « Revenus » et « Dépenses ». La première transaction de $year le crée aussi.';
  }

  @override
  String categoriesCreateTree(int year) {
    return 'Créer l\'arbre $year';
  }

  @override
  String get categoriesNewGroup => 'Nouveau groupe';

  @override
  String get categoryName => 'Nom';

  @override
  String get categoryNature => 'Nature';

  @override
  String get categoryAddChild => 'Ajouter une sous-catégorie';

  @override
  String get categoryRename => 'Renommer';

  @override
  String get categoryMove => 'Déplacer';

  @override
  String get categoryMoveUp => 'Monter';

  @override
  String get categoryMoveDown => 'Descendre';

  @override
  String categoryMoveTitle(String name) {
    return 'Déplacer « $name » vers';
  }

  @override
  String categoryTopLevel(String nature) {
    return 'Premier niveau, $nature';
  }

  @override
  String categoryDeleteConfirm(String name) {
    return 'Supprimer la catégorie « $name » ?';
  }

  @override
  String get categoryDeleted => 'Catégorie supprimée.';

  @override
  String get categoriesToReplace => 'À replacer';

  @override
  String get categoriesToReplaceHint =>
      'Ces catégories ne sont plus rattachées à l\'arbre, souvent après des modifications faites en même temps sur deux appareils. Déplacez-les pour les replacer ; leurs sous-catégories suivent.';

  @override
  String get detachedLoop => 'Placée sous une de ses propres sous-catégories';

  @override
  String get detachedMissingParent => 'Sa catégorie parente a été supprimée';

  @override
  String get detachedParentInOtherYear => 'Sa catégorie parente appartient à une autre année';

  @override
  String get detachedGroupWithoutNature => 'Groupe sans nature (revenus ou dépenses)';

  @override
  String get detachedAncestor => 'Sous une catégorie à replacer';

  @override
  String get natureIncome => 'revenus';

  @override
  String get natureExpense => 'dépenses';

  @override
  String get errorUnknownCategory => 'Cette catégorie n\'existe plus.';

  @override
  String get errorCategoryNameTaken =>
      'Ce nom est déjà utilisé dans l\'arbre de cette année (majuscules, accents et espaces autour ne comptent pas).';

  @override
  String get errorNatureRequired => 'Choisissez la nature du groupe : revenus ou dépenses.';

  @override
  String get errorTreeExists => 'L\'arbre de cette année existe déjà.';

  @override
  String get errorNoTree => 'Cette année n\'a pas encore d\'arbre.';

  @override
  String get errorCategoryLoop =>
      'Une catégorie ne peut pas être placée sous elle-même ni sous une de ses sous-catégories.';

  @override
  String errorParentHasTransactions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions sont classées',
      one: 'une transaction est classée',
    );
    return 'Impossible : $_temp0 dans cette catégorie. Seule une catégorie sans transaction peut recevoir des sous-catégories.';
  }

  @override
  String get errorCategoryHasChildren => 'Supprimez ou déplacez d\'abord ses sous-catégories.';

  @override
  String errorCategoryInUse(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions utilisent',
      one: 'une transaction utilise',
    );
    return 'Suppression refusée : $_temp0 cette catégorie.';
  }

  @override
  String get errorUnknownTransaction => 'Cette transaction n\'existe plus.';

  @override
  String get errorAmountRequired => 'Saisissez un montant supérieur à zéro.';

  @override
  String get errorArchivedAccount => 'Ce compte est archivé.';

  @override
  String get errorDetailedAccountManual =>
      'Le compte détaillé ne reçoit que les transactions de ses relevés : pas de saisie manuelle.';

  @override
  String get errorDebtsAccountManual => 'Un compte de dettes ne se modifie que par le tableau des dettes.';

  @override
  String get errorCategoryNotAssignable =>
      'Choisissez une catégorie sans sous-catégorie, dans l\'arbre de l\'année du paiement.';

  @override
  String get errorPeriodInvalid => 'La fin de la période précède son début.';

  @override
  String get errorSameAccount => 'Choisissez deux comptes différents.';

  @override
  String get errorAccountNotDetailed =>
      'Ce compte n\'est pas détaillé : activez l\'import du compte pour y importer ses relevés.';

  @override
  String get errorStatementOtherFormat => 'Ce relevé n\'est pas au format d\'import de ce compte.';

  @override
  String get errorStatementAlreadyImported => 'Ce relevé est déjà importé.';

  @override
  String errorStatementOtherAccount(String found, String expected) {
    return 'Ce relevé est celui d\'un autre compte : IBAN $found, alors que les relevés précédents portent l\'IBAN $expected.';
  }

  @override
  String errorStatementNotContiguous(
    String foundStart,
    String foundOpening,
    String expectedStart,
    String expectedOpening,
  ) {
    return 'Ce relevé ne suit pas le précédent : il commence le $foundStart avec un solde de $foundOpening, alors que le suivant doit commencer le $expectedStart avec un solde de $expectedOpening.';
  }

  @override
  String get errorStatementSumMismatch =>
      'Les lignes du relevé ne donnent pas l\'écart entre ses soldes initial et final.';

  @override
  String get errorStatementTooLarge => 'Ce relevé compte trop de lignes pour être importé en une fois.';

  @override
  String get errorStatementNotLast => 'Seul le dernier relevé du compte peut être supprimé.';

  @override
  String get errorUnknownStatement => 'Ce relevé n\'existe plus.';

  @override
  String get errorImportedTransaction =>
      'Une ligne importée garde le montant, la date, le compte et le texte de la banque ; seules sa catégorie, sa période, sa description et sa note se modifient.';

  @override
  String get errorUnknownRule => 'Cette règle n\'existe plus.';

  @override
  String get errorRuleKeywordsRequired => 'Indiquez au moins un mot-clé.';

  @override
  String get errorRuleKeywordInvalid => 'Expression régulière invalide : corrigez le mot-clé qui commence par « re: ».';

  @override
  String get errorRuleTargetRequired => 'Choisissez une catégorie ou un compte de transfert.';

  @override
  String get errorRulePeriodInvalid => 'Indiquez un nombre de mois entre 1 et 120.';

  @override
  String errorCategoryUsedByRules(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count règles visent',
      one: 'une règle vise',
    );
    return 'Suppression refusée : $_temp0 cette catégorie.';
  }

  @override
  String get errorUnknownRedistribution => 'Cette règle de redistribution n\'existe plus.';

  @override
  String get errorRedistributionSameCategory => 'La source et la cible doivent être deux catégories différentes.';

  @override
  String get errorRedistributionNotLeaf =>
      'La source et la cible doivent être des catégories sans sous-catégorie de l\'année.';

  @override
  String get errorRedistributionNatureMismatch => 'La source et la cible doivent être deux dépenses ou deux revenus.';

  @override
  String get errorRedistributionPercentInvalid =>
      'Indiquez un pourcentage entre 0.01 et 100, avec deux décimales au plus.';

  @override
  String get errorRedistributionDuplicate => 'Une règle va déjà de cette source vers cette cible : modifiez-la.';

  @override
  String get errorRedistributionTargetIsSource =>
      'Cette cible est déjà la source d\'une autre règle : une cible ne peut pas être une source.';

  @override
  String get errorRedistributionSourceIsTarget =>
      'Cette source est déjà la cible d\'une autre règle : une cible ne peut pas être une source.';

  @override
  String errorRedistributionOverHundred(String total) {
    return 'Les règles de cette source totaliseraient $total : 100 % au plus.';
  }

  @override
  String errorCategoryUsedByRedistributions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count règles de redistribution utilisent',
      one: 'une règle de redistribution utilise',
    );
    return 'Suppression refusée : $_temp0 cette catégorie.';
  }

  @override
  String get errorRefundNotInflow => 'Seule une entrée d\'argent peut rembourser une dépense.';

  @override
  String get errorRefundIsTransfer => 'Un transfert ne peut pas rembourser une dépense.';

  @override
  String get errorRefundTargetNotExpense => 'Un remboursement se rattache à une dépense validée.';

  @override
  String get errorShareNatureMismatch =>
      'Choisissez une catégorie de même nature que celle d\'origine : une dépense reste une dépense.';

  @override
  String get edit => 'Modifier';

  @override
  String get transactionsEmpty => 'Aucune transaction.';

  @override
  String get transactionsAllAccounts => 'Tous les comptes';

  @override
  String get transactionsAllYears => 'Toutes les années';

  @override
  String get transactionNew => 'Nouvelle transaction';

  @override
  String get transactionNewEntry => 'Dépense ou revenu';

  @override
  String get transactionNewTransfer => 'Transfert';

  @override
  String get entryNewTitle => 'Dépense ou revenu';

  @override
  String get entryEditTitle => 'Modifier la transaction';

  @override
  String get transferNewTitle => 'Nouveau transfert';

  @override
  String get transferEditTitle => 'Modifier le transfert';

  @override
  String get fieldAmount => 'Montant';

  @override
  String get fieldDate => 'Date (jj.mm.aaaa)';

  @override
  String get fieldAccount => 'Compte';

  @override
  String get fieldCategory => 'Catégorie';

  @override
  String get fieldDescription => 'Description';

  @override
  String get fieldNote => 'Note';

  @override
  String get fieldRawText => 'Texte de la banque';

  @override
  String get fieldFrom => 'Compte de départ';

  @override
  String get fieldTo => 'Compte d\'arrivée';

  @override
  String get pickDate => 'Choisir la date';

  @override
  String get directionInflow => 'Entrée';

  @override
  String get directionOutflow => 'Sortie';

  @override
  String get periodCustom => 'Période différente du paiement';

  @override
  String get periodCustomHint => 'Par exemple une assurance payée pour douze mois.';

  @override
  String get periodStart => 'Début de la période';

  @override
  String get periodEnd => 'Fin de la période';

  @override
  String get errorAmountInvalid => 'Montant invalide : saisissez par exemple 45.90, sans signe.';

  @override
  String get errorDateInvalid => 'Date invalide : saisissez par exemple 31.12.2026.';

  @override
  String get errorAccountMissing => 'Choisissez un compte.';

  @override
  String get errorCategoryMissing => 'Choisissez une catégorie.';

  @override
  String get entryNoAccount => 'Aucun compte n\'accepte la saisie manuelle. Créez-en un dans Plus › Comptes.';

  @override
  String entryNoCategory(int year) {
    return 'Aucune catégorie disponible en $year. Ajoutez-en dans Plus › Catégories.';
  }

  @override
  String get kindExpense => 'Dépense';

  @override
  String get kindRefund => 'Remboursement';

  @override
  String get kindIncome => 'Revenu';

  @override
  String get kindTransfer => 'Transfert';

  @override
  String get kindUnclassified => 'Non classé';

  @override
  String transferAccounts(String from, String to) {
    return '$from → $to';
  }

  @override
  String get detailTitle => 'Transaction';

  @override
  String get detailType => 'Type';

  @override
  String get detailPeriod => 'Période';

  @override
  String get detailShares => 'Parts par mois';

  @override
  String get detailYearTotals => 'Total par année';

  @override
  String get transactionDeleteConfirm => 'Supprimer cette transaction ?';

  @override
  String get transactionDeleted => 'Transaction supprimée.';

  @override
  String get syncTitle => 'Synchronisation';

  @override
  String get syncNotPaired => 'Cet appareil n\'est associé à aucun serveur : ses données restent sur lui seul.';

  @override
  String get syncPairAction => 'Associer un serveur';

  @override
  String get syncNever => 'Jamais synchronisé';

  @override
  String get syncRunning => 'Synchronisation en cours…';

  @override
  String get syncUpToDate => 'À jour';

  @override
  String get syncOffline => 'Hors ligne';

  @override
  String get syncOfflineHint =>
      'Le serveur est injoignable. Les modifications partiront à la prochaine synchronisation.';

  @override
  String get syncRevoked => 'Appareil révoqué';

  @override
  String get syncRevokedHint =>
      'Le serveur a révoqué cet appareil : la synchronisation est arrêtée. Ses données restent sur cet appareil. Pour reprendre, oubliez ce serveur dans Plus › Serveur, puis associez l\'appareil à nouveau : ses modifications non envoyées partiront au premier échange.';

  @override
  String get syncIncompatible => 'Versions incompatibles';

  @override
  String syncAppTooOld(String version) {
    return 'Synchronisation refusée : cette version de l\'app est trop ancienne pour le serveur, qui demande au moins la version $version. Mettez l\'app à jour.';
  }

  @override
  String syncServerTooOld(String version) {
    return 'Synchronisation refusée : le serveur (version $version) est trop ancien pour cette version de l\'app. Mettez le serveur à jour.';
  }

  @override
  String get syncError => 'Erreur de synchronisation';

  @override
  String syncErrorHint(String detail) {
    return 'La dernière synchronisation a échoué : $detail';
  }

  @override
  String syncLast(String date, String time) {
    return 'Dernière synchronisation : $date à $time';
  }

  @override
  String syncPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count modifications en attente',
      one: 'Une modification en attente',
      zero: 'Aucune modification en attente',
    );
    return '$_temp0';
  }

  @override
  String get syncNow => 'Synchroniser';

  @override
  String syncClockWarning(int minutes) {
    return 'L\'horloge de cet appareil s\'écarte de $minutes minutes de celle du serveur. Corrigez-la : l\'ordre des modifications faites sur plusieurs appareils en dépend.';
  }

  @override
  String get syncDecision => 'Premier échange avec le serveur';

  @override
  String get syncDecisionHint =>
      'Cet appareil et le serveur ont chacun des données, sans rien en commun : elles viennent d\'appareils utilisés séparément. Fusionner réunit les deux ; des doublons peuvent apparaître, ils seront signalés dans les tâches. Remplacer efface les données de cet appareil et reprend celles du serveur.';

  @override
  String get syncMerge => 'Fusionner';

  @override
  String get syncReplace => 'Remplacer celles de l\'appareil';

  @override
  String get syncReplaceAction => 'Remplacer les données de cet appareil par celles du serveur';

  @override
  String get syncReplaceConfirm =>
      'Remplacer les données de cet appareil par celles du serveur ? Tout ce que cet appareil n\'a pas encore envoyé au serveur sera définitivement perdu.';

  @override
  String get syncReplaceDone => 'Les données de cet appareil sont maintenant celles du serveur.';

  @override
  String get syncServerChanged => 'Le serveur a changé';

  @override
  String get syncServerChangedHint =>
      'Le serveur présente un autre certificat ou ne connaît plus cet appareil : il a sans doute été réinstallé. Associez cet appareil de nouveau : ses données, modifications non envoyées comprises, y seront recopiées.';

  @override
  String get syncPairAgain => 'Associer de nouveau';

  @override
  String get serverErrorUnknownDevice =>
      'Le serveur ne connaît pas cet appareil : il a sans doute été réinstallé. Oubliez ce serveur puis associez l\'appareil à nouveau.';

  @override
  String get tasksTitle => 'À faire';

  @override
  String get tasksNone => 'Rien à faire pour l\'instant.';

  @override
  String taskDuplicateName(int count, String name, int year) {
    return '$count catégories « $name » en $year';
  }

  @override
  String get taskDuplicateNameHint =>
      'Un nom n\'apparaît qu\'une fois dans l\'arbre d\'une année : renommez ou supprimez l\'une d\'elles.';

  @override
  String taskDetailedAccounts(int count) {
    return '$count comptes détaillés';
  }

  @override
  String get taskDetailedAccountsHint => 'Un seul compte reçoit les relevés : désactivez l\'import sur les autres.';

  @override
  String taskDetached(int count, int year) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count catégories à replacer',
      one: 'Une catégorie à replacer',
    );
    return '$_temp0 en $year';
  }

  @override
  String get taskDetachedHint => 'Elles ne sont plus rattachées à l\'arbre de l\'année : déplacez-les.';

  @override
  String get categoryDuplicateName => 'Nom en double dans cette année';

  @override
  String get importTitle => 'Importer un relevé';

  @override
  String get importSyncing => 'Synchronisation avant l\'import…';

  @override
  String importNotReady(String reason) {
    return 'L\'import commence par une synchronisation aboutie. Elle n\'a pas abouti : $reason';
  }

  @override
  String get importRetry => 'Réessayer';

  @override
  String get importNoDetailedAccount => 'Aucun compte détaillé : activez l\'import d\'un compte dans Plus › Comptes.';

  @override
  String get importAccount => 'Compte';

  @override
  String get importChoose => 'Choisir le relevé PDF';

  @override
  String get importSending => 'Le serveur lit et vérifie le relevé…';

  @override
  String get importRefusedTitle => 'Relevé refusé';

  @override
  String get importDoneTitle => 'Relevé importé';

  @override
  String importDonePeriod(String start, String end) {
    return 'Du $start au $end';
  }

  @override
  String importDoneLines(int lines, int proposed, int toComplete) {
    String _temp0 = intl.Intl.pluralLogic(lines, locale: localeName, other: '$lines lignes', one: 'Une ligne');
    String _temp1 = intl.Intl.pluralLogic(
      proposed,
      locale: localeName,
      other: 'proposées',
      one: 'proposée',
      zero: 'proposée',
    );
    return '$_temp0 : $proposed $_temp1, $toComplete à compléter.';
  }

  @override
  String get importStatements => 'Relevés du compte';

  @override
  String get importFirstTitle => 'Premier relevé de ce compte';

  @override
  String importFirstBody(String balance, String date) {
    return 'Ce relevé fixe le solde de départ du compte : $balance au $date. Aucun relevé antérieur ne pourra être importé ensuite.';
  }

  @override
  String get importFirstConfirm => 'Importer';

  @override
  String get importUnreadable => 'Ce fichier n\'est pas un PDF lisible.';

  @override
  String get importUnknownFormat => 'Ce PDF n\'est pas un relevé PostFinance.';

  @override
  String importInconsistent(String reason) {
    return 'Relevé incohérent, rien n\'est importé : $reason.';
  }

  @override
  String get importCheckLayout => 'il n\'a pas pu être lu en entier';

  @override
  String get importCheckCurrency => 'le compte n\'est pas en francs suisses';

  @override
  String get importCheckPeriod => 'une ligne est hors de la période du relevé, ou dans le désordre';

  @override
  String get importCheckRunningBalance =>
      'un solde imprimé en cours de relevé ne correspond pas aux mouvements qui le précèdent';

  @override
  String get importCheckTotals => 'les totaux imprimés des crédits ou des débits ne correspondent pas aux mouvements';

  @override
  String get importCheckClosingBalance => 'le solde final ne correspond pas au solde initial plus les mouvements';

  @override
  String get importTooLarge => 'Ce fichier dépasse 10 Mo.';

  @override
  String importServerRefused(String code) {
    return 'Le serveur refuse l\'envoi ($code).';
  }

  @override
  String importServerTooOld(String version) {
    return 'Le serveur (version $version) est trop ancien pour importer des relevés : installez la version 0.4.0 ou une suivante.';
  }

  @override
  String get importUnreachable => 'Le serveur ne répond plus : le relevé n\'a pas été envoyé.';

  @override
  String statementsTitle(String account) {
    return 'Relevés de $account';
  }

  @override
  String get statementsEmpty => 'Aucun relevé importé.';

  @override
  String statementPeriod(String start, String end) {
    return '$start – $end';
  }

  @override
  String statementSummary(String opening, String closing, int lines) {
    String _temp0 = intl.Intl.pluralLogic(lines, locale: localeName, other: '$lines lignes', one: 'une ligne');
    return 'Solde initial $opening · final $closing · $_temp0';
  }

  @override
  String get statementSavePdf => 'Enregistrer le PDF d\'origine';

  @override
  String get statementPdfSaved => 'PDF enregistré.';

  @override
  String get statementPdfMissing => 'Le serveur n\'a plus ce PDF : il a sans doute été reconstruit depuis l\'import.';

  @override
  String get statementPdfNotPaired => 'Associez un serveur pour récupérer le PDF d\'origine.';

  @override
  String get statementPdfUnreachable => 'Le serveur ne répond pas : le PDF n\'a pas pu être récupéré.';

  @override
  String get statementDeleteLast => 'Supprimer le dernier relevé';

  @override
  String statementDeleteConfirm(String start, String end, int lines) {
    return 'Supprimer le relevé du $start au $end et ses $lines lignes ? Leurs classements sont perdus ; le relevé pourra être importé de nouveau.';
  }

  @override
  String get statementDeleted => 'Relevé supprimé.';

  @override
  String get accountStatements => 'Relevés importés';

  @override
  String get validationTitle => 'Validation';

  @override
  String validationToCompleteTab(int count) {
    return 'À compléter ($count)';
  }

  @override
  String validationProposedTab(int count) {
    return 'Proposées ($count)';
  }

  @override
  String get validationNothingToComplete => 'Aucune ligne à compléter.';

  @override
  String get validationNothingProposed => 'Aucune proposition à confirmer.';

  @override
  String validationConfirm(int count) {
    return 'Confirmer les propositions ($count)';
  }

  @override
  String validationConfirmed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lignes validées',
      one: 'Une ligne validée',
    );
    return '$_temp0.';
  }

  @override
  String validationConflict(String rules) {
    return 'Règles en concurrence : $rules';
  }

  @override
  String validationUnusable(String keywords) {
    return 'La règle « $keywords » vise une cible inutilisable.';
  }

  @override
  String validationRule(String keywords) {
    return 'Règle « $keywords »';
  }

  @override
  String validationTransferWith(String account) {
    return 'Transfert avec $account';
  }

  @override
  String get validationAction => 'Valider les lignes';

  @override
  String get classifyTitle => 'Classer la ligne';

  @override
  String get classifyCategory => 'Catégorie';

  @override
  String get classifyTransfer => 'Transfert';

  @override
  String get classifyCounterpart => 'Compte de contrepartie';

  @override
  String get classifyTransferOut => 'L\'argent part vers ce compte.';

  @override
  String get classifyTransferIn => 'L\'argent vient de ce compte.';

  @override
  String get classifyValidate => 'Valider';

  @override
  String get classifyValidated => 'Ligne validée.';

  @override
  String get classifyCreateRule => 'Créer une règle';

  @override
  String get classifyChooseCategory => 'Choisissez une catégorie.';

  @override
  String get classifyChooseAccount => 'Choisissez un compte.';

  @override
  String get rulesMenu => 'Règles de classement';

  @override
  String rulesTitle(int year) {
    return 'Règles $year';
  }

  @override
  String get rulesEmpty => 'Aucune règle pour cette année.';

  @override
  String get rulesNoTree => 'Cette année n\'a pas encore d\'arbre de catégories.';

  @override
  String get ruleNew => 'Nouvelle règle';

  @override
  String get ruleEdit => 'Modifier la règle';

  @override
  String get ruleKeywords => 'Mots-clés, un par ligne';

  @override
  String get ruleKeywordsHint =>
      'Tous sont requis, sans tenir compte des majuscules, des accents ni des espaces. « re: » au début d\'un mot-clé pour une expression régulière.';

  @override
  String ruleKeywordInvalid(String keyword) {
    return 'Expression régulière invalide : $keyword';
  }

  @override
  String get ruleTarget => 'Cible';

  @override
  String get rulePeriod => 'Période';

  @override
  String get rulePeriodNone => 'Date du paiement';

  @override
  String get rulePeriodPreviousMonth => 'Mois précédent';

  @override
  String get rulePeriodNextMonth => 'Mois suivant';

  @override
  String get rulePeriodMonthsAfter => 'N mois après le paiement';

  @override
  String get rulePeriodMonthsBefore => 'N mois avant le paiement';

  @override
  String get rulePeriodCurrentYear => 'Année civile en cours';

  @override
  String get rulePeriodPreviousYear => 'Année civile précédente';

  @override
  String get ruleMonths => 'Nombre de mois';

  @override
  String ruleMatches(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lignes non validées',
      one: 'une ligne non validée',
      zero: 'aucune ligne non validée',
    );
    return 'Cette règle classerait $_temp0.';
  }

  @override
  String get ruleSaved => 'Règle enregistrée.';

  @override
  String get ruleDeleted => 'Règle supprimée.';

  @override
  String get ruleDeleteConfirm => 'Supprimer cette règle ? Les lignes déjà validées ne changent pas.';

  @override
  String get ruleUnusable => 'Cible inutilisable : cette règle ne propose rien.';

  @override
  String ruleSummary(String keywords, String target) {
    return '$keywords → $target';
  }

  @override
  String taskLinesToValidate(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lignes à valider',
      one: 'Une ligne à valider',
    );
    return '$_temp0';
  }

  @override
  String get taskLinesToValidateHint => 'Lignes importées : complétez-les ou confirmez les propositions.';

  @override
  String taskConflicts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lignes dont les règles sont en concurrence',
      one: 'Une ligne dont les règles sont en concurrence',
    );
    return '$_temp0';
  }

  @override
  String get taskConflictsHint => 'Classez-les à la main ou ajustez les règles.';

  @override
  String taskUnusableRules(int count, int year) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count règles de $year ne proposent plus rien',
      one: 'Une règle de $year ne propose plus rien',
    );
    return '$_temp0';
  }

  @override
  String get taskUnusableRulesHint => 'Leur catégorie ou leur compte n\'est plus utilisable : modifiez-les.';

  @override
  String get transactionsSearch => 'Rechercher';

  @override
  String get transactionsAllMonths => 'Tous les mois';

  @override
  String get transactionsAllCategories => 'Toutes les catégories';

  @override
  String get transactionsUnclassified => 'Non classé';

  @override
  String get transactionsAllStatuses => 'Tous les statuts';

  @override
  String get statusToValidate => 'À valider';

  @override
  String get statusToComplete => 'À compléter';

  @override
  String get statusProposed => 'Proposée';

  @override
  String get statusValidated => 'Validée';

  @override
  String get yearViewCash => 'Trésorerie';

  @override
  String get yearViewEconomic => 'Économique';

  @override
  String get yearPick => 'Année affichée';

  @override
  String get yearIncome => 'Revenus';

  @override
  String get yearExpenses => 'Dépenses';

  @override
  String get yearSavings => 'Épargne';

  @override
  String get yearUnclassified => 'Non classé';

  @override
  String get yearToClassify => 'À classer';

  @override
  String yearToClassifyNature(String nature) {
    return 'À classer · $nature';
  }

  @override
  String get yearOffsets => 'Décalages de période';

  @override
  String yearPaidForOtherYears(String year) {
    return 'Payé en $year pour d\'autres années';
  }

  @override
  String yearPaidInOtherYears(String year) {
    return 'Payé d\'autres années pour $year';
  }

  @override
  String yearToValidate(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lignes à valider comptent',
      one: 'Une ligne à valider compte',
    );
    return '$_temp0 comme ses règles le proposent.';
  }

  @override
  String yearPreview(String year) {
    return '$year n\'a pas encore d\'arbre : il s\'affiche avec celui que sa copie lui donnera.';
  }

  @override
  String get yearNone => 'Aucune année à afficher : la première transaction d\'une année crée son arbre.';

  @override
  String get yearTotal => 'Total';

  @override
  String get yearMonths => 'janv.,févr.,mars,avr.,mai,juin,juil.,août,sept.,oct.,nov.,déc.';

  @override
  String get yearMonthDetail => 'Détail par mois';

  @override
  String get yearCostsHint => 'Les dépenses s\'affichent comme des coûts ; un remboursement les diminue.';

  @override
  String yearRedistributionTo(String name, String percent) {
    return 'Vers $name · $percent';
  }

  @override
  String yearRedistributionFrom(String name, String percent) {
    return 'Depuis $name · $percent';
  }

  @override
  String get compositionEmpty => 'Aucune transaction dans ce montant.';

  @override
  String get compositionTotal => 'Total';

  @override
  String compositionPeriod(String month, String year) {
    return '$month $year';
  }

  @override
  String keyFiguresTitle(String year) {
    return 'Chiffres clés $year';
  }

  @override
  String get keyFiguresHint => 'Vue économique : ce que l\'année coûte.';

  @override
  String get keyFiguresOpen => 'Voir l\'année';

  @override
  String get redistributionMenu => 'Redistribution';

  @override
  String redistributionTitle(String year) {
    return 'Redistribution $year';
  }

  @override
  String get redistributionExplain =>
      'Chaque mois, le pourcentage du montant de la source passe dans la cible, sur une ligne distincte de chaque côté, dans les deux vues.';

  @override
  String get redistributionEmpty => 'Aucune règle de redistribution cette année.';

  @override
  String get redistributionNoTree => 'Cette année n\'a pas encore d\'arbre.';

  @override
  String get redistributionNew => 'Nouvelle règle';

  @override
  String get redistributionEdit => 'Modifier la règle';

  @override
  String get redistributionSource => 'Source';

  @override
  String get redistributionTarget => 'Cible';

  @override
  String get redistributionPercent => 'Pourcentage';

  @override
  String get redistributionPercentHint => 'De 0.01 à 100, deux décimales au plus.';

  @override
  String redistributionRule(String source, String target) {
    return 'De $source vers $target';
  }

  @override
  String get redistributionSaved => 'Règle enregistrée.';

  @override
  String get redistributionDeleted => 'Règle supprimée.';

  @override
  String get redistributionDeleteConfirm => 'Supprimer cette règle de redistribution ?';

  @override
  String get redistributionChooseSource => 'Choisissez la source.';

  @override
  String get redistributionChooseTarget => 'Choisissez la cible.';

  @override
  String get redistributionProblemSourceMissing =>
      'Ne s\'applique pas : la source n\'est plus dans l\'arbre de l\'année.';

  @override
  String get redistributionProblemTargetMissing =>
      'Ne s\'applique pas : la cible n\'est plus dans l\'arbre de l\'année.';

  @override
  String get redistributionProblemSourceNotLeaf => 'Ne s\'applique pas : la source a des sous-catégories.';

  @override
  String get redistributionProblemTargetNotLeaf => 'Ne s\'applique pas : la cible a des sous-catégories.';

  @override
  String get redistributionProblemSameCategory => 'Ne s\'applique pas : la source et la cible sont la même catégorie.';

  @override
  String get redistributionProblemNatureMismatch =>
      'Ne s\'applique pas : la source et la cible ne sont pas de même nature.';

  @override
  String get redistributionProblemPercentInvalid => 'Ne s\'applique pas : le pourcentage n\'est pas entre 0.01 et 100.';

  @override
  String get redistributionProblemOverHundred => 'Ne s\'applique pas : les règles de cette source dépassent 100 %.';

  @override
  String get redistributionProblemChain => 'Ne s\'applique pas : une cible est aussi la source d\'une règle.';

  @override
  String taskInapplicableRedistributions(int count, String year) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count règles de redistribution ne s\'appliquent pas',
      one: 'Une règle de redistribution ne s\'applique pas',
    );
    return '$_temp0 en $year';
  }

  @override
  String get taskInapplicableRedistributionsHint => 'Corrigez-les ou supprimez-les.';

  @override
  String taskShares(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count parts à classer',
      one: 'Une part à classer',
    );
    return '$_temp0';
  }

  @override
  String get taskSharesHint => 'Des montants reportés sur une autre année n\'y trouvent pas leur catégorie.';

  @override
  String taskBrokenRefunds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count remboursements ont perdu leur dépense',
      one: 'Un remboursement a perdu sa dépense',
    );
    return '$_temp0';
  }

  @override
  String get taskBrokenRefundsHint =>
      'Ils comptent dans leur propre catégorie : détachez-les ou rattachez-les à une autre dépense.';

  @override
  String get classifyRefund => 'Remboursement';

  @override
  String get refundExpense => 'Dépense remboursée';

  @override
  String get refundPick => 'Choisir la dépense';

  @override
  String get refundSearch => 'Texte ou montant de la dépense';

  @override
  String get refundNoExpense => 'Aucune dépense validée trouvée.';

  @override
  String get refundExpenseMissing => 'Choisissez la dépense remboursée.';

  @override
  String get refundHint => 'Le remboursement prend la catégorie et la période de sa dépense, qui affiche son coût net.';

  @override
  String get refundAttached => 'Remboursement rattaché.';

  @override
  String get refundDetach => 'Détacher';

  @override
  String get refundDetached => 'Remboursement détaché.';

  @override
  String get refundAttach => 'Rattacher à une dépense';

  @override
  String get detailRefunds => 'Remboursements';

  @override
  String get detailNetCost => 'Coût net';

  @override
  String get detailRefundOf => 'Rembourse';

  @override
  String get detailBrokenLink =>
      'La dépense de ce remboursement n\'existe plus ou n\'est plus une dépense validée : il compte dans sa propre catégorie, à sa date.';

  @override
  String get entryRefund => 'Rembourse une dépense';

  @override
  String get brokenRefundsTitle => 'Remboursements sans dépense';

  @override
  String get sharesTitle => 'Parts à classer';

  @override
  String get sharesEmpty => 'Aucune part à classer.';

  @override
  String sharesGroup(String origin, String originYear, String year) {
    return '$origin $originYear, parts de $year';
  }

  @override
  String sharesExplain(String year, String name) {
    return 'L\'arbre de $year n\'a pas de catégorie « $name » qui puisse recevoir ces montants. La réponse est mémorisée pour chaque ligne.';
  }

  @override
  String sharesCategory(String year) {
    return 'Catégorie en $year';
  }

  @override
  String get sharesClassifyGroup => 'Classer le groupe';

  @override
  String get sharesClassified => 'Parts classées.';

  @override
  String get sharesChoose => 'Choisissez une catégorie.';

  @override
  String get sharesLineCategory => 'Pour cette ligne seulement';

  @override
  String yearInapplicable(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count règles de redistribution ne s\'appliquent pas',
      one: 'Une règle de redistribution ne s\'applique pas',
    );
    return '$_temp0 cette année.';
  }

  @override
  String get errorUnknownBalance => 'Ce solde n\'existe plus.';

  @override
  String get errorBalanceOnDetailedAccount =>
      'Le solde du compte détaillé vient de ses relevés : il ne se déclare pas.';

  @override
  String get errorBalanceOnDebtsAccount =>
      'Un compte « Dettes » n\'a pas de solde propre : la fortune compte les dettes du tableau des dettes.';

  @override
  String get errorBalanceInFuture => 'Un solde ne se déclare pas pour une date future.';

  @override
  String accountArchivedBalances(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count soldes déclarés l\'utilisent',
      one: 'un solde déclaré l\'utilise',
    );
    return 'Compte archivé et non supprimé : $_temp0. Il reste dans la fortune avec son dernier solde ; déclarez un solde de 0 pour l\'en sortir.';
  }

  @override
  String get errorUnknownDebt => 'Cette dette n\'existe plus.';

  @override
  String get errorDebtPersonRequired => 'Indiquez la personne.';

  @override
  String get errorDebtPercentInvalid => 'Indiquez un pourcentage entre 0.01 et 100, avec deux décimales au plus.';

  @override
  String get errorDebtReceivedBeforeEvent => 'La date de réception ne peut pas précéder la date de l\'événement.';

  @override
  String get errorDebtSplitOutOfTotal =>
      'La première part doit être supérieure à zéro et inférieure au total de la dette.';
}
