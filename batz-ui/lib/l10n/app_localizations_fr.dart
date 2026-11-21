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
}
